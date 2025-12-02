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
    var accum: usize = 0;
    for (lines) |line| {
        var iter = std.mem.splitSequence(u8, line, ",");
        while (iter.next()) |sequence| {
            var numbers = std.mem.splitSequence(u8, sequence, "-");
            const first_number = try std.fmt.parseInt(usize, numbers.next().?, 10);
            const last_number = try std.fmt.parseInt(usize, numbers.next().?, 10);

            for (first_number..last_number + 1) |current| {
                if (try contains_repeated_1(current)) {
                    accum += current;
                }
            }
        }
    }

    return @intCast(accum);
}

fn contains_repeated_1(value: usize) !bool {
    var buf: [256]u8 = undefined;
    const str = try std.fmt.bufPrint(&buf, "{}", .{value});
    if (@mod(str.len, 2) != 0) {
        return false;
    }

    for (@divFloor(str.len, 2)..str.len) |index| {
        const slice = str[0..index];
        const ocurrences: usize = std.mem.count(u8, str, slice);
        if (ocurrences > 1) {
            return true;
        }
    }
    return false;
}

fn second(_: std.mem.Allocator, lines: [][]const u8) !i64 {
    var accum: usize = 0;
    for (lines) |line| {
        var iter = std.mem.splitSequence(u8, line, ",");
        while (iter.next()) |sequence| {
            var numbers = std.mem.splitSequence(u8, sequence, "-");
            const first_number = try std.fmt.parseInt(usize, numbers.next().?, 10);
            const last_number = try std.fmt.parseInt(usize, numbers.next().?, 10);

            for (first_number..last_number + 1) |current| {
                if (try contains_repeated_2(current)) {
                    accum += current;
                }
            }
        }
    }

    return @intCast(accum);
}

fn contains_repeated_2(value: usize) !bool {
    var buf: [256]u8 = undefined;
    const str = try std.fmt.bufPrint(&buf, "{}", .{value});

    for (1..str.len / 2 + 1) |index| {
        const slice = str[0..index];
        const ocurrences: usize = std.mem.count(u8, str, slice);
        if (ocurrences >= str.len) {
            return true;
        }
        const gcd = std.math.gcd(slice.len,str.len);
        if (str.len / gcd == ocurrences) {
            return true;
        }
    }
    return false;
}
