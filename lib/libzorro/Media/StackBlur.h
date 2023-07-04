#ifndef _LIBZORRO_MEDIA_STACKBLUR_H
#define _LIBZORRO_MEDIA_STACKBLUR_H

void StackBlur(
    unsigned char *src,
    unsigned int w,
    unsigned int radius,
    unsigned int min_x,
    unsigned int max_x,
    unsigned int min_y,
    unsigned int max_y);

#endif