module list_alloc

import panic

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
	panic.panic(panic.ZorroPanicCategory.out_of_memory,"Kernel Heap Freelist Deprived")
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
		return &allocation_memory_segments[(&allocation_memory_segments[self.current]).next]
	} else {
		return none
	}
}

fn (mut self LinkedListCursor) peek_prev() ?&LinkedListEntry {
	if allocation_memory_segments[self.current].prev != -1 {
		return &allocation_memory_segments[(&allocation_memory_segments[self.current]).prev]
	} else {
		return none
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
				panic("Kernel Heap Freelist is in an unusual and unrecoverable state")
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
	allocation_memory_segments = [LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}, LinkedListEntry{}]!
	allocation_head_index = int(-1)
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