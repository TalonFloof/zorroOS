#include <Graphics/Framebuffer.h>
#include "FB.h"
#include "Limine.h"

static volatile struct limine_framebuffer_request limine_framebuffer_request = {
  .id = LIMINE_FRAMEBUFFER_REQUEST,
  .revision = 1
};

static volatile struct limine_terminal_request limine_terminal_request = {
  .id = LIMINE_TERMINAL_REQUEST,
  .revision = 2
};

void Limine_InitFB() {
  fbPtr = limine_framebuffer_request.response->framebuffers[0]->address;
  fbWidth = limine_framebuffer_request.response->framebuffers[0]->width;
  fbHeight = limine_framebuffer_request.response->framebuffers[0]->height;
  fbBpp = (uint8_t)(limine_framebuffer_request.response->framebuffers[0]->bpp);
  limine_terminal_request.response->write(limine_terminal_request.response->terminals[0],"\x1b[?25l",6);
}