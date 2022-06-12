/// Structure representing a diagnostic associated with some source code.
///



const std = @import("std");

const nl = @import("../nl.zig");
const Location = nl.diagnostic.Location;

const Diagnostic = @This();



/// Kind of diagnostic.
kind: Kind,
/// Message associated. Held in heap.
message: []const u8,
/// Primary diagnostic.
primary: bool,

/// Start location of the diagnostic in the code.
start_location: Location,
/// End location of the diagnostic in the code.
end_location: Location,



/// Deinitialises the diagnostic.
///
pub fn deinit(
  self: *Diagnostic,
  alloc: std.mem.Allocator
) void {
  alloc.free(self.message);
}



/// Available kinds of diagnostics.
///
pub const Kind = enum {
  error_,
  warning,
  note,
  verbose,
};
