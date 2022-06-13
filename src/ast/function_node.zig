/// Structure representing a function declaration.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const ast = nl.ast;
const flags = ast.flags;
const Location = nl.diagnostic.Location;
const IdentifierNode = ast.IdentifierNode;
const ExpressionNode = ast.ExpressionNode;
const StatementNode = ast.StatementNode;

const FunctionNode = @This();



/// Name of the function.
name: IdentifierNode,
/// Arguments of the function.
arguments: []ArgumentNode,
/// Optional return type of the function.
return_type: ?ExpressionNode,
/// Body of the function
body: []StatementNode, // TODO use a BlockNode
/// Other metadata associated with the function.
metadata: Metadata = .{},

/// Start location of the function.
start_location: Location,
/// End location of the function (.kw_end token after the body).
end_location: Location,
/// End location of the signature (last token before the .kw_begin token).
signature_end_location: Location,

/// Documentation associated with the function.
documentation: ?[]const u8 = null,
/// Statement flags.
statement_flags: ast.StatementFlags = .{},



/// Deinitialise the function.
///
pub fn deinit(
  self: *FunctionNode,
  alloc: Allocator
) void {
  for( self.arguments ) |*arg| arg.deinit(alloc);
  for( self.body ) |*stmt| stmt.deinit(alloc);

  if( self.return_type ) |*expr| expr.deinit(alloc);
  self.name.deinit(alloc);

  alloc.free(self.arguments);
  alloc.free(self.body);
}



/// Gets the start location of the function.
///
pub fn getStartLocation(
  self: FunctionNode
) Location {
  return self.start_location;
}

/// Gets the end location of the function.
///
/// Note: Compared to other nodes, this function returns the end location of
/// the function's signature and not the end of the whole function node.
///
pub fn getEndLocation(
  self: FunctionNode
) Location {
  return self.signature_end_location;
}



// TODO move it to its own file
/// Structure representing an argument definition.
///
pub const ArgumentNode = struct {
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
};



/// Structure representing the additional metadata associated with a function
/// declaration.
///
pub const Metadata = struct {
  /// If true, the function supports recursion.
  is_recursive: bool = false,
  /// If true, the function is an entry-point of the program.
  is_entry_point: bool = false,
};
