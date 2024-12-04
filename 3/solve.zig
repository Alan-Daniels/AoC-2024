const std = @import("std");

const RuntimeError = error{
    BadValue,
};

const outw = std.io.getStdOut().writer();

const InstructionType = enum { mul, do, dont };
const Instruction = struct { t: InstructionType, x: i32, y: i32 };

//var instructions: [1000]Instruction = undefined;
//var instLen: usize = 0;

var accum: i32 = 0;
var enable: bool = true;

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
        try parse(line);
    }
}

fn nextInst(comptime T: type, haystack: []const T) ?usize {
    //const div = std.mem.indexOf(u8, line, " ").?;
    var nextMul = std.mem.indexOf(T, haystack, "mul(");
    var nextDo = std.mem.indexOf(T, haystack, "do()");
    var nextDont = std.mem.indexOf(T, haystack, "don't()");

    if (nextMul == null and nextDo == null and nextDont == null) {
        return null;
    }

    if (nextMul == null) {
        nextMul = 5000;
    }
    if (nextDo == null) {
        nextDo = 5000;
    }
    if (nextDont == null) {
        nextDont = 5000;
    }

    const min = @min(nextMul.?, @min(nextDo.?, nextDont.?));

    if (min == nextMul) {
        try InstMul(haystack[nextMul.? + 4 ..]);
    } else if (min == nextDo) {
        enable = true;
    } else if (min == nextDont) {
        enable = false;
    }
    return min;
}

fn InstMul(window: []const u8) !void {
    var inst: Instruction = Instruction{ .x = 0, .y = 0, .t = .mul };
    var space = window[0..@min(4, window.len)];
    //std.debug.print("\n{s}\n", .{space});
    const num1end = std.mem.indexOf(u8, space, ",");
    if (num1end == null) {
        return;
    }
    inst.x = std.fmt.parseInt(i32, space[0..num1end.?], 10) catch {
        return;
    };

    space = window[num1end.? + 1 .. @min(num1end.? + 5, window.len)];

    //std.debug.print("\n{s}\n", .{space});
    const num2end = std.mem.indexOf(u8, space, ")");
    if (num2end == null) {
        return;
    }
    inst.y = std.fmt.parseInt(i32, space[0..num2end.?], 10) catch {
        return;
    };

    if (enable) {
        std.debug.print("{any}\n", .{inst});
        accum += inst.x * inst.y;
    }
}

fn parse(line: []const u8) !void {
    var window = line[0..];
    var div: ?usize = 0;
    while (window.len > 0) : ({}) {
        div = nextInst(u8, window);
        if (div == null) {
            window = window[0..0];
        } else {
            window = window[div.? + 1 ..];
        }
    }
}

fn solve(filename: []const u8) !void {
    try readFile(filename);
    std.debug.print("p1: {any}\n", .{accum});
}

pub fn main() !void {
    try solve("input");
}
