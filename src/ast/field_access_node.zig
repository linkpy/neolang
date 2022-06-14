/// Structure representing a field access.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const ast = nl.ast;
const flags = ast.flags;
const ExpressionNode = ast.ExpressionNode;
const IdentifierNode = ast.IdentifierNode;
const Location = nl.diagnostic.Location;
const Type = nl.types.Type;

const FieldAccessNode = @This();



/// Expression representing the field's storage.
storage: *ExpressionNode,
/// Field's name.
field: IdentifierNode,

/// Constantness of the expression.
constantness: ast.ConstantExpressionFlag = .unknown,
/// Type of the expression.
type: ?Type = null,



/// Deinitialises the node.
///
pub fn deinit(
  self: *FieldAccessNode,
  alloc: Allocator
) void {
  self.storage.deinit(alloc);
  self.field.deinit(alloc);

  alloc.destroy(self.storage);
}



/// Gets the start location of the node.
///
pub fn getStartLocation(
  self: FieldAccessNode
) Location {
  return self.storage.getStartLocation();
}

/// Gets the end location of the node.
///
pub fn getEndLocation(
  self: FieldAccessNode
) Location {
  return self.field.getEndLocation();
}



/// Gets the constantness of the expression.
///
pub fn getConstantness(
  self: FieldAccessNode
) flags.ConstantExpressionFlag {
  return self.constantness;
}

/// Gets the type of the expression.
///
pub fn getType(
  self: FieldAccessNode
) ?Type {
  return self.type;
}
