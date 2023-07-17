#include "kbd.h"
#include "raven.h"
#include <System/Thread.h>
#include <Filesystem/Filesystem.h>

const uint8_t unshiftedMap[] = {
    0,    27,  '1', '2', '3', '4', '5', '6', '7',  '8', '9', '0',  '-',  '=', 8,   '\t',
    'q',  'w', 'e', 'r', 't', 'y', 'u', 'i', 'o',  'p', '[', ']',  '\n', 0,   'a', 's',
    'd',  'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0,   '\\', 'z',  'x', 'c', 'v',
    'b',  'n', 'm', ',', '.', '/', 0,   '*', 0,    ' ', 0,   0,    0,    0,   0,   0,
    0,    0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,    0,    0,   0,   0,
    '\\', 0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,    0,    0,   0,   0,
    0,    0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,    0,    0,   0,   0,
    0,    0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,    0,    0,   0,   0,
};

const uint8_t shiftedMap[] = {
    0,   27,  '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_',  '+', 8,   '\t',
    'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n', 0,   'A', 'S',
    'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0,   '|', 'Z',  'X', 'C', 'V',
    'B', 'N', 'M', '<', '>', '?', 0,   '*', 0,   ' ', 0,   0,   0,    0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,
    '|', 0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,
};

void KeyboardThread() {
    OpenedFile kbdFile;
    if(Open("/dev/ps2kbd",O_RDONLY,&kbdFile) < 0) {
        RyuLog("Failed to open /dev/ps2kbd!\n");
        Exit(1);
    }
    char shifted = 0;
    unsigned char packet;
    while(1) {
        if(kbdFile.Read(&kbdFile,(void*)&packet,1) == 1) {
            if(packet == 0x2a || packet == 0x36) {
                shifted = 1;
            } else if(packet == 0xaa || packet == 0xb6) {
                shifted = 0;
            } else {
                if(packet == 0xe0) {
                    unsigned char packet2;
                    kbdFile.Read(&kbdFile,(void*)&packet2,1);
                    if(winFocus != NULL) {
                        RavenEvent event;
                        event.type = packet2 >= 0x80 ? RAVEN_KEY_RELEASED : RAVEN_KEY_PRESSED;
                        event.id = winFocus->id;
                        event.key.key = 0xe000 | (packet2 >= 0x80 ? packet2-0x80 : packet2);
                        event.key.rune = 0;
                        MQueue_SendToClient(msgQueue,winFocus->owner,&event,sizeof(RavenEvent));
                    }
                } else {
                    if(winFocus != NULL) {
                        RavenEvent event;
                        event.type = packet >= 0x80 ? RAVEN_KEY_RELEASED : RAVEN_KEY_PRESSED;
                        event.id = winFocus->id;
                        event.key.key = packet >= 0x80 ? packet-0x80 : packet;
                        event.key.rune = shifted ? shiftedMap[event.key.key] : unshiftedMap[event.key.key];
                        MQueue_SendToClient(msgQueue,winFocus->owner,&event,sizeof(RavenEvent));
                    }
                }
            }
        } else {
            RyuLog("WARNING: /dev/ps2kbd returned unusual value!\n");
        }
    }
}