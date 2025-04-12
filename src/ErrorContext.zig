const ErrorContext = @This();

const std = @import("std");
const testing = std.testing;

arg: ?[]const u8 = null,
msg: ?[]const u8 = null,
populated: bool = false,

pub const Error = error{ AlreadyPopulated, MsgCannotBeEmpty };

/// Records the argument and diagnostic message associated with the report.
/// This function prepares the report for output by capturing relevant context.
pub fn record(self: *ErrorContext, arg: []const u8, msg: []const u8) Error!void {
    // Return an error if our `Report` is already populated by a previous
    // error. It is best to deal with current error first and overwrite it
    // with another message.
    if (self.populated) return Error.AlreadyPopulated;

    // A diagnostic or error message should never be empty — even if
    // the error seems obvious. Messages should be succinct, meaningful,
    // and easy to understand.
    if (msg.len < 1) return Error.MsgCannotBeEmpty;
    self.msg = msg;

    // It's possible to encounter an empty input, especially in cases
    // where a non-empty argument is expected. When generating diagnostics,
    // the `Report` will explicitly reflect that an empty argument was received,
    // making the issue clear during output.
    self.arg = arg;

    // Mark this `Report` as populated, In general it would be bad to overwrite
    // a previous error. There might be cases where a previous meaningful error
    // is overwritten by an empty message.
    self.populated = true;
}

pub fn write(self: ErrorContext, writer: std.io.AnyWriter) !void {
    if (self.populated) {
        try std.fmt.format(
            writer,
            "Status: Failure\nArgument: {any}\n{any}",
            .{ self.arg, self.msg },
        );
    } else {
        try writer.writeAll("Status: OK\nNothing to report");
    }
}

test {
    var rep = ErrorContext{};
    var rep2 = ErrorContext{};

    const arg = "test";
    const msg = "Test Error Message";

    // record
    try testing.expect(rep.arg == null);
    try testing.expect(rep.msg == null);
    try testing.expectEqual(false, rep.populated);

    try rep.record("", msg);

    try testing.expect(rep.populated);

    try testing.expect(rep.arg != null);
    try testing.expect(rep.arg.?.len == 0);

    try testing.expect(rep.msg != null);
    try testing.expect(rep.msg.?.len > 0);
    try testing.expectEqualStrings(msg, rep.msg.?);

    try testing.expectError(Error.AlreadyPopulated, rep.record("", ""));

    try testing.expectError(Error.MsgCannotBeEmpty, rep2.record("", ""));

    try rep2.record(arg, msg);

    try testing.expect(rep2.populated);

    try testing.expect(rep2.arg != null);
    try testing.expect(rep2.arg.?.len > 0);
    try testing.expectEqualStrings(arg, rep2.arg.?);

    try testing.expect(rep2.msg != null);
    try testing.expect(rep2.msg.?.len > 0);
    try testing.expectEqualStrings(msg, rep2.msg.?);

    // Write
    // case: report msg
    const repExpectedMsg = std.fmt.comptimePrint(
        "Status: Failure\nArgument: {any}\n{any}",
        .{ "", msg },
    );

    var buf: [repExpectedMsg.len]u8 = undefined;

    var bufStream = std.io.fixedBufferStream(&buf);
    const writer = bufStream.writer().any();

    try rep.write(writer);

    try testing.expectEqualStrings(repExpectedMsg, &buf);

    // case: report arg & msg
    const rep2ExpectedMsg = std.fmt.comptimePrint(
        "Status: Failure\nArgument: {any}\n{any}",
        .{ arg, msg },
    );

    var buf2: [rep2ExpectedMsg.len]u8 = undefined;
    var buf2Stream = std.io.fixedBufferStream(&buf2);
    const writer2 = buf2Stream.writer().any();

    try rep2.write(writer2);

    try testing.expectEqualStrings(rep2ExpectedMsg, &buf2);

    // case: nothing to report
    var rep3 = ErrorContext{};

    const rep3ExpectedMsg = "Status: OK\nNothing to report";

    var buf3: [rep3ExpectedMsg.len]u8 = undefined;
    var buf3Writer = std.io.fixedBufferStream(&buf3);
    const writer3 = buf3Writer.writer().any();

    try rep3.write(writer3);

    try testing.expectEqualStrings(rep3ExpectedMsg, &buf3);
}
