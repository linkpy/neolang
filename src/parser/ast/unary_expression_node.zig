/// Structure representing an unary expression.
///



const std = @import("std");
const Location = @import("../../diagnostic/location.zig");
const Token = @import("../lexer.zig").Token;

const ExpressionNode = @import("./expression_node.zig").ExpressionNode;

const Allocator = std.mem.Allocator;
const UnaryExpressionNode = @This();



/// Node on which the unary operation is executed.
child: *ExpressionNode,
/// Operation applied.
operator: Operator,

/// Start location of the node.
start_location: Location,



/// Deinitializes the node.
///
/// #### Parameters
///
/// - `alloc`: Allocator used to free used memory.
///
pub fn deinit(
  self: *UnaryExpressionNode,
  alloc: Allocator
) void {
  self.child.deinit(alloc);

  alloc.destroy(self.child);
}



/// Gets the start location of the node.
///
pub fn getStartLocation(
  self: UnaryExpressionNode
) Location {
  return self.start_location;
}

/// Gets the end location of the node.
///
pub fn getEndLocation(
  self: UnaryExpressionNode
) Location {
  return self.child.getEndLocation();
}



/// Available unary operations.
///
pub const Operator = enum {
  id, neg, bnot, lnot,
};
