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
                T = @as(*Node, @ptrFromInt(@intFromPtr(Memory.Pool.PagedPool.Alloc(@sizeOf(Node)).?.ptr)));
                T.?.key = x;
                T.?.value = y;
                T.?.link[0] = null;
                T.?.link[1] = null;
                T.?.level = 1;
                return T;
            } else {
                const dir: usize = if (x < T.?.key) 0 else 1;
                T.?.link[dir] = insertInternal(T.?.link[dir], x, y);
                T = skew(T);
                T = split(T);
                return T;
            }
        }

        pub inline fn insert(self: *Self, x: K, y: V) void {
            self.root = insertInternal(self.root, x, y);
        }

        fn decreaseLevel(T: ?*Node) ?*Node {
            var t = T;
            var wdo: isize = 0;
            if (t.?.link[0] != null and t.?.link[1] != null) {
                wdo = @min(t.?.link[0].?.level, t.?.link[1].?.level) + 1;
                if (wdo < t.?.level) {
                    t.?.level = wdo;
                    if (t.?.link[1] != null) {
                        if (wdo < t.?.link[1].?.level) {
                            t.?.link[1].?.level = wdo;
                        }
                    }
                }
            }
            return t;
        }

        fn deleteInternal(T: ?*Node, x: K) ?*Node {
            var t = T;
            if (t == null) {
                return null;
            }
            if (t.?.key != x) {
                const dir: usize = if (x < t.?.key) 0 else 1;
                t.?.link[dir] = deleteInternal(t.?.link[dir], x);
            } else {
                if (t.?.link[0] == null and t.?.link[1] == null) {
                    Memory.Pool.PagedPool.Free(@as([*]u8, @ptrCast(@alignCast(t)))[0..@sizeOf(Node)]);
                    return null;
                }
                if (t.?.link[0] == null) {
                    var l = t.?.link[1].?;
                    t.?.key = l.key;
                    t.?.value = l.value;
                    t.?.link[1] = deleteInternal(t.?.link[1], l.key);
                } else {
                    var l = t.?.link[0].?;
                    t.?.key = l.key;
                    t.?.value = l.value;
                    t.?.link[0] = deleteInternal(t.?.link[0], l.key);
                }
            }
            t = decreaseLevel(t);
            t = skew(t);
            var m = t.?.link[1];
            t.?.link[1] = skew(m);
            if (m != null) {
                if (m.?.link[1] != null) {
                    t.?.link[1].?.link[1] = skew(m.?.link[1]);
                }
            }
            t = split(t);
            t.?.link[1] = split(m);
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

        fn destroyInternal(T: *Node, f: *const fn (K, *V) void) void {
            if (T.link[0]) |prev| {
                destroyInternal(prev, f);
            }
            if (T.link[1]) |next| {
                destroyInternal(next, f);
            }
            f(T.key, &T.value);
            Memory.Pool.PagedPool.Free(@as([*]u8, @ptrFromInt(@intFromPtr(T)))[0..@sizeOf(Node)]);
        }

        pub fn destroy(self: *Self, f: *const fn (K, *V) void) void {
            if (self.root) |root| {
                destroyInternal(root, f);
            }
        }
    };
}
