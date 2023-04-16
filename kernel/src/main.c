#include <stdint.h>
#include <Arch/Arch.h>
#include <Graphics/Framebuffer.h>
#include <Graphics/Images.h>
#include <Graphics/StackBlur.h>
#include <Misc.h>
#include <Utilities/String.h>

extern void* _binary____files_knxt_psf_start;
extern void* _binary____files_unifont_psf_start;
extern void* _binary____files_terminus_psf_start;

void main() {
  Arch_EarlyInitialize();
  StackBlur(fbPtr,fbWidth,32,0,fbWidth,0,fbHeight);
  Framebuffer_RenderMonoBitmap((fbWidth/2)-64,(fbHeight/2)-64,128,128,128,128,(uint8_t*)&zorroOSLogo,0xcdd6f4);
  Framebuffer_RenderMonoBitmap((fbWidth/2)-64,(fbHeight/2)+72,128,42,128,42,(uint8_t*)&zorroOSText,0xcdd6f4);
  SetCurrentStatus("Welcome to zorroOS");
  Arch_Initialize();
  SetCurrentStatus("Boot Complete!");
  for(;;);
}

void SetCurrentStatus(char* msg) {
  Framebuffer_DrawRect(0,fbHeight-64,fbWidth,20,0x1e1e2e);
  Framebuffer_RenderString((fbWidth/2)-((strlen(msg)*9)/2),fbHeight-64,0xcdd6f4,(PSFHeader*)&_binary____files_knxt_psf_start,msg);
}