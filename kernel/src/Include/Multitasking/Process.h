#pragma once
#include <Arch/Context.h>
#include <Lock/Spinlock.h>

enum ProcessState { UNDEFINED, RUNNABLE, RUNNING, SLEEPING, ZOMBIE };

typedef struct {
  Lock spinlock;

  int pid;
  int isKilled; /* If not zero, then a kill signal was sent to this process. */
  void* sleepChannel; /* If not NULL, then wer are sleeping on this channel. */
  IContext context;
  uintptr_t kstack; /* Pointer to the kernel stack of this process */
} Process;