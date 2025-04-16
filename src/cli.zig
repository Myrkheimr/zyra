const std = @import("std");
const testing = std.testing;

const StaticStringSet = std.StaticStringMap(void);
const StaticStringOptionMap = std.StaticStringMap([]const u8);

const StaticStringSetEntry = struct { []const u8 };
const StaticStringOptionMapEntry = struct { []const u8, []const u8 };

fn countValidOptions(comptime name: []const u8, comptime options: []const u8) usize {
    var count: usize = 0;

    var it = std.mem.splitScalar(u8, options, '\n');
    while (it.next()) |line| {
        const trimmed_line = std.mem.trim(u8, line, " ");

        if (trimmed_line.len == 0) continue;

        if (!std.mem.startsWith(u8, trimmed_line, "-")) {
            @compileError(
                std.fmt.comptimePrint(
                    \\Error: Invalid `options` Spec 
                    \\
                    \\Command: {s}
                    \\Option: {s}
                ,
                    .{ name, trimmed_line },
                ),
            );
        } else {
            count += 1;
        }
    }

    return count;
}

const ComptimeCommandInternal = struct {
    option_set: StaticStringSet,
    short_to_long_option_mapping: StaticStringOptionMap,
};

pub const ComptimeCommand = struct {
    name: []const u8,
    _internal: ComptimeCommandInternal,
};

pub const CommandSpec = struct {
    options: []const u8 = "",
    sub_cmds: []const ComptimeCommand = &[_]ComptimeCommand{},
};

pub fn Command(comptime name: []const u8, comptime Spec: CommandSpec) ComptimeCommand {
    const comptime_command_internal = comptime command_internal: {
        const option_count = countValidOptions(name, Spec.options);

        var setEntries: [option_count]StaticStringSetEntry = undefined;
        var mapEntries: [option_count]StaticStringOptionMapEntry = undefined;

        var generated_entry_count: usize = 0;
        var it = std.mem.splitScalar(u8, Spec.options, '\n');

        while (it.next()) |line| {
            const trimmed_line = std.mem.trim(u8, line, " ");

            if (trimmed_line.len == 0) continue;

            const short, const long = part_scope: {
                var partIter = std.mem.splitAny(u8, trimmed_line, ", ");

                var shortPart: []const u8 = "";
                var longPart: []const u8 = "";

                while (partIter.next()) |part| {
                    if (std.mem.startsWith(u8, part, "--")) {
                        longPart = part[2..part.len];
                    } else if (std.mem.startsWith(u8, part, "-")) {
                        shortPart = part[1..part.len];
                    }
                }

                if (shortPart.len == 0 or longPart.len == 0) {
                    @compileError(
                        std.fmt.comptimePrint(
                            "\n{s}\n\n{s}\n\nShort: {s}\nLong: {s}",
                            .{
                                "Error: Invalid option declaration",
                                trimmed_line,
                                shortPart,
                                longPart,
                            },
                        ),
                    );
                }

                break :part_scope .{ shortPart, longPart };
            };

            setEntries[generated_entry_count] = .{long};
            mapEntries[generated_entry_count] = .{ short, long };

            generated_entry_count += 1;
        }

        // Verify that created entries are equal to the number of provided options
        if (generated_entry_count != option_count) @compileError(
            std.fmt.comptimePrint(
                "\n{s} {s}\nExpected: {d}\nGot: {d}",
                .{
                    "Error: Mismatched option count for Command",
                    name,
                    option_count,
                    generated_entry_count,
                },
            ),
        );

        const internal: ComptimeCommandInternal = .{
            .option_set = StaticStringSet.initComptime(setEntries),
            .short_to_long_option_mapping = StaticStringOptionMap.initComptime(mapEntries),
        };

        break :command_internal internal;
    };

    return .{
        .name = name,
        ._internal = comptime_command_internal,
    };
}

test "Command" {
    const name = "test";
    const long_options = [_][]const u8{ "output", "verbose", "help" };
    const short_options = [_][]const u8{ "o", "v", "h" };

    const cmd = Command(
        "test",
        .{
            .options =
            \\ -o, --output     Output file path
            \\ -v, --verbose    Enable verbose mode
            \\ -h, --help       Show this help message and exit
            ,
        },
    );

    try testing.expectEqualStrings(name, cmd.name);
    try testing.expectEqual(long_options.len, cmd._internal.option_set.keys().len);
    try testing.expectEqual(short_options.len, cmd._internal.short_to_long_option_mapping.keys().len);
    try testing.expectEqual(cmd._internal.option_set.keys().len, cmd._internal.short_to_long_option_mapping.keys().len);

    for (long_options) |opt| {
        try testing.expect(cmd._internal.option_set.has(opt));
    }

    for (short_options) |opt| {
        try testing.expect(cmd._internal.short_to_long_option_mapping.has(opt));
    }

    for (cmd._internal.short_to_long_option_mapping.keys()) |key| {
        const mapping = cmd._internal.short_to_long_option_mapping.get(key) orelse "";
        try testing.expect(cmd._internal.option_set.has(mapping));
    }
}
