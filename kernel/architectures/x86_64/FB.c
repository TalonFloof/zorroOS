#include <Graphics/Framebuffer.h>
#include "FB.h"
#include "Limine.h"

static volatile struct limine_framebuffer_request limine_framebuffer_request = {
  .id = LIMINE_FRAMEBUFFER_REQUEST,
  .revision = 1
};

void Limine_InitFB() {
  fbPtr = limine_framebuffer_request.response->framebuffers[0]->address;
  fbWidth = limine_framebuffer_request.response->framebuffers[0]->width;
  fbHeight = limine_framebuffer_request.response->framebuffers[0]->height;
  fbBpp = (uint8_t)(limine_framebuffer_request.response->framebuffers[0]->bpp);
}