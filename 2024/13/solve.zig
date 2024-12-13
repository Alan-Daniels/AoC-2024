const std = @import("std");

const assert = std.debug.assert;

const RuntimeError = error{ OutOfBounds, OutOfMemory, OptionsExausted, UnexpectedResult };
const outw = std.io.getStdOut().writer();

// Allocators
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

// Data Types

const Point = struct {
    x: i32,
    y: i32,
    pub fn eq(self: @This(), other: @This()) bool {
        return self.x == other.x and self.y == other.y;
    }
    pub fn mul(self: @This(), by: i32) @This() {
        return Point{
            .x = self.x * by,
            .y = self.y * by,
        };
    }
    pub fn add(self: @This(), other: @This()) @This() {
        return Point{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }
    pub fn sub(self: @This(), other: @This()) @This() {
        return Point{
            .x = self.x - other.x,
            .y = self.y - other.y,
        };
    }
    pub fn dist(self: @This(), other: @This()) @This() {
        return Point{
            .x = @max(self.x, other.x) - @min(self.x, other.x),
            .y = @max(self.y, other.y) - @min(self.y, other.y),
        };
    }
    pub fn parse(str: []const u8) !@This() {
        const Signs = enum { @"+", @"-", @"=" };
        const xpos = std.mem.indexOf(u8, str, "X").?;
        const xsign = std.meta.stringToEnum(Signs, str[xpos + 1 .. xpos + 2]).?;
        const xend = std.mem.indexOf(u8, str[xpos..], ",").?;
        const x = try std.fmt.parseInt(i32, str[xpos + 2 .. xend], 10);

        const ypos = std.mem.indexOf(u8, str, "Y").?;
        const ysign = std.meta.stringToEnum(Signs, str[ypos + 1 .. ypos + 2]).?;
        const y = try std.fmt.parseInt(i32, str[ypos + 2 ..], 10);

        var pt: @This() = .{ .x = x, .y = y };
        if (xsign == Signs.@"-") {
            pt.x = -pt.x;
        }
        if (ysign == Signs.@"-") {
            pt.y = -pt.y;
        }
        return pt;
    }
};

const Solve = struct { pt1: u32, pt2: u32 };

const ClawGameState = struct {
    genA: u32,
    genB: u32,
    spent: u32,
    at: Point,
    fn dist(self: @This(), goal: ClawMachine) u32 {
        const dst = goal.Prize.dist(self.at);
        return @abs(dst.x) + @abs(dst.y) + self.spent;
    }
    pub fn cmp(ctx: ClawMachine, a: @This(), b: @This()) std.math.Order {
        return std.math.order(a.dist(ctx), b.dist(ctx));
    }
    const Queue = std.PriorityQueue(@This(), ClawMachine, @This().cmp);
    const Cache = std.AutoHashMap(@This(), void);
};

const ClawMachine = struct {
    BtnA: Point,
    BtnB: Point,
    Prize: Point,

    pub fn pt1(self: @This(), debug: bool) !ClawGameState {
        var queue = ClawGameState.Queue.init(genAlloc, self);
        defer queue.deinit();
        var cache = ClawGameState.Cache.init(genAlloc);
        defer cache.deinit();

        try queue.add(.{ .genA = 0, .genB = 0, .spent = 0, .at = .{ .x = 0, .y = 0 } });

        defer std.debug.print("\n", .{});
        std.debug.print("machine: {any}\n", .{self});

        var i: usize = 0;
        while (queue.count() > 0) : (i += 1) {
            const state = queue.remove();
            const incache = try cache.getOrPut(state);
            if (incache.found_existing) {
                continue;
            }
            if (state.at.eq(self.Prize)) {
                return state;
            }
            if (state.at.x > self.Prize.x or state.at.y > self.Prize.y) {
                // ignore overshoots
                continue;
            }
            if (debug) {
                std.debug.print("{any}\n{d}\n", .{ state, state.dist(self) });
            }

            // A
            if (state.genA <= 100) {
                try queue.add(ClawGameState{
                    .spent = state.spent + 3,
                    .at = state.at.add(self.BtnA),
                    .genA = state.genA + 1,
                    .genB = state.genB,
                });
            }

            // B
            if (state.genB <= 100) {
                try queue.add(ClawGameState{
                    .spent = state.spent + 1,
                    .at = state.at.add(self.BtnB),
                    .genA = state.genA,
                    .genB = state.genB + 1,
                });
            }
        }

        return .{ .genA = 0, .genB = 0, .spent = 0, .at = .{ .x = 0, .y = 0 } };
    }
};
//

fn readFile(filename: []const u8) !std.ArrayList(ClawMachine) {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var cmachine: ClawMachine = undefined;
    var machines = std.ArrayList(ClawMachine).init(buffAlloc);

    var i: usize = 0;
    while (try file.reader()
        .readUntilDelimiterOrEofAlloc(buffAlloc, '\n', buffer.len)) |line| : (i += 1)
    {
        defer buffAlloc.free(line);
        const udiv = std.mem.indexOf(u8, line, ": ");
        if (udiv == null) {
            try machines.append(cmachine);
        } else {
            const div = udiv.?;
            const options = enum { @"Button A", @"Button B", Prize };
            const option = std.meta.stringToEnum(options, line[0..div]);
            if (option == null) {
                std.debug.print("unexpected result '{s}'", .{line[0..div]});
                return RuntimeError.UnexpectedResult;
            }
            const rest = line[div + 2 ..];
            switch (option.?) {
                .Prize => {
                    cmachine.Prize = try Point.parse(rest);
                },
                .@"Button A" => {
                    cmachine.BtnA = try Point.parse(rest);
                },
                .@"Button B" => {
                    cmachine.BtnB = try Point.parse(rest);
                },
            }
        }
    }

    return machines;
}

fn solve(filename: []const u8, debug: bool) !Solve {
    try outw.print("<<{s}>>\n", .{filename});
    const machines = try readFile(filename);
    defer machines.deinit();

    var solveResult = Solve{ .pt1 = 0, .pt2 = 0 };
    for (machines.items) |machine| {
        const result = try machine.pt1(debug and false);
        std.debug.print("{any}\n", .{result});
        solveResult.pt1 += result.spent;
    }

    return solveResult;
}

pub fn main() !void {
    defer {
        _ = gpa.deinit();
        _ = aa.deinit();
    }
    const dummy = try solve("dummy", true);
    std.debug.print("{any}\n", .{dummy});
    assert(dummy.pt1 == 480);

    const real = try solve("input", true);
    std.debug.print("{any}\n", .{real});
    assert(real.pt1 > 34879);
}
