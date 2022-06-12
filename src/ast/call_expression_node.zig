/// Structure representing a call expression.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const flags = nl.ast.flags;
const Location = nl.diagnostic.Location;
const Type = nl.types.Type;
const ExpressionNode = nl.ast.ExpressionNode;

const CallExpressionNode = @This();



/// Called function.
function: *ExpressionNode,
/// Arguments of the function.
arguments: []ExpressionNode,

/// Location of the exclamation point.
/// Undefined if the node has arguments.
exclam_location: Location,

/// Cached constantness of the node.
constantness: flags.ConstantExpressionFlag = .unknown,
/// Cached type of the node.
type: ?Type = null,



/// Deinitializes the node.
///
/// #### Parameters
///
/// - `alloc`: Allocator used to free used memory.
///
pub fn deinit(
  self: *CallExpressionNode,
  alloc: Allocator
) void {
  self.function.deinit(alloc);
  for( self.arguments ) |*arg| arg.deinit(alloc);

  alloc.destroy(self.function);
  alloc.free(self.arguments);
}



/// Gets the start location of the node.
///
pub fn getStartLocation(
  self: CallExpressionNode
) Location {
  return self.function.getStartLocation();
}

/// Gets the end location of the node.
///
pub fn getEndLocation(
  self: CallExpressionNode
) Location {
  if( self.arguments.len == 0 ) {
    return self.exclam_location;
  }
  return self.arguments[self.arguments.len - 1].getEndLocation();
}



/// Gets the constantness of the expression node.
///
pub fn getConstantness(
  self: CallExpressionNode
) flags.ConstantExpressionFlag {
  return self.constantness;
}

/// Gets the type of the expression node.
/// 
pub fn getType(
  self: CallExpressionNode
) ?Type {
  return self.type;
}
