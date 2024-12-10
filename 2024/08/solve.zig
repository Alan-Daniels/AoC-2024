const std = @import("std");

const RuntimeError = error{OutOfBounds};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const genAlloc = gpa.allocator();

var buffer: [500]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const buffAlloc = fba.allocator();

var accum1: i64 = 0;
var accum2: i64 = 0;
const debug = false;

const Point = struct { x: i32, y: i32 };
const Antenna = struct { t: u8, points: [100]Point, pcount: usize };
var antennaMap = std.AutoHashMap(u8, Antenna).init(
    genAlloc,
);
var antinodeMap = std.AutoHashMap(Point, bool).init(
    genAlloc,
);

var mapSize: usize = 0;

pub fn main() !void {
    defer {
        _ = gpa.deinit();
    }
    try solve("input");
}

fn readFile(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var i: usize = 0;
    while (try file.reader()
        .readUntilDelimiterOrEofAlloc(buffAlloc, '\n', buffer.len)) |line| : (i += 1)
    {
        defer buffAlloc.free(line);
        mapSize = line.len;
        for (line, 0..line.len) |ch, k| {
            if (ch == '.' or ch == '#') {
                continue;
            }
            const res = try antennaMap.getOrPut(ch);
            const val = res.value_ptr;
            if (!res.found_existing) {
                val.t = ch;
                val.pcount = 0;
                val.points = undefined;
            }

            val.points[val.pcount] = Point{ .x = @intCast(k), .y = @intCast(i) };
            val.pcount += 1;
        }
    }
}

fn solve(filename: []const u8) !void {
    defer antennaMap.deinit();
    defer antinodeMap.deinit();
    try readFile(filename);

    var iterator = antennaMap.iterator();

    while (iterator.next()) |entry| {
        const points = entry.value_ptr.points[0..entry.value_ptr.pcount];
        std.debug.print("{c}: {any}\n", .{ entry.value_ptr.t, points });
        for (0..points.len - 1) |i| {
            for (i + 1..points.len) |k| {
                const p1 = points[i];
                const p2 = points[k];
                try doPt1(p1, p2);
                try doPt2(p1, p2);
            }
        }
    }

    iterator.index = 0;
    while (iterator.next()) |entry| {
        const points = entry.value_ptr.points[0..entry.value_ptr.pcount];
        for (points) |pt| {
            const exists = try antinodeMap.getOrPut(pt);
            if (!exists.found_existing) {
                std.debug.print("{c}: {any}\n", .{ entry.value_ptr.t, pt });
                accum2 += 1;
            }
        }
    }

    std.debug.print("p1: {}\n", .{accum1});
    std.debug.print("p2: {}\n", .{accum2 + accum1});

    for (0..mapSize) |y| {
        for (0..mapSize) |x| {
            if (antinodeMap.get(.{ .x = @intCast(x), .y = @intCast(y) }) != null) {
                std.debug.print("#", .{});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

fn doPt1(p1: Point, p2: Point) !void {
    const dist = pointDistance(p1, p2);
    const a1 = Point{ .x = p1.x + dist.x, .y = p1.y + dist.y };
    const a2 = Point{ .x = p2.x - dist.x, .y = p2.y - dist.y };

    if (pointValid(a1)) {
        const exists = try antinodeMap.getOrPut(a1);
        if (!exists.found_existing) {
            accum1 += 1;
        }
    }
    if (pointValid(a2)) {
        const exists = try antinodeMap.getOrPut(a2);
        if (!exists.found_existing) {
            accum1 += 1;
        }
    }
}
fn doPt2(p1: Point, p2: Point) !void {
    const dist = pointDistance(p1, p2);
    var a1 = p1;
    var a2 = p2;

    while (pointValid(a1)) {
        a1 = Point{ .x = a1.x + dist.x, .y = a1.y + dist.y };
        if (pointValid(a1)) {
            const exists = try antinodeMap.getOrPut(a1);
            if (!exists.found_existing) {
                accum2 += 1;
            }
        }
    }
    while (pointValid(a2)) {
        a2 = Point{ .x = a2.x - dist.x, .y = a2.y - dist.y };
        if (pointValid(a2)) {
            const exists = try antinodeMap.getOrPut(a2);
            if (!exists.found_existing) {
                accum2 += 1;
            }
        }
    }
}

fn pointDistance(p1: Point, p2: Point) Point {
    return Point{ .x = p1.x - p2.x, .y = p1.y - p2.y };
}

fn pointValid(p: Point) bool {
    if (p.x >= mapSize or p.x < 0) {
        return false;
    }
    if (p.y >= mapSize or p.y < 0) {
        return false;
    }
    return true;
}
