const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const buffer = try std.fs.cwd().readFileAlloc(allocator, "input.txt", 1024 * 1024);
    defer allocator.free(buffer);

    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();
    var iter = std.mem.splitSequence(u8, buffer, "\n");
    while (iter.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        try lines.append(line);
    }

    var result = try first(allocator, lines.items);
    std.debug.print("Result 1: {d}\n", .{result});

    result = try second(allocator, lines.items);
    std.debug.print("Result 2: {d}\n", .{result});
}

fn first(_: std.mem.Allocator, lines: [][]const u8) !i32 {
    const max: i32 = 100;
    const start: i32 = 50;
    var current: i32 = start;
    var zero_count: i32 = 0;

    for (lines) |line| {
        const direction = line[0];
        const amount: i32 = try std.fmt.parseInt(i32, line[1..], 10);

        current = switch (direction) {
            'L' => @mod(current - amount, max),
            'R' => @mod(current + amount, max),
            else => unreachable,
        };
        if (current == 0) {
            zero_count += 1;
        }
    }

    return zero_count;
}

fn second(_: std.mem.Allocator, lines: [][]const u8) !i32 {
    const max: i32 = 100;
    const start: i32 = 50;
    var current: i32 = start;
    var zero_count: i32 = 0;

    for (lines) |line| {
        const direction = line[0];
        const amount: i32 = try std.fmt.parseInt(i32, line[1..], 10);

        current = switch (direction) {
            'L' => blk: {
                if (current - amount <= 0) {
                    zero_count += @divFloor(current - amount - max, -max);
                }
                if (current == 0) {
                    // when we start at 0 do not count
                    // it's already counted in previous cycle
                    zero_count -= 1;
                }
                break :blk @mod(current - amount, max);
            },
            'R' => blk: {
                zero_count += @divFloor(current + amount, max);
                break :blk @mod(current + amount, max);
            },
            else => unreachable,
        };
    }

    return zero_count;
}
