// PFN Database
pub const PFNEntry = packed struct {
    prev: ?*PFNEntry = null,
    next: ?*PFNEntry = null,
    refs: i28 = 0,
    state: u3 = 1,
    swappable: u1 = 0,
};
