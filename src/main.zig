const std = @import("std");

const Buffer = struct {
    const capacity = 8;
    const half_capacity = capacity / 2;

    buffer: [capacity]u8,
    length: usize
};
const File = std.TailQueue(Buffer);

fn of_buffer(alloc: *std.mem.Allocator, buffer: []u8) !File {
    var f = File{};

    var i: usize = 0;
    while (i < buffer.len) : (i += Buffer.half_capacity) {
        // leak
        var node = try alloc.create(File.Node);

        var end = std.math.min(i + Buffer.half_capacity, buffer.len);
        node.data.length = end - i;

        // slice isn't unicode aware
        std.mem.copy(u8, &node.data.buffer, buffer[i..end]);

        f.append(node);
    }
    return f;
}

fn write(buf: []const u8) !void {
    try std.io.getStdOut().writeAll(buf);
}

fn readByte() !u8 {
    var buf: [1]u8 = undefined;
    var n = try std.io.getStdIn().readAll(&buf);
    if (n != 1) {
        return error.EndOfStream;
    }
    return buf[0];
}

var original_termios: std.os.termios = undefined;

const stdin = std.io.getStdIn().handle;

fn disable_raw_mode() void {
    std.os.tcsetattr(stdin, .FLUSH, original_termios) catch {};
}

fn enable_raw_mode() !void {
    var termios = try std.os.tcgetattr(std.io.getStdIn().handle);
    original_termios = termios;

    termios.iflag &= ~@as(u32, std.os.BRKINT | std.os.ICRNL | std.os.INPCK | std.os.ISTRIP | std.os.IXON);
    termios.oflag &= ~@as(u32, std.os.OPOST);
    termios.cflag |= (std.os.CS8);
    termios.lflag &= ~@as(u32, std.os.ECHO | std.os.ICANON | std.os.IEXTEN | std.os.ISIG);
    termios.cc[std.os.VMIN] = 0;
    termios.cc[std.os.VTIME] = 1;

    try std.os.tcsetattr(stdin, .FLUSH, termios);
}

const Pos = struct { row: u32, col: u32 };

fn get_cursor_pos() !Pos {
    try write("\x1B[6n");

    const N = 32;
    var buf: [N]u8 = undefined;

    var i: usize = 0;
    while (i < N) : (i += 1) {
        var c = try readByte();
        if (c == 'R') break;
        buf[i] = c;
    }

    const end = i;

    if (buf[0] != '\x1B' and buf[1] != '[') {
        return error.CouldntParseCursorPos;
    }

    var j: usize = 2;
    while (j < end) : (j += 1) {
        if (buf[j] == ';') break;
    }

    if (j == buf.len - 1) {
        return error.CouldntParseCursorPos;
    }

    var row = try std.fmt.parseInt(u32, buf[2..j], 0);
    var col = try std.fmt.parseInt(u32, buf[j + 1 .. end], 0);

    return Pos{ .row = row, .col = col };
}

fn try_restore_cursor_pos(pos: Pos) void {
    // can't recover from error
    std.io.getStdOut().writer().print("\x1b[{};{}H", .{ pos.row, pos.col }) catch {};
}

fn get_win_size() !Pos {
    var pos = try get_cursor_pos();
    defer try_restore_cursor_pos(pos);

    try write("\x1b[999C\x1b[999B");

    return get_cursor_pos();
}

fn print(file: File) void {
    std.debug.print("\x1B[2J\x1B[1;1H", .{});
    var it = file.first;
    while (it) |node| : (it = node.next) {
        var data = node.data;
        std.debug.print("{s}", .{data.buffer[0..data.length]});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    var alloc = &gpa.allocator;

    const file = try std.fs.cwd().openFile("src/main.zig", .{ .read = true });
    defer file.close();

    var data = try file.readToEndAlloc(alloc, 1_000_000);
    defer alloc.free(data);

    var f = try of_buffer(alloc, data);
    // print(f);

    var winsize: Pos = undefined;
    {
        try enable_raw_mode();
        defer disable_raw_mode();
        winsize = try get_win_size();
    }
    std.debug.print("{}\n", .{winsize});
}
