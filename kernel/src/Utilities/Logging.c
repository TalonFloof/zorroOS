#include <Utilities/Logging.h>
#include <Lock/Spinlock.h>
#include <Graphics/Framebuffer.h>
#include <Graphics/PSF.h>
#include <Compositor/Window.h>

Lock logLock = {.name="Kernel Log Lock"};
int cursorY = 0;

extern void* _binary____files_terminus_psf_start;

extern Window rootWindow;

void Logger_Log(char* str) {
  Lock_Acquire(&logLock);
  Framebuffer_SwapBuffer((uint8_t*)rootWindow.backBuffer,rootWindow.w,rootWindow.h,32);
  Framebuffer_RenderString(1,21+(cursorY*12),0xffffffff,(PSFHeader*)&_binary____files_terminus_psf_start,str);
  if(cursorY < 25) {
    cursorY += 1;
  } else {
    int i;
    for(i=33;i < fbHeight;i++) {
        memcpy(((uint32_t*)fbPtr)[((i-12)*fbWidth)+1],((uint32_t*)fbPtr)[(i*fbWidth)+1],fbWidth-2);
    }
    Framebuffer_DrawRect(1,fbHeight-13,fbWidth-2,12,0xff101010);
  }
  Framebuffer_SwapBuffer(0,0,0,0);
  Compositor_SwapWindowBuffer(&rootWindow);
  Lock_Release(&logLock);
}