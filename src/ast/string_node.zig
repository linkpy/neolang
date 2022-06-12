/// Structure representing a string.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const flags = nl.ast.flags;
const Location = nl.diagnostic.Location;

const StringNode = @This();



/// Value of the string.
value: []u8,

/// Start location of the node.
start_location: Location,
/// End location of the node.
end_location: Location,



/// Deinitializes the node.
///
/// #### Parameters
///
/// - `alloc`: Allocator used to free used memory.
///
pub fn deinit(
  self: *StringNode,
  alloc: Allocator
) void {
  alloc.free(self.value);
}



/// Gets the start location of the node.
///
pub fn getStartLocation(
  self: StringNode
) Location {
  return self.start_location;
}

/// Gets the start location of the node.
///
pub fn getEndLocation(
  self: StringNode
) Location {
  return self.end_location;
}
