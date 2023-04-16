#include <stdint.h>
#include <Arch/Arch.h>
#include <Graphics/Framebuffer.h>
#include <Graphics/Images.h>

extern void* _binary____files_knxt_psf_start;
extern void* _binary____files_unifont_psf_start;
extern void* _binary____files_terminus_psf_start;

void main() {
  Arch_Initialize();
  Framebuffer_Clear(0x101010);
  Framebuffer_RenderMonoBitmap((fbWidth/2)-64,(fbHeight/2)-64,128,128,128,128,(uint8_t*)&zorroOSLogo,0xcde2ff);
  Framebuffer_RenderMonoBitmap((fbWidth/2)-64,(fbHeight/2)+72,128,42,128,42,(uint8_t*)&zorroOSText,0xcde2ff);
  Framebuffer_RenderString(0,0,0xffffff,(PSFHeader*)&_binary____files_knxt_psf_start,"This font is knxt, and is stored in memory as a PSF (v2)!");
  Framebuffer_RenderString(0,20,0xffffff,(PSFHeader*)&_binary____files_unifont_psf_start,"And here is GNU Unifont using a PSF file as well!");
  Framebuffer_RenderString(0,36,0xffffff,(PSFHeader*)&_binary____files_terminus_psf_start,"Small fonts like Terminus 12pt works as well");
  for(;;);
}