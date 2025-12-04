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

fn first(_: std.mem.Allocator, lines: [][]const u8) !usize {
    var total: usize = 0;

    for (0..lines.len) |row| {
        for (0..lines[row].len) |col| {
            var count: usize = 0;
            const current = Pos{ .row = @intCast(row), .col = @intCast(col) };
            if (lines[row][col] != '@') {
                continue;
            }
            inline for (std.meta.fields(Direction)) |field| {
                const direction = @field(Direction, field.name);
                if (current.move(direction, 1, lines.len)) |peek| {
                    const r: usize = @intCast(peek.row);
                    const c: usize = @intCast(peek.col);
                    if(lines[r][c] == '@') {
                        count += 1;
                    }
                }
            }

            if (count < 4) {
                total += 1;
            }
        }
    }
    return total;
}

fn second(allocator: std.mem.Allocator, lines_src: [][]const u8) !usize {
    var total: usize = 0;

    var lines: std.ArrayList([]u8) = .empty;
    defer lines.clearAndFree(allocator);

    for (lines_src) |line| {
        const mutable_line = try allocator.dupe(u8, line);
        try lines.append(allocator, mutable_line);
    }

    outer: while(true) {
        var remove_list: std.ArrayList(Pos) = .empty;
        defer remove_list.deinit(allocator);

        for (0..lines.items.len) |row| {
            for (0..lines.items[row].len) |col| {
                var count: usize = 0;
                const current = Pos{ .row = @intCast(row), .col = @intCast(col) };
                if (lines.items[row][col] != '@') {
                    continue;
                }
                inline for (std.meta.fields(Direction)) |field| {
                    const direction = @field(Direction, field.name);
                    if (current.move(direction, 1, lines.items.len)) |peek| {
                        const r: usize = @intCast(peek.row);
                        const c: usize = @intCast(peek.col);
                        if(lines.items[r][c] == '@') {
                            count += 1;
                        }
                    }
                }

                if (count < 4) {
                    try remove_list.append(allocator, current);
                }
            }
        }

        total += remove_list.items.len;
        if (remove_list.items.len == 0) {
            break :outer;
        }
        for (remove_list.items) |pos| {
            const r: usize = @intCast(pos.row);
            const c: usize = @intCast(pos.col);
            lines.items[r][c] = '.';
        }
        remove_list.clearRetainingCapacity();
    }
    return total;
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
