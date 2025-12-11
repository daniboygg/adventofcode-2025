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
    var points: std.ArrayList(Point) = .empty;
    for (lines) |line| {
        var numbers = std.mem.splitSequence(u8, line, ",");
        try points.append(allocator, Point{
            .x = try std.fmt.parseInt(usize, numbers.next() orelse unreachable, 10),
            .y = try std.fmt.parseInt(usize, numbers.next() orelse unreachable, 10),
            .z = try std.fmt.parseInt(usize, numbers.next() orelse unreachable, 10),
        });
    }

    var connections: std.ArrayList(Connection) = .empty;
    for (points.items[0 .. points.items.len - 1], 0..) |p1, i| {
        for (points.items[i + 1 .. points.items.len]) |p2| {
            try connections.append(allocator, Connection{
                .p1 = p1,
                .p2 = p2,
                .distance = p1.distance(p2),
            });
        }
    }
    std.mem.sort(Connection, connections.items, {}, struct {
        fn lessThan(_: void, a: Connection, b: Connection) bool {
            return a.distance < b.distance;
        }
    }.lessThan);

    var circuits: std.ArrayList(Circuit) = .empty;
    for (connections.items[0..1000]) |conn| {
        const idx1 = belongs(circuits.items, conn.p1);
        const idx2 = belongs(circuits.items, conn.p2);

        if (idx1 == null and idx2 == null) {
            var new_circuit = Circuit.init(allocator);
            try new_circuit.put(conn.p1, {});
            try new_circuit.put(conn.p2, {});
            try circuits.append(allocator, new_circuit);
            continue;
        }

        if (idx1) |i| {
            if (idx2) |j| {
                if (i == j) {
                    continue;
                }
                var iter = circuits.items[j].keyIterator();
                while (iter.next()) |point| {
                    try circuits.items[i].put(point.*, {});
                }
                _ = circuits.swapRemove(j);
            } else {
                try circuits.items[i].put(conn.p2, {});
            }
            continue;
        }

        if (idx2) |i| {
            try circuits.items[i].put(conn.p1, {});
        }
    }

    std.mem.sort(Circuit, circuits.items, {}, struct {
        fn lessThan(_: void, a: Circuit, b: Circuit) bool {
            return a.count() > b.count();
        }
    }.lessThan);

    var sum: usize = 1;
    for (circuits.items[0..3]) |circuit| {
        sum *= circuit.count();
    }
    return sum;
}

fn second(allocator: std.mem.Allocator, lines: [][]const u8) !usize {
    var points: std.ArrayList(Point) = .empty;
    for (lines) |line| {
        var numbers = std.mem.splitSequence(u8, line, ",");
        try points.append(allocator, Point{
            .x = try std.fmt.parseInt(usize, numbers.next() orelse unreachable, 10),
            .y = try std.fmt.parseInt(usize, numbers.next() orelse unreachable, 10),
            .z = try std.fmt.parseInt(usize, numbers.next() orelse unreachable, 10),
        });
    }

    var connections: std.ArrayList(Connection) = .empty;
    for (points.items[0 .. points.items.len - 1], 0..) |p1, i| {
        for (points.items[i + 1 .. points.items.len]) |p2| {
            try connections.append(allocator, Connection{
                .p1 = p1,
                .p2 = p2,
                .distance = p1.distance(p2),
            });
        }
    }
    std.mem.sort(Connection, connections.items, {}, struct {
        fn lessThan(_: void, a: Connection, b: Connection) bool {
            return a.distance < b.distance;
        }
    }.lessThan);

    var circuits: std.ArrayList(Circuit) = .empty;
    for (connections.items) |conn| {
        // std.debug.print("circuits {any}\n", .{circuits.items.len});
        // std.debug.print("processing conn {any}\n", .{conn});

        const idx1 = belongs(circuits.items, conn.p1);
        const idx2 = belongs(circuits.items, conn.p2);

        if (idx1 == null and idx2 == null) {
            var new_circuit = Circuit.init(allocator);
            try new_circuit.put(conn.p1, {});
            try new_circuit.put(conn.p2, {});
            try circuits.append(allocator, new_circuit);
            continue;
        }

        if (idx1) |i| {
            if (idx2) |j| {
                if (i == j) {
                    continue;
                }
                var iter = circuits.items[j].keyIterator();
                while (iter.next()) |point| {
                    try circuits.items[i].put(point.*, {});
                }
                _ = circuits.swapRemove(j);
            } else {
                try circuits.items[i].put(conn.p2, {});
            }
        } else if (idx2) |i| {
            try circuits.items[i].put(conn.p1, {});
        }

        if (circuits.items.len == 1 and circuits.items[0].count() == points.items.len) {
            return conn.p1.x * conn.p2.x;
        }
    }

    return 0;
}

fn belongs(circuits: []Circuit, point: Point) ?usize {
    for (circuits, 0..) |circuit, i| {
        if (circuit.contains(point)) {
            return i;
        }
    }
    return null;
}

const Circuit = std.AutoHashMap(Point, void);

const Connection = struct {
    p1: Point,
    p2: Point,
    distance: usize,

    pub fn format(self: Connection, writer: *std.io.Writer) !void {
        try writer.print("{},{},{} - {},{},{} = {}", .{
            self.p1.x,     self.p1.y, self.p1.z,
            self.p2.x,     self.p2.y, self.p2.z,
            self.distance,
        });
    }
};

const Point = struct {
    x: usize,
    y: usize,
    z: usize,

    fn distance(self: Point, other: Point) usize {
        const dx: i64 = @as(isize, @intCast(self.x)) - @as(isize, @intCast(other.x));
        const dy: i64 = @as(isize, @intCast(self.y)) - @as(isize, @intCast(other.y));
        const dz: i64 = @as(isize, @intCast(self.z)) - @as(isize, @intCast(other.z));
        return @intCast(dx * dx + dy * dy + dz * dz);
    }
};

fn print_slice(items: anytype, limit: usize) void {
    for (items, 0..) |value, i| {
        if (i == limit and limit > 0) {
            break;
        }
        std.debug.print("{}\n", .{value});
    }
    std.debug.print("\n", .{});
}
