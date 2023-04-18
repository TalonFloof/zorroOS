#pragma once

void Arch_EarlyInitialize();
void Arch_Initialize();
void Arch_ClearScreen();
void Arch_Halt();
void Arch_IRQEnableDisable(int enabled);