#pragma once
#include <stdint.h>

typedef struct {
  unsigned char magic[4];
  uint32_t version;
  uint32_t headerSize;
  uint32_t flags;
  uint32_t length;
  uint32_t charSize;
  uint32_t height;
  uint32_t width;
}__attribute__((packed)) PSFHeader;