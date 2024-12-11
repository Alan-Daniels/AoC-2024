const std = @import("std");

const RuntimeError = error{ OutOfBounds, UnevenSize };

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

const chunk = u64;
var runes: []chunk = undefined;
var runeI: usize = 0;

const Rune = struct {
    value: u64,
    generation: u8,
};

const RuneMap = std.AutoHashMap(Rune, u128);

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
        var rest = line[0..line.len];
        var working = rest;
        var div = std.mem.indexOf(u8, rest, " ");
        while (rest.len > 0) {
            div = std.mem.indexOf(u8, rest, " ");
            if (div == null) {
                working = rest;
                rest = rest[0..0];
            } else {
                working = rest[0..div.?];
                rest = rest[div.? + 1 ..];
            }

            try Push(try std.fmt.parseInt(chunk, working, 10));
        }
    }
}

fn solve(filename: []const u8) !void {
    try readFile(filename);
    defer genAlloc.free(runes);

    std.debug.print("p1: {d}\n", .{try BlinkN(25)});
    std.debug.print("p2: {d}\n", .{try BlinkN(75)});
}

fn PrintRunes() void {
    for (runes[0..runeI]) |ch| {
        std.debug.print("[{d}]", .{ch});
    }
    std.debug.print("\n", .{});
}

fn Push(ch: chunk) !void {
    if (runes.len == undefined) {
        runes = try genAlloc.alloc(chunk, 65536);
    }
    if (runeI >= runes.len) {
        var newRunes = try genAlloc.alloc(chunk, runes.len * 2);
        @memcpy(newRunes[0..runes.len], runes);
        genAlloc.free(runes);
        runes = newRunes;
        std.log.debug("array grown to: {d}", .{runes.len});
    }
    runes[runeI] = ch;
    runeI += 1;
}

fn Split(ch: chunk) ![]chunk {
    const str = std.fmt.allocPrint(arenaAlloc, "{d}", .{ch}) catch |err| fmt: {
        std.log.debug("{any}", .{@errorName(err)});
        break :fmt &[_]u8{};
    };

    if (str.len % 2 != 0) {
        const ret = try arenaAlloc.alloc(chunk, 1);
        ret[0] = ch;
        return ret;
    }

    const div = @divFloor(str.len, 2);

    const ch1 = try std.fmt.parseInt(chunk, str[0..div], 10);
    const ch2 = try std.fmt.parseInt(chunk, str[div..], 10);
    const ret = try arenaAlloc.alloc(chunk, 2);
    ret[0] = ch1;
    ret[1] = ch2;
    return ret;
}

fn RuneCMP(ctx: void, a: Rune, b: Rune) std.math.Order {
    _ = ctx;
    return std.math.order(b.generation, a.generation);
}
const RuneQueue = std.PriorityQueue(Rune, void, RuneCMP);

fn BlinkN(times: u8) !u128 {
    var pq = RuneQueue.init(buffAlloc, {});
    var mp = RuneMap.init(genAlloc);
    defer pq.deinit();
    defer mp.deinit();
    var count: u128 = 0;
    for (runes[0..runeI]) |ch| {
        const r = Rune{ .value = ch, .generation = 0 };
        try pq.add(r);
    }

    while (pq.count() > 0) {
        defer {
            _ = aa.reset(.free_all);
        }
        const rrn: Rune = pq.remove();
        if (rrn.generation >= times) {
            const mapPut = try mp.getOrPut(rrn);
            if (!mapPut.found_existing) {
                mapPut.value_ptr.* = 1;
            }
            count += 1;
            continue;
        }

        if (rrn.value == 0) {
            const ch: Rune = .{ .generation = rrn.generation + 1, .value = 1 };
            const ex = mp.get(ch);
            if (ex != null) {
                try mp.put(rrn, ex.?);
                count += ex.?;
            } else {
                try pq.add(ch);
            }
        } else {
            const spl = try Split(rrn.value);
            if (spl.len == 2) {
                const ch1: Rune = .{ .generation = rrn.generation + 1, .value = spl[0] };
                const ch2: Rune = .{ .generation = rrn.generation + 1, .value = spl[1] };

                const ex1 = mp.get(ch1);
                const ex2 = mp.get(ch2);
                if (rrn.generation + 1 >= times) {
                    try mp.put(rrn, 2);
                    count += 2;
                } else if (ex1 != null and ex2 != null) {
                    const total = ex1.? + ex2.?;
                    try mp.put(rrn, total);
                    count += total;
                } else {
                    try pq.add(ch1);
                    try pq.add(ch2);
                }
            } else {
                const ch: Rune = .{ .generation = rrn.generation + 1, .value = rrn.value * 2024 };
                const ex = mp.get(ch);
                if (ex != null) {
                    try mp.put(rrn, ex.?);
                    count += ex.?;
                } else {
                    try pq.add(ch);
                }
            }
        }
    }

    return count;
}
