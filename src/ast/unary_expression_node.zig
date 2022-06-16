/// Structure representing an unary expression.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const flags = nl.ast.flags;
const Location = nl.diagnostic.Location;
const Type = nl.types.Type;
const ExpressionNode = nl.ast.ExpressionNode;
const Variant = nl.vm.Variant;

const UnaryExpressionNode = @This();



/// Node on which the unary operation is executed.
child: *ExpressionNode,
/// Operation applied.
operator: Operator,

/// Start location of the node.
start_location: Location,

/// Constantness of the expression node.
constantness: flags.ConstantExpressionFlag = .unknown,
type: ?Type = null,
value: ?Variant = null,



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
  return self.type;
}

/// Gets the cached value of the expression node.
///
pub fn getValue(
  self: UnaryExpressionNode
) ?Variant {
  return self.value;
}



/// Available unary operations.
///
pub const Operator = enum {
  id, neg, bnot, lnot,
};
