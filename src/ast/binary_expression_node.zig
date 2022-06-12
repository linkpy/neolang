/// Structure representing a binary expression.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const flags = nl.ast.flags; 
const Location = nl.diagnostic.Location;
const Type = nl.types.Type;
const ExpressionNode = nl.ast.ExpressionNode;

const BinaryExpressionNode = @This();



/// Left-hand side of the expression.
left: *ExpressionNode,
/// Right-hand side of the expression.
right: *ExpressionNode,
/// Operator of the expression.
operator: Operator,

/// Constantness of the expression.
constantness: flags.ConstantExpressionFlag = .unknown,
/// Type of the expression.
type: ?Type = null,



/// Deinitializes the node.
///
/// #### Parameters
///
/// - `alloc`: Allocator used to free used memory.
///
pub fn deinit(
  self: *BinaryExpressionNode,
  alloc: Allocator,
) void {
  self.left.deinit(alloc);
  self.right.deinit(alloc);

  alloc.destroy(self.left);
  alloc.destroy(self.right);
}



/// Gets the start location of the node.
///
pub fn getStartLocation(
  self: BinaryExpressionNode
) Location {
  return self.left.getStartLocation();
}

/// Gets the end location of the node.
///
pub fn getEndLocation(
  self: BinaryExpressionNode
) Location {
  return self.right.getEndLocation();
}



/// Gets the constantness of the expression node.
///
pub fn getConstantness(
  self: BinaryExpressionNode
) flags.ConstantExpressionFlag {
  return self.constantness;
}

/// Gets the type of the expression node.
/// 
pub fn getType(
  self: BinaryExpressionNode
) ?Type {
  return self.type;
}



/// Possible binary operations.
///
pub const Operator = enum {
  add, sub, mul, div, mod, 
  eq, ne, lt, le, gt, ge,
  land, lor,
  shl, shr, band, bor, bxor,
};
