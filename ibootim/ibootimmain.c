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

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdbool.h>
#include <getopt.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "png.h"
#include "ibootim.h"
#include "lzss.h"

const char *license = "\nCopyright 2015 Pupyshev Nikita\n\
All rights reserved\n\
\n\
Redistribution and use in source and binary forms, with or without\n\
modification, are permitted providing that the following conditions\n\
are met:\n\
1. Redistributions of source code must retain the above copyright\n\
   notice, this list of conditions and the following disclaimer.\n\
2. Redistributions in binary form must reproduce the above copyright\n\
   notice, this list of conditions and the following disclaimer in the\n\
   documentation and/or other materials provided with the distribution.\n\
\n\
THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR\n\
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED\n\
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE\n\
ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY\n\
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL\n\
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS\n\
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)\n\
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,\n\
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING\n\
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE\n\
POSSIBILITY OF SUCH DAMAGE.\n";

const char *warning_fmt_len_less_m = "WARNING: Content length of image %u is shorter than expected.\n";
const char *warning_fmt_len_less_o = "WARNING: Content length is shorter than expected.\n";
const char *warning_fmt_len_more_m = "WARNING: Content length of image %u is longer than expected.\n";
const char *warning_fmt_len_more_o = "WARNING: Content length is longer than expected.\n";
const char *error_fmt_create_png_m = "ERROR: Failed to create a PNG file for image %u.\n";
const char *error_fmt_create_png_o = "ERROR: Failed to create a PNG file.\n";
const char *error_fmt_image_corrupt_m = "ERROR: Image %u is corrupt.\n";
const char *error_fmt_image_corrupt_o = "ERROR: iBoot Embedded Image is corrupt.\n";

const char *warning_fmt_len_less;
const char *warning_fmt_len_more;
const char *error_fmt_create_png;
const char *error_fmt_image_corrupt;

void show_license() {
	puts(license);
}

void show_usage() {
	puts("Usage: ibootim [-x <x offset> -y <y offset>] [-l -W <width> -H <height>] [-c | -g] <infile> <outfile>\n"
		 "    or  ibootim license\n"
		 "\n"
		 "    Description:\n"
		 "     Converts PNGs to iBoot Embedded Images and vice versa.\n"
		 "\n"
		 "    Parameters:\n"
		 "     infile - PNG or iBoot Embedded Image file.\n"
		 "     outfile - path where converted image will be written.\n"
		 "     x/y offset - offsets that will be written into iBoot Embedded\n"
		 "                  Image file. Hex numbers are allowed. If input file\n"
		 "                  is an iBoot Embedded Image, offsets are ignored.\n"
		 "\n"
		 "    Non-zero offsets are outputted if the input file is an iBoot\n"
		 "    Embedded Image.\n"
		 "\n"
		 "    You can safely ignore the content length warning.");
}

bool file_is_png(const char *file) {
	bool result = false;
	if (file) {
		FILE *f = fopen(file, "rb");
		if (f) {
			char magic[8];
			fread(magic, 8, 1, f);
			result = png_sig_cmp((png_bytep)magic, 0, 8) == 0;
			fclose(f);
		}
	}
	return result;
}

bool is_decimal_digit(char c) {
	return ((c >= '0') && (c <= '9'));
}

bool is_hex_digit(char c) {
	if (is_decimal_digit(c)) return true;
	if ((c >= 'a') && (c <= 'f')) return true;
	if ((c >= 'A') && (c <= 'F')) return true;
	return false;
}

bool string_is_number(const char *str) {
	bool hex = false;
	char c;
	unsigned long i = 0;
	unsigned long length = strlen(str);
	
	if (length == 0) return false;
	
	if (str[0] == '-') i = 1;
	else if (memcmp("0x", str, 2) && (length > 2)) {
		hex = true;
		i = 2;
	}
	
	for (; i < length; i++) {
		c = str[i];
		if (hex) {
			if (!is_hex_digit(c)) return false;
		} else {
			if (!is_decimal_digit(c)) return false;
		}
	}
	
	return true;
}

void path_add_index(char *dst, const char *path, unsigned int index) {
	const char *extension = strrchr(path, '.');
	if (!extension) extension = "";
	
	size_t raw_path_length = strlen(path) - strlen(extension);
	char *raw_path = alloca(raw_path_length + 1);
	strncpy(raw_path, path, raw_path_length);
	
	if (extension) sprintf(dst, "%s_%u%s", raw_path, index, extension);
}

int ibootimMain(const char *inFile, const char *outFile) {
	int16_t x_offset = 0, y_offset = 0;
	uint16_t width = 0, height = 0;
	const char *input_path, *output_path;
	const char *ibootim_path, *png_path;
	bool force_grayscale = false;
	bool force_argb = false;
	struct stat st;
	int rc;

	input_path = inFile;
	output_path = outFile;
	
	if (stat(input_path, &st) != 0) {
		printf("Path '%s' does not exist.\n", input_path);
		return 1;
	} else if (!S_ISREG(st.st_mode)) {
		printf("'%s' is not a regular file.\n", input_path);
		return 1;
	}
	
	if (stat(output_path, &st) != 0) {
		if (!S_ISREG(st.st_mode)) {
			printf("'%s' already exists and is not a regular file.\n", output_path);
			return 1;
		}
	}
	
	if (file_is_png(input_path)) {
		ibootim_path = output_path;
		png_path = input_path;
		
		ibootim *image = NULL;
		
		rc = ibootim_load_png(png_path, &image);
		if (rc != 0) {
			printf("ERROR: Failed to load PNG file '%s'.\n", png_path);
			return 1;
		}
		
		printf("width=%u, height=%u\n", ibootim_get_width(image), ibootim_get_height(image));
		
		ibootim_set_x_offset(image, x_offset);
		ibootim_set_y_offset(image, y_offset);
		
		if (force_argb) {
			rc = ibootim_convert_to_colorspace(image, ibootim_color_space_argb);
			if (rc != 0) {
				puts("[-] Failed to convert image to the requested color space.");
				ibootim_close(image);
				return 1;
			}
		} else if (force_grayscale) {
			rc = ibootim_convert_to_colorspace(image, ibootim_color_space_grayscale);
			if (rc != 0) {
				puts("[-] Failed to convert image to the requested color space.");
				ibootim_close(image);
				return 1;
			}
		}
		
		rc = ibootim_write(image, ibootim_path);
		ibootim_close(image);
		if (rc != 0) {
			switch (rc) {
				case ENOMEM:
					puts("ERROR: Not enough memory.");
					break;
				case ENOENT:
					printf("ERROR: Failed to open '%s' for writing: %s.\n", ibootim_path, strerror(errno));
					break;
				case EFAULT:
					printf("ERROR: Compression error: %s (code %i).\n", lzss_strerror(lzss_errno), lzss_errno);
					break;
				default:
					printf("ERROR: Unknown error (code %i).\n", rc);
					break;
			}
			
			return 1;
		}
	} else if (file_is_ibootim(input_path)) {
		ibootim_path = input_path;
		png_path = output_path;
		
		ibootim *image   = NULL;
		char *path		 = alloca(strlen(png_path) + 7);
		unsigned int images_count = ibootim_count_images_in_file(ibootim_path, NULL);
		
		if (images_count == 1) {
			warning_fmt_len_less = warning_fmt_len_less_o;
			warning_fmt_len_more = warning_fmt_len_more_o;
			error_fmt_create_png = error_fmt_create_png_o;
			error_fmt_image_corrupt = error_fmt_image_corrupt_o;
		} else {
			warning_fmt_len_less = warning_fmt_len_less_m;
			warning_fmt_len_more = warning_fmt_len_more_m;
			error_fmt_create_png = error_fmt_create_png_m;
			error_fmt_image_corrupt = error_fmt_image_corrupt_m;
		}
		
		for (unsigned int i = 0; i < images_count; i++) {
			if ((rc = ibootim_load_at_index(ibootim_path, &image, i)) != 0) {
				switch (rc) {
					case ENOMEM:
						puts("ERROR: Not enough memory.");
						break;
					case EFTYPE:
						printf(error_fmt_image_corrupt, i);
						break;
					case ENOENT:
						printf("ERROR: Failed to open '%s' for reading: %s.\n", ibootim_path, strerror(errno));
						break;
					default:
						printf("ERROR: Unknown error (code %i).\n", rc);
						break;
				}
				
				return 1;
			}
			
			if (force_argb) {
				rc = ibootim_convert_to_colorspace(image, ibootim_color_space_argb);
				if (rc != 0) {
					puts("[-] Failed to convert image to the requested color space.");
					ibootim_close(image);
					return 1;
				}
			} else if (force_grayscale) {
				rc = ibootim_convert_to_colorspace(image, ibootim_color_space_grayscale);
				if (rc != 0) {
					puts("[-] Failed to convert image to the requested color space.");
					ibootim_close(image);
					return 1;
				}
			}
			
			if (i > 0) path_add_index(path, png_path, i);
			else strcpy(path, png_path);
			
			int16_t x_offset = ibootim_get_x_offset(image);
			int16_t y_offset = ibootim_get_y_offset(image);
			if ((x_offset != 0) || (y_offset != 0)) {
				if (images_count > 1) printf("%u:\n", i);
				if (x_offset != 0) printf(" X offset = %i\n", x_offset);
				if (y_offset != 0) printf(" Y offset = %i\n", y_offset);
			}
			
			/*unsigned int length = ibootim_get_content_length(image);
			unsigned int expected_length = ibootim_get_expected_content_size(image);
			if (length < expected_length) printf(warning_fmt_len_less, i);
			else if (length > expected_length) printf(warning_fmt_len_more, i);*/
			
			if (ibootim_write_png(image, path) != 0)
				printf(error_fmt_create_png, i);
			
			ibootim_close(image);
		}
	} else {
		puts("Input file must be a PNG or an iBoot Image File (legacy images \n"
			 "decoding is not supported yet).");
		return 1;
	}
	
	return 0;
}
