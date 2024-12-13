const std = @import("std");

const assert = std.debug.assert;

const RuntimeError = error{ OutOfBounds, OutOfMemory, OptionsExausted, UnexpectedResult };
const outw = std.io.getStdOut().writer();

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

const Point = struct {
    x: i32,
    y: i32,
    pub fn eq(self: @This(), other: @This()) bool {
        return self.x == other.x and self.y == other.y;
    }
};
const Fencing = struct { area: u32, perimiter: u32 };
const Garden = struct { t: u8, fencing: Fencing };

const VisitedMap = std.AutoHashMap(Point, void);

fn cmp(ctx: void, a: Garden, b: Garden) std.math.Order {
    _ = ctx;
    return std.math.order(b.t, a.t);
}
const GardenQueue = std.PriorityQueue(Garden, void, cmp);

pub fn main() !void {
    defer {
        _ = gpa.deinit();
        _ = aa.deinit();
    }
    const edgecase = try solve("edgecase", false);
    std.debug.print("{any}\n", .{edgecase});
    assert(edgecase.pt2 == (3 * 6) + (10 * 12) + (3 * 6));

    const edgecase2 = try solve("edgecase2", false);
    std.debug.print("{any}\n", .{edgecase2});
    assert(edgecase2.pt2 == (5 * 8) + (4 * 8));

    const edgecase4 = try solve("edgecase4", false);
    std.debug.print("{any}\n", .{edgecase4});
    assert(edgecase4.pt2 == (4 * 4) + (4 * 4) + (28 * 12));

    //const edgecase3 = try solve("edgecase3", false);
    //std.debug.print("{any}\n", .{edgecase3});
    //assert(edgecase3.pt2 == (7 * 10) + 4 + 4);

    const dummy = try solve("dummy", false);
    std.debug.print("{any}\n", .{dummy});
    assert(dummy.pt1 == 1930);
    assert(dummy.pt2 == 1206);

    const real = try solve("input", true);
    std.debug.print("{any}\n", .{real});
    assert(real.pt1 == 1473276);
    assert(real.pt2 > 880294);
    assert(real.pt2 != 898008);
}

var board: []u8 = undefined;
var boardSize: usize = 0;
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

const Solve = struct { pt1: u32, pt2: u32 };
fn solve(filename: []const u8, debug: bool) !Solve {
    try outw.print("<<{s}>>\n", .{filename});
    try readFile(filename);
    defer genAlloc.free(board);
    defer boardSize = 0;

    var vstPt1 = VisitedMap.init(genAlloc);
    defer vstPt1.deinit();
    var vstPt2 = VisitedMap.init(genAlloc);
    defer vstPt2.deinit();

    var accum1: u32 = 0;
    var accum2: u32 = 0;
    for (0..boardSize) |y| {
        for (0..boardSize) |x| {
            const pt = Point{ .x = @intCast(x), .y = @intCast(y) };
            const t = board[index(pt)];
            const ex = vstPt1.get(pt);
            const garden: Garden = .{ .t = t, .fencing = .{ .area = 0, .perimiter = 0 } };
            if (ex == null) {
                const fencing = try TrAreaPt(&vstPt1, garden, pt);
                accum1 += fencing.perimiter * fencing.area;

                var cvst = VisitedMap.init(genAlloc);
                defer cvst.deinit();

                var edges: u32 = 0;
                edges = edges;
                _ = try TrCorner(&cvst, &cvst, t, pt, .none, &edges, debug and boardSize <= 10);

                accum2 += edges * fencing.area;
                if (debug) {
                    //std.debug.print("fencing: {any}\n", .{fencing});
                    std.debug.print("perimiter: {d}\n", .{fencing.perimiter});
                    std.debug.print("area: {d}\n", .{fencing.area});
                    std.debug.print("edges: {d}\n", .{edges});
                }
                if (debug) {
                    std.debug.print("---\n", .{});
                    defer std.debug.print("---\n", .{});
                    DebugMap(&cvst, t, .{ .x = -1, .y = -1 });
                    try outw.print("{c}> {d} * {d} = {d}\n", .{ t, fencing.area, edges, fencing.area * edges });
                }
            }
        }
    }
    return Solve{ .pt1 = accum1, .pt2 = accum2 };
}

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

fn printBoardO(t: u8) void {
    for (0..boardSize) |i| {
        const line = board[i * boardSize .. (i + 1) * boardSize];
        for (line) |ch| {
            if (ch == t) {
                std.debug.print("{c}", .{ch});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

fn printBoard() void {
    for (0..boardSize) |i| {
        std.debug.print("{s}\n", .{board[i * boardSize .. (i + 1) * boardSize]});
    }
}

fn TrAreaPt(vst: *VisitedMap, oldGargen: Garden, pt: Point) RuntimeError!Fencing {
    var garden = oldGargen;
    if (!pointValid(pt)) {
        garden.fencing.perimiter += 1;
    } else if (board[index(pt)] == garden.t) {
        const ex = try vst.getOrPut(pt);
        if (!ex.found_existing) {
            garden.fencing.area += 1;
            garden.fencing = try TrArea(vst, garden, pt);
        }
    } else {
        garden.fencing.perimiter += 1;
    }
    return garden.fencing;
}

fn TrArea(vst: *VisitedMap, oldGarden: Garden, pt: Point) RuntimeError!Fencing {
    var garden = oldGarden;
    garden.fencing = try TrAreaPt(vst, garden, .{ .x = pt.x, .y = pt.y + 1 });
    garden.fencing = try TrAreaPt(vst, garden, .{ .x = pt.x, .y = pt.y - 1 });
    garden.fencing = try TrAreaPt(vst, garden, .{ .x = pt.x + 1, .y = pt.y });
    garden.fencing = try TrAreaPt(vst, garden, .{ .x = pt.x - 1, .y = pt.y });
    return garden.fencing;
}

// Now, the trick is this:A region has the same amount of sides as corners.
// ^ Hint for tomorrow ;)
// Below is wrong solution:

const AtPoint = enum {
    void,
    self,
    other,
    fn tou8(self: @This(), t: u8) u8 {
        return switch (self) {
            .void => ' ',
            .other => '.',
            .self => t,
        };
    }
};

const CornerDirection = enum { ne, se, nw, sw, n, e, s, w, none };
const CornerType = enum { none, normal, clover };

fn CornerPoint(pt: Point, direction: CornerDirection) Point {
    var newPt: Point = .{ .x = pt.x * 2, .y = pt.y * 2 };
    switch (direction) {
        .sw, .se => {
            newPt.y += 1;
        },
        .nw, .ne => {
            newPt.y -= 1;
        },
        else => {},
    }
    switch (direction) {
        .ne, .se => {
            newPt.x += 1;
        },
        .nw, .sw => {
            newPt.x -= 1;
        },
        else => {},
    }
    return newPt;
}

fn TrCorner(vst: *VisitedMap, cvst: *VisitedMap, t: u8, pt: Point, direction: CornerDirection, corners: *u32, debug: bool) RuntimeError!AtPoint {
    if (!pointValid(pt)) {
        return AtPoint.void;
    } else if (board[index(pt)] == t) {
        switch (direction) {
            .n, .s, .e, .w, .none => {
                const ex = vst.getOrPut(CornerPoint(pt, .none)) catch {
                    return RuntimeError.OutOfMemory;
                };
                //const ex = try vst.getOrPut(pt);
                if (!ex.found_existing) {
                    try TrCorners(vst, cvst, t, pt, corners, debug);
                }
            },
            else => {},
        }
        return AtPoint.self;
    } else {
        return AtPoint.other;
    }
}

fn TrCorners(vst: *VisitedMap, cvst: *VisitedMap, t: u8, pt: Point, corners: *u32, debug: bool) !void {
    const n: Point = .{ .x = pt.x, .y = pt.y - 1 };
    const e: Point = .{ .x = pt.x + 1, .y = pt.y };
    const s: Point = .{ .x = pt.x, .y = pt.y + 1 };
    const w: Point = .{ .x = pt.x - 1, .y = pt.y };

    const c_n = try TrCorner(vst, cvst, t, n, .n, corners, debug);
    const c_e = try TrCorner(vst, cvst, t, e, .e, corners, debug);
    const c_s = try TrCorner(vst, cvst, t, s, .s, corners, debug);
    const c_w = try TrCorner(vst, cvst, t, w, .w, corners, debug);

    const ne = Point{ .x = pt.x + 1, .y = pt.y - 1 };
    const se = Point{ .x = pt.x + 1, .y = pt.y + 1 };
    const sw = Point{ .x = pt.x - 1, .y = pt.y + 1 };
    const nw = Point{ .x = pt.x - 1, .y = pt.y - 1 };

    const c_ne = try TrCorner(vst, cvst, t, ne, .ne, corners, debug);
    const c_se = try TrCorner(vst, cvst, t, se, .se, corners, debug);
    const c_sw = try TrCorner(vst, cvst, t, sw, .sw, corners, debug);
    const c_nw = try TrCorner(vst, cvst, t, nw, .nw, corners, debug);

    var sum: u8 = 0;
    var ch: [4]u8 = undefined;

    ch[0] = try applyCorner(isCorner(.{ c_w, c_nw, c_n }, vst, CornerPoint(nw, .none)), &sum, vst, CornerPoint(pt, .nw));
    ch[1] = try applyCorner(isCorner(.{ c_n, c_ne, c_e }, vst, CornerPoint(ne, .none)), &sum, vst, CornerPoint(pt, .ne));
    ch[2] = try applyCorner(isCorner(.{ c_s, c_sw, c_w }, vst, CornerPoint(sw, .none)), &sum, vst, CornerPoint(pt, .sw));
    ch[3] = try applyCorner(isCorner(.{ c_e, c_se, c_s }, vst, CornerPoint(se, .none)), &sum, vst, CornerPoint(pt, .se));

    if (debug and sum > 0) {
        // std.debug.print("{c}{c}{c}\n", .{ c_wn.tou8(t), c_n.tou8(t), c_ne.tou8(t) });
        // std.debug.print("{c}☐{c}\n", .{ c_w.tou8(t), c_e.tou8(t) });
        // std.debug.print("{c}{c}{c}\n", .{ c_sw.tou8(t), c_s.tou8(t), c_es.tou8(t) });
        DebugMap(vst, t, pt);
        std.debug.print("{c}: {d},{d}; {d}\n", .{ t, pt.x, pt.y, sum });
        std.debug.print("{c} {c}\n", .{ ch[0], ch[1] });
        std.debug.print(" ☐ \n", .{});
        std.debug.print("{c} {c}\n", .{ ch[2], ch[3] });
        std.debug.print("---\n", .{});
    }

    corners.* += sum;
}

fn applyCorner(ct: CornerType, sum: *u8, vst: *VisitedMap, cpt: Point) !u8 {
    if (ct != CornerType.none) {
        const ex = try vst.getOrPut(cpt);
        if (ex.found_existing) {
            return 'x';
        } else {
            switch (ct) {
                CornerType.normal => {
                    sum.* += 1;
                    return '+';
                },
                CornerType.clover => {
                    sum.* += 2;
                    return '*';
                },
                else => unreachable,
            }
        }
    } else {
        return ' ';
    }
    unreachable;
}

fn DebugMap(vst: *VisitedMap, t: u8, at: Point) void {
    for (0..boardSize) |y| {
        for (0..boardSize) |x| {
            const pt: Point = .{ .x = @intCast(x), .y = @intCast(y) };
            const ex = vst.get(CornerPoint(pt, .none));
            if (pt.eq(at)) {
                std.debug.print("☐", .{});
            } else if (board[index(pt)] == t) {
                if (ex != null) {
                    std.debug.print("{c}", .{t});
                } else {
                    std.debug.print(".", .{});
                }
            } else {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

// corners should be given is CW order
fn isCorner(itms: [3]AtPoint, vst: *VisitedMap, cpt: Point) CornerType {
    var sum: u2 = 0;
    sum += if (itms[0] == AtPoint.self) 1 else 0;
    sum += if (itms[1] == AtPoint.self) 1 else 0;
    sum += if (itms[2] == AtPoint.self) 1 else 0;
    const cloverConnected = vst.get(cpt);
    return switch (sum) {
        0 => CornerType.normal,
        1 => spcl: {
            //if (itms[1] == AtPoint.self and cloverConnected != null) CornerType.clover else CornerType.none,
            if (itms[1] == AtPoint.self) {
                if (cloverConnected == null) {
                    break :spcl CornerType.normal;
                } else {
                    break :spcl CornerType.clover;
                }
            } else {
                break :spcl CornerType.none;
            }
        },
        2 => CornerType.normal,
        3 => CornerType.none,
    };
}
