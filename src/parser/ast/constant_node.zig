/// Structure representing a constant definition.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../../nl.zig");
const Location = nl.diagnostic.Location;
const IdentifierNode = nl.parser.ast.IdentifierNode;
const ExpressionNode = nl.parser.ast.ExpressionNode;

const ConstantNode = @This();



/// Name of the constant.
name: IdentifierNode,
/// Type of the constant. Defined in the source.
type: ?ExpressionNode,
/// Value of the constant.
value: ExpressionNode,

/// Start location of the node (usually, from the `const` keyword).
start_location: Location,
/// End location of the node (usually, from the `.` symbol).
end_location: Location,



/// Deinitializes the node.
///
/// #### Parameters
///
/// - `alloc`: Allocator used to free used memory.
///
pub fn deinit(
  self: *ConstantNode,
  alloc: Allocator
) void {
  self.name.deinit(alloc);
  if( self.type ) |*expr| expr.deinit(alloc);
  self.value.deinit(alloc);
}



/// Gets the start location of the node.
///
pub fn getStartLocation(
  self: ConstantNode
) Location {
  return self.start_location;
}

/// Gets the end location of the node.
///
pub fn getEndLocation(
  self: ConstantNode
) Location {
  return self.end_location;
}
