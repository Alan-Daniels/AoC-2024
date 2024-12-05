const std = @import("std");

const RuntimeError = error{
    BadValue,
};

const outw = std.io.getStdOut().writer();

const PRule = struct {
    before: i32,
    after: i32,
};

var PageRules: [2048]PRule = undefined;
var PageRulei: usize = 0;

const ReadMode = enum { Rule, List };

var accum1: i32 = 0;
var accum2: i32 = 0;

fn readFile(filename: []const u8) !void {
    var buffer: [5000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var rmode = ReadMode.Rule;

    var i: usize = 0;
    while (try file.reader()
        .readUntilDelimiterOrEofAlloc(allocator, '\n', buffer.len)) |line| : (i += 1)
    {
        defer allocator.free(line);
        if (line.len == 0) {
            rmode = ReadMode.List;
        } else if (rmode == ReadMode.Rule) {
            const n1 = try std.fmt.parseInt(i32, line[0..2], 10);
            const n2 = try std.fmt.parseInt(i32, line[3..5], 10);
            PageRules[PageRulei] = PRule{ .before = n1, .after = n2 };
            PageRulei += 1;
        } else if (rmode == ReadMode.List) {
            const list = try mkPageList(line);
            defer alloc.free(list);
            if (validate(list)) {
                std.debug.print("{any}\n", .{list});
                const middle = list.len / 2;
                std.debug.print("[{}] = {}\n", .{ middle, list[middle] });
                accum1 += list[middle];
            } else if (fix(list)) {
                std.debug.print("{any}\n", .{list});
                const middle = list.len / 2;
                std.debug.print("[{}] = {}\n", .{ middle, list[middle] });
                accum2 += list[middle];
            } else {
                std.debug.print("{any}\n", .{list});
                std.debug.print("uh oh\n", .{});
                return;
            }
        }
    }
}

fn mkPageList(line: []const u8) ![]i32 {
    const len = (line.len + 1) / 3;
    var out: []i32 = try alloc.alloc(i32, len);
    var i: usize = 0;
    var window = line;
    var div: ?usize = 0;
    var num: []const u8 = undefined;
    while (window.len > 0) : (i += 1) {
        div = std.mem.indexOf(u8, window, ",");
        if (div == null) {
            num = window;
            window = window[0..0];
        } else {
            num = window[0..div.?];
            window = window[div.? + 1 ..];
        }
        out[i] = try std.fmt.parseInt(i32, num, 10);
    }
    return out;
}

fn validate(list: []i32) bool {
    for (PageRules[0..PageRulei]) |value| {
        const befr = std.mem.indexOf(i32, list, &[_]i32{value.before});
        const aftr = std.mem.indexOf(i32, list, &[_]i32{value.after});

        if (befr == null or aftr == null) {
            continue;
        }
        if (befr.? > aftr.?) {
            return false;
        }
    }
    return true;
}

fn fix(list: []i32) bool {
    for (0..64) |_| {
        for (PageRules[0..PageRulei]) |rule| {
            const befr = std.mem.indexOf(i32, list, &[_]i32{rule.before});
            const aftr = std.mem.indexOf(i32, list, &[_]i32{rule.after});

            if (befr == null or aftr == null) {
                continue;
            }
            if (befr.? > aftr.?) {
                list[befr.?] = rule.after;
                list[aftr.?] = rule.before;
            }
        }
        if (validate(list)) {
            return true;
        }
    }
    return validate(list);
}

fn solve(filename: []const u8) !void {
    try readFile(filename);
    std.debug.print("p1: {}\n", .{accum1});
    std.debug.print("p2: {}\n", .{accum2});
}

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

pub fn main() !void {
    defer {
        _ = gpa.deinit();
    }
    try solve("input");
}
