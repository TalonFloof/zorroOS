pub const EventQueue = extern struct {
    listLock: u8 = 0,
    threadHead: ?*void = null,
};
