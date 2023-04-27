// Interface for Keyboard Drivers
pub const Keyboard = struct { getKey: *const fn (*Keyboard) u8 };
