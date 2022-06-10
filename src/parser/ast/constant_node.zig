/// Structure representing a constant definition.
///



const std = @import("std");
const Location = @import("../../diagnostic/location.zig");
const Token = @import("../lexer.zig").Token;

const IdentifierNode = @import("./identifier_node.zig");
const ExpressionNode = @import("./expression_node.zig").ExpressionNode;

const Allocator = std.mem.Allocator;
const ConstantNode = @This();



/// Name of the constant.
name: IdentifierNode,
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
