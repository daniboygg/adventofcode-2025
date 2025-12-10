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
    var buffer: [1024]Point = undefined;
    var index: usize = 0;
    for (lines) |line| {
        var numbers = std.mem.splitSequence(u8, line, ",");
        buffer[index] = Point{
            .x = try std.fmt.parseInt(i64, numbers.next() orelse unreachable, 10),
            .y = try std.fmt.parseInt(i64, numbers.next() orelse unreachable, 10),
            .z = try std.fmt.parseInt(i64, numbers.next() orelse unreachable, 10),
        };
        index += 1;
    }
    const points = buffer[0..lines.len];

    var circuits: std.ArrayList(Circuit) = .empty;
    defer circuits.deinit(allocator);

    // Run the algorithm for 1000 iterations
    try algorithm(allocator, &circuits, points, 1000);

    return try multiply_top_3_circuits_len(allocator, circuits.items, points);
}

fn second(allocator: std.mem.Allocator, lines: [][]const u8) !i64 {
    var buffer: [1024]Point = undefined;
    var index: usize = 0;
    for (lines) |line| {
        var numbers = std.mem.splitSequence(u8, line, ",");
        buffer[index] = Point{
            .x = try std.fmt.parseInt(i64, numbers.next() orelse unreachable, 10),
            .y = try std.fmt.parseInt(i64, numbers.next() orelse unreachable, 10),
            .z = try std.fmt.parseInt(i64, numbers.next() orelse unreachable, 10),
        };
        index += 1;
    }
    const points = buffer[0..lines.len];

    var circuits: std.ArrayList(Circuit) = .empty;
    defer circuits.deinit(allocator);

    // Find the pair that connects everything into a single circuit
    const last_pair = try find_final_connection(allocator, &circuits, points);

    return last_pair.p1.x * last_pair.p2.x;
}

const Circuit = struct {
    points: std.AutoHashMap(Point, void) = undefined,

    fn init(self: *Circuit, allocator: std.mem.Allocator) void {
        self.points = std.AutoHashMap(Point, void).init(allocator);
    }

    fn append(self: *Circuit, p: Point) !void {
        try self.points.put(p, {});
    }

    fn has_point(self: Circuit, p: Point) bool {
        var iter = self.points.keyIterator();
        while (iter.next()) |point| {
            if (point.equal(p)) {
                return true;
            }
        }
        return false;
    }
};

const Point = struct {
    x: i64,
    y: i64,
    z: i64,

    fn equal(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    fn distance(self: Point, other: Point) i64 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        // Use squared distance to preserve ordering without floating point
        return dx * dx + dy * dy + dz * dz;
    }
};

fn find_point_in_circuit(circuits: []Circuit, point: Point) ?*Circuit {
    for (circuits) |*circuit| {
        if (circuit.has_point(point)) {
            return circuit;
        }
    }
    return null;
}

const PointPair = struct {
    p1: Point,
    p2: Point,
    distance: i64,
};

fn find_final_connection(allocator: std.mem.Allocator, circuits: *std.ArrayList(Circuit), points: []const Point) !PointPair {
    // Generate all pairs and their distances
    var pairs: std.ArrayList(PointPair) = .empty;
    defer pairs.deinit(allocator);

    for (points[0 .. points.len - 1], 0..) |p1, idx1| {
        for (points[idx1 + 1 ..]) |p2| {
            const distance = p1.distance(p2);
            try pairs.append(allocator, PointPair{ .p1 = p1, .p2 = p2, .distance = distance });
        }
    }

    // Sort pairs by distance
    std.mem.sort(PointPair, pairs.items, {}, struct {
        fn lessThan(_: void, pair_a: PointPair, pair_b: PointPair) bool {
            return pair_a.distance < pair_b.distance;
        }
    }.lessThan);

    var last_pair: PointPair = pairs.items[0];

    // Process pairs until we have a single circuit containing all points
    for (pairs.items) |pair| {
        const circuit1 = find_point_in_circuit(circuits.items, pair.p1);
        const circuit2 = find_point_in_circuit(circuits.items, pair.p2);

        if (circuit1 == null and circuit2 == null) {
            // Both points are new - create a new circuit
            var circuit: Circuit = .{};
            circuit.init(allocator);
            try circuit.append(pair.p1);
            try circuit.append(pair.p2);
            try circuits.append(allocator, circuit);
            last_pair = pair;
        } else if (circuit1 != null and circuit2 != null) {
            if (circuit1 == circuit2) {
                // Both points already in same circuit - do nothing
            } else {
                // Merge two different circuits
                var iter = circuit2.?.points.keyIterator();
                while (iter.next()) |point| {
                    try circuit1.?.append(point.*);
                }
                // Remove circuit2 from the list
                for (circuits.items, 0..) |*c, i| {
                    if (c == circuit2.?) {
                        _ = circuits.orderedRemove(i);
                        break;
                    }
                }
                last_pair = pair;

                // Check if we now have a single circuit containing all points
                if (circuits.items.len == 1 and circuits.items[0].points.count() == points.len) {
                    return last_pair;
                }
            }
        } else if (circuit1) |c1| {
            // Only point1 is in a circuit - add point2 to it
            try c1.append(pair.p2);
            last_pair = pair;
        } else if (circuit2) |c2| {
            // Only point2 is in a circuit - add point1 to it
            try c2.append(pair.p1);
            last_pair = pair;
        }
    }

    return last_pair;
}

fn algorithm(allocator: std.mem.Allocator, circuits: *std.ArrayList(Circuit), points: []const Point, num_pairs: usize) !void {
    // Generate all pairs and their distances
    var pairs: std.ArrayList(PointPair) = .empty;
    defer pairs.deinit(allocator);

    for (points[0 .. points.len - 1], 0..) |p1, idx1| {
        for (points[idx1 + 1 ..]) |p2| {
            const distance = p1.distance(p2);
            try pairs.append(allocator, PointPair{ .p1 = p1, .p2 = p2, .distance = distance });
        }
    }

    // Sort pairs by distance
    std.mem.sort(PointPair, pairs.items, {}, struct {
        fn lessThan(_: void, pair_a: PointPair, pair_b: PointPair) bool {
            return pair_a.distance < pair_b.distance;
        }
    }.lessThan);

    // Process the first 'num_pairs' pairs
    for (pairs.items[0..@min(num_pairs, pairs.items.len)]) |pair| {
        const circuit1 = find_point_in_circuit(circuits.items, pair.p1);
        const circuit2 = find_point_in_circuit(circuits.items, pair.p2);

        if (circuit1 == null and circuit2 == null) {
            // Both points are new - create a new circuit
            var circuit: Circuit = .{};
            circuit.init(allocator);
            try circuit.append(pair.p1);
            try circuit.append(pair.p2);
            try circuits.append(allocator, circuit);
        } else if (circuit1 != null and circuit2 != null) {
            if (circuit1 == circuit2) {
                // Both points already in same circuit - do nothing
            } else {
                // Merge two different circuits
                var iter = circuit2.?.points.keyIterator();
                while (iter.next()) |point| {
                    try circuit1.?.append(point.*);
                }
                // Remove circuit2 from the list
                for (circuits.items, 0..) |*c, i| {
                    if (c == circuit2.?) {
                        _ = circuits.orderedRemove(i);
                        break;
                    }
                }
            }
        } else if (circuit1) |c1| {
            // Only point1 is in a circuit - add point2 to it
            try c1.append(pair.p2);
        } else if (circuit2) |c2| {
            // Only point2 is in a circuit - add point1 to it
            try c2.append(pair.p1);
        }
    }
}

fn multiply_top_3_circuits_len(allocator: std.mem.Allocator, circuits: []Circuit, all_points: []const Point) !i64 {
    // Count how many points are in circuits
    var connected_points = std.AutoHashMap(Point, void).init(allocator);
    defer connected_points.deinit();

    for (circuits) |circuit| {
        var iter = circuit.points.keyIterator();
        while (iter.next()) |point| {
            try connected_points.put(point.*, {});
        }
    }

    // Calculate total number of circuits including individual unconnected points
    const unconnected_count = all_points.len - connected_points.count();
    const total_circuits = circuits.len + unconnected_count;

    // Collect all circuit sizes
    const circuit_sizes = try allocator.alloc(usize, total_circuits);
    defer allocator.free(circuit_sizes);

    // Add sizes of connected circuits
    for (circuits, 0..) |circuit, i| {
        circuit_sizes[i] = circuit.points.count();
    }

    // Add individual unconnected points (each is a circuit of size 1)
    for (circuits.len..total_circuits) |i| {
        circuit_sizes[i] = 1;
    }

    std.mem.sort(usize, circuit_sizes, {}, std.sort.desc(usize));

    // Multiply the 3 largest
    var result: i64 = 1;
    const count = @min(3, circuit_sizes.len);
    for (0..count) |i| {
        result *= @as(i64, @intCast(circuit_sizes[i]));
    }

    return result;
}

fn print_circuits(circuits: []Circuit) void {
    for (circuits) |circuit| {
        std.debug.print("Circuit ({}):\n", .{circuit.points.count()});
        var iter = circuit.points.keyIterator();
        while (iter.next()) |point| {
            std.debug.print(" {any}\n", .{point});
        }
    }
    std.debug.print("=====================================================================\n", .{});
}

test "points algorithm" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const points = [_]Point{
        Point{ .x = 162, .y = 817, .z = 812 },
        Point{ .x = 57, .y = 618, .z = 57 },
        Point{ .x = 906, .y = 360, .z = 560 },
        Point{ .x = 592, .y = 479, .z = 940 },
        Point{ .x = 352, .y = 342, .z = 300 },
        Point{ .x = 466, .y = 668, .z = 158 },
        Point{ .x = 542, .y = 29, .z = 236 },
        Point{ .x = 431, .y = 825, .z = 988 },
        Point{ .x = 739, .y = 650, .z = 466 },
        Point{ .x = 52, .y = 470, .z = 668 },
        Point{ .x = 216, .y = 146, .z = 977 },
        Point{ .x = 819, .y = 987, .z = 18 },
        Point{ .x = 117, .y = 168, .z = 530 },
        Point{ .x = 805, .y = 96, .z = 715 },
        Point{ .x = 346, .y = 949, .z = 466 },
        Point{ .x = 970, .y = 615, .z = 88 },
        Point{ .x = 941, .y = 993, .z = 340 },
        Point{ .x = 862, .y = 61, .z = 35 },
        Point{ .x = 984, .y = 92, .z = 344 },
        Point{ .x = 425, .y = 690, .z = 689 },
    };

    var circuits: std.ArrayList(Circuit) = .empty;
    defer circuits.deinit(a);
    try algorithm(a, &circuits, &points, 1);

    try std.testing.expectEqual(1, circuits.items.len);
    try std.testing.expectEqual(2, circuits.items[0].points.count());
    try std.testing.expect(circuits.items[0].points.contains(Point{.x=162, .y=817, .z = 812}));
    try std.testing.expect(circuits.items[0].points.contains(Point{.x=425, .y=690, .z = 689}));

    circuits.clearRetainingCapacity();
    try algorithm(a, &circuits, &points, 2);

    try std.testing.expectEqual(1, circuits.items.len);
    try std.testing.expectEqual(3, circuits.items[0].points.count());
    try std.testing.expect(circuits.items[0].points.contains(Point{.x=162, .y=817, .z = 812}));
    try std.testing.expect(circuits.items[0].points.contains(Point{.x=425, .y=690, .z = 689}));
    try std.testing.expect(circuits.items[0].points.contains(Point{.x=431, .y=825, .z = 988}));

    circuits.clearRetainingCapacity();
    try algorithm(a, &circuits, &points, 3);

    try std.testing.expectEqual(2, circuits.items.len);
    try std.testing.expectEqual(3, circuits.items[0].points.count());
    try std.testing.expect(circuits.items[0].points.contains(Point{.x=162, .y=817, .z = 812}));
    try std.testing.expect(circuits.items[0].points.contains(Point{.x=425, .y=690, .z = 689}));
    try std.testing.expect(circuits.items[0].points.contains(Point{.x=431, .y=825, .z = 988}));
    try std.testing.expectEqual(2, circuits.items[1].points.count());
    try std.testing.expect(circuits.items[1].points.contains(Point{.x=906, .y=360, .z = 560}));
    try std.testing.expect(circuits.items[1].points.contains(Point{.x=805, .y=96, .z = 715}));

    circuits.clearRetainingCapacity();
    try algorithm(a, &circuits, &points, 10);

    const result = try multiply_top_3_circuits_len(a, circuits.items, &points);
    try std.testing.expectEqual(40, result);
}

test "find final connection" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const points = [_]Point{
        Point{ .x = 162, .y = 817, .z = 812 },
        Point{ .x = 57, .y = 618, .z = 57 },
        Point{ .x = 906, .y = 360, .z = 560 },
        Point{ .x = 592, .y = 479, .z = 940 },
        Point{ .x = 352, .y = 342, .z = 300 },
        Point{ .x = 466, .y = 668, .z = 158 },
        Point{ .x = 542, .y = 29, .z = 236 },
        Point{ .x = 431, .y = 825, .z = 988 },
        Point{ .x = 739, .y = 650, .z = 466 },
        Point{ .x = 52, .y = 470, .z = 668 },
        Point{ .x = 216, .y = 146, .z = 977 },
        Point{ .x = 819, .y = 987, .z = 18 },
        Point{ .x = 117, .y = 168, .z = 530 },
        Point{ .x = 805, .y = 96, .z = 715 },
        Point{ .x = 346, .y = 949, .z = 466 },
        Point{ .x = 970, .y = 615, .z = 88 },
        Point{ .x = 941, .y = 993, .z = 340 },
        Point{ .x = 862, .y = 61, .z = 35 },
        Point{ .x = 984, .y = 92, .z = 344 },
        Point{ .x = 425, .y = 690, .z = 689 },
    };

    var circuits: std.ArrayList(Circuit) = .empty;
    defer circuits.deinit(a);

    const last_pair = try find_final_connection(a, &circuits, &points);
    const result = last_pair.p1.x * last_pair.p2.x;

    // The final connection should be between 216,146,977 and 117,168,530
    try std.testing.expectEqual(25272, result);
}
