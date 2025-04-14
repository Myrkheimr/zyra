const cli = @import("cli.zig");

pub const Command = cli.Command;
pub const ErrorContext = @import("ErrorContext.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
