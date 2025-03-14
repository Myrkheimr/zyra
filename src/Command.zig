const Self = @This();

const std = @import("std");
const testing = std.testing;

name: []const u8,
help: []const u8 = "",
sub_cmds: ?[]Self = null,
handler: ?fn (args: [][]const u8) anyerror!void = null,

pub fn run(self: *const Self, args: [][]const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: {s}\n", .{self.name});
        return;
    }

    if (self.sub_cmds) |cmds| {
        for (cmds) |cmd| {
            if (std.mem.eql(u8, args[0], cmd.name)) {
                cmd.run(args[1..]);
                return;
            }
        }
    }

    if (self.handler) |handle| {
        try handle(args);
    } else {
        std.debug.print("Unknown Command: {s}\n", .{args[0]});
    }
}

test "init" {
    const name = "test";
    const help = "test help";
    const cmd = Self{ .name = name, .help = help };

    try testing.expectEqualStrings(name, cmd.name);
    try testing.expectEqualStrings(help, cmd.help);
}

fn testSuccessHandler(args: [][]const u8) !void {
    _ = args;
}

fn testFailureHandler(args: [][]const u8) !void {
    _ = args;
    return error.SomeFailure;
}

test "handler" {
    const name = "test";
    const help = "test help";

    const allocator = testing.allocator;
    var args = try allocator.alloc([]const u8, 3);
    args[0] = "one";
    args[1] = "two";
    args[2] = "three";

    defer allocator.free(args);

    const cmd_success = Self{ .name = name, .help = help, .handler = testSuccessHandler };
    const handler_success = blk: {
        cmd_success.run(args) catch break :blk false;
        break :blk true;
    };
    try testing.expect(handler_success);

    // Failure
    const cmd_failure = Self{ .name = name, .help = help, .handler = testFailureHandler };
    const handler_failure = blk: {
        cmd_failure.run(args) catch break :blk false;
        break :blk true;
    };

    try testing.expect(!handler_failure);
    try testing.expectError(error.SomeFailure, cmd_failure.run(args));
}

var test1_executed = false;
fn test1_handler(_: [][]const u8) anyerror!void {
    test1_executed = true;
}

test "sub commands" {
    const name = "test";
    const help = "test help";

    const allocator = testing.allocator;
    var unknown_args = try allocator.alloc([]const u8, 3);
    unknown_args[0] = "one";
    unknown_args[1] = "two";
    unknown_args[2] = "three";

    const cmd = Self{
        .name = name,
        .help = help,
        .sub_cmds = &[_]Self{.{ .name = "test1", .help = "test1 help", .handler = test1_handler }},
    };
    cmd.run(unknown_args);
    allocator.free(unknown_args);

    try testing.expectEqual(false, test1_executed);

    var args = try allocator.alloc([]const u8, 1);
    args[0] = "test1";
    defer allocator.free(args);

    cmd.run(unknown_args);
    try testing.expect(test1_executed);
}
