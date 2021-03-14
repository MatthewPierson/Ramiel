/*-
 * Copyright 2015 Pupyshev Nikita
 * All rights reserved
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted providing that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include "ibootim.h"
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>

#include "png.h"
#include "lzss.h"

#define IBOOTIM_HEADER_SIZE sizeof(struct ibootim_header)

typedef struct {
	uint8_t brightness;
	uint8_t alpha;
} ibootim_grayscale_pixel;

typedef struct {
	uint8_t blue;
	uint8_t green;
	uint8_t red;
	uint8_t alpha;
} ibootim_argb_pixel;

typedef struct {
	uint8_t red;
	uint8_t green;
	uint8_t blue;
	uint8_t alpha;
} pixel_rgba_8;

typedef struct {
	uint8_t brightness;
	uint8_t alpha;
} pixel_grayscale_8;

typedef struct {
	uint16_t red;
	uint16_t green;
	uint16_t blue;
	uint16_t alpha;
} pixel_rgba_16;

typedef struct {
	uint16_t brightness;
	uint16_t alpha;
} pixel_grayscale_16;

const char *ibootim_signature = "iBootIm";

struct ibootim_header {
	char signature[8];
	uint32_t adler;
	uint32_t compressionType;
	uint32_t colorSpace;
	uint16_t width;
	uint16_t height;
	int16_t offsetX;
	int16_t offsetY;
	uint32_t compressedSize;
	uint32_t reserved[8];
};

typedef union {
	ibootim_argb_pixel *argb;
	ibootim_grayscale_pixel *grayscale;
	void *pointer;
} ibootim_pixel_buffer_t;

typedef struct ibootim {
	uint16_t width;
	uint16_t height;
	int16_t offsetX;
	int16_t offsetY;
	ibootim_compression_type_t compressionType;
	ibootim_color_space_t colorSpace;
	ibootim_pixel_buffer_t pixels;
} ibootim;

static unsigned _adler32(unsigned adler, const unsigned char* data, unsigned len) {
	unsigned s1 = adler & 0xffff;
	unsigned s2 = (adler >> 16) & 0xffff;
	
	while(len > 0) {
		/*at least 5550 sums can be done before the sums overflow, saving a lot of module divisions*/
		unsigned amount = len > 5550 ? 5550 : len;
		len -= amount;
		while(amount > 0) {
			s1 += (*data++);
			s2 += s1;
			--amount;
		}
		s1 %= 65521;
		s2 %= 65521;
	}
	
	return (s2 << 16) | s1;
}

static void *_ibootim_pixel_ptr_at(ibootim *image, uint16_t x, uint16_t y);
static void _ibootim_set_pixel_with_params(ibootim *image, void *png_pixel, uint16_t x, uint16_t y, int bit_depth, int has_alpha);
static inline void *_ibootim_get_row(ibootim *image, unsigned int row);

static unsigned int _ibootim_pixel_size_for_color_space(ibootim_color_space_t colorSpace) {
	switch (colorSpace) {
		case ibootim_color_space_argb:
			return sizeof(ibootim_argb_pixel);
		case ibootim_color_space_grayscale:
			return sizeof(ibootim_grayscale_pixel);
		default:
			return 0; //invalid color space value
	}
}

static int _ibootim_sanity_check_header(struct ibootim_header *imageHeader, const char **errDst) {
	ibootim_color_space_t colorSpace;
	ibootim_compression_type_t compressionType;
	
	//check if header has proper magic
	if (memcmp(imageHeader->signature, ibootim_signature, 8) != 0) {
		if (errDst != NULL) *errDst = "header does not have \"iBootIm\" signature";
		return -1;
	}
	//check if compression type field has valid value
	compressionType = imageHeader->compressionType;
	if (compressionType != ibootim_compression_type_lzss) {
		if (errDst != NULL) *errDst = "invalid compression type field value";
		return -1;
	}
	//check if color space field has known value
	colorSpace = imageHeader->colorSpace;
	if (colorSpace != ibootim_color_space_argb &&
		colorSpace != ibootim_color_space_grayscale) {
		if (errDst != NULL) *errDst = "invalid color space field value";
		return -1;
	}
	
	return 0;
}

static unsigned int _ibootim_get_pixel_buffer_size(ibootim *image) {
	unsigned int width = image->width, height = image->height;
	unsigned int pixelSize = _ibootim_pixel_size_for_color_space(image->colorSpace);
	return width * height * pixelSize;
}

int ibootim_load(const char *path, ibootim **handle) {
	return ibootim_load_at_index(path, handle, 0);
}

int ibootim_load_at_index(const char *path, ibootim **handle, unsigned int targetIndex) {
	int rc;
	const char *errorDesc;
	ssize_t items;
	FILE *inputFile;
	struct ibootim_header header;
	unsigned int width, height;
	unsigned int pixelsCount, pixelSize, compressedSize;
	ssize_t expectedUncompressedSize, actualUncompressedSize;
	
	if (targetIndex == UINT_MAX) {
		printf("[-] INTERNAL ERROR: iBootIm image index is equal to UINT_MAX.");
		return EINVAL;
	}
	
	inputFile = fopen(path, "r");
	if (!inputFile) {
		printf("[-] Failed to open '%s': %s, aborting.\n", path, strerror(errno));
		return ENOENT;
	}
	
	for (unsigned int i = 0; i <= targetIndex; i++) {
		//This complex structure was introduced to handle both errors in one place
		items = fread(&header, sizeof(header), 1, inputFile);
		if (items == 1) {
			//sanity check the header
			rc = _ibootim_sanity_check_header(&header, &errorDesc);
			if (rc != 0) {
				printf("[-] Invalid iBootIm image header: %s.\n", errorDesc);
				fclose(inputFile);
				return EFTYPE;
			}
			
			//We don't need to skip the compressed data of the image we are going
			//to load.
			if (i != targetIndex) {
				compressedSize = header.compressedSize;
				rc = fseek(inputFile, compressedSize, SEEK_CUR);
			} else {
				rc = 0;
			}
		} else {
			rc = -1;
		}
		
		//Check if an error occurred during file I/O and handle report it to the
		//user if so.
		if (rc != 0) {
			if (feof(inputFile)) {
				printf("[-] iBootIm file is either truncated or image index is out of bounds.\n");
				rc = EFTYPE;
			} else {
				printf("[-] An I/O error occurred while reading iBootIm header at index %u (offset %lu): %s.\n", i, ftell(inputFile), strerror(ferror(inputFile)));
				rc = EIO;
			}
			fclose(inputFile);
			return rc;
		}
	}
	
	//No integer overflow should occur, since header.width and header.height
	//are uint16_t, all the following variables are unsigned int.
	width = header.width;
	height = header.height;
	pixelsCount = width * height;
	pixelSize = _ibootim_pixel_size_for_color_space(header.colorSpace);
	//Finally we get to the compressed and uncompressed sizes, not verifying
	//them yet.
	compressedSize = header.compressedSize;
	expectedUncompressedSize = pixelsCount * pixelSize;
	
	//Read compressed image data.
	void *compressedData = malloc(compressedSize);
	if (!compressedData) {
		fclose(inputFile);
		printf("[-] Can not allocate memory for compressed image data, aborting.\n");
		return ENOMEM;
	}
	items = fread(compressedData, 1, compressedSize, inputFile);
	//nothing else will be read here, so close the file
	fclose(inputFile);
	if (items != compressedSize) {
		//Determine what kind of error has occurred.
		if (feof(inputFile)) {
			printf("[-] iBootIm image data is truncated.\n");
			rc = EFTYPE;
		} else {
			printf("[-] An I/O error occurred while reading iBootIm image data: %s.\n", strerror(ferror(inputFile)));
			rc = EIO;
		}
		//clean up and return error code
		free(compressedData);
		return rc;
	}
	
	unsigned headerAdler = _adler32(1,
									(void *)&header.compressionType,
									sizeof(header) - offsetof(struct ibootim_header, compressionType));
	unsigned imageAdler = _adler32(headerAdler, compressedData, compressedSize);
	if (header.adler != imageAdler) {
		printf("[!] Checksum in the header is not valid (0x%08x != 0x%08x).\n", imageAdler, header.adler);
	}
	
	//decompress pixel data
	void *pixelData = malloc(expectedUncompressedSize);
	actualUncompressedSize = lzss_decompress(pixelData,
											 (unsigned int)expectedUncompressedSize,
											 compressedData,
											 compressedSize);
	free(compressedData);
	if (actualUncompressedSize <= 0) {
		free(pixelData);
		printf("[-] An error occurred during decompression of pixel data, aborting.\n");
		return EFTYPE;
	} else if (actualUncompressedSize != expectedUncompressedSize) {
		printf("[!] Actual length of uncompressed pixel data is less than expected.");
		memset(&pixelData[actualUncompressedSize], 0, expectedUncompressedSize - actualUncompressedSize);
	}
	
	//finally allocate memory for ibootim structure and fill it
	ibootim *image = malloc(sizeof(ibootim));
	if (!image) {
		free(pixelData);
		printf("[-] Memory allocation error, aborting.\n");
		return ENOMEM;
	}
	image->width = width;
	image->height = height;
	image->offsetX = header.offsetX;
	image->offsetY = header.offsetY;
	image->compressionType = header.compressionType;
	image->colorSpace = header.colorSpace;
	image->pixels.pointer = pixelData;
	
	//write handle and return the image gracefully
	*handle = image;
	return 0;
};

int ibootim_convert_to_colorspace(ibootim *image, ibootim_color_space_t targetColorSpace) {
	int rc;
	ibootim_color_space_t sourceColorSpace;
	ibootim_argb_pixel *argbPixelPtr;
	ibootim_grayscale_pixel *grayscalePixelPtr;
	size_t pixelsCount, bufferSize;
	void *pixelBuffer;
	
	sourceColorSpace = image->colorSpace;
	if (sourceColorSpace == targetColorSpace) return 0; // nothing to do here
	pixelsCount = image->width * image->height;
	
	if (targetColorSpace == ibootim_color_space_grayscale) {
		if (sourceColorSpace == ibootim_color_space_argb) {
			argbPixelPtr = image->pixels.argb;
			grayscalePixelPtr = image->pixels.grayscale;
			
			puts("[*] Converting image from argb to grayscale color space...");
			
			uint8_t brightness, alpha;
			for (unsigned int i = 0; i < pixelsCount; i++) {
				//first get the values, since structures are in the same buffer
				alpha = argbPixelPtr->alpha;
				brightness = ((unsigned int)argbPixelPtr->red +
							  (unsigned int)argbPixelPtr->green +
							  (unsigned int)argbPixelPtr->blue) / 3;
				//then write them down
				grayscalePixelPtr->brightness = brightness;
				grayscalePixelPtr->alpha = alpha;
				//finally advance the pointers
				argbPixelPtr++;
				grayscalePixelPtr++;
			}
			
			//Try to reallocate the buffer and leave it as is if we get an error for
			//some weird reason.
			bufferSize = pixelsCount * sizeof(ibootim_grayscale_pixel);
			pixelBuffer = realloc(image->pixels.pointer, bufferSize);
			if (pixelBuffer) image->pixels.pointer = pixelBuffer;
			else {
				puts("[!] Reducing image pixel buffer size failed, leaving as-is.");
			}
			
			//Set colorSpace field after it's all done and return success.
			image->colorSpace = ibootim_color_space_grayscale;
			rc = 0;
		} else {
			printf("[-] INTERNAL ERROR: Invalid source color space value 0x%08x.\n", sourceColorSpace);
			rc = EFAULT;
		}
	} else if (targetColorSpace == ibootim_color_space_argb) {
		if (sourceColorSpace == ibootim_color_space_grayscale) {
			//Try to increase the buffer size and abort if that is not possible.
			bufferSize = pixelsCount * sizeof(ibootim_grayscale_pixel);
			pixelBuffer = realloc(image->pixels.pointer, bufferSize);
			if (pixelBuffer) image->pixels.pointer = pixelBuffer;
			else {
				puts("[-] Increasing image pixel buffer size failed, aborting.");
				return ENOMEM;
			}
			
			//Assign pointers after the buffer has been reallocated.
			argbPixelPtr = &image->pixels.argb[pixelsCount];
			grayscalePixelPtr = &image->pixels.grayscale[pixelsCount];
			
			puts("[*] Converting image from grayscale to argb color space...");
			
			//Convert pixels from the last one to the first one to not overwrite
			//unconverted grayscale pixels with converted argb pixels.
			uint8_t brightness, alpha;
			for (size_t i = pixelsCount; i > 0; i--) {
				//First reduce the pointers.
				argbPixelPtr--;
				grayscalePixelPtr--;
				//Then read alpha and brightness before the may be overwritten.
				alpha = grayscalePixelPtr->alpha;
				brightness = grayscalePixelPtr->brightness;
				//Finally write them down to the argb pixel.
				argbPixelPtr->red = argbPixelPtr->green = argbPixelPtr->blue = brightness;
				argbPixelPtr->alpha = alpha;
			}
			
			//Set colorSpace field after it's all done and return success.
			image->colorSpace = ibootim_color_space_argb;
			rc = 0;
		} else {
			printf("[-] INTERNAL ERROR: Invalid source color space value 0x%08x.\n", sourceColorSpace);
			rc = EFAULT;
		}
	} else {
		printf("[-] INTERNAL ERROR: Invalid target color space value 0x%08x.\n", targetColorSpace);
		rc = EFAULT;
	}
	
	return rc;
}

int ibootim_write(ibootim *image, const char *path) {
	int rc;
	FILE *outputFile;
	struct ibootim_header header;
	unsigned int uncompressedSize = _ibootim_get_pixel_buffer_size(image);
	unsigned int estimatedMaxCompSize = uncompressedSize;
	ssize_t actualCompSize;
	
	outputFile = fopen(path, "w");
	if (!outputFile) {
		printf("[-] Failed to open '%s' for writing: %s\n", path, strerror(errno));
		return ENOENT;
	}
	ftruncate(fileno(outputFile), 0);
	
	memcpy(header.signature, ibootim_signature, 8);
	header.width = image->width;
	header.height = image->height;
	header.offsetX = image->offsetX;
	header.offsetY = image->offsetY;
	header.colorSpace = image->colorSpace;
	header.compressionType = image->compressionType;
	memset(header.reserved, 0, sizeof(header.reserved));
	
	void *compressedDataBuf = malloc(estimatedMaxCompSize);
	if (!compressedDataBuf) {
		printf("[-] Memory allocation failed\n");
		return ENOMEM;
	}
	
	//do this while buffer is not large enough
	while ((actualCompSize = lzss_compress(compressedDataBuf,
										   estimatedMaxCompSize,
										   image->pixels.pointer,
										   uncompressedSize)) <= 0) {
		if (lzss_errno != LZSS_NOMEM) {
			printf("[-] An error occurred while compressing pixel data, aborting.\n");
			free(compressedDataBuf);
			return EFAULT;
		} else {
			printf("[!] Compressed pixel data is longer than expected, enlarging buffer.\n");
			estimatedMaxCompSize += 0x100;
			free(compressedDataBuf);
			compressedDataBuf = malloc(estimatedMaxCompSize);
			if (!compressedDataBuf) {
				printf("[-] Larger buffer allocation failed, aborting.\n");
				return ENOMEM;
			}
		}
	}
	
	//complete the header and write it along with data
	header.compressedSize = (uint32_t)actualCompSize;
	unsigned headerAdler = _adler32(1, (void *)&header.compressionType, sizeof(header) - offsetof(struct ibootim_header, compressionType));
	unsigned imageAdler = _adler32(headerAdler, compressedDataBuf, (unsigned)actualCompSize);
	header.adler = imageAdler;
	rc = (int)fwrite(&header, sizeof(header), 1, outputFile);
	if (rc != 1) {
		printf("[-] Failed to write iBootIm header, aborting.\n");
		free(compressedDataBuf);
		return EIO;
	}
	rc = (int)fwrite(compressedDataBuf, (uint32_t)actualCompSize, 1, outputFile);
	free(compressedDataBuf);
	if (rc != 1) {
		printf("[-] Failed to write compressed pixel data, aborting.\n");
		return EIO;
	}
	
	printf("[+] iBootIm image was written to '%s'.\n", path);
	return 0;
}

int ibootim_load_png(const char *path, ibootim **handle) {
	FILE *f = fopen(path, "rb");
	if (!f) {
		puts("Failed to open file.");
		return -1;
	}
	
	//check if file has PNG signature
	char fileSignature[8];
	fread(fileSignature, 1, 8, f);
	if (png_sig_cmp((png_const_bytep)fileSignature, 0, 8) != 0) {
		fclose(f);
		puts("Not a png.");
		return -1;
	}
	
	ibootim *image = malloc(sizeof(ibootim));
	if (!image) {
		fclose(f);
		puts("malloc");
		return -1;
	}
	memset(image, 0, sizeof(ibootim));
	
	png_structp read_struct = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (!read_struct) {
		fclose(f);
		puts("Failed to make read struct.");
		return -1;
	}
	
	png_infop info_struct = png_create_info_struct(read_struct);
	if (!info_struct) {
		png_destroy_read_struct(&read_struct, NULL, NULL);
		fclose(f);
		puts("Failed to make info struct.");
		return -1;
	}
	
	//setup error handling
	if (setjmp(png_jmpbuf(read_struct)))
	{
		png_destroy_read_struct(&read_struct, &info_struct, NULL);
		fclose(f);
		puts("libpng error");
		return -1;
	}
	
	//init i/o
	png_init_io(read_struct, f);
	png_set_sig_bytes(read_struct, 8);
	
	//read info
	png_read_info(read_struct, info_struct);
	
	//read common info
	uint32_t width = png_get_image_width(read_struct, info_struct);
	uint32_t height = png_get_image_height(read_struct, info_struct);
	uint8_t color_type = png_get_color_type(read_struct, info_struct);
	uint8_t bit_depth = png_get_bit_depth(read_struct, info_struct);
	
	//convert 16-bit colors to 8-bit
	if (bit_depth == 16) {
		png_set_strip_16(read_struct);
	}
	
	//add alpha if not present
	if ((color_type & PNG_COLOR_MASK_ALPHA) == 0) {
		png_set_add_alpha(read_struct, 0, PNG_FILLER_AFTER);
	}
	png_set_invert_alpha(read_struct);
	
	//if we have RGB colors, convert them to bgr
	if ((color_type == PNG_COLOR_TYPE_RGB) || (color_type == PNG_COLOR_TYPE_RGBA)) {
	    png_set_bgr(read_struct);
	} else if (color_type == PNG_COLOR_TYPE_GA) {
		//png_set_swap_alpha(read_struct);
	}
	
	//update structures after setting properties
	png_read_update_info(read_struct, info_struct);
	
	//fill in ibootim image properties
	image->width = width;
	image->height = height;
	image->offsetX = 0;
	image->offsetY = 0;
	image->compressionType = ibootim_compression_type_lzss;
	unsigned int pixelSize;
	if ((color_type == PNG_COLOR_TYPE_RGB) || (color_type == PNG_COLOR_TYPE_RGBA)) {
		image->colorSpace = ibootim_color_space_argb;
		pixelSize = 4;
	} else {//if ((color_type == PNG_COLOR_TYPE_GRAY) || (color_type == PNG_COLOR_TYPE_GA)) {
		image->colorSpace = ibootim_color_space_grayscale;
		pixelSize = 2;
	}
	image->pixels.pointer = malloc(width * height * pixelSize);
	
	//allocate and fill in array for rows
	void **rows = (void **)malloc(height * sizeof(void *));
	if (!rows) {
		printf("Failed to alloc rows\n");
		return -1;
	}
	for (uint16_t y = 0; y < height; y++)
		rows[y] = _ibootim_get_row(image, y);
	
	//read color data
	png_read_image(read_struct, (png_bytepp)rows);
	
	free(rows);
	png_read_end(read_struct, NULL);
	png_destroy_read_struct(&read_struct, &info_struct, NULL);
	
	*handle = image;
	return 0;
	
	/*if (path && handle) {
		FILE *f = fopen(path, "rb");
		if (f) {
			char png_sig[8];
			fread(png_sig, 1, 8, f);
			if (png_sig_cmp((png_const_bytep)png_sig, 0, 8) == 0) {
				png_structp read_struct = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
				if (read_struct) {
					png_info *info_struct = png_create_info_struct(read_struct);
					if (info_struct) {
						ibootim *image = malloc(sizeof(ibootim));
						if (image) {
							image->compressionType = ibootim_compression_type_lzss;
							image->offsetX = 0;
							image->offsetY = 0;
							image->pixels.pointer = NULL;
							
							if (setjmp(png_jmpbuf(read_struct))) {
								ret = EFAULT;
								
								if (image) {
									if (image->pixels.pointer) free(image->pixels.pointer);
									free(image);
								}
								
								goto end;
							}
							
							png_init_io(read_struct, f);
							png_set_sig_bytes(read_struct, 8);
							
							png_read_info(read_struct, info_struct);
							
							uint32_t width = png_get_image_width(read_struct, info_struct);
							uint32_t height = png_get_image_height(read_struct, info_struct);
							image->width = width;
							image->height = height;
							
							uint8_t color_type = png_get_color_type(read_struct, info_struct);
							uint8_t bit_depth = png_get_bit_depth(read_struct, info_struct);
							int has_alpha = (color_type & PNG_COLOR_MASK_ALPHA) >> 2;
							color_type &= ~PNG_COLOR_MASK_ALPHA;
							image->colorSpace = color_type == PNG_COLOR_TYPE_GRAY ? ibootim_color_space_grayscale : ibootim_color_space_argb;
							
							if (((color_type == PNG_COLOR_TYPE_GRAY) || (color_type == PNG_COLOR_TYPE_RGB)) && (bit_depth == 8)) {
								if (color_type == PNG_COLOR_TYPE_RGB) image->colorSpace = ibootim_color_space_argb;
								else image->colorSpace = ibootim_color_space_grayscale;
								
								int pixel_size = ibootim_get_pixel_size(image);
								
								void *contents = malloc(width * height * pixel_size);
								if (contents) {
									image->pixels.pointer = contents;
									
									if (!has_alpha) {
										png_set_add_alpha(read_struct, 0, PNG_FILLER_AFTER);
									}
									png_set_interlace_handling(read_struct);
									png_set_invert_alpha(read_struct);
									png_set_bgr(read_struct);
									
									png_read_update_info(read_struct, info_struct);
									
									void **rows = malloc(height * sizeof(void *));
									if (rows)
										for (uint16_t y = 0; y < height; y++)
											rows[y] = _ibootim_get_row(image, y);
									
									png_read_image(read_struct, (png_bytepp)rows);
									
									free(rows);
									ret = 0;
									*handle = image;
								}
							}
							
						end:
							png_destroy_info_struct(read_struct, &info_struct);
						} else ret = ENOMEM;
					} else ret = ENOMEM;
					png_destroy_read_struct(&read_struct, &info_struct, NULL);
				}
			} else ret = EFTYPE;
			fclose(f);
		}
	}
	
	return ret;*/
}

int ibootim_write_png(ibootim *image, const char *path) {
	int ret = -1;
	
	png_structp write_struct = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (!write_struct) return -1;
	
	png_info *info_struct = png_create_info_struct(write_struct);
	if (!info_struct) goto error;
	
	if (setjmp(png_jmpbuf(write_struct))) goto error;
	
	png_init_io(write_struct, fopen(path, "wb"));
	//png_set_sig_bytes(write_struct, 8);
	
	uint32_t color_space = image->colorSpace;
	int color_type, transforms = PNG_TRANSFORM_INVERT_ALPHA;
	if (color_space == ibootim_color_space_argb) {
		color_type = PNG_COLOR_TYPE_RGBA;
		transforms |= PNG_TRANSFORM_BGR;
	} else {
		color_type = PNG_COLOR_TYPE_GA;
		transforms |= PNG_TRANSFORM_IDENTITY;
	}
	
	png_set_IHDR(write_struct,
				 info_struct,
				 image->width,
				 image->height,
				 8,
				 color_type,
				 PNG_INTERLACE_NONE,
				 PNG_COMPRESSION_TYPE_DEFAULT,
				 PNG_FILTER_TYPE_DEFAULT);
	//png_set_invert_alpha(write_struct);
	//png_set_bgr(write_struct);
	
	void **rows = png_malloc(write_struct, image->height * sizeof(void *));
	
	for (uint16_t y = 0; y < image->height; y++)
		rows[y] = _ibootim_get_row(image, y);
	
	png_set_rows(write_struct, info_struct, (png_bytepp)rows);
	png_write_png(write_struct, info_struct, transforms, NULL);
	
	png_free(write_struct, rows);
	ret = 0;
	
error:
	png_destroy_write_struct(&write_struct, &info_struct);
	
	return ret;
}

void ibootim_close(ibootim *image) {
	if (image) {
		if (image->pixels.pointer) free(image->pixels.pointer);
		free(image);
	}
}

bool file_is_ibootim(const char *path) {
	struct ibootim_header header;
	int result = 0;
	int fd = open(path, O_RDONLY);
	if (fd) {
		if (read(fd, &header, sizeof(struct ibootim_header)) == sizeof(struct ibootim_header)) {
			result = _ibootim_sanity_check_header(&header, NULL) == 0;
		}
		close(fd);
	}
	return result;
}

/* Properties */

uint16_t ibootim_get_width(ibootim *image) {
	return image->width;
}

uint16_t ibootim_get_height(ibootim *image) {
	return image->height;
}

int16_t ibootim_get_x_offset(ibootim *image) {
	return image->offsetX;
}

int16_t ibootim_get_y_offset(ibootim *image) {
	return image->offsetY;
}

void ibootim_set_x_offset(ibootim *image, int16_t offset) {
	image->offsetX = offset;
}

void ibootim_set_y_offset(ibootim *image, int16_t offset) {
	image->offsetY = offset;
}

ibootim_color_space_t ibootim_get_color_space(ibootim *image) {
	return image->colorSpace;
}
	
ibootim_compression_type_t ibootim_get_compression_type(ibootim *image) {
	return image->compressionType;
}

unsigned int ibootim_get_pixel_size(ibootim *image) {
	if (image->colorSpace == ibootim_color_space_argb) return 4;
	else if (image->colorSpace == ibootim_color_space_grayscale) return 2;
	else return 0;
}

/* Private functions */

static void _ibootim_set_pixel_with_params(ibootim *image, void *png_pixel, uint16_t x, uint16_t y, int bit_depth, int has_alpha) {
	int png_pixel_size = bit_depth / 8;
	
	if (image->colorSpace == ibootim_color_space_argb) {
		png_pixel_size *= 3 + (has_alpha != 0);
		
		if (bit_depth == 8) {
			pixel_rgba_8 *png_rgba_pixel = png_pixel;
			ibootim_argb_pixel *pixel = _ibootim_pixel_ptr_at(image, x, y);
			
			pixel->red = png_rgba_pixel->red;
			pixel->green = png_rgba_pixel->green;
			pixel->blue = png_rgba_pixel->blue;
			if (has_alpha) pixel->alpha = ~png_rgba_pixel->alpha;
			else pixel->alpha = 0xff;
		}
		else if (bit_depth == 16) {
			pixel_rgba_16 *png_rgba_pixel = png_pixel;
			ibootim_argb_pixel *pixel = _ibootim_pixel_ptr_at(image, x, y);
			
			pixel->red = png_rgba_pixel->red / 0x100;
			pixel->green = png_rgba_pixel->green / 0x100;
			pixel->blue = png_rgba_pixel->blue / 0x100;
			if (has_alpha) pixel->alpha = png_rgba_pixel->alpha / 0x100;
			else pixel->alpha = 0xff;
		}
	} else {
		if (has_alpha) png_pixel_size *= 2;
		
		if (bit_depth == 8) {
			pixel_grayscale_8 *png_rgba_pixel = png_pixel;
			ibootim_grayscale_pixel *pixel = _ibootim_pixel_ptr_at(image, x, y);
			
			pixel->brightness = png_rgba_pixel->brightness;
			if (has_alpha) pixel->alpha = png_rgba_pixel->alpha;
			else pixel->alpha = 0xff;
		}
		else if (bit_depth == 16) {
			pixel_grayscale_16 *png_rgba_pixel = png_pixel;
			ibootim_grayscale_pixel *pixel = _ibootim_pixel_ptr_at(image, x, y);
			
			pixel->brightness = png_rgba_pixel->brightness / 0x100;
			if (has_alpha) pixel->alpha = png_rgba_pixel->alpha / 0x100;
			else pixel->alpha = 0xff;
		}
	}
}

int ibootim_count_images_in_file(const char *path, int *error) {
	FILE *file;
	int ret = -1;
	struct ibootim_header header;
	
	file = fopen(path, "r");
	if (!file) {
		if (error) *error = ENOENT;
		return -1;
	}
	
	unsigned int count = 0;
	while (fread(&header, sizeof(header), 1, file) == 1) {
		if (_ibootim_sanity_check_header(&header, NULL) != 0) break;
		if (fseek(file, header.compressedSize, SEEK_CUR) == -1) break;
		count++;
	}
	ret = count;
	if (error) *error = 0;
	
	fclose(file);
	return ret;
}

static inline void *_ibootim_pixel_ptr_at(ibootim *image, uint16_t x, uint16_t y) {
	return (void *)image->pixels.pointer + (y * image->width + x) * ibootim_get_pixel_size(image);
}

static inline void *_ibootim_get_row(ibootim *image, unsigned int row) {
	int offset = image->width * ibootim_get_pixel_size(image);
	return image->pixels.pointer + offset * row;
}
