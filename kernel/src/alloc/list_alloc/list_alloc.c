#include <alloc/alloc.h>
#include <stdint.h>

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
  /* TODO: Panic, Msg: "Kernel Heap Freelist Deprived" */
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
        /* TODO: Panic, Msg: "Kernel Heap Freelist is in an unusual and
         * unrecoverable state" */
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

/*
[noinit]
struct LinkedListEntry {
mut:
    is_used bool
pub mut:
    prev int = -1
    next int = -1
    data MemSegmentEntry
}

fn find_next_free_entry() int {
    for i, val in allocation_memory_segments {
        if !val.is_used {
            return i
        }
    }
    panic.panic(panic.ZorroPanicCategory.out_of_memory,"Kernel Heap Freelist
Deprived")
}

[noinit]
struct LinkedListCursor {
pub mut:
    current int
}

fn new_cursor() LinkedListCursor {
    return LinkedListCursor{current: allocation_head_index}
}

fn (mut self LinkedListCursor) next() ?&LinkedListEntry {
    if self.current != -1 {
        current := self.current
        self.current = (&allocation_memory_segments[self.current]).next
        return &allocation_memory_segments[current]
    } else {
        return none
    }
}

fn (mut self LinkedListCursor) peek_next() ?&LinkedListEntry {
    if allocation_memory_segments[self.current].next != -1 {
        return
&allocation_memory_segments[(&allocation_memory_segments[self.current]).next] }
else { return none
    }
}

fn (mut self LinkedListCursor) peek_prev() ?&LinkedListEntry {
    if allocation_memory_segments[self.current].prev != -1 {
        return
&allocation_memory_segments[(&allocation_memory_segments[self.current]).prev] }
else { return none
    }
}

fn (mut self LinkedListCursor) insert_before(entry MemSegmentEntry) {
    prev := allocation_memory_segments[self.current].prev
    next_entry := find_next_free_entry()
    allocation_memory_segments[self.current].prev = next_entry
    if prev != -1 {allocation_memory_segments[prev].next = next_entry}
    allocation_memory_segments[next_entry].is_used = true
    allocation_memory_segments[next_entry].prev = prev
    allocation_memory_segments[next_entry].next = self.current
    allocation_memory_segments[next_entry].data = entry
    if allocation_head_index == self.current {
        allocation_head_index = next_entry
    }
}

fn (mut self LinkedListCursor) remove_current() {
    prev := allocation_memory_segments[self.current].prev
    next := allocation_memory_segments[self.current].next
    if prev != -1 {allocation_memory_segments[prev].next = next}
    if next != -1 {allocation_memory_segments[next].prev = prev}
    allocation_memory_segments[self.current].is_used = false
    allocation_memory_segments[self.current].prev = -1
    allocation_memory_segments[self.current].next = -1
    if allocation_head_index == self.current {
        if next == -1 {
            if prev != -1 {
                panic("Kernel Heap Freelist is in an unusual and unrecoverable
state")
            }
            allocation_head_index = -1
        } else {
            allocation_head_index = next
        }
    }
}

fn push_back(entry MemSegmentEntry) {
    mut i := if allocation_head_index == -1 {0} else {allocation_head_index}
    for {
        if allocation_memory_segments[i].next == -1 {
            next_entry := find_next_free_entry()
            if allocation_head_index == -1 {
                allocation_head_index = next_entry
            }
            allocation_memory_segments[i].next = next_entry
            allocation_memory_segments[next_entry].is_used = true
            allocation_memory_segments[next_entry].prev = i
            allocation_memory_segments[next_entry].next = -1
            allocation_memory_segments[next_entry].data = entry
            return
        }
        i = allocation_memory_segments[i].next
    }

}

[noinit]
struct MemSegmentEntry {
pub mut:
    start usize
    end usize
}

[cinit]
__global (
    allocation_memory_segments = [LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{},
LinkedListEntry{}, LinkedListEntry{}]! allocation_head_index = int(-1)
)

[export: "kalloc"]
pub fn alloc(n usize, align usize) voidptr {
    allocation_lock.acquire()
    size := n+align
    mut cursor := new_cursor()
    for mut i in cursor {
        segment_start := i.data.start
        segment_size := i.data.end - i.data.start
        if segment_size > size {
            // (value + (alignment - 1)) & ~(alignment - 1)
            if align > 0 {
                new_addr := (segment_start + (align - 1)) & ~(align - 1)
                i.data.start += n + (new_addr - segment_start)
                if new_addr != segment_start {
                    new_entry := MemSegmentEntry{segment_start, new_addr}
                    cursor.insert_before(new_entry)
                }
                allocation_lock.release()
                return voidptr(new_addr)
            } else {
                i.data.start += size
                allocation_lock.release()
                return voidptr(segment_start)
            }
        } else if segment_size == size {
            if align > 0 {
                new_addr := (segment_start + (align - 1)) & ~(align - 1)
                if new_addr != segment_start {
                    i.data.end = new_addr
                }
                allocation_lock.release()
                return voidptr(new_addr)
            } else {
                cursor.remove_current()
                allocation_lock.release()
                return voidptr(segment_start)
            }
        }
    }
    allocation_lock.release()
    panic.panic(panic.ZorroPanicCategory.out_of_memory,"Kernel Heap Deprived")
}

[export: "kfree"]
pub fn free(addr voidptr, n usize) {
    allocation_lock.acquire()
    end := usize(addr) + n
    mut cursor := new_cursor()
    for mut i in cursor {
        segment_start := i.data.start
        segment_end := i.data.end
        if segment_start == end {
            i.data.start = usize(addr)
            if mut prev_node := cursor.peek_prev() {
                prev_segment_end := prev_node.data.end
                if prev_segment_end == usize(addr) {
                    prev_node.data.end = segment_end
                    cursor.remove_current()
                }
            }
            allocation_lock.release()
            return
        } else if segment_end == usize(addr) {
            i.data.end = end
            if mut next_node := cursor.peek_next() {
                next_segment_start := next_node.data.start
                if next_segment_start == end {
                    next_node.data.start = segment_start
                    cursor.remove_current()
                }
            }
            allocation_lock.release()
            return
        } else if end < segment_start {
            new_entry := MemSegmentEntry{start: usize(addr), end: end}
            cursor.insert_before(new_entry)
            allocation_lock.release()
            return
        }
    }
    push_back(MemSegmentEntry{start: usize(addr), end: end})
    allocation_lock.release()
}
*/

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
  // panic.panic(panic.ZorroPanicCategory.out_of_memory,"Kernel Heap Deprived");
}

void dealloc(void* ptr, uintptr_t n, uintptr_t align) {
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

void* malloc(uintptr_t n) {}

void free(void* ptr) {}

#endif