const std = @import("std");

const RuntimeError = error{ OutOfBounds, UnevenSize, OutOfMemory };

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const genAlloc = gpa.allocator();

var buffer: [69420]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const buffAlloc = fba.allocator();

var aabuf: [69420]u8 = undefined;
var aafba = std.heap.FixedBufferAllocator.init(&aabuf);
const aabuffalloc = fba.allocator();

var aa = std.heap.ArenaAllocator.init(aabuffalloc);
const arenaAlloc = aa.allocator();

//const chunk = u64;
//var runes: []chunk = undefined;
//var runeI: usize = 0;

//const Rune = struct {
//    value: u64,
//    generation: u8,
//};
//
//const RuneMap = std.AutoHashMap(Rune, u128);

const Point = struct { x: i32, y: i32 };
const Fencing = struct { area: u32, perimiter: u32 };
const Garden = struct { t: u8, fencing: Fencing };

var board: []u8 = undefined;
var boardSize: usize = 0;

const VisitedMap = std.AutoHashMap(Point, void);
const QueuedGardens = std.AutoHashMap(u8, Point);

fn cmp(ctx: void, a: Garden, b: Garden) std.math.Order {
    _ = ctx;
    return std.math.order(b.t, a.t);
}
const GardenQueue = std.PriorityQueue(Garden, void, cmp);

fn index(pt: Point) usize {
    return (@as(usize, @intCast(pt.y)) * boardSize) + @as(usize, @intCast(pt.x));
}
fn pointValid(p: Point) bool {
    if (p.x >= boardSize or p.x < 0) {
        return false;
    }
    if (p.y >= boardSize or p.y < 0) {
        return false;
    }
    return true;
}

pub fn main() !void {
    defer {
        _ = gpa.deinit();
        _ = aa.deinit();
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
        if (boardSize == 0) {
            boardSize = line.len;
            board = try genAlloc.alloc(u8, boardSize * boardSize);
        }
        @memcpy(board[i * boardSize .. (i + 1) * boardSize], line);
    }
}

fn solve(filename: []const u8) !void {
    try readFile(filename);
    defer genAlloc.free(board);

    var qg = QueuedGardens.init(genAlloc);
    defer qg.deinit();
    var vst = VisitedMap.init(genAlloc);
    defer vst.deinit();

    const newT = board[0];
    try qg.put(newT, .{ .x = 0, .y = 0 });

    var accum1: u32 = 0;
    for (0..boardSize) |y| {
        for (0..boardSize) |x| {
            const pt = Point{ .x = @intCast(x), .y = @intCast(y) };
            const t = board[index(pt)];
            const ex = vst.get(pt);
            const garden: Garden = .{ .t = t, .fencing = .{ .area = 0, .perimiter = 0 } };
            if (ex == null) {
                std.debug.print("{c};\n", .{t});
                const fencing = try TraversePt(&qg, &vst, garden, pt);
                std.debug.print("{any}\n", .{fencing});
                accum1 += fencing.perimiter * fencing.area;
            }
        }
    }

    std.debug.print("{d}\n", .{accum1});

    printBoard();
}

fn printBoard() void {
    for (0..boardSize) |i| {
        std.debug.print("{s}\n", .{board[i * boardSize .. (i + 1) * boardSize]});
    }
}

fn TraversePt(qg: *QueuedGardens, vst: *VisitedMap, oldGargen: Garden, pt: Point) RuntimeError!Fencing {
    var garden = oldGargen;
    if (!pointValid(pt)) {
        garden.fencing.perimiter += 1;
    } else if (board[index(pt)] == garden.t) {
        const ex = try vst.getOrPut(pt);
        if (!ex.found_existing) {
            garden.fencing.area += 1;
            garden.fencing = try Traverse(qg, vst, garden, pt);
        }
    } else {
        garden.fencing.perimiter += 1;
        const newT = board[index(pt)];
        const pex = qg.get(newT);
        if (pex == null) {
            try qg.put(newT, pt);
        }
    }
    return garden.fencing;
}

fn Traverse(qg: *QueuedGardens, vst: *VisitedMap, oldGarden: Garden, pt: Point) RuntimeError!Fencing {
    var garden = oldGarden;
    garden.fencing = try TraversePt(qg, vst, garden, .{ .x = pt.x, .y = pt.y + 1 });
    garden.fencing = try TraversePt(qg, vst, garden, .{ .x = pt.x, .y = pt.y - 1 });
    garden.fencing = try TraversePt(qg, vst, garden, .{ .x = pt.x + 1, .y = pt.y });
    garden.fencing = try TraversePt(qg, vst, garden, .{ .x = pt.x - 1, .y = pt.y });
    return garden.fencing;
}
