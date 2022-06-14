/// Structure representing an argument declaration.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const ast = nl.ast;
const IdentifierNode = ast.IdentifierNode;
const ExpressionNode = ast.ExpressionNode;
const Location = nl.diagnostic.Location;

const ArgumentNode = @This();



/// Name of the argument.
name: IdentifierNode,
/// Type of the argument.
type: ExpressionNode,



/// Deinitialises the argument node.
///
pub fn deinit(
  self: *ArgumentNode,
  alloc: Allocator
) void {
  self.name.deinit(alloc);
  self.type.deinit(alloc);
}
