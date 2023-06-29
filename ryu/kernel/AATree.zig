const Memory = @import("root").Memory;

pub fn AATree(comptime K: type, comptime V: type) type {
    return struct {
        pub const Node = struct {
            link: [2]?*Node = [_]?*Node{ null, null },
            level: isize = 1,
            key: K,
            value: V,
        };

        root: ?*Node = null,

        fn skew(n: ?*Node) ?*Node {
            if (n) |node| {
                if (node.link[0] == null) {
                    return node;
                } else if (node.link[0].?.level == node.level) {
                    var l = node.link[0].?;
                    node.link[0] = l.link[1];
                    l.link[1] = node;
                    return l;
                } else {
                    return node;
                }
            } else {
                return null;
            }
        }

        fn split(n: ?*Node) ?*Node {
            if (n) |node| {
                if (node.link[1] == null) {
                    return node;
                } else if (node.link[1].?.link[1] == null) {
                    return node;
                } else if (node.level == node.link[1].?.link[1].?.level) {
                    var r = node.link[1].?;
                    node.link[1] = r.link[0];
                    r.link[0] = node;
                    r.level = r.level + 1;
                    return r;
                } else {
                    return node;
                }
            } else {
                return null;
            }
        }

        const Self = @This();

        fn insertInternal(t: ?*Node, x: K, y: V) ?*Node {
            var T = t;
            if (T == null) {
                T = @intToPtr(*Node, @ptrToInt(Memory.Pool.PagedPool.Alloc(@sizeOf(Node)).?.ptr));
                T.?.key = x;
                T.?.value = y;
            } else {
                const dir: usize = if (T.?.key < x) 1 else 0;
                T.?.link[dir] = insertInternal(T.?.link[dir], x, y);
                T = skew(T);
                T = split(T);
            }
            return T;
        }

        pub inline fn insert(self: *Self, x: K, y: V) void {
            self.root = insertInternal(self.root, x, y);
        }

        fn deleteInternal(T: ?*Node, x: K) ?*Node {
            var t = T;
            var item: ?*Node = null;
            var heir: ?*Node = null;
            if (t != null) {
                const dir: usize = if (t.?.key < x) 1 else 0;
                heir = t;
                if (dir == 0) {
                    item = t;
                }
                t.?.link[dir] = deleteInternal(t.?.link[dir], x);
            }
            if (t == heir) {
                if (item != null and item.?.key == x) {
                    item.?.key = heir.?.key;
                    item.?.value = heir.?.value;
                    Memory.Pool.PagedPool.Free(@intToPtr([*]u8, @ptrToInt(heir))[0..@sizeOf(Node)]);
                    t = t.?.link[1];
                }
            } else {
                if (t.?.link[0].?.level < t.?.level - 1 or t.?.link[1].?.level < t.?.level - 1) {
                    t.?.level -= 1;
                    if (t.?.link[1].?.level > t.?.level) {
                        t.?.link[1].?.level = t.?.level;
                    }
                    t = skew(t);
                    t.?.link[1] = skew(t.?.link[1]);
                    t.?.link[1].?.link[1] = skew(t.?.link[1].?.link[1]);
                    t = split(t);
                    t.?.link[1] = split(t.?.link[1]);
                }
            }
            return t;
        }

        pub inline fn delete(self: *Self, x: K) void {
            self.root = deleteInternal(self.root, x);
        }

        pub fn search(self: *Self, key: K) ?V {
            var x = self.root;
            while (x) |node| {
                if (key < node.key) {
                    x = node.link[0];
                } else if (key > node.key) {
                    x = node.link[1];
                } else {
                    return node.value;
                }
            }
            return null;
        }
    };
}
