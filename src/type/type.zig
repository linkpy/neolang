
const ast = @import("../parser/ast.zig");
const BinOp = ast.BinaryExpressionNode.Operator;
const UnaOp = ast.UnaryExpressionNode.Operator;



pub const Type = union(Type.Kind) {
  pub const Integer = Type{ .integer = {} };
  pub const String = Type{ .string = {} };
  pub const Boolean = Type{ .boolean = {} };



  integer: void,
  string: void,
  boolean: void,



  pub fn isSameAs(
    self: Type,
    other: Type
  ) bool {
    return @as(Kind, self) == @as(Kind, other);
  }



  pub fn getBinaryOperationResultType(
    self: Type,
    op: BinOp
  ) ?Type {
    // TODO switch to union dispatch
    return switch( op )  {
      .eq, .ne, .lt, .le, .gt, .ge => Type.Boolean,
      else => self,
    };
  }

  pub fn getUnaryOperationResultType(
    self: Type,
    op: UnaOp
  ) ?Type {
    // TODO switch to union dispatch
    return switch( op ) {
      else => self,
    };
  }



  pub const Kind = enum {
    integer,
    string, 
    boolean, 
  };
};
