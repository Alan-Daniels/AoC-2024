const std = @import("std");

const RuntimeError = error{OutOfBounds};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const genAlloc = gpa.allocator();

var buffer: [65536]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const buffAlloc = fba.allocator();

var accum1: u64 = 0;
var accum2: u64 = 0;
const debug = false;

const chunk = u16;
var map: [16777216]chunk = undefined;
var mapi: usize = 0;

fn mapPush(item: chunk) !void {
    if (mapi >= map.len) {
        return RuntimeError.OutOfBounds;
    }
    map[mapi] = item;
    mapi += 1;
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
        for (0..line.len) |k| {
            if (k % 2 == 0) {
                const id = @divFloor(k, 2);
                const blockSize: u8 = line[k] - '0';
                for (0..blockSize) |_| {
                    try mapPush(@intCast(id + 1));
                }
            } else {
                const freeSpace: u8 = line[k] - '0';
                for (0..freeSpace) |_| {
                    try mapPush(0);
                }
            }
        }
    }
}

fn mapPrint(mp: []chunk) void {
    for (mp) |it| {
        if (it == 0) {
            std.debug.print("[.]", .{});
        } else {
            std.debug.print("[{d}]", .{it - 1});
        }
    }
    std.debug.print("\n", .{});
}

fn mapCompress1() u64 {
    var k = mapi - 1;
    for (map[0..mapi], 0..mapi) |it, i| {
        if (it != 0) {
            continue;
        }
        while (k > i) : (k -= 1) {
            const rep = map[k];
            if (rep != 0) {
                map[k] = 0;
                map[i] = rep;
                break;
            }
        }
    }
    mapi = k;
    return mapCheckSum();
}

fn mapCompress2() u64 {
    var k = mapi - 1;
    while (k > 0) : (k -= @min(k, 1)) {
        const kt = map[k];
        const kend = k + 1;
        if (kt == 0) {
            continue;
        }
        var kstart: usize = kend - @min(10, kend);
        while (map[kstart] != kt) : (kstart += 1) {}

        k -= (kend - kstart) - 1;

        const klen = kend - kstart;

        var j: usize = 0;
        while (j < k) : (j += 1) {
            const jt = map[j];
            const jstart = j;
            if (jt != 0) {
                continue;
            }
            var jend: usize = jstart;
            while (map[jend] == 0) : (jend += 1) {}

            j = jend;
            const jlen = jend - jstart;

            if (jlen >= klen) {
                std.debug.print("({d}) = {d}..{d} => ", .{ klen, kstart, kend });
                mapPrint(map[kstart..kend]);
                std.debug.print("{d}..{d} => ", .{ jstart, jend });
                mapPrint(map[jstart..jend]);
                std.debug.print("match\n", .{});
                for (jstart..jstart + klen, kstart..kend) |jj, kk| {
                    map[jj] = kt;
                    map[kk] = 0;
                }
                break;
            }
        }
    }
    return mapCheckSum();
}

fn mapCheckSum() u64 {
    var accum: u64 = 0;
    for (map[0..mapi], 0..mapi) |it, i| {
        if (it == 0) {
            continue;
        }
        const id = it - 1;
        accum += id * i;
    }
    return accum;
}

fn solve(filename: []const u8) !void {
    try readFile(filename);

    //mapPrint(map[0..mapi]);

    //accum1 = mapCompress1();
    accum2 = mapCompress2();

    //mapPrint(map[0..mapi]);

    std.debug.print("p1: {}\n", .{accum1});
    std.debug.print("p2: {}\n", .{accum2});
}
