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

#ifndef __ibootim_h__
#define __ibootim_h__

#include <stdint.h>
#include <stdbool.h>
#include <errno.h>

typedef struct ibootim ibootim;

typedef enum {
    ibootim_color_space_grayscale = 0x67726579, // 'grey'
    ibootim_color_space_argb      = 0x61726762  // 'argb'
} ibootim_color_space_t;

typedef enum {
    ibootim_compression_type_lzss = 0x6C7A7373, // 'lzss'
} ibootim_compression_type_t;

extern const char *ibootim_signature;

/*!
 @function file_is_ibootim
 @abstract Checks if file is an iBoot Embedded Image file.
 @param path Path to the file.
 @result 0 if file is not an iBoot Embedded Image and 1 if it is.
 */

extern bool file_is_ibootim(const char *path);

/*!
 @function ibootim_load
 @abstract Loads an iBoot Embedded Image file.
 @discussion Loads and uncompresses LZSS compressed iBoot Embedded Image file located at path 'path' and returns an ibootim image handle that represents an iBoot Embedded Image and must be closed with ibootim_close() function. This is equivalent to ibootim_load_at_index(path, handle, 0).
 @param path Path to the iBoot Embedded Image file.
 @param handle A pointer where the handle is written on success.
 @result UNIX error code or 0 on success.
 */

extern int ibootim_load(const char *path, ibootim **handle);

/*!
 @function ibootim_load_at_index
 @abstract Loads an iBoot Embedded Image file at given index.
 @discussion Loads and uncompresses LZSS compressed iBoot Embedded Image file located at path 'path' and returns an ibootim image handle that represents an iBoot Embedded Image and must be closed with ibootim_close() function. This is used for concatenated images.
 @param path Path to the iBoot Embedded Image file.
 @param handle A pointer where the handle is written on success.
 @param index Index of the image in the file.
 @result UNIX error code or 0 on success.
 */

extern int ibootim_load_at_index(const char *path, ibootim **handle, unsigned int index);

/*!
 @function ibootim_load
 @abstract Loads a PNG file and converts it into iBoot Embedded Image.
 @discussion Loads a PNG file located at path 'path', converts it into an iBoot Embedded Image and returns an ibootim image handle that represents an iBoot Embedded Image and must be closed with ibootim_close() function.
 @param path Path to the PNG file.
 @param handle A pointer where the handle is written on success.
 @result UNIX error code or 0 on success.
 */

extern int ibootim_load_png(const char *path, ibootim **handle);

/*!
 @function ibootim_get_pixel_size
 @abstract Returns the size of one pixel of the image in bytes.
 @param image The image.
 @result Size of one pixel of the image.
 */

extern unsigned int ibootim_get_pixel_size(ibootim *image);

/*!
 @function ibootim_write
 @abstract Converts the iBoot Embedded Image to a PNG image.
 @discussion Converts the iBoot Embedded Image to a PNG image and writes the PNG image to the specified path
 @param image The image.
 @param path The path where the PNG image will be written.
 @result 0 on success or an error code on error.
 */

extern int ibootim_write(ibootim *image, const char *path);

/*!
 @function ibootim_write_png
 @abstract Writes iBoot Embedded Image to a file.
 @discussion Compresses and writes iBoot Embedded Image 'image' to a file at path 'path'.
 @param image The image.
 @param path The path where to write the image.
 @result 0 on success or -1 on error.
 */

extern int ibootim_write_png(ibootim *image, const char *path);

/*!
 @function ibootim_get_expected_size
 @abstract Calculates expected raw content length for the image.
 @param image The image handle.
 @param path Where to write PNG file.
 @result Expected content length.
 */

extern unsigned int ibootim_get_expected_content_size(ibootim *image);

/*!
 @function ibootim_close
 @abstract Destroys ibootim image handle.
 @param image The image handle.
 */

extern void ibootim_close(ibootim *image);

/* Properties */

extern uint16_t ibootim_get_width(ibootim *image);
extern uint16_t ibootim_get_height(ibootim *image);
extern int16_t ibootim_get_x_offset(ibootim *image);
extern void ibootim_set_x_offset(ibootim *image, int16_t offset);
extern int16_t ibootim_get_y_offset(ibootim *image);
extern void ibootim_set_y_offset(ibootim *image, int16_t offset);
extern ibootim_color_space_t ibootim_get_color_space(ibootim *image);
extern ibootim_compression_type_t ibootim_get_compression_type(ibootim *image);

extern int ibootim_convert_to_colorspace(ibootim *image, ibootim_color_space_t targetColorSpace);
extern int ibootim_count_images_in_file(const char *path, int *error);

#endif /* defined(__ibootim__ibootim__) */
