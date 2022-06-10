/// Structure representing a segmented identifier.
///
/// This structure is also used for simple identifiers, which are segmented
/// identifiers with only 1 segment.
///



const std = @import("std");
const Location = @import("../../diagnostic/location.zig");
const Token = @import("../lexer.zig").Token;

const Allocator = std.mem.Allocator;
const IdentifierNode = @This();



/// Segments of the identifier.
parts: []Token,



/// Deinitializes the node.
///
/// #### Parameters
///
/// - `alloc`: Allocator used to free used memory.
///
pub fn deinit(
  self: *IdentifierNode,
  alloc: Allocator
) void {
  alloc.free(self.parts);
}



/// Gets the start location of the node.
///
pub fn getStartLocation(
  self: IdentifierNode
) Location {
  return self.parts[0].start_location;
}

/// Gets the end location of the node.
///
pub fn getEndLocation(
  self: IdentifierNode
) Location {
  return self.parts[self.parts.len - 1].end_location;
}



/// Checks if the identifier is segmented (more than 1 segment) or not.
///
pub fn isSegmented(
  self: IdentifierNode
) bool {
  return self.parts.len > 1;
}
