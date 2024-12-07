const std = @import("std");

const RuntimeError = error{GenericError};

var accum: i64 = 0;

fn readFile(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var numBuff: [64]i32 = undefined;

    var i: usize = 0;
    while (try file.reader()
        .readUntilDelimiterOrEofAlloc(buffAlloc, '\n', buffer.len)) |line| : (i += 1)
    {
        defer buffAlloc.free(line);

        var div = std.mem.indexOf(u8, line, ": ");
        var working = line[0..div.?];
        const res = try std.fmt.parseInt(i64, working, 10);
        var rest = line[div.? + 2 ..];
        var k: usize = 0;
        std.debug.print("{s};{s};{d}\n", .{ working, rest, res });
        while (rest.len > 0) {
            defer k += 1;
            div = std.mem.indexOf(u8, rest, " ");
            if (div == null) {
                working = rest;
                rest = rest[0..0];
            } else {
                working = rest[0..div.?];
                rest = rest[div.? + 1 ..];
            }

            numBuff[k] = try std.fmt.parseInt(i32, working, 10);
        }
        if (findSolution(res, numBuff[0], numBuff[1..k])) {
            accum += res;
        }
    }
}

fn findSolution(result: i64, current: i64, rest: []i32) bool {
    if (rest.len > 0) {
        const pop = rest[0];
        if (findSolution(result, current + pop, rest[1..])) {
            return true;
        }
        if (findSolution(result, current * pop, rest[1..])) {
            return true;
        }
        if (do_pt2) {
            const concat = std.fmt.allocPrint(buffAlloc, "{d}{d}", .{ current, pop }) catch |err| fmt: {
                std.log.debug("{any}", .{@errorName(err)});
                break :fmt &[_]u8{};
            };
            defer buffAlloc.free(concat);
            const ncurrent = std.fmt.parseInt(i64, concat, 10) catch |err| fmt: {
                std.log.debug("{any}", .{@errorName(err)});
                break :fmt 0;
            };
            if (findSolution(result, ncurrent, rest[1..])) {
                return true;
            }
        }
        return false;
    } else {
        return current == result;
    }
}

const do_pt2: bool = true;

fn solve(filename: []const u8) !void {
    try readFile(filename);
    std.debug.print("p: {}\n", .{accum});
}

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const genAlloc = gpa.allocator();

var buffer: [5000]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const buffAlloc = fba.allocator();

pub fn main() !void {
    defer {
        _ = gpa.deinit();
    }
    try solve("input");
}
