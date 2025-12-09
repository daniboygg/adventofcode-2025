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

fn first(_: std.mem.Allocator, lines: [][]const u8) !i64 {
    var sum: i64 = 0;
    for (lines) |line| {
        var joltage: i64 = 0;

        for (0..line.len - 1) |i| {
            for (i + 1..line.len) |j| {
                if (i == j) {
                    continue;
                }
                var buff: [2]u8 = undefined;
                buff[0] = line[i];
                buff[1] = line[j];
                const number = try std.fmt.parseInt(i64, buff[0..], 10);
                if (number > joltage) {
                    joltage = number;
                }
            }
        }
        sum += joltage;
    }
    return sum;
}

fn second(_: std.mem.Allocator, lines: [][]const u8) !i64 {
    var sum: i64 = 0;
    for (lines) |line| {

        const window_size: usize = 12;
        var number_buffer: [window_size]u8 = undefined;

        var current_number: usize = 1;
        var from: usize = 0;
        while (current_number <= window_size) {
            const to = line.len - (window_size - current_number);
            const window = line[from..to];

            var max: usize = 0;
            var max_index: usize = 0;
            for (0..window.len) |i| {
                const number = try std.fmt.parseInt(usize, window[i..i+1], 10);
                if (number > max) {
                    max = number;
                    max_index = i;
                }
            }
            number_buffer[current_number-1] = window[max_index];
            current_number += 1;
            from = from + 1 + max_index;
        }

        sum += try std.fmt.parseInt(i64, &number_buffer, 10);
    }
    return sum;
}