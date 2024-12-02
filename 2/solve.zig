const std = @import("std");

var safeCount: u32 = 0;
var countp: u32 = 0;
var countm: u32 = 0;
var badness: u32 = 0;
var sign: ?bool = null;
var history: [10]i32 = undefined;
var historyI: u32 = 0;

const RuntimeError = error{
    BadValue,
};

const outw = std.io.getStdOut().writer();

fn readFile(filename: []const u8, lookback: u8) !void {
    var buffer: [512]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var i: usize = 0;
    while (try file.reader()
        .readUntilDelimiterOrEofAlloc(allocator, '\n', buffer.len)) |line| : (i += 1)
    {
        defer allocator.free(line);

        defer badness = 0;
        defer countp = 0;
        defer countm = 0;
        defer historyI = 0;
        defer sign = null;

        std.debug.print("\n{d}\n", .{i + 1});
        var rest = line[0..];
        var div = std.mem.indexOf(u8, rest, " ");
        var k: u32 = 0;
        while (rest.len > 0) : ({
            div = std.mem.indexOf(u8, rest, " ");
            k += 1;
        }) {
            var num: []u8 = undefined;
            if (div == null) {
                num = rest;
                rest = rest[0..0];
            } else {
                num = rest[0..div.?];
                rest = rest[div.? + 1 ..];
            }
            const val = try std.fmt.parseInt(i32, num, 10);

            if (historyI >= 1) {
                const err = processReport(val, lookback);
                switch (err) {
                    0 => {
                        try historyAppend(val);
                    },
                    1 => {
                        try historyReplace(val);
                    },
                    2 => {
                        // history skip
                    },
                    else => {
                        return RuntimeError.BadValue;
                    },
                }
            } else {
                try historyAppend(val);
            }
        }

        //badness += @min(countm, countp);
        std.debug.print("+: {d}\n-: {d}\n", .{ countp, countm });

        badness += k - historyI;
        //std.debug.print("i: {d}\nk: {d}\n", .{ historyI, k });

        if (badness >= lookback) {
            try outw.print("ERR\n", .{});
        } else {
            try outw.print("OK\n", .{});
            safeCount += 1;
        }
        try peek();
    }
}

fn historyReplace(curr: i32) !void {
    const i = historyI % history.len;
    history[i] = curr;
}

fn historyAppend(curr: i32) !void {
    historyI += 1;
    const i = historyI % history.len;
    history[i] = curr;
}

fn peek() !void {
    const i = historyI % history.len;
    std.debug.print("{any}; [{any}]={any};\n", .{ history[1 .. i + 1], i, history[i] });
}

fn processReport(curr: i32, lookback: u32) u32 {
    const _lk = @min(lookback, historyI);
    for (0.._lk) |i| {
        const k = (historyI - i) % history.len;
        if (evalNumbers(history[k], curr)) {
            return @intCast(i);
        }
    }
    return _lk;
}

fn evalNumbers(prev: i32, curr: i32) bool {
    std.debug.print("{any};{any};{s}  ", .{ prev, curr, if (curr > prev) "+" else "-" });

    if (sign != null and sign.? != (curr > prev)) {
        sign = (curr > prev);
        std.debug.print("bad sign!\n", .{});
        return false;
    }

    if (curr == prev) {
        std.debug.print("not moving!\n", .{});
        return false;
    }
    if (@abs(curr - prev) > 3) {
        std.debug.print("too fast!\n", .{});
        return false;
    }

    std.debug.print("\n", .{});
    sign = (curr > prev);
    if (sign.?) {
        countp += 1;
    } else {
        countm += 1;
    }
    return true;
}

fn solve(filename: []const u8) !void {
    try readFile(filename, 2);
    std.debug.print("safe: {any}\n", .{safeCount});
}

pub fn main() !void {
    try solve("input");
}
