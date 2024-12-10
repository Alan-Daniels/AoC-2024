const std = @import("std");
const print = std.debug.print;

const list = i32;
var list1: [1000]list = undefined;
var list2: [1000]list = undefined;
var listlen: usize = 0;

fn readLists(filename: []const u8) !void {
    var buffer: [64]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var i: usize = 0;
    while (try file.reader()
        .readUntilDelimiterOrEofAlloc(allocator, '\n', buffer.len)) |line| : (i += 1)
    {
        defer allocator.free(line);
        const div = std.mem.indexOf(u8, line, " ").?;
        // note: '.?' makes a promise to the compiler that we wont come across any null values
        // pretty daring of me to do this here, but this is temp code anyway
        list1[i] = try std.fmt.parseInt(list, line[0..div], 10);
        list2[i] = try std.fmt.parseInt(list, line[div + 3 ..], 10);
    }
    listlen = i;
}

fn solve(filename: []const u8) !void {
    readLists(filename) catch |err| {
        std.log.err("reading file err: {s}", .{@errorName(err)});
        return;
    };
    const l1 = list1[0..listlen];
    const l2 = list2[0..listlen];

    std.mem.sort(list, l1, {}, comptime std.sort.asc(list));
    std.mem.sort(list, l2, {}, comptime std.sort.asc(list));

    // begin part 1
    var distSum: u32 = 0;
    for (l1, l2) |itm1, itm2| {
        distSum += @abs(itm1 - itm2);
    }

    print("part 1: {any}\n", .{distSum});
    // end part 1

    // begin part 2
    var l2_i: usize = 0;
    var lvalue: list = 0;
    var lcount: i32 = 0;
    distSum = 0;
    for (l1) |v1| {
        if (lvalue != v1) {
            lvalue = v1;
            lcount = 0;
            while (l2_i < l2.len) : (l2_i += 1) {
                if (l2[l2_i] > lvalue) break;
                if (l2[l2_i] < lvalue) continue;
                lcount += 1;
            }
        }
        distSum += @abs(lvalue * lcount);
    }

    print("part 2: {any}\n", .{distSum});
    // end part 2
}

pub fn main() !void {
    try solve("dummy");
}
