#include "framebuffer.h"
#include "limine.h"

static volatile struct limine_framebuffer_request limine_framebuffer_request = {
  .id = LIMINE_FRAMEBUFFER_REQUEST,
  .revision = 1
};

uint32_t fb_get(int x, int y);
void fb_set(int x, int y, uint32_t color);

static IOwlFramebuffer fb = {
  .signature = 0x42466f72726f5a49,

  .set = fb_set,
  .get = fb_get,
};

uint32_t fb_get(int x, int y) {
  return ((uint32_t*)fb.pointer)[(y*fb.resolution[0])+x];
}

void fb_set(int x, int y, uint32_t color) {
  ((uint32_t*)fb.pointer)[(y*fb.resolution[0])+x] = color;
}

void x86_64_FBInit() {
  fb.resolution[0] = limine_framebuffer_request.response->framebuffers[0]->width;
  fb.resolution[1] = limine_framebuffer_request.response->framebuffers[0]->height;
  fb.depth = limine_framebuffer_request.response->framebuffers[0]->bpp;
  fb.pointer = limine_framebuffer_request.response->framebuffers[0]->address;
}

IOwlFramebuffer* x86_64_GetFramebuffer() {
  return &fb;
}