#include <stdint.h>
#include <Arch/Arch.h>
#include <Graphics/Framebuffer.h>
#include <Graphics/Images.h>
#include <Graphics/StackBlur.h>
#include <Utilities/String.h>
#include <Panic.h>
#include <Compositor/MouseCursor.h>

extern void* _binary____files_knxt_psf_start;
extern void* _binary____files_unifont_psf_start;

void main() {
  Arch_EarlyInitialize();
  /*StackBlur(fbPtr,fbWidth,32,0,fbWidth,0,fbHeight);*/
  /*Framebuffer_RenderMonoBitmap((fbWidth/2)-64,(fbHeight/2)-64,128,128,128,128,(uint8_t*)&zorroOSLogo,0xcdd6f4);*/
  /*Framebuffer_RenderMonoBitmap((fbWidth/2)-64,(fbHeight/2)+72,128,42,128,42,(uint8_t*)&zorroOSText,0xcdd6f4);*/
  Compositor_WindowSetup();
  Compositor_RedrawCursor(0,0);
  Arch_IRQEnableDisable(1);
  Arch_Initialize();
  for(;;) {
    Arch_IRQEnableDisable(1);
    Arch_Halt();
  }
}