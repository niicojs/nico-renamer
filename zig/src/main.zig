const std = @import("std");
const Io = std.Io;
const excel = @import("excel.zig");
const utils = @import("utils.zig");

const PREFIX = "Sample concentration: ";

pub fn main(init: std.process.Init) !void {
    const cp_out = utils.UTF8ConsoleOutput.init();
    defer cp_out.deinit();

    std.debug.print("┌──────────────┐\n", .{});
    std.debug.print("│ nico renamer │\n", .{});
    std.debug.print("└──────────────┘\n", .{});

    const io = init.io;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const dir_path = if (args.len > 1) args[1] else ".";
    std.debug.print("Répertoire: {s}\n", .{dir_path});

    var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| {
        std.debug.print("Impossible d'ouvrir le répertoire: {s}\n", .{@errorName(err)});
        return;
    };
    defer dir.close(io);

    const has_excel = blk: {
        dir.access(io, excel.RENAME_FILE, .{}) catch break :blk false;
        break :blk true;
    };

    if (!has_excel) {
        std.debug.print("Fichier excel non existant, on le crée.\n", .{});
        try buildExcelFile(io, allocator, &dir);
        std.debug.print("Ok.\n", .{});
        return;
    }

    std.debug.print("Fichier excel existant, on renomme.\n", .{});
    try renameFromExcel(io, allocator, &dir);
    std.debug.print("Ok.\n", .{});
}

fn buildExcelFile(io: Io, allocator: std.mem.Allocator, dir: *Io.Dir) !void {
    var rows = std.ArrayList(excel.RowData).empty;
    defer {
        for (rows.items) |row| excel.freeRow(allocator, row);
        rows.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".txt")) continue;

        const concentration = extractConcentration(entry.name) orelse "0";
        try rows.append(allocator, .{
            .nom = try allocator.dupe(u8, entry.name),
            .concentration = try allocator.dupe(u8, concentration),
            .maj = try allocator.dupe(u8, concentration),
        });
    }

    try excel.writeXlsx(io, allocator, dir, rows.items);
}

fn renameFromExcel(io: Io, allocator: std.mem.Allocator, dir: *Io.Dir) !void {
    var rows = try excel.readXlsx(io, allocator, dir);
    defer {
        for (rows.items) |row| excel.freeRow(allocator, row);
        rows.deinit(allocator);
    }

    for (rows.items) |row| {
        if (row.nom.len == 0 or row.maj.len == 0) continue;
        dir.access(io, row.nom, .{}) catch continue;

        const new_name = try buildNewName(allocator, row.nom, row.maj);
        defer allocator.free(new_name);

        if (std.mem.eql(u8, row.nom, new_name)) continue;

        dir.rename(row.nom, dir.*, new_name, io) catch continue;
        try rewriteConcentrationInFile(io, allocator, dir, new_name, row.maj);
    }
}

fn extractConcentration(name: []const u8) ?[]const u8 {
    if (name.len < 2 or name[0] != '[') return null;

    var i: usize = 1;
    const start = i;
    while (i < name.len and (std.ascii.isDigit(name[i]) or name[i] == '.')) : (i += 1) {}
    if (i == start) return null;

    return name[start..i];
}

fn buildNewName(allocator: std.mem.Allocator, old_name: []const u8, maj: []const u8) ![]u8 {
    if (old_name.len < 2 or old_name[0] != '[') return allocator.dupe(u8, old_name);

    var i: usize = 1;
    while (i < old_name.len and (std.ascii.isDigit(old_name[i]) or old_name[i] == '.')) : (i += 1) {}
    if (i == 1 or i >= old_name.len) return allocator.dupe(u8, old_name);

    return std.fmt.allocPrint(allocator, "[{s}{s}", .{ maj, old_name[i..] });
}

fn rewriteConcentrationInFile(io: Io, allocator: std.mem.Allocator, dir: *Io.Dir, name: []const u8, maj: []const u8) !void {
    const content = try dir.readFileAlloc(io, name, allocator, Io.Limit.limited(1024 * 1024 * 64));
    defer allocator.free(content);

    const idx = std.mem.indexOf(u8, content, PREFIX) orelse return;
    const start = idx + PREFIX.len;

    var end: usize = start;
    while (end < content.len and (std.ascii.isDigit(content[end]) or content[end] == '.')) : (end += 1) {}
    if (end == start) return;

    const new_content = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ content[0..start], maj, content[end..] });
    defer allocator.free(new_content);

    var file = try dir.createFile(io, name, .{ .truncate = true });
    defer file.close(io);
    try file.writeStreamingAll(io, new_content);
}
