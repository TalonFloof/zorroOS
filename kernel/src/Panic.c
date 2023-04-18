#include <Arch/Arch.h>
#include <Graphics/Framebuffer.h>
#include <Graphics/StackBlur.h>
#include <Graphics/PSF.h>

extern void* _binary____files_terminus_psf_start;

void Panic(char* msg) {
  int i, j;
  for(i=0;i<fbHeight;i++) {
    for(j=i%2;j<fbWidth;j+=2) {
      Framebuffer_DrawRect(j,i,1,1,0);
    }
  }
  /*StackBlur(fbPtr,fbWidth,32,0,fbWidth,0,fbHeight);*/
  Framebuffer_RenderString(0,0,0xffffff,(PSFHeader*)&_binary____files_terminus_psf_start,"panic: ");
  Framebuffer_RenderString(42,0,0xffffff,(PSFHeader*)&_binary____files_terminus_psf_start,msg);
  Arch_IRQEnableDisable(0);
  Arch_Halt();
}