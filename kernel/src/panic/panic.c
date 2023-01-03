#include "panic.h"

#include <arch/arch.h>

#include "panic_images.h"

#ifdef _OWL_ARCH_X86_64
#include <util/string.h>

extern char Owl_SymbolTable_Start[];
extern char Owl_SymbolTable_End[];

typedef struct {
  uintptr_t addr;
	char name[];
} Symbol;

uintptr_t GetSymbol(uintptr_t addr, const char** name) {
  Symbol* ptr = ((Symbol*)&Owl_SymbolTable_Start);
  *name = (const char*)(&"???");
  uintptr_t best_match = 0;
  while(ptr < ((Symbol*)&Owl_SymbolTable_End)) {
    uintptr_t sym_addr = ptr->addr;
    if(sym_addr < addr && sym_addr > best_match) {
      best_match = sym_addr;
      *name = ((const char*)(&(ptr->name)));
    }
    ptr = (Symbol*)(((uintptr_t)ptr)+((uintptr_t)(sizeof(uintptr_t)+1+strlen((const char*)(&(ptr->name))))));
  }
  if(best_match != 0) {
    return addr-best_match;
  } else {
    return 0;
  }
}
#endif

__attribute__((noreturn)) void PanicMultiline(OwlPanicCategory category,
                                              const char** msgs, int len) {
  IOwlLogger logger = owlArch.get_logger();
  if (logger != 0) {
    if (category != PANIC_RAMDISK && category != PANIC_INVALID_SETUP) {
      LogFatal(logger, "panic (hart %x) %s", 0, msgs[0]);
      int i;
      for(i=1; i < len; i++) {
        LogFatal(logger, "debug info: %s", msgs[i]);
      }
      #ifdef _OWL_ARCH_X86_64
      uint64_t* stack_ptr = (uint64_t*)__builtin_frame_address(0);
      LogFatal(logger, "Stack Backtrace:");
      uint32_t frame;
      for(frame = 0; stack_ptr != 0 && frame < 32; ++frame) {
        if(stack_ptr[1] < 0xffffffff80000000UL) break;
        const char* name = 0;
        uintptr_t offset = GetSymbol(stack_ptr[1],&name);
        LogFatal(logger, "  %x <%s+%x>", stack_ptr[1], name, offset);
        stack_ptr = (uint64_t*)stack_ptr[0];
      }
      if(frame == 32) {
        LogFatal(logger, "...Backtrace may continue past this point");
      }
      #else
      LogFatal(logger, "NOTICE: Stack Backtracing is not available on this CPU Architecture");
      #endif
    } else if(category == PANIC_RAMDISK) {
      LogError(logger, "%s", msgs[0]);
    }
  }
  #ifndef _DEBUG_BUILD_
  IOwlFramebuffer* fb = owlArch.get_framebuffer();
  if(fb != 0) {
    int x,y;
    for(y=0;y<fb->resolution[1];y++) { // Dim Screen
		  for(x=0;x<fb->resolution[0];x++) {
			  fb->set(x,y,(fb->get(x,y) >> 1) & 0x7f7f7f7f);
		  }
	  }
    switch(category) {
      case PANIC_GENERIC:
        Framebuffer_RenderMonochromeBitmap(fb,fb->resolution[0]/2-(35*3/2),fb->resolution[1]/2-(45*3/2),35,45,3,0xffffff,5,(uint8_t*)&OwlGenericPanicImage);
        break;
      case PANIC_INCOMPATABLE_HARDWARE:
        Framebuffer_RenderMonochromeBitmap(fb,fb->resolution[0]/2-(35*3/2),fb->resolution[1]/2-(45*3/2),35,45,3,0xffffff,5,(uint8_t*)&OwlIncompatibleHardwareImage);
        break;
      case PANIC_OUT_OF_MEMORY:
        Framebuffer_RenderMonochromeBitmap(fb,fb->resolution[0]/2-(35*3/2),fb->resolution[1]/2-(45*3/2),35,45,3,0xffffff,5,(uint8_t*)&OwlOutOfMemoryImage);
        break;
      case PANIC_RAMDISK:
        Framebuffer_RenderMonochromeBitmap(fb,fb->resolution[0]/2-(35*3/2),fb->resolution[1]/2-(45*3/2),35,45,3,0xffffff,5,(uint8_t*)&OwlRamdiskImage);
        break;
      default:
        Framebuffer_RenderMonochromeBitmap(fb,fb->resolution[0]/2-(35*3/2),fb->resolution[1]/2-(45*3/2),35,45,3,0xffffff,5,(uint8_t*)&OwlGenericPanicImage);
        break;
    }
  }
  if(category == PANIC_RAMDISK) {
    int i;
		for(i=0;i<len;i++) {
			Framebuffer_RenderCenteredText(fb, fb->resolution[0]/2,fb->resolution[1]/2+(45*3/2)+(i*16),1,0xffffff,msgs[i]);
		}
	} else {
		Framebuffer_RenderCenteredText(fb, fb->resolution[0]/2,fb->resolution[1]/2+(45*3/2),1,0xffffff,"Kernel Panic");
		int i;
		for(i=0;i<len;i++) {
			Framebuffer_RenderCenteredText(fb, fb->resolution[0]/2,fb->resolution[1]/2+(45*3/2)+16+(i*16),1,0xffffff,msgs[i]);
		}
	}
  #endif
  for(;;) {
    owlArch.disable_interrupts();
    owlArch.halt();
  }
}

__attribute__((noreturn)) void PanicCat(OwlPanicCategory category, const char* msg) {
  PanicMultiline(category, &msg, 1);
}

__attribute__((noreturn)) void Panic(const char* msg) {
  PanicMultiline(PANIC_GENERIC, &msg, 1);
}