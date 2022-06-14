/// Structure representing aa identifier.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const flags = nl.ast.flags;
const Location = nl.diagnostic.Location;
const Type = nl.types.Type;
const IdentifierID = nl.storage.Identifier.IdentifierID;

const IdentifierNode = @This();



/// Name of the identifier.
name: []u8,

/// Start location of the identifier.
start_location: Location,
/// End location of the identifier.
end_location: Location,

/// Identifier ID from the identifier storage.
/// Used by the identifier resolver.
identifier_id: ?IdentifierID = null,

/// Cached constantness of the identifier.
constantness: flags.ConstantExpressionFlag = .unknown,
/// Cached type of the identifier.
type: ?Type = null,



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
  alloc.free(self.name);
}



/// Gets the start location of the node.
///
pub fn getStartLocation(
  self: IdentifierNode
) Location {
  return self.start_location;
}

/// Gets the end location of the node.
///
pub fn getEndLocation(
  self: IdentifierNode
) Location {
  return self.end_location;
}



/// Gets the constantness of the expression node.
///
pub fn getConstantness(
  self: IdentifierNode
) flags.ConstantExpressionFlag {
  _ = self;
  return self.constantness;
}

/// Gets the type of the expression node.
///
pub fn getType(
  self: IdentifierNode
) ?Type {
  return self.type;
}



/// Formats the identifier.
///
pub fn format(
  self: IdentifierNode,
  comptime fmt: []const u8,
  options: std.fmt.FormatOptions,
  writer: anytype
) @TypeOf(writer).Error!void {
  _ = fmt;
  _ = options;
  try writer.writeAll(self.name);
}
