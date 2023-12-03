const AATree = @import("root").AATree;

pub const UserSession = struct {
    parent: ?*UserSession = null,
    userID: i32 = 0,
    groupID: i32 = 0,
};

const UserSessionTreeType = AATree(i64, *UserSession);
