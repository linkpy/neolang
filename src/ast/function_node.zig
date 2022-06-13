
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



name: IdentifierNode,
arguments: []ArgumentNode,
return_type: ?ExpressionNode,
body: []StatementNode,
metadata: Metadata = .{},

start_location: Location,
end_location: Location,
signature_end_location: Location,

documentation: ?[]const u8 = null,
statement_flags: ast.StatementFlags = .{},




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



pub fn getStartLocation(
  self: FunctionNode
) Location {
  return self.start_location;
}

pub fn getEndLocation(
  self: FunctionNode
) Location {
  return self.signature_end_location;
}



// TODO move it to its own file
pub const ArgumentNode = struct {
  name: IdentifierNode,
  type: ExpressionNode,



  pub fn deinit(
    self: *ArgumentNode,
    alloc: Allocator
  ) void {
    self.name.deinit(alloc);
    self.type.deinit(alloc);
  }
};

pub const Metadata = struct {
  is_recursive: bool = false,
  is_entry_point: bool = false,
};
