const std = @import("std");
const builtin = @import("builtin");

const windows = std.os.windows;

const UINT = windows.UINT;

extern "kernel32" fn GetConsoleOutputCP() callconv(.winapi) UINT;
extern "kernel32" fn SetConsoleOutputCP(wCodePageID: UINT) callconv(.winapi) windows.BOOL;

pub const UTF8ConsoleOutput = struct {
    original_cp: UINT,
    active: bool,

    pub fn init() UTF8ConsoleOutput {
        if (builtin.os.tag != .windows) {
            return .{ .original_cp = 0, .active = false };
        }

        const original = GetConsoleOutputCP();
        const ok = SetConsoleOutputCP(65001) != 0;
        return .{ .original_cp = original, .active = ok };
    }

    pub fn deinit(self: UTF8ConsoleOutput) void {
        if (builtin.os.tag != .windows) return;
        if (!self.active) return;
        _ = SetConsoleOutputCP(self.original_cp);
    }
};
