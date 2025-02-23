const std = @import("std");
const testing = std.testing;

/// [u8] gives us 8-bits of storage to save indexes. Meaning we can essentially store `2^(8-1) = 0-255` indexes.
///
/// Total of 256 element indexes, which is more than enough for our use case to store indexes of elements from an Array
/// as value reference in our map.
///
/// Keys are of type `[]const u8`.
const IndexMap = std.StaticStringMap(u8);

pub fn HashBackedArray(comptime V: type) type {
    return struct {
        const Self = @This();

        _array: []const V,
        _index_map: IndexMap,
        len: usize,

        pub const KV = struct { []const u8, V };

        pub fn initComptime(comptime Arr: []const V, comptime key: fn (e: V) []const u8) Self {
            const kvs: [Arr.len]KV = undefined;

            for (Arr, 0..) |a, i| {
                kvs[i] = .{ key(a), i };
            }

            return .{
                ._array = Arr,
                ._index_map = IndexMap.initComptime(kvs),
                .len = Arr.len,
            };
        }

        pub fn has(self: *Self, key: []const u8) bool {
            return self._index_map.has(key);
        }

        pub fn values(self: *Self) []const V {
            return self._array;
        }

        pub fn keys(self: *Self) []const []const u8 {
            return self._index_map.keys();
        }

        pub fn get(self: *Self, key: []const u8) ?V {
            if (!self.has(key)) return null;

            return self._array[self._index_map.get(key)];
        }

        pub fn indexOf(self: *Self, key: []const u8) ?u8 {
            return self._index_map.get(key);
        }
    };
}
