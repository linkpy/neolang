
const std = @import("std");

const nl = @import("../nl.zig");
const ast = nl.ast;
const IntegerType = nl.types.IntegerType;

const BinOp = ast.BinaryExpressionNode.Operator;
const UnaOp = ast.UnaryExpressionNode.Operator;



/// Structure representing a type.
///
pub const Type = union(enum) {
  /// Compile time integer.
  pub const CtInt = newInt(.dynamic, true);

  /// 1 byte signed integer.
  pub const I1 = newInt(.{ .bytes = 1 }, true);
  /// 2 byte signed integer.
  pub const I2 = newInt(.{ .bytes = 2 }, true);
  /// 4 byte signed integer.
  pub const I4 = newInt(.{ .bytes = 4 }, true);
  /// 8 byte signed integer.
  pub const I8 = newInt(.{ .bytes = 8 }, true);

  /// 1 byte unsigned integer.
  pub const U1 = newInt(.{ .bytes = 1 }, false);
  /// 2 byte unsigned integer.
  pub const U2 = newInt(.{ .bytes = 2 }, false);
  /// 4 byte unsigned integer.
  pub const U4 = newInt(.{ .bytes = 4 }, false);
  /// 8 byte unsigned integer.
  pub const U8 = newInt(.{ .bytes = 8 }, false);

  /// Pointer-sized signed integer.
  pub const IPtr = newInt(.pointer, true);
  /// Pointer-sized unsigned integer.
  pub const UPtr = newInt(.pointer, false);

  /// Boolean.
  pub const Bool = Type { .boolean = {} };

  /// Type.
  pub const TypeT = Type { .type = {} };




  /// Integer type variant.
  integer: IntegerType,
  /// Boolean type variant.
  boolean: void, // TODO add a BoolType struct

  /// Type type variant.
  type: void, // TODO add a TypeType structure



  /// Creates a new integer type.
  ///
  pub fn newInt(
    width: IntegerType.Width,
    signed: bool
  ) Type {
    return IntegerType.init(width, signed).toType();
  }



  /// Checks if the type is an integer.
  ///
  pub fn isInteger(
    self: Type
  ) bool {
    return switch( self ) {
      .integer => true,
      else => false,
    };
  }

  /// Checks if the type is a boolean.
  ///
  pub fn isBoolean(
    self: Type
  ) bool {
    return switch( self ) {
      .boolean => true,
      else => false,
    };
  }

  /// Checks if the type is a type.
  ///
  pub fn isType(
    self: Type
  ) bool {
    return switch( self ) {
      .type => true,
      else => false
    };
  }



  /// Checks if both types are the same.
  ///
  pub fn isSameAs(
    self: Type,
    other: Type
  ) bool {
    return switch( self ) {
      .integer => |self_int| self_int.isSameAsType(other),
      .boolean => other == .boolean,
      .type => other == .type,
    };
  }



  /// Checks if the current type can be coerced into the given type.
  ///
  pub fn canBeCoercedTo(
    self: Type,
    to: Type
  ) bool {
    return switch( self ) {
      .integer => |int| int.canBeCoercedToType(to),
      .boolean => to == .boolean,
      .type => to == .type,
    };
  }

  /// Finds the type that both type can coerce into.
  ///
  pub fn peerResolution(
    self: Type,
    other: Type
  ) ?Type {
    return switch( self ) {
      .integer => |int| int.peerResolutionType(other),
      .boolean => if( other == .boolean ) Type.Bool else null,
      .type => if( other == .type ) Type.TypeT else null,
    };
  }



  /// Gets the resulting type of the binary operation between both types.
  ///
  pub fn getBinaryOperationResultType(
    self: Type,
    op: BinOp,
    other: Type,
  ) ?Type {
    return switch( self ) {
      .integer => |int| int.getBinaryOperationType(op, other),
      else => null,
    };
  }

  /// Gets the resulting type of the unary operation on the integer type.
  ///
  pub fn getUnaryOperationResultType(
    self: Type,
    op: UnaOp
  ) ?Type {
    return switch( self ) {
      .integer => |int| int.getUnaryOperationType(op),
      else => null,
    };
  }



  /// Formats the instance.
  ///
  pub fn format(
    self: Type,
    comptime fmt: []const u8, 
    options: std.fmt.FormatOptions,
    writer: anytype
  ) !void {
    switch( self ) {
      .integer => |int| try int.format(fmt, options, writer),
      .boolean => try writer.writeAll("bool"),
      .type => try writer.writeAll("type"),
    }
  }


  
  pub const Integer = IntegerType;
};
