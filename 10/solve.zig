const std = @import("std");

const RuntimeError = error{OutOfBounds};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const genAlloc = gpa.allocator();

var buffer: [500]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const buffAlloc = fba.allocator();

const Point = struct { x: usize, y: usize };
const Path = struct { start: Point, end: Point };

var accum1: u32 = 0;
var accum2: u32 = 0;

var mapSize: usize = 0;
var map: []u8 = undefined;

var pathMap = std.AutoHashMap(Path, bool).init(
    genAlloc,
);

fn index(pt: Point) usize {
    return (pt.y * mapSize) + pt.x;
}

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
        if (map.len == undefined) {
            map = try genAlloc.alloc(u8, mapSize * mapSize);
        }
        @memcpy(map[mapSize * i .. mapSize * (i + 1)], line);
    }
}

fn printMap() void {
    for (0..mapSize) |i| {
        std.debug.print("{s}\n", .{map[mapSize * i .. mapSize * (i + 1)]});
    }
}

fn traverse(start: Point, current: Point, prev: u8) !void {
    if (!pointValid(current)) {
        return;
    }

    const ch = map[index(current)];
    if (ch <= prev or ch - prev != 1) {
        return;
    }

    if (ch == '9') {
        const pth = Path{ .start = start, .end = current };
        //std.debug.print("pth: {any}\n", .{pth});

        const exists = try pathMap.getOrPut(pth);
        if (!exists.found_existing) {
            accum1 += 1;
        } else {
            accum2 += 1;
        }
        return;
    }

    try traverse(start, Point{ .x = current.x, .y = current.y + 1 }, ch);
    try traverse(start, Point{ .x = current.x + 1, .y = current.y }, ch);
    try traverse(start, Point{ .x = current.x, .y = current.y - @min(1, current.y) }, ch);
    try traverse(start, Point{ .x = current.x - @min(1, current.x), .y = current.y }, ch);
}

fn solve(filename: []const u8) !void {
    try readFile(filename);
    defer genAlloc.free(map);
    defer pathMap.deinit();

    printMap();

    for (0..mapSize * mapSize) |i| {
        const ch = map[i];
        if (ch == '0') {
            const x = i % mapSize;
            const y = @divFloor(i, mapSize);

            const pt = Point{ .x = x, .y = y };
            //std.debug.print("start: {any}\n", .{pt});
            try traverse(pt, pt, ch - 1);
        }
    }

    std.debug.print("p1: {d}\n", .{accum1});
    std.debug.print("p2: {d}\n", .{accum2 + accum1});
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
