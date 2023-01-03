#include <alloc/alloc.h>
#include <stdint.h>
#include <panic/panic.h>

#if OWL_DEFAULT_ALLOCATOR == LINKED_LIST_ALLOCATOR

typedef struct {
  uintptr_t start;
  uintptr_t end;
} MemSegmentEntry;

typedef struct {
  int isUsed;
  int prev;
  int next;
  MemSegmentEntry data;
} LinkedListEntry;

typedef struct {
  int current;
} LinkedListCursor;

LinkedListEntry owlAllocationMemorySegments[64] = {
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
    {.isUsed = 0, .prev = -1, .next = -1, .data = {.start = 0, .end = 0}},
};
int owlAllocationHeadIndex = -1;

static int FindNextFreeEntry() {
  int i;
  for (i = 0; i < 64; i++) {
    if (!owlAllocationMemorySegments[i].isUsed) {
      return i;
    }
  }
  PanicCat(PANIC_OUT_OF_MEMORY, "Kernel Heap Freelist Deprived");
}

static LinkedListCursor NewCursor() {
  return (LinkedListCursor){
      .current = owlAllocationHeadIndex,
  };
}

static LinkedListEntry* CursorNext(LinkedListCursor* self) {
  if (self->current != -1) {
    int current = self->current;
    self->current = owlAllocationMemorySegments[self->current].next;
    return &owlAllocationMemorySegments[current];
  } else {
    return 0;
  }
}

static LinkedListEntry* CursorPeekNext(LinkedListCursor* self) {
  if (owlAllocationMemorySegments[self->current].next != -1) {
    return &owlAllocationMemorySegments
        [owlAllocationMemorySegments[self->current].next];
  } else {
    return 0;
  }
}

static LinkedListEntry* CursorPeekPrev(LinkedListCursor* self) {
  if (owlAllocationMemorySegments[self->current].prev != -1) {
    return &owlAllocationMemorySegments
        [owlAllocationMemorySegments[self->current].prev];
  } else {
    return 0;
  }
}

static void CursorInsertBefore(LinkedListCursor* self, MemSegmentEntry entry) {
  int prev = owlAllocationMemorySegments[self->current].prev;
  int next_entry = FindNextFreeEntry();
  if (prev != -1) {
    owlAllocationMemorySegments[prev].next = next_entry;
  }
  owlAllocationMemorySegments[next_entry].isUsed = 1;
  owlAllocationMemorySegments[next_entry].prev = prev;
  owlAllocationMemorySegments[next_entry].next = self->current;
  owlAllocationMemorySegments[next_entry].data = entry;
  if (owlAllocationHeadIndex == self->current) {
    owlAllocationHeadIndex = next_entry;
  }
}

static void CursorRemoveCurrent(LinkedListCursor* self) {
  int prev = owlAllocationMemorySegments[self->current].prev;
  int next = owlAllocationMemorySegments[self->current].next;
  if (prev != -1) {
    owlAllocationMemorySegments[prev].next = next;
  }
  if (next != -1) {
    owlAllocationMemorySegments[next].prev = prev;
  }
  owlAllocationMemorySegments[self->current].isUsed = 0;
  owlAllocationMemorySegments[self->current].prev = -1;
  owlAllocationMemorySegments[self->current].next = -1;
  if (owlAllocationHeadIndex == self->current) {
    if (next == -1) {
      if (prev != -1) {
        Panic("Kernel Heap Freelist is in an unusual and unrecoverable state");
      }
      owlAllocationHeadIndex = -1;
    } else {
      owlAllocationHeadIndex = next;
    }
  }
}

static void ListAlloc_PushBack(MemSegmentEntry entry) {
  int i = (owlAllocationHeadIndex == -1) ? 0 : owlAllocationHeadIndex;
  for (;;) {
    if (owlAllocationMemorySegments[i].next == -1) {
      int next_entry = FindNextFreeEntry();
      if (owlAllocationHeadIndex == -1) {
        owlAllocationHeadIndex = next_entry;
      }
      owlAllocationMemorySegments[i].next = next_entry;
      owlAllocationMemorySegments[next_entry].isUsed = 1;
      owlAllocationMemorySegments[next_entry].prev = i;
      owlAllocationMemorySegments[next_entry].next = -1;
      owlAllocationMemorySegments[next_entry].data = entry;
      return;
    }
    i = owlAllocationMemorySegments[i].next;
  }
}

extern Lock owlAllocationLock;

void* alloc(uintptr_t n, uintptr_t align) {
  Lock_Acquire(&owlAllocationLock);
  uintptr_t size = n + align;
  LinkedListCursor cursor = NewCursor();
  LinkedListEntry* i = CursorNext(&cursor);
  while ((uintptr_t)i != 0) {
    uintptr_t segment_start = i->data.start;
    uintptr_t segment_size = i->data.end - i->data.start;
    if (segment_size > size) {
      if (align > 0) {
        uintptr_t new_addr = (segment_start + (align - 1)) & ~(align - 1);
        i->data.start += n + (new_addr - segment_start);
        if (new_addr != segment_start) {
          CursorInsertBefore(&cursor, (MemSegmentEntry){
                                          .start = segment_start,
                                          .end = new_addr,
                                      });
        }
        Lock_Release(&owlAllocationLock);
        return (void*)new_addr;
      } else if (segment_size == size) {
        if (align > 0) {
          uintptr_t new_addr = (segment_start + (align - 1)) & ~(align - 1);
          if (new_addr != segment_start) {
            i->data.start = new_addr;
          }
          Lock_Release(&owlAllocationLock);
          return (void*)segment_start;
        }
      }
    }
    i = CursorNext(&cursor);
  }
  Lock_Release(&owlAllocationLock);
  PanicCat(PANIC_OUT_OF_MEMORY,"Kernel Heap Deprived");
}

void dealloc(void* ptr, uintptr_t n) {
  Lock_Acquire(&owlAllocationLock);
  uintptr_t end = ((uintptr_t)ptr) + n;
  LinkedListCursor cursor = NewCursor();
  LinkedListEntry* i = CursorNext(&cursor);
  while ((uintptr_t)i != 0) {
    uintptr_t segment_start = i->data.start;
    uintptr_t segment_end = i->data.end;
    if(segment_start == end) {
      i->data.start = ((uintptr_t)ptr);
      if(CursorPeekPrev(&cursor) != NULL) {
        LinkedListEntry* prev_node = CursorPeekPrev(&cursor);
        uintptr_t prev_segment_end = prev_node->data.end;
        if(prev_segment_end == ((uintptr_t)ptr)) {
          prev_node->data.end = segment_end;
          CursorRemoveCurrent(&cursor);
        }
      }
      Lock_Release(&owlAllocationLock);
      return;
    } else if(segment_end == ((uintptr_t)ptr)) {
      i->data.end = end;
      if(CursorPeekNext(&cursor) != NULL) {
        LinkedListEntry* next_node = CursorPeekPrev(&cursor);
        uintptr_t next_segment_start = next_node->data.start;
        if(next_segment_start == end) {
          next_node->data.start = segment_start;
          CursorRemoveCurrent(&cursor);
        }
      }
      Lock_Release(&owlAllocationLock);
      return;
    } else if(end < segment_start) {
      MemSegmentEntry new_entry = (MemSegmentEntry){.start=((uintptr_t)ptr), .end=end};
      CursorInsertBefore(&cursor,new_entry);
      Lock_Release(&owlAllocationLock);
      return;
    }
    i = CursorNext(&cursor);
  }
  ListAlloc_PushBack((MemSegmentEntry){.start=((uintptr_t)ptr), .end=end});
  Lock_Release(&owlAllocationLock);
}

void* malloc(uintptr_t n) {
  void* ret = alloc(n+sizeof(uintptr_t),1);
  *((uintptr_t*)ret) = n+sizeof(uintptr_t);
  return (ret+sizeof(uintptr_t));
}

void free(void* ptr) {
  void* true_ptr = (ptr-sizeof(uintptr_t));
  dealloc(true_ptr,*((uintptr_t*)true_ptr));
}

#endif