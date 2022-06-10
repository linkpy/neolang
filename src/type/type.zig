
const std = @import("std");

const ast = @import("../parser/ast.zig");
const BinOp = ast.BinaryExpressionNode.Operator;
const UnaOp = ast.UnaryExpressionNode.Operator;



pub const Type = union(Type.Kind) {
  pub const CtInt = Type { .integer = .{ .size = null, .signed = true }};

  pub const I1 = Type { .integer = .{ .size = 1, .signed = true } };
  pub const I2 = Type { .integer = .{ .size = 2, .signed = true } };
  pub const I4 = Type { .integer = .{ .size = 4, .signed = true } };
  pub const I8 = Type { .integer = .{ .size = 8, .signed = true } };
  pub const I16 = Type { .integer = .{ .size = 16, .signed = true } };

  pub const U1 = Type { .integer = .{ .size = 1, .signed = false } };
  pub const U2 = Type { .integer = .{ .size = 2, .signed = false } };
  pub const U4 = Type { .integer = .{ .size = 4, .signed = false } };
  pub const U8 = Type { .integer = .{ .size = 8, .signed = false } };
  pub const U16 = Type { .integer = .{ .size = 16, .signed = false } };

  pub const Bool = Type{ .boolean = {} };



  integer: Integer,
  boolean: void, // TODO add a Bool struct



  pub fn isSameAs(
    self: Type,
    other: Type
  ) bool {
    return switch( self ) {
      .integer => |self_int| self_int.isSameAsType(other),
      .boolean => other == .boolean,
    };
  }



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

  pub fn getUnaryOperationResultType(
    self: Type,
    op: UnaOp
  ) ?Type {
    return switch( self ) {
      .integer => |int| int.getUnaryOperationType(op),
      else => null,
    };
  }



  pub fn format(
    self: Type,
    comptime fmt: []const u8, 
    options: std.fmt.FormatOptions,
    writer: anytype
  ) !void {
    switch( self ) {
      .integer => |int| try int.format(fmt, options, writer),
      .boolean => try writer.writeAll("bool"),
    }
  }



  pub const Kind = enum {
    integer,
    boolean, 
  };


  // TODO move to its own file
  pub const Integer = struct {
    size: ?usize,
    signed: bool, 



    pub fn isSameAsType(
      self: Integer,
      other: Type
    ) bool {
      return switch( other ) {
        .integer => |int| self.isSameAs(int),
        else => false
      };
    }

    pub fn isSameAs(
      self: Integer,
      other: Integer 
    ) bool {
      return self.size == other.size and self.signed == other.signed;
    }



    pub fn getBinaryOperationType(
      self: Integer,
      op: BinOp,
      other: Type, 
    ) ?Type {
      _ = self;

      return switch( other ) {
        .integer => |int| self.getBinaryOperationInteger(op, int),
        else => null
      };
    }

    pub fn getBinaryOperationInteger(
      self: Integer,
      op: BinOp,
      other: Integer
    ) ?Type {
      switch( op ) {
        .eq, .ne, .lt, .le, .gt, .ge => {
          if( self.size == null and other.size == null ) {
            return Bool;

          } else if( self.size == null and other.size != null ) {
            return Bool;

          } else if( self.size != null and other.size == null ) {
            return Bool;

          } else {
            if( self.signed != other.signed )
              return null;
            
            return Bool;
          }
        }, 
        else => {
          if( self.size == null and other.size == null ) {
            return CtInt;

          } else if( self.size == null and other.size != null ) {
            return Type { .integer = self };

          } else if( self.size != null and other.size == null ) {
            return Type { .integer = other };

          } else {
            if( self.signed != other.signed )
              return null;
            
            if( self.size.? > other.size.? )
              return Type { .integer = self }
            else
              return Type { .integer = other };
          }
        }
      }
    }

    pub fn getUnaryOperationType(
      self: Integer,
      op: UnaOp
    ) ?Type {
      _ = op;

      return Type { .integer = self };
    }



    pub fn format(
      self: Integer,
      comptime fmt: []const u8, 
      options: std.fmt.FormatOptions,
      writer: anytype
    ) !void {
      _ = fmt;
      _ = options;

      if( self.size ) |size| {
        const c: u8 = if( self.signed ) 'i' else 'u';
        try std.fmt.format(writer, "{c}{}", .{ c, size });
      } else {
        try writer.writeAll("ct_int");
      }
    }
  };
};
