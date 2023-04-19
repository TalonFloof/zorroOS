#include "../PortIO.h"
#include <Panic.h>
#include <Utilities/String.h>
#include <Compositor/MouseCursor.h>

void PS2MouseWait(int type) {
  if(!type) {
    for(;;) {
			if (inb(0x64) & 1) return;
			asm ("pause");
		}
  } else {
    for(;;) {
			if (!(inb(0x64) & 2)) return;
			asm ("pause");
		}
  }
}

uint8_t PS2MouseRead() {
	PS2MouseWait(0);
	return inb(0x60);
}

void PS2MouseWrite(uint8_t write) {
	PS2MouseWait(1);
	outb(0x64, 0xD4);
	PS2MouseWait(1);
	outb(0x60, write);
  if(PS2MouseRead() != 0xFA) {
    Panic("PS/2 Init Fail!");
  }
}

int packetID = 0;
unsigned char packetData[3] = {0};

void PS2MouseIRQ() {
  uint8_t status;
  while(((status = inb(0x64)) & 0x01) != 0) {
    if((status & 0x20)) {
      packetData[packetID] = inb(0x60);
      if(packetID == 2) {
        int8_t flags = packetData[0];
        int16_t offX = packetData[1] - ((flags << 4) & 0x100);
        int16_t offY = packetData[2] - ((flags << 3) & 0x100);
        int mX, mY;
        Compositor_GetMousePosition(&mX,&mY);
        if(offX != 0 || offY != 0) {
          Compositor_SetMousePosition(mX+offX,mY-offY);
        }
        Compositor_SetMouseStatus(flags & 1);
      }
      if(packetID == 0 && !(packetData[packetID] & 0x8)) {
        packetID = 0;
      } else {
        packetID = (packetID + 1) % 3;
      }
    } else {
      inb(0x60); /* PS/2 Keyboard */
    }
  }
}

void PS2MouseInit() {
  while(inb(0x64) & 1) {
		inb(0x60);
	}

  PS2MouseWait(1);
  outb(0x64, 0xa8);
  /*PS2MouseWait(0);
  inb(0x60);*/

  PS2MouseWait(1);
  outb(0x64, 0x20);
	unsigned char status = (inb(0x60) | 2) & (~0x10);
  PS2MouseWait(1);
  outb(0x64, 0x60);
  PS2MouseWait(1);
  outb(0x60, status);

  PS2MouseWrite(0xf6);

  PS2MouseWrite(0xf4);
  outb(0xA1, 0x00);
}