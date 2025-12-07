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

fn first(allocator: std.mem.Allocator, lines: [][]const u8) !i64 {
    var numbers: std.ArrayList([]const i64) = .empty;
    defer numbers.deinit(allocator);

    for (lines[0 .. lines.len - 1]) |line| {
        var iter = std.mem.tokenizeScalar(u8, line, ' ');

        var buffer = try allocator.alloc(i64, 1024);
        var i: usize = 0;
        while (iter.next()) |item| {
            buffer[i] = try std.fmt.parseInt(i64, item, 10);
            i += 1;
        }

        const slice = buffer[0..i];
        try numbers.append(allocator, slice);
    }

    var operators: std.ArrayList([]const u8) = .empty;
    defer operators.deinit(allocator);

    var iter = std.mem.tokenizeScalar(u8, lines[lines.len - 1], ' ');
    while (iter.next()) |item| {
        try operators.append(allocator, item);
    }

    var result: i64 = 0;
    for (0..numbers.items[0].len) |col| {
        var accum: i64 = 0;
        if (operators.items[col][0] == '*') {
            accum = 1;
        }
        for (0..numbers.items.len) |row| {
            if (operators.items[col][0] == '+') {
                accum += numbers.items[row][col];
            } else {
                accum *= numbers.items[row][col];
            }
        }

        result += accum;
    }

    return result;
}

fn second(allocator: std.mem.Allocator, lines: [][]const u8) !i64 {
    var operators: std.ArrayList(Operator) = .empty;
    defer operators.deinit(allocator);
    var last_index: usize = 0;
    for (lines[lines.len - 1], 0..) |item, index| {
        if (item == ' ') {
            continue;
        }
        try operators.append(allocator, Operator{
            .char = item,
            .size = index,
            .index = index,
        });
        if (operators.items.len > 1) {
            operators.items[operators.items.len - 2].size = index - operators.items[operators.items.len - 2].size;
        }
        last_index = index;
    }
    operators.items[operators.items.len - 1].size = lines[lines.len - 1].len - operators.items[operators.items.len - 1].size;

    // std.debug.print("{any}\n", .{operators});

    var numbers: std.ArrayList([][]const u8) = .empty;
    defer numbers.deinit(allocator);
    for (0..lines.len - 1) |i| {
        const line: []const u8 = lines[i];

        var buffer: std.ArrayList([]const u8) = .empty;
        defer buffer.deinit(allocator);

        var index: usize = 0;
        for (operators.items) |operator| {
            try buffer.append(allocator, line[index .. index + operator.size - 1]);
            index += operator.size;
        }
        try numbers.append(allocator, try buffer.toOwnedSlice(allocator));
    }

    var result: i64 = 0;
    for (operators.items, 0..) |operator, operator_index| {
        // std.debug.print("operator :{any} \n", .{operator});

        var accum: i64 = 0;
        if (operator.char == '*') {
            accum = 1;
        }

        var number_i: usize = 0;
        const limit = operator.size - 1;
        // std.debug.print("  lim: {}\n", .{limit});
        while (number_i < limit) {
            // + 1 hack for some edge condition, since we init with ' ' and then we trim is safe to allocate more
            const buff = try allocator.alloc(u8, operator.size+1);
            @memset(buff, ' ');
            var buffer_i: usize = 0;
            for (0..numbers.items.len) |row| {
                if (number_i >= numbers.items[row][operator_index].len) {
                    buff[buffer_i] = ' ';
                } else {
                    buff[buffer_i] = numbers.items[row][operator_index][number_i];
                }
                buffer_i += 1;
            }
            // std.debug.print(" buff: {s}\n", .{buff});

            const number = try std.fmt.parseInt(i64, std.mem.trim(u8, buff, " "), 10);
            if (operator.char == '*') {
                accum *= number;
            } else {
                accum += number;
            }

            number_i += 1;
        }
        // std.debug.print(" accum: {}\n", .{accum});

        result += accum;
    }

    return result;
}

const Operator = struct {
    char: u8,
    size: usize,
    index: usize,
};
