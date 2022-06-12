/// Struct representing a group expression.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const flags = nl.ast.flags;
const Location = nl.diagnostic.Location;
const Type = nl.types.Type;
const ExpressionNode = nl.ast.ExpressionNode;

const GroupExpressionNode = @This();



/// Expression contained in the group.
child: *ExpressionNode,

/// Start location of the group.
start_location: Location,
/// End location of the group.
end_location: Location,



/// Deinitialises the node.
///
pub fn deinit(
  self: *GroupExpressionNode,
  alloc: Allocator
) void {
  self.child.deinit(alloc);

  alloc.destroy(self.child);
}



/// Gets the start location of the node.
///
pub fn getStartLocation(
  self: GroupExpressionNode
) Location {
  return self.start_location;
}

/// Gets the end location of the node.
///
pub fn getEndLocation(
  self: GroupExpressionNode
) Location {
  return self.end_location;
}



/// Gets the constantness of the node.
///
pub fn getConstantness(
  self: GroupExpressionNode
) flags.ConstantExpressionFlag {
  return self.child.getConstantness();
}

/// Gets the type of the node.
///
pub fn getType(
  self: GroupExpressionNode
) ?Type {
  return self.child.getType();
}
