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
    var board: std.ArrayList([]u8) = .empty;
    defer board.deinit(allocator);

    var start: Pos = undefined;

    for (0..lines.len) |row| {
        var row_board: std.ArrayList(u8) = .empty;
        defer row_board.deinit(allocator);

        for (0..lines[row].len) |col| {
            const char = lines[row][col];
            if (char == 'S') {
                start = Pos{
                    .row = @intCast(row),
                    .col = @intCast(col),
                };
            }
            try row_board.append(allocator, char);
        }

        try board.append(allocator, try row_board.toOwnedSlice(allocator));
    }

    var beams = std.AutoHashMap(Pos, void).init(allocator);
    defer beams.deinit();
    try beams.put(start, {});

    var next_beams = std.AutoHashMap(Pos, void).init(allocator);
    defer next_beams.deinit();

    var count: usize = 0;
    while (beams.count() > 0) {
        next_beams.clearRetainingCapacity();

        var iter = beams.keyIterator();
        while (iter.next()) |beam| {
            if (beam.move(.down, 1, board.items.len)) |next| {
                board.items[@intCast(beam.row)][@intCast(beam.col)] = '|';
                if (board.items[@intCast(next.row)][@intCast(next.col)] == '^') {
                    if (next.move(.left, 1, board.items[0].len)) |left| {
                        try next_beams.put(left, {});
                    }
                    if (next.move(.right, 1, board.items[0].len)) |right| {
                        try next_beams.put(right, {});
                    }
                    count += 1;
                } else {
                    try next_beams.put(next, {});
                }
            }
        }

        // Clone next_beams into beams
        beams.clearRetainingCapacity();
        var next_iter = next_beams.keyIterator();
        while (next_iter.next()) |key| {
            try beams.put(key.*, {});
        }
    }

    return count;
}

fn second(allocator: std.mem.Allocator, lines: [][]const u8) !usize {
    var board: std.ArrayList([]u8) = .empty;
    defer board.deinit(allocator);

    var start: Pos = undefined;

    for (0..lines.len) |row| {
        var row_board: std.ArrayList(u8) = .empty;
        defer row_board.deinit(allocator);

        for (0..lines[row].len) |col| {
            const char = lines[row][col];
            if (char == 'S') {
                start = Pos{
                    .row = @intCast(row),
                    .col = @intCast(col),
                };
            }
            try row_board.append(allocator, char);
        }

        try board.append(allocator, try row_board.toOwnedSlice(allocator));
    }

    // Track count of timelines for each position
    var beams = std.AutoHashMap(Pos, usize).init(allocator);
    defer beams.deinit();
    try beams.put(start, 1);

    var next_beams = std.AutoHashMap(Pos, usize).init(allocator);
    defer next_beams.deinit();

    var total_timelines: usize = 0;
    while (beams.count() > 0) {
        next_beams.clearRetainingCapacity();

        var iter = beams.iterator();
        while (iter.next()) |entry| {
            const beam = entry.key_ptr.*;
            const timeline_count = entry.value_ptr.*;

            if (beam.move(.down, 1, board.items.len)) |next| {
                if (board.items[@intCast(next.row)][@intCast(next.col)] == '^') {
                    // Split into two beams, each carrying the same number of timelines
                    if (next.move(.left, 1, board.items[0].len)) |left| {
                        const result = try next_beams.getOrPut(left);
                        if (result.found_existing) {
                            result.value_ptr.* += timeline_count;
                        } else {
                            result.value_ptr.* = timeline_count;
                        }
                    }
                    if (next.move(.right, 1, board.items[0].len)) |right| {
                        const result = try next_beams.getOrPut(right);
                        if (result.found_existing) {
                            result.value_ptr.* += timeline_count;
                        } else {
                            result.value_ptr.* = timeline_count;
                        }
                    }
                } else {
                    // Continue with same timeline count
                    const result = try next_beams.getOrPut(next);
                    if (result.found_existing) {
                        result.value_ptr.* += timeline_count;
                    } else {
                        result.value_ptr.* = timeline_count;
                    }
                }
            } else {
                // Beam exits - add its timeline count to total
                total_timelines += timeline_count;
            }
        }

        // Clone next_beams into beams
        beams.clearRetainingCapacity();
        var next_iter = next_beams.iterator();
        while (next_iter.next()) |entry| {
            try beams.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return total_timelines;
}

const Pos = struct {
    row: i64,
    col: i64,

    pub fn move(self: Pos, direction: Direction, multiplier: i64, size: usize) ?Pos {
        switch (direction) {
            .up => {
                if (self.row - 1 * multiplier < 0) {
                    return null;
                }
                return Pos{ .row = self.row - 1 * multiplier, .col = self.col };
            },
            .right_up => {
                if (self.row - 1 * multiplier < 0) {
                    return null;
                }
                if (self.col + 1 * multiplier > size - 1) {
                    return null;
                }
                return Pos{ .row = self.row - 1 * multiplier, .col = self.col + 1 * multiplier };
            },
            .right => {
                if (self.col + 1 * multiplier > size - 1) {
                    return null;
                }
                return Pos{ .row = self.row, .col = self.col + 1 * multiplier };
            },
            .right_down => {
                if (self.row + 1 * multiplier > size - 1) {
                    return null;
                }
                if (self.col + 1 * multiplier > size - 1) {
                    return null;
                }
                return Pos{ .row = self.row + 1 * multiplier, .col = self.col + 1 * multiplier };
            },
            .down => {
                if (self.row + 1 * multiplier > size - 1) {
                    return null;
                }
                return Pos{ .row = self.row + 1 * multiplier, .col = self.col };
            },
            .left_down => {
                if (self.row + 1 * multiplier > size - 1) {
                    return null;
                }
                if (self.col - 1 * multiplier < 0) {
                    return null;
                }
                return Pos{ .row = self.row + 1 * multiplier, .col = self.col - 1 * multiplier };
            },
            .left => {
                if (self.col - 1 * multiplier < 0) {
                    return null;
                }
                return Pos{ .row = self.row, .col = self.col - 1 * multiplier };
            },
            .left_up => {
                if (self.row - 1 * multiplier < 0) {
                    return null;
                }
                if (self.col - 1 * multiplier < 0) {
                    return null;
                }
                return Pos{ .row = self.row - 1 * multiplier, .col = self.col - 1 * multiplier };
            },
        }
    }
};

const Direction = enum {
    up,
    right_up,
    right,
    right_down,
    down,
    left_down,
    left,
    left_up,
};
