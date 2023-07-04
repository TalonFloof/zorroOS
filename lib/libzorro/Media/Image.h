#ifndef _LIBZORRO_MEDIA_IMAGE_H
#define _LIBZORRO_MEDIA_IMAGE_H
#include <stdint.h>
#include <stddef.h>

void Image_ScaleNearest(uint32_t* src, uint32_t* dst, int oldW, int oldH, int newW, int newH);
void Image_ABGRToARGB(uint32_t* src, size_t size);

#endif