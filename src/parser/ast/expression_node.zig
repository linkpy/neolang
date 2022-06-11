
const std = @import("std");
const Location = @import("../../diagnostic/location.zig");
const Token = @import("../lexer.zig").Token;
const Type = @import("../../type/type.zig").Type;

const flags = @import("./flags.zig");
const IdentifierNode = @import("./identifier_node.zig");
const IntegerNode = @import("./integer_node.zig");
const StringNode = @import("./string_node.zig");
const BinaryExpressionNode = @import("./binary_expression_node.zig");
const UnaryExpressionNode = @import("./unary_expression_node.zig");
const CallExpressionNode = @import("./call_expression_node.zig");
const GroupExpressionNode = @import("./group_expression_node.zig");

const Allocator = std.mem.Allocator;



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
    };
  }

};
