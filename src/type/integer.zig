/// Structure reprensenting an integer type.
///



const std = @import("std");
const ast = @import("../parser/ast.zig");

const Type = @import("./type.zig").Type;
const BinOp = ast.BinaryExpressionNode.Operator;
const UnaOp = ast.UnaryExpressionNode.Operator;

const IntegerType = @This();



/// Width of the integer.
width: Width,
/// If true the integer is signed.
signed: bool, 



/// Initialises a new instance.
///
pub fn init(
  width: Width,
  signed: bool
) IntegerType {
  return IntegerType {
    .width = width,
    .signed = signed
  };
}



/// Wraps the integer type into a `Type` union.
///
pub fn toType(
  self: IntegerType
) Type {
  return Type { .integer = self };
}



/// Checks if the integer type is the same as the given type.
///
pub fn isSameAsType(
  self: IntegerType,
  other: Type
) bool {
  return switch( other ) {
    .integer => |int| self.isSameAs(int),
    else => false
  };
}

/// Checks if both integers are the same.
///
pub fn isSameAs(
  self: IntegerType,
  other: IntegerType 
) bool {
  return self.width.eq(other.width) and self.signed == other.signed;
}



pub fn canBeCoercedToType(
  self: IntegerType,
  to: Type,
) bool {
  return switch( to ) {
    .integer => |int| self.canBeCoercedToInt(int),
    else => false,
  };
}

pub fn canBeCoercedToInt(
  self: IntegerType,
  to: IntegerType
) bool {
  if( self.width == .dynamic or to.width == .dynamic ) {
    return true;

  } else {
    if( self.signed != to.signed )
      return false;
    
    switch( self.width ) {
      .bytes => |self_width| switch( to.width ) {
        .bytes => |to_width| return self_width <= to_width,
        else => return false,
      },
      .pointer => return to.width == .pointer,
      else => unreachable,
    }
  }
}



pub fn peerResolutionType(
  self: IntegerType,
  other: Type
) ?Type {
  return switch( other ) {
    .integer => |int| self.peerResolutionInt(int),
    else => null,
  };
}

pub fn peerResolutionInt(
  self: IntegerType,
  other: IntegerType
) ?Type {
  if( self.width == .dynamic and other.width == .dynamic ) {
    return Type.CtInt;

  } else if( self.width == .dynamic and other.width != .dynamic ) {
    return other.toType();

  } else if( self.width != .dynamic and other.width == .dynamic ) {
    return self.toType();

  } else {
    if( self.signed != other.signed )
      return null;
    
    switch( self.width ) {
      .bytes => |self_width| switch( other.width ) {
        .bytes => |other_width| if( self_width > other_width )
          return self.toType()
        else 
          return other.toType(),
        else => return null,
      },
      .pointer => switch( other.width ) {
        .pointer => return self.toType(),
        else => return null,
      },
      else => unreachable,
    }
  }
}



/// Gets the resulting type of the binary operation between both types.
///
pub fn getBinaryOperationType(
  self: IntegerType,
  op: BinOp,
  other: Type, 
) ?Type {
  return switch( other ) {
    .integer => |int| self.getBinaryOperationInteger(op, int),
    else => null
  };
}

/// Gets the resulting type of the binary operation between both integer types.
///
pub fn getBinaryOperationInteger(
  self: IntegerType,
  op: BinOp,
  other: IntegerType
) ?Type {

  switch( op ) {

    .eq, .ne, .lt, .le, .gt, .ge => {
      if( self.width != .dynamic and other.width != .dynamic and self.signed != other.signed )
        return null;

      return Type.Bool;
    }, 

    else => {
      if( self.width == .dynamic and other.width == .dynamic ) {
        return Type.CtInt;

      } else if( self.width == .dynamic and other.width != .dynamic ) {
        return other.toType();

      } else if( self.width != .dynamic and other.width == .dynamic ) {
        return self.toType();

      } else {
        if( self.signed != other.signed )
          return null;
        
        switch( self.width ) {
          .bytes => |self_width| switch( other.width ) {
            .bytes => |other_width| if( self_width > other_width )
              return self.toType()
            else 
              return other.toType(),
            else => return null,
          },
          .pointer => switch( other.width ) {
            .pointer => return self.toType(),
            else => return null,
          },
          else => unreachable,
        }
      }

    }

  }
}

/// Gets the resulting type of the unary operation on the integer type.
///
pub fn getUnaryOperationType(
  self: IntegerType,
  op: UnaOp
) ?Type {
  _ = op;

  return Type { .integer = self };
}



/// Formats the instance.
///
pub fn format(
  self: IntegerType,
  comptime fmt: []const u8, 
  options: std.fmt.FormatOptions,
  writer: anytype
) !void {
  _ = fmt;
  _ = options;

  const c: u8 = if( self.signed ) 'i' else 'u';

  switch( self.width ) {
    .dynamic => try writer.writeAll("ct_int"),
    .bytes => |width| try std.fmt.format(writer, "{c}{}", .{ c, width }),
    .pointer => try std.fmt.format(writer, "{c}ptr", .{ c }),
  }
}



pub const Width = union(enum) {
  dynamic: void,
  bytes: u8,
  pointer: void,



  pub fn eq(
    a: Width,
    b: Width
  ) bool {
    return switch( a ) {
      .dynamic => b == .dynamic,
      .bytes => |ab| switch( b ) {
        .bytes => |bb| ab == bb,
        else => false,
      },
      .pointer => b == .pointer,
    };
  }
};
