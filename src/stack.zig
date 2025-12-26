const std = @import("std");

pub fn stack(comptime T: type, comptime stack_size: usize) type {
    return struct {
        const Stack = @This();
        buffer: [stack_size * @typeInfo(T).int.bits * 8]u8,
        fba: std.heap.FixedBufferAllocator,
        items: std.ArrayList(T),

        pub fn init(this: *Stack) !void {
            this.* = .{
                .buffer = undefined,
                .fba = undefined,
                .items = undefined,
            };
            this.fba = std.heap.FixedBufferAllocator.init(&this.buffer);
            this.items = try std.ArrayList(T).initCapacity(this.fba.allocator(), stack_size);
        }
        pub fn push(this: *Stack, item: T) !void {
            try this.items.append(this.fba.allocator(), item);
        }
        pub fn pop(this: *Stack) ?T {
            return this.items.pop();
        }
        pub fn peek(this: *const Stack) T {
            return this.items.getLastOrNull();
        }
        pub fn len(this: *const Stack) usize {
            return this.items.items.len;
        }
        pub fn deinit(this: *Stack) void {
            this.items.deinit(this.fba.allocator());
        }
    };
}
