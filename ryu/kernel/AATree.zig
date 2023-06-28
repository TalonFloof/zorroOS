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

        fn insertInternal(t: ?*Node, x: *Node) ?*Node {
            var T = t;
            if (T == null) {
                T = x;
            } else {
                var dir: usize = if (T.?.key < x.key) 1 else 0;
                T.?.link[dir] = insertInternal(T.?.link[dir], x);
                T = skew(T);
                T = split(T);
            }
            return T;
        }

        pub inline fn insert(self: *Self, x: *Node) void {
            self.root = insertInternal(self.root, x);
        }

        fn deleteInternal(T: ?*Node, x: *Node) ?*Node {
            var t = T;
            if (t != null) {
                if (x.key == t.?.key) {
                    if (t.?.link[0] != null and t.?.link[1] != null) {
                        var heir = t.?.link[0];
                        while (heir.?.link[1] != null) {
                            heir = heir.?.link[1];
                        }
                        t.?.key = heir.?.key;
                        t.?.value = heir.?.value;
                        t.?.link[0] = deleteInternal(t.?.link[0], t.?);
                    } else {
                        const dir: usize = if (t.?.link[0] == null) 1 else 0;
                        t = t.?.link[dir];
                    }
                } else {
                    const dir: usize = if (t.?.key < x.key) 1 else 0;
                    t.?.link[dir] = deleteInternal(t.?.link[dir], x);
                }
            }
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
            return t;
        }

        pub inline fn delete(self: *Self, x: *Node) void {
            self.root = deleteInternal(self.root, x);
        }

        pub fn search(self: *Self, key: K) ?*Node {
            var x = self.root;
            while (x) |node| {
                if (key < node.key) {
                    x = node.link[0];
                } else if (key > node.key) {
                    x = node.link[1];
                } else {
                    return x;
                }
            }
            return null;
        }
    };
}
