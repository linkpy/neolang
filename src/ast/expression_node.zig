
const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const flags = nl.ast.flags;
const Location = nl.diagnostic.Location;
const Type = nl.types.Type;
const IdentifierNode = nl.ast.IdentifierNode;
const IntegerNode = nl.ast.IntegerNode;
const StringNode = nl.ast.StringNode;
const BinaryExpressionNode = nl.ast.BinaryExpressionNode;
const UnaryExpressionNode = nl.ast.UnaryExpressionNode;
const CallExpressionNode = nl.ast.CallExpressionNode;
const GroupExpressionNode = nl.ast.GroupExpressionNode;
const FieldAccessNode = nl.ast.FieldAccessNode;



/// Union representing any node that is considered an expression node.
///
pub const ExpressionNode = union(enum) {
  identifier: IdentifierNode,
  integer: IntegerNode,
  string: StringNode,
  binary: BinaryExpressionNode,
  unary: UnaryExpressionNode,
  call: CallExpressionNode,
  group: GroupExpressionNode,
  field: FieldAccessNode,



  /// Deinitializes the node.
  ///
  /// #### Parameters
  ///
  /// - `alloc`: Allocator used to free used memory.
  ///
  pub fn deinit(
    self: *ExpressionNode,
    alloc: Allocator
  ) void {
    switch( self.* ) {
      .integer => {},
      .identifier => |*id| id.deinit(alloc),
      .string => |*str| str.deinit(alloc),
      .binary => |*bin| bin.deinit(alloc),
      .unary => |*un| un.deinit(alloc),
      .call => |*call| call.deinit(alloc),
      .group => |*grp| grp.deinit(alloc),
      .field => |*fa| fa.deinit(alloc),
    }
  }


  /// Gets the start location of the node.
  ///
  pub fn getStartLocation(
    self: ExpressionNode
  ) Location {
    return switch( self ) {
      .identifier => |id| id.getStartLocation(),
      .integer => |int| int.getStartLocation(),
      .string => |str| str.getStartLocation(),
      .binary => |bin| bin.getStartLocation(),
      .unary => |un| un.getStartLocation(),
      .call => |call| call.getStartLocation(),
      .group => |grp| grp.getStartLocation(),
      .field => |fa| fa.getStartLocation(),
    };
  }

  /// Gets the end location of the node.
  ///
  pub fn getEndLocation(
    self: ExpressionNode
  ) Location {
    return switch( self ) {
      .identifier => |id| id.getEndLocation(),
      .integer => |int| int.getEndLocation(),
      .string => |str| str.getEndLocation(),
      .binary => |bin| bin.getEndLocation(),
      .unary => |un| un.getEndLocation(),
      .call => |call| call.getEndLocation(),
      .group => |grp| grp.getEndLocation(),
      .field => |fa| fa.getEndLocation(),
    };
  }



  /// Gets the constantness of the expression node.
  /// 
  pub fn getConstantness(
    self: ExpressionNode
  ) flags.ConstantExpressionFlag {
    return switch( self ) {
      .integer, .string => .constant,
      .identifier => |id| id.getConstantness(),
      .binary => |bin| bin.getConstantness(),
      .unary => |un| un.getConstantness(),
      .call => |call| call.getConstantness(),
      .group => |grp| grp.getConstantness(),
      .field => |fa| fa.getConstantness(),
    };
  }

  /// Gets the type of the expression node.
  ///
  pub fn getType(
    self: ExpressionNode
  ) ?Type {
    return switch( self ) {
      .integer => |int| int.getType(),
      .string => null,
      .identifier => |id| id.getType(),
      .binary => |bin| bin.getType(),
      .unary => |una| una.getType(),
      .call => |call| call.getType(),
      .group => |grp| grp.getType(),
      .field => |fa| fa.getType(),
    };
  }

};
