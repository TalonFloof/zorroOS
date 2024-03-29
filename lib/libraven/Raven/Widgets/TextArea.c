#include "TextArea.h"
#include <Common/Alloc.h>
#include <Common/String.h>

extern PSFHeader* RavenUnifont;

typedef struct {
    char selected;
    char line[256];
} UITextBoxPrivateData;

static void TextBoxRedraw(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = (UIWidget*)self;
    UITextBoxPrivateData* private = (UITextBoxPrivateData*)widget->privateData;
    Graphics_DrawRect(gfx,widget->x,widget->y,widget->w,widget->h,0xff18181b);
    int len = strlen(&private->line);
    for(int i=0; i < (widget->w/8); i++) {
        int offset = (len < ((widget->w/8))) ? i : (((len-(widget->w/8)))+1+i);
        if(offset >= len) {
            Graphics_DrawRect(gfx,widget->x+(i*8),widget->y+((widget->h/2)-8),2,16,private->selected ? 0xff1d4ed8 : 0xff2a2a2a);
            break;
        }
        Graphics_RenderGlyph(gfx,widget->x+(i*8),widget->y+((widget->h/2)-8),0xffffffff,RavenUnifont,1,private->line[offset]);
    }
}

static void TextBoxEvent(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx, RavenEvent* event) {
    UIWidget* widget = (UIWidget*)self;
    UITextBoxPrivateData* private = (UITextBoxPrivateData*)widget->privateData;
    if(event->type == RAVEN_MOUSE_PRESSED) {
        private->selected = (event->mouse.x >= widget->x && event->mouse.x < widget->x+widget->w && event->mouse.y >= widget->y && event->mouse.y < widget->y+widget->h) ? 1 : 0;
        TextBoxRedraw(self,session,win,gfx);
        RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
    }
    if(event->type == RAVEN_KEY_PRESSED && private->selected) {
        if(event->key.rune != '\n' && event->key.rune != 8 && event->key.rune != '\t' && event->key.rune != 0) {
            int len = strlen((const char*)&private->line);
            private->line[len] = (uint8_t)event->key.rune;
            private->line[len+1] = 0;
            TextBoxRedraw(self,session,win,gfx);
            RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
        } else if(event->key.rune == 8) { // Backspace
            int len = strlen((const char*)&private->line);
            if(len > 0) {
                private->line[len-1] = 0;
                TextBoxRedraw(self,session,win,gfx);
                RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
            }
        }
    }
}

static void TextAreaRedraw(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx) {
    UIWidget* widget = (UIWidget*)self;
    UITextAreaPrivateData* private = (UITextAreaPrivateData*)widget->privateData;
    Graphics_DrawRect(gfx,widget->x,widget->y,widget->w,widget->h,0xff18181b);
    for(int i=0; i < (widget->h/16); i++) {
        if(i+private->scrollY < private->lineCount) {
            int lineLen = strlen(private->lines[i+private->scrollY]);
            for(int j=0; j < (widget->w/8); j++) {
                if(j+private->scrollX >= lineLen) {
                    break;
                }
                Graphics_RenderGlyph(gfx,widget->x+(j*8),widget->y+(i*16),0xffffffff,RavenUnifont,1,private->lines[i+private->scrollY][j+private->scrollX]);
            }
        } else {
            break;
        }
    }
    Graphics_DrawRect(gfx,widget->x+(private->cursorX*8),widget->y+(private->cursorY*16),2,16,private->selected ? 0xff1d4ed8 : 0xff2a2a2a);
}

static void TextAreaEvent(void* self, RavenSession* session, ClientWindow* win, GraphicsContext* gfx, RavenEvent* event) {
    UIWidget* widget = (UIWidget*)self;
    UITextAreaPrivateData* private = (UITextAreaPrivateData*)widget->privateData;
    if(event->type == RAVEN_MOUSE_PRESSED) {
        private->selected = (event->mouse.x >= widget->x && event->mouse.x < widget->x+widget->w && event->mouse.y >= widget->y && event->mouse.y < widget->y+widget->h) ? 1 : 0;
        TextAreaRedraw(self,session,win,gfx);
        RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
    }
    if(event->type == RAVEN_KEY_PRESSED && private->selected) {
        if(event->key.rune != '\n' && event->key.rune != 8 && event->key.rune != '\t' && event->key.rune != 0) {
            char* newLine = malloc(strlen(private->lines[private->cursorY])+1);
            memcpy(newLine,private->lines[private->cursorY],private->cursorX);
            newLine[private->cursorX] = (uint8_t)event->key.rune;
            memcpy(&newLine[private->cursorX+1],&private->lines[private->cursorY][private->cursorX],strlen(&private->lines[private->cursorY][private->cursorX])+1);
            free(private->lines[private->cursorY]);
            private->lines[private->cursorY] = newLine;
            private->cursorX += 1;
            TextAreaRedraw(self,session,win,gfx);
            RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
        } else if(event->key.rune == 8) { // Backspace
            if(private->cursorX > 0) {
                char* newLine = malloc(strlen(private->lines[private->cursorY]));
                memcpy(newLine,private->lines[private->cursorY],private->cursorX-1);
                memcpy(&newLine[private->cursorX-1],&private->lines[private->cursorY][private->cursorX],strlen(&private->lines[private->cursorY][private->cursorX])+1);
                free(private->lines[private->cursorY]);
                private->lines[private->cursorY] = newLine;
                private->cursorX -= 1;
                TextAreaRedraw(self,session,win,gfx);
                RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
            } else if(private->cursorY > 0) {
                if(strlen(private->lines[private->cursorY]) > 0) {
                    int prevLen = strlen(private->lines[private->cursorY-1]);
                    private->cursorX = strlen(private->lines[private->cursorY-1]);
                    private->lines[private->cursorY-1] = realloc(private->lines[private->cursorY-1],prevLen+strlen(private->lines[private->cursorY])+1);
                    memcpy(&private->lines[private->cursorY-1][prevLen],private->lines[private->cursorY],strlen(private->lines[private->cursorY])+1);
                } else {
                    private->cursorX = strlen(private->lines[private->cursorY-1]);
                }
                free(private->lines[private->cursorY]);
                memcpy(&private->lines[private->cursorY],&private->lines[private->cursorY+1],(private->lineCount-(private->cursorY+1))*sizeof(void*));
                private->lines = realloc(private->lines,(private->lineCount-1)*sizeof(void*));
                private->lineCount--;
                private->cursorY -= 1;
                TextAreaRedraw(self,session,win,gfx);
                RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
            }
        } else if(event->key.rune == '\n') {
            char** newLineList = malloc(sizeof(void*)*(private->lineCount+1));
            memcpy(newLineList,private->lines,(private->cursorY+1)*sizeof(void*));
            newLineList[private->cursorY+1] = malloc(strlen(&private->lines[private->cursorY][private->cursorX])+1);
            memcpy(newLineList[private->cursorY+1],&private->lines[private->cursorY][private->cursorX],strlen(&private->lines[private->cursorY][private->cursorX])+1);
            memcpy(&newLineList[private->cursorY+2],&private->lines[private->cursorY+1],(private->lineCount-(private->cursorY+1))*sizeof(void*));
            newLineList[private->cursorY] = realloc(private->lines[private->cursorY],private->cursorX+1);
            newLineList[private->cursorY][private->cursorX] = 0;
            free(private->lines);
            private->lines = newLineList;
            private->lineCount++;
            private->cursorY++;
            private->cursorX = 0;
            TextAreaRedraw(self,session,win,gfx);
            RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
        } else if(event->key.key == 0xe04b) { // Left Arrow
            if(private->cursorX > 0) {
                private->cursorX -= 1;
            }
            TextAreaRedraw(self,session,win,gfx);
            RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
        } else if(event->key.key == 0xe04d) { // Right Arrow
            if(private->cursorX < strlen(private->lines[private->cursorY])) {
                private->cursorX += 1;
            }
            TextAreaRedraw(self,session,win,gfx);
            RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
        } else if(event->key.key == 0xe050) { // Down Arrow
            if(private->cursorY < private->lineCount-1) {
                private->cursorY += 1;
                if(private->cursorX > strlen(private->lines[private->cursorY])) {
                    private->cursorX = strlen(private->lines[private->cursorY]);
                }
                TextAreaRedraw(self,session,win,gfx);
                RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
            }
        } else if(event->key.key == 0xe048) { // Up Arrow
            if(private->cursorY > 0) {
                private->cursorY -= 1;
                if(private->cursorX > strlen(private->lines[private->cursorY])) {
                    private->cursorX = strlen(private->lines[private->cursorY]);
                }
                TextAreaRedraw(self,session,win,gfx);
                RavenFlipArea(session,win,widget->x,widget->y,widget->w,widget->h);
            }
        }
    }
}

int64_t NewTextAreaWidget(ClientWindow* win, int dest, int x, int y, int w, int h) {
    // 0xff18181b
    UIWidget* widget = malloc(sizeof(UIWidget));
    UITextAreaPrivateData* private = malloc(sizeof(UITextAreaPrivateData));
    private->selected = 0;
    private->cursorX = 0;
    private->cursorY = 0;
    private->scrollX = 0;
    private->scrollY = 0;
    private->lineCount = 1;
    private->lines = malloc(sizeof(void*));
    private->lines[0] = malloc(1);
    private->lines[0][0] = 0;
    widget->privateData = private;
    widget->x = x;
    widget->y = y;
    widget->w = w;
    widget->h = h;
    widget->Redraw = &TextAreaRedraw;
    widget->Event = &TextAreaEvent;
    return UIAddWidget(win,widget,dest);
}

int64_t NewTextBoxWidget(ClientWindow* win, int dest, int x, int y, int w, int h, const char* text) {
    UIWidget* widget = malloc(sizeof(UIWidget));
    UITextBoxPrivateData* private = malloc(sizeof(UITextBoxPrivateData));
    private->selected = 0;
    memset(&private->line,0,256);
    memcpy(&private->line,text,strlen(text));
    widget->privateData = private;
    widget->x = x;
    widget->y = y;
    widget->w = w;
    widget->h = h;
    widget->Redraw = &TextBoxRedraw;
    widget->Event = &TextBoxEvent;
    return UIAddWidget(win,widget,dest);
}