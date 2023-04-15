#include <stdint.h>
#include <Graphics/Framebuffer.h>

typedef struct {
  char magic[8];
  uint32_t videoMode;
  uint64_t videoAddr;
  uint16_t videoWidth;
  uint16_t videoHeight;
  uint8_t videoBpp;
  uint64_t memoryMap;
  uint64_t kernelSize;
}__attribute__((packed)) LegacyInfo;

extern LegacyInfo* KInfo;

void Arch_Initialize() {
  fbPtr = (uint8_t*)(KInfo->videoAddr);
  fbWidth = KInfo->videoWidth;
  fbHeight = KInfo->videoHeight;
  fbBpp = KInfo->videoBpp;
}