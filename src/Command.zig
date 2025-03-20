const Command = @This();

const std = @import("std");
const Flag = @import("Flag.zig");
const Option = @import("Option.zig");

const testing = std.testing;

name: []const u8,
help: []const u8 = "",
flags: []const Flag = &[0]Flag{},
options: []const Option = &[0]Option{},
sub_cmds: []const Command = &[0]Command{},
handler: ?fn (args: [][]const u8) void = null,

pub fn run(self: *const Command, args: [][]const u8) void {
    inline for (self.sub_cmds) |cmd| {
        if (std.mem.eql(u8, args[0], cmd.name)) {
            cmd.run(args[1..]);
            return;
        }
    }

    if (self.handler) |handle| {
        handle(args);
    } else {
        std.debug.print("Unknown Command: {s}\n", .{args[0]});
    }

    if (args.len == 0) {
        std.debug.print("Usage: {s}\n", .{self.name});
        return;
    }
}

test "init" {
    const name = "test";
    const help = "test help";
    const cmd = Command{ .name = name, .help = help };

    try testing.expectEqualStrings(name, cmd.name);
    try testing.expectEqualStrings(help, cmd.help);
}

fn testHandler(args: [][]const u8) void {
    _ = args;
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

    const cmd = Command{ .name = name, .help = help, .handler = testHandler };
    const handler_success = blk: {
        cmd.run(args);
        break :blk true;
    };

    try testing.expect(handler_success);
}

var sub_test1_executed = false;
fn sub_test1_handler(_: [][]const u8) void {
    sub_test1_executed = true;
}

test "sub commands" {
    const name = "test";
    const help = "test help";

    const allocator = testing.allocator;
    var unknown_args = try allocator.alloc([]const u8, 3);
    unknown_args[0] = "one";
    unknown_args[1] = "two";
    unknown_args[2] = "three";

    const cmd = Command{
        .name = name,
        .help = help,
        .sub_cmds = &[_]Command{.{ .name = "test1", .help = "test1 help", .handler = sub_test1_handler }},
    };
    cmd.run(unknown_args);
    allocator.free(unknown_args);

    try testing.expectEqual(false, sub_test1_executed);

    var args = try allocator.alloc([]const u8, 1);
    args[0] = "test1";
    defer allocator.free(args);

    cmd.run(args);
    try testing.expect(sub_test1_executed);
}
