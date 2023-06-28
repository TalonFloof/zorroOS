pub const EventQueue = struct {
    listLock: u8,
    threadHead: ?*void,
};
