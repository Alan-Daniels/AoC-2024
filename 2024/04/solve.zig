const std = @import("std");

const RuntimeError = error{
    BadValue,
};

const outw = std.io.getStdOut().writer();

var board: [200][200]u8 = undefined;
var sizeX: i32 = 0;
var sizeY: i32 = 0;
var accump1: u32 = 0;
var accump2: u32 = 0;

fn readFile(filename: []const u8) !void {
    var buffer: [5000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var i: usize = 0;
    while (try file.reader()
        .readUntilDelimiterOrEofAlloc(allocator, '\n', buffer.len)) |line| : (i += 1)
    {
        defer allocator.free(line);
        sizeX = @intCast(line.len);
        var k: usize = 0;
        while (k < sizeX) : (k += 1) {
            board[i][k] = line[k];
        }
    }
    sizeY = @intCast(i);
}

const Coord = struct {
    x: i32,
    y: i32,
};

fn findTransform(c: Coord, transform: Coord, haystack: []const u8) bool {
    var cc = c;
    //std.debug.print("\n{any},{any}\n", .{ cc.x, cc.y });
    //std.debug.print("{s}\n", .{haystack});
    for (haystack) |v| {
        if (cc.x > sizeX or cc.y > sizeY or cc.x < 0 or cc.y < 0) {
            return false;
        }
        const ch = board[@intCast(cc.y)][@intCast(cc.x)];
        //std.debug.print("{c}", .{ch});
        if (ch != v) {
            return false;
        }
        cc.y += transform.y;
        cc.x += transform.x;
    }
    return true;
}

fn solve(filename: []const u8) !void {
    try readFile(filename);
    var x: i32 = 0;
    var y: i32 = 0;

    while (y < sizeY) : (y += 1) {
        defer x = 0;
        std.debug.print("{s}\n", .{board[@intCast(y)][0..@intCast(sizeX)]});
        while (x < sizeX) : (x += 1) {
            const coord = Coord{ .x = x, .y = y };
            var p1 = false;
            p1 = p1 or findTransform(coord, Coord{ .x = 1, .y = 0 }, "XMAS");
            p1 = p1 or findTransform(coord, Coord{ .x = -1, .y = 0 }, "XMAS");
            p1 = p1 or findTransform(coord, Coord{ .x = 1, .y = 1 }, "XMAS");
            p1 = p1 or findTransform(coord, Coord{ .x = 1, .y = -1 }, "XMAS");
            p1 = p1 or findTransform(coord, Coord{ .x = -1, .y = 1 }, "XMAS");
            p1 = p1 or findTransform(coord, Coord{ .x = -1, .y = -1 }, "XMAS");
            p1 = p1 or findTransform(coord, Coord{ .x = 0, .y = 1 }, "XMAS");
            p1 = p1 or findTransform(coord, Coord{ .x = 0, .y = -1 }, "XMAS");

            if (p1) {
                accump1 += 1;
            }

            var p2: i32 = 0;
            p2 += if (findTransform(Coord{ .x = coord.x + 1, .y = coord.y + 1 }, Coord{ .x = -1, .y = -1 }, "MAS")) 1 else 0;
            p2 += if (findTransform(Coord{ .x = coord.x - 1, .y = coord.y + 1 }, Coord{ .x = 1, .y = -1 }, "MAS")) 1 else 0;
            p2 += if (findTransform(Coord{ .x = coord.x + 1, .y = coord.y - 1 }, Coord{ .x = -1, .y = 1 }, "MAS")) 1 else 0;
            p2 += if (findTransform(Coord{ .x = coord.x - 1, .y = coord.y - 1 }, Coord{ .x = 1, .y = 1 }, "MAS")) 1 else 0;

            if (p2 == 2) {
                accump2 += 1;
            }
        }
    }

    std.debug.print("p1: {any}\n", .{accump1});
    std.debug.print("p2: {any}\n", .{accump2});
}

pub fn main() !void {
    try solve("dummy");
}
