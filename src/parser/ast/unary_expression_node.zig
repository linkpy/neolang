/// Structure representing an unary expression.
///



const std = @import("std");
const Location = @import("../../diagnostic/location.zig");
const Token = @import("../lexer.zig").Token;
const Type = @import("../../type/type.zig").Type;

const flags = @import("./flags.zig");
const ExpressionNode = @import("./expression_node.zig").ExpressionNode;

const Allocator = std.mem.Allocator;
const UnaryExpressionNode = @This();



/// Node on which the unary operation is executed.
child: *ExpressionNode,
/// Operation applied.
operator: Operator,

/// Start location of the node.
start_location: Location,

/// Constantness of the expression node.
constantness: flags.ConstantExpressionFlag = .unknown,
/// Type of the expression node.
type: ?Type = null,



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



/// Gets the constantness of the expression node.
///
pub fn getConstantness(
  self: UnaryExpressionNode
) flags.ConstantExpressionFlag {
  return self.child.getConstantness();
}

/// Gets the type of the expression node.
///
pub fn getType(
  self: UnaryExpressionNode
) ?Type {
  return self.child.getType();
}



/// Available unary operations.
///
pub const Operator = enum {
  id, neg, bnot, lnot,
};
