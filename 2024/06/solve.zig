const std = @import("std");

const RuntimeError = error{ SpaceFilled, OutOfBounds };

const outw = std.io.getStdOut().writer();

var accum1: i32 = 0;
var accum2: i32 = 0;

const MapTile = enum { air, box, walked };
var board: []MapTile = undefined;
var boardW: usize = 0;

const Facing = enum { north, south, east, west };
const Coord = struct { x: usize, y: usize, facing: Facing };
var pos: Coord = Coord{ .x = 0, .y = 0, .facing = Facing.north };

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
        if (board.len == undefined) {
            board = try alloc.alloc(MapTile, line.len * line.len);
            boardW = line.len;
        }
        for (line, 0..line.len) |char, k| {
            if (char == '#') {
                board[index(k, i)] = MapTile.box;
            } else if (char == '^') {
                board[index(k, i)] = MapTile.walked;
                pos.x = k;
                pos.y = i;
                accum1 += 1;
            } else {
                board[index(k, i)] = MapTile.air;
            }
        }
    }
}

fn index(x: usize, y: usize) usize {
    return (y * boardW) + x;
}

fn Walk() !MapTile {
    var newPos: Coord = pos;
    switch (pos.facing) {
        Facing.north => {
            if (pos.y == 0) {
                return RuntimeError.OutOfBounds;
            }
            newPos = Coord{ .x = pos.x, .y = pos.y - 1, .facing = pos.facing };
        },
        Facing.south => {
            if (pos.y == boardW - 1) {
                return RuntimeError.OutOfBounds;
            }
            newPos = Coord{ .x = pos.x, .y = pos.y + 1, .facing = pos.facing };
        },
        Facing.east => {
            if (pos.x == boardW - 1) {
                return RuntimeError.OutOfBounds;
            }
            newPos = Coord{ .x = pos.x + 1, .y = pos.y, .facing = pos.facing };
        },
        Facing.west => {
            if (pos.x == 0) {
                return RuntimeError.OutOfBounds;
            }
            newPos = Coord{ .x = pos.x - 1, .y = pos.y, .facing = pos.facing };
        },
    }
    const tile: MapTile = board[index(newPos.x, newPos.y)];
    switch (tile) {
        MapTile.box => {
            return RuntimeError.SpaceFilled;
        },
        MapTile.air => {
            board[index(newPos.x, newPos.y)] = MapTile.walked;
            accum1 += 1;
        },
        MapTile.walked => {},
    }
    pos = newPos;
    return tile;
}

fn Turn() void {
    const newPos: Coord = switch (pos.facing) {
        Facing.north => Coord{ .x = pos.x, .y = pos.y, .facing = Facing.east },
        Facing.south => Coord{ .x = pos.x, .y = pos.y, .facing = Facing.west },
        Facing.east => Coord{ .x = pos.x, .y = pos.y, .facing = Facing.south },
        Facing.west => Coord{ .x = pos.x, .y = pos.y, .facing = Facing.north },
    };

    pos = newPos;
}

fn simulate(addition: ?Coord) !bool {
    const copy = try alloc.alloc(MapTile, boardW * boardW);
    defer alloc.free(copy);
    @memcpy(copy, board);
    defer @memcpy(board, copy);

    const copyPos = pos;
    defer pos = copyPos;

    if (addition != null) {
        board[index(addition.?.x, addition.?.y)] = MapTile.box;
    }

    //printB();

    const maxSteps = 1024;
    var stepsRetraced: usize = 0;
    while (stepsRetraced < maxSteps) {
        const tile = Walk() catch |err| blk: {
            if (err == RuntimeError.SpaceFilled) {
                Turn();
            } else {
                break;
            }
            break :blk MapTile.box;
        };
        if (tile == MapTile.walked) {
            stepsRetraced += 1;
        }
    }
    //printB();
    return stepsRetraced < maxSteps;
}

fn printB() void {
    std.debug.print("-----\n", .{});
    for (0..boardW) |i| {
        for (0..boardW) |k| {
            const v: u8 = switch (board[index(k, i)]) {
                MapTile.walked => 'X',
                MapTile.air => '.',
                MapTile.box => '#',
            };
            std.debug.print("{c}", .{v});
        }
        std.debug.print("\n", .{});
    }
}

fn solve(filename: []const u8) !void {
    try readFile(filename);
    var res = try simulate(null);
    std.debug.print("p1: {}\n", .{accum1});

    for (0..boardW) |i| {
        for (0..boardW) |k| {
            if (board[index(k, i)] == MapTile.air) {
                res = try simulate(Coord{ .x = k, .y = i, .facing = Facing.north });
                if (!res) {
                    accum2 += 1;
                }
            }
        }
    }

    std.debug.print("p2: {}\n", .{accum2});

    alloc.free(board);
}

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

pub fn main() !void {
    defer {
        _ = gpa.deinit();
    }
    try solve("input");
}
