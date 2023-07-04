#include "Image.h"

void Image_ScaleNearest(uint32_t* src, uint32_t* dst, int oldW, int oldH, int newW, int newH) {
    int xRatio = ((oldW << 16) / newW) + 1;
    int yRatio = ((oldH << 16) / newH) + 1;
    for(int i=0; i < newH; i++) {
        for(int j=0; j < newW; j++) {
            int finalX = (j * xRatio) >> 16;
            int finalY = (i * yRatio) >> 16;
            dst[(i*newW)+j] = src[(finalY*oldW)+finalX];
        }
    }
}

void Image_ABGRToARGB(uint32_t* src, size_t size) {
    uint8_t* src8;
    for(size_t i=0; i < size; i++) {
        unsigned int r = src[i] & 0xFF;
        unsigned int g = src[i] & 0xFF00;
        unsigned int b = (src[i] >> 16) & 0xFF;
        unsigned int a = src[i] & 0xFF000000;
        src[i] = a | (r << 16) | g | b;
    }
}