const std = @import("std");
const AATree = @import("aatree.zig").AATree;
const Spinlock = @import("spinlock.zig").Spinlock;
const alloc = @import("alloc.zig");

pub const ObjectTree = AATree(u64, *Object);

pub const ObjectType = enum { Any, Universe, Port, Core, Area, Thread };

var objId = 1;
var objects = ObjectTree{};
var objLock: Spinlock = .unaquired;

pub const Object = struct {
    id: u64 = 0,
    typ: ObjectType,
    rc: u64 = 0,
    decon: fn (self: *void) void,

    pub fn init(self: *Object) void {
        objLock.acquire("Object Tree");
        self.id = objId;
        self.rc = 0;
        objId += 1;
        objects.insert(ObjectTree.Node.new(self.id, self));
        objLock.release();
    }

    pub fn ref(self: *Object) void {
        _ = @atomicRmw(u64, &self.rc, .Add, 1, .SeqCst);
    }

    pub fn deref(self: *Object) void {
        objLock.acquire("Object Tree");
        if (@atomicRmw(u64, &self.rc, .Sub, 1, .SeqCst) <= 1) {
            objects.delete(objects.search(self.id).?);
            objLock.release();
            self.decon();
        } else {
            objLock.release();
        }
    }
};
