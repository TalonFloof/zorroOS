#pragma once


void Compositor_RedrawCursor(int oldX, int oldY);
void Compositor_GetMousePosition(int* mouseX, int* mouseY);
void Compositor_SetMousePosition(int mouseX, int mouseY);
void Compositor_SetMouseStatus(int lclick);