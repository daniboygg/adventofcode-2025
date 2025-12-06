const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const buffer = try std.fs.cwd().readFileAlloc(allocator, "input.txt", 1024 * 1024);
    defer allocator.free(buffer);

    var lines: std.ArrayList([]const u8) = .empty;
    defer lines.deinit(allocator);
    var iter = std.mem.splitSequence(u8, buffer, "\n");
    while (iter.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        try lines.append(allocator, line);
    }

    var result = try first(allocator, lines.items);
    std.debug.print("Result 1: {d}\n", .{result});

    result = try second(allocator, lines.items);
    std.debug.print("Result 2: {d}\n", .{result});
}

fn first(allocator: std.mem.Allocator, lines: [][]const u8) !usize {
    var ranges: std.ArrayList(Range) = .empty;
    defer ranges.deinit(allocator);

    var fresh = std.AutoHashMap(i64, void).init(allocator);
    defer fresh.deinit();

    for (lines) |line| {
        if (std.mem.indexOf(u8, line, "-") != null) {
            var iter = std.mem.splitSequence(u8, line, "-");
            try ranges.append(allocator, Range{
                .start = try std.fmt.parseInt(i64, iter.next() orelse unreachable, 10),
                .end = try std.fmt.parseInt(i64, iter.next() orelse unreachable, 10),
            });
        } else {
            const number = try std.fmt.parseInt(i64, line, 10);
            for (ranges.items) |range| {
                if (range.in_range(number)) {
                    try fresh.put(number, {});
                }
            }
        }
    }

    return fresh.count();
}

fn second(allocator: std.mem.Allocator, lines: [][]const u8) !usize {
    var ranges = std.AutoHashMap(Range, void).init(allocator);
    defer ranges.deinit();

    for (lines) |line| {
        if (std.mem.indexOf(u8, line, "-") != null) {
            var iter = std.mem.splitSequence(u8, line, "-");
            try ranges.put(Range{
                .start = try std.fmt.parseInt(i64, iter.next() orelse unreachable, 10),
                .end = try std.fmt.parseInt(i64, iter.next() orelse unreachable, 10),
            }, {});
        }
    }

    var processed = std.AutoHashMap(Range, void).init(allocator);
    defer processed.deinit();
    var ranges_array: std.ArrayList(Range) = .empty;
    defer ranges_array.deinit(allocator);

    var had_fusion = true;
    while (had_fusion) {
        had_fusion = false;

        ranges_array.clearRetainingCapacity();
        var iter = ranges.keyIterator();
        while (iter.next()) |key| {
            try ranges_array.append(allocator, key.*);
        }
        ranges.clearRetainingCapacity();

        for (ranges_array.items, 0..) |range1, i| {
            if (processed.contains(range1)) {
                continue;
            }

            for (ranges_array.items[i+1..]) |range2| {
                if (range1.overlaps(range2) or range2.overlaps(range1)) {
                    const fusion = range1.fusion(range2);
                    try ranges.put(fusion, {});
                    try processed.put(range1, {});
                    try processed.put(range2, {});
                    had_fusion = true;
                    break;
                }
            }
            if (!processed.contains(range1)) {
                try ranges.put(range1, {});
            }
        }

        processed.clearRetainingCapacity();
    }

    var sum: usize = 0;
    var final_iter = ranges.keyIterator();
    while (final_iter.next()) |range| {
        sum += @intCast(range.end - range.start + 1);
    }

    return sum;
}

const Range = struct {
    start: i64,
    end: i64,

    pub fn in_range(self: Range, n: i64) bool {
        return self.start <= n and n <= self.end;
    }

    pub fn contains(self: Range, other: Range) bool {
        return self.start <= other.start and self.end >= other.end;
    }

    pub fn overlaps(self: Range, other: Range) bool {
        return self.in_range(other.start) or self.in_range(other.end);
    }

    pub fn fusion(self: Range, other: Range) Range {
        std.debug.assert(self.overlaps(other) or other.overlaps(self));
        return Range{
            .start = @min(self.start, other.start),
            .end = @max(self.end, other.end),
        };
    }
};

test {
    const range = Range{ .start = 5, .end = 10 };
    try std.testing.expectEqual(true, range.overlaps(Range{ .start = 4, .end = 5 }));
    try std.testing.expectEqual(
        Range{ .start = 4, .end = 10 },
        range.fusion(Range{ .start = 4, .end = 5 }),
    );
    try std.testing.expectEqual(true, range.overlaps(Range{ .start = 10, .end = 11 }));
    try std.testing.expectEqual(
        Range{ .start = 5, .end = 11 },
        range.fusion(Range{ .start = 10, .end = 11 }),
    );

    // fusion should cover contains
    try std.testing.expectEqual(true, range.overlaps(Range{ .start = 5, .end = 6 }));
    try std.testing.expectEqual(
        Range{ .start = 5, .end = 10 },
        range.fusion(Range{ .start = 5, .end = 6 }),
    );
    try std.testing.expectEqual(true, range.overlaps(Range{ .start = 9, .end = 11 }));
    try std.testing.expectEqual(
        Range{ .start = 5, .end = 10 },
        range.fusion(Range{ .start = 9, .end = 10 }),
    );
    try std.testing.expectEqual(true, range.overlaps(Range{ .start = 6, .end = 8 }));
    try std.testing.expectEqual(
        Range{ .start = 5, .end = 10 },
        range.fusion(Range{ .start = 6, .end = 8 }),
    );

    try std.testing.expectEqual(false, range.overlaps(Range{ .start = 1, .end = 4 }));
    try std.testing.expectEqual(false, range.overlaps(Range{ .start = 11, .end = 12 }));
}
