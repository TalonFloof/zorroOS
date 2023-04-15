#include <stdint.h>
#include <Arch/Arch.h>
#include <Graphics/Framebuffer.h>
#include <Graphics/Images.h>

void main() {
  Arch_Initialize();
  Framebuffer_Clear(0x101010);
  Framebuffer_RenderMonoBitmap((fbWidth/2)-64,(fbHeight/2)-64,128,128,128,128,(uint8_t*)&zorroOSLogo,0xcde2ff);
  Framebuffer_RenderMonoBitmap((fbWidth/2)-64,(fbHeight/2)+72,128,42,128,42,(uint8_t*)&zorroOSText,0xcde2ff);
  for(;;);
}