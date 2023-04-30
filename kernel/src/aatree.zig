const std = @import("std");

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
            if (n != null) |node| {
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
            if (n != null) |node| {
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
            if (t == null) {
                return x;
            } else {
                var it = T;
                var up = [_]?*Node{null} ** 128;
                var top = 0;
                var dir = 0;
                while (true) {
                    up[top] = it;
                    top += 1;
                    dir = if (it.?.key < x.key) 1 else 0;
                    if (it.?.link[dir] == null) {
                        break;
                    }
                    it = it.?.link[dir];
                }
                it.?.link[dir] = x;
                while (top >= 0) {
                    top -= 1;
                    if (top != 0) {
                        dir = if (up[top - 1].?.link[1] == up[top]) 1 else 0;
                    }
                    up[top] = skew(up[top]);
                    up[top] = split(up[top]);
                    if (top != 0) {
                        up[top - 1].?.link[dir] = up[top];
                    } else {
                        T = up[top];
                    }
                }
            }
            return T;
        }

        pub inline fn insert(self: *Self, x: *Node) void {
            self.root = insertInternal(self.root, x);
        }

        fn deleteInternal(T: ?*Node, x: *Node) ?*Node {
            var t = T;
            if (t != null) {
                var it = t;
                var up = [_]?*Node{null} ** 128;
                var top = 0;
                var dir = 0;
                while (true) {
                    up[top] = it;
                    top += 1;
                    if (it == null) {
                        return t;
                    } else if (x.key == it.?.key) {
                        break;
                    }
                    dir = if (it.?.key < x.key) 1 else 0;
                    it = it.?.link[dir];
                }
                if (it.?.link[0] == null or it.?.link[1] == null) {
                    var dir2 = if (it.?.link[0] == null) 1 else 0;
                    top = top -% 1;
                    if ((top +% 1) != 0) {
                        up[top - 1].?.link[dir] = it.?.link[dir2];
                    } else {
                        t = it.?.link[1];
                    }
                } else {
                    var heir = it.?.link[1];
                    var prev = it;
                    while (heir.?.link[0] != null) {
                        up[top] = prev;
                        prev = heir;
                        heir = heir.?.link[0];
                    }
                    it.?.key = heir.?.key;
                    it.?.value = heir.?.value;
                    prev.?.link[if (@ptrToInt(prev) == @ptrToInt(it)) 1 else 0] = heir.?.link[1];
                }
                while (top >= 0) {
                    top -= 1;
                    if (top != 0) {
                        dir = if (up[top - 1].?.link[1] == up[top]) 1 else 0;
                    }

                    if ((up[top].?.link[0].?.level < up[top].?.level - 1) or (up[top].?.link[1].?.level < up[top].?.level - 1)) {
                        if (up[top].?.link[1].?.level > up[top].?.level) {
                            up[top].?.level -= 1;
                            up[top].?.link[1].?.level = up[top].?.level;
                        } else {
                            up[top].?.level -= 1;
                        }

                        up[top] = skew(up[top]);
                        up[top].?.link[1] = skew(up[top].?.link[1]);
                        up[top].?.link[1].?.link[1] = skew(up[top].?.link[1].?.link[1]);
                        up[top] = split(up[top]);
                        up[top].?.link[1] = split(up[top].?.link[1]);
                    }
                    if (top != 0) {
                        up[top - 1].?.link[dir] = up[top];
                    } else {
                        t = up[top];
                    }
                }
            }
            return t;
        }

        pub inline fn delete(self: *Self, x: *Node) void {
            self.root = deleteInternal(self.root, x);
        }

        pub fn search(self: *Self, key: K) ?*Node {
            var x = self.root;
            while (x != null) {
                if (key < x.?.key) {
                    x = x.?.link[0];
                } else if (key > x.?.key) {
                    x = x.?.link[1];
                } else {
                    return x;
                }
            }
            return null;
        }
    };
}
