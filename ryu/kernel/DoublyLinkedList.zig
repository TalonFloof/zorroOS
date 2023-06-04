const Memory = @import("root").Memory;

pub fn DoublyLinkedList(comptime V: type) type {
    return struct {
        const Node = struct {
            prev: ?*Node = null,
            next: ?*Node = null,
            onPagedPool: bool,
            val: V,
        };
        head: ?*Node = null,
        tail: ?*Node = null,

        const Self = @This();

        pub fn insert(self: *Self, val: V, isPaged: bool) void {
            var node: *allowzero Node = @intToPtr(*allowzero Node, 0);
            if (isPaged) {
                node = @ptrCast(*Node, @alignCast(@alignOf(Node), Memory.Pool.PagedPool.Alloc(@sizeOf(Node)).?.ptr));
            } else {
                node = @ptrCast(*Node, @alignCast(@alignOf(Node), Memory.Pool.StaticPool.Alloc(@sizeOf(Node)).?.ptr));
            }
            node.onPagedPool = isPaged;
            node.val = val;
            if (self.head == null) {
                node.prev = null;
                node.next = null;
                self.head = node;
                self.tail = node;
            } else {
                self.tail.?.next = node;
                node.prev = self.tail;
                node.next = null;
                self.tail = node;
            }
        }
    };
}
