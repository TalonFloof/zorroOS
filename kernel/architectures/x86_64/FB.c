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
  Framebuffer_SwapBuffer(limine_framebuffer_request.response->framebuffers[0]->address, limine_framebuffer_request.response->framebuffers[0]->width, limine_framebuffer_request.response->framebuffers[0]->height, limine_framebuffer_request.response->framebuffers[0]->bpp);
  limine_terminal_request.response->write(limine_terminal_request.response->terminals[0],"\x1b[?25l",6);
}

void Limine_ClearScreen() {
  limine_terminal_request.response->write(limine_terminal_request.response->terminals[0],(char*)0,LIMINE_TERMINAL_FULL_REFRESH);
}