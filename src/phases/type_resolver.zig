
const std = @import("std");

const ast = @import("../parser/ast.zig");
const IdentifierStorage = @import("../storage/identifier.zig");
const Diagnostics = @import("../diagnostic/diagnostics.zig");
const Type = @import("../type/type.zig");

const TypeResolver = @This();



/// Diagnostics used in case of error.
diagnostics: *Diagnostics,
/// Registered identifiers.
identifiers: *IdentifierStorage,
/// Number of error that occured during resolving.
errors: usize, 



/// Initialises a new instance.
///
pub fn init(
  diags: *Diagnostics,
  ids: *IdentifierStorage
) TypeResolver {
  return TypeResolver {
    .diagnostics = diags,
    .identifiers = ids,
    .errors = 0,
  };
}



pub fn resolveConstant(
  self: *TypeResolver,
  cst: *ast.ConstantNode
) Error!void {
  if( cst.name.identifier_id ) |id| {
    try self.resolveExpression(&cst.value);

    if( cst.value.getType() ) |typ| {
      var entry = self.identifiers.getEntry(id).?;

      entry.data = .{ .expression = .{
        .constantness = cst.value.getConstantness(),
        .type = typ,
      }};
    }
  }
}

pub fn resolveExpression(
  self: *TypeResolver,
  expr: *ast.ExpressionNode
) Error!void {
  switch( expr.* ) {
    .identifier => |*id| try self.resolveIdentifier(id),
    .unary => |*una| try self.resolveUnaryExpression(una),
    .binary => |*bin| try self.resolveBinaryExpression(bin),
    .call => @panic("NYI"),
    else => {},
  }
}

pub fn resolveIdentifier(
  self: *TypeResolver,
  id_expr: *ast.IdentifierNode
) Error!void {
  if( id_expr.isSegmented() ) {
    @panic("NYI");
  } else {

    if( id_expr.identifier_id ) |id| {
      var entry = self.identifiers.getEntry(id).?;
      
      if( entry.data == .expression ) {
        const expr_data = entry.data.expression;
        id_expr.constantness = expr_data.constantness;
        id_expr.type = expr_data.type;

      } else {

        @panic("not sure if it's ok");
      }
    }

  }
}

pub fn resolveUnaryExpression(
  self: *TypeResolver,
  una: *ast.UnaryExpressionNode
) Error!void {
  try self.resolveExpression(una.child);

  if( una.child.getType() ) |typ| {
    const child_constantness = una.child.getConstantness();

    una.constantness = child_constantness;
    una.type = typ.getUnaryOperationResultType(una.operator);
  }
}

pub fn resolveBinaryExpression(
  self: *TypeResolver,
  bin: *ast.BinaryExpressionNode
) Error!void {
  try self.resolveExpression(bin.left);
  try self.resolveExpression(bin.right);

  if( bin.left.getType() ) |left_type| {
    if( bin.right.getType() ) |right_type| {
      if( left_type.getBinaryOperationResultType(bin.operator, right_type) ) |typ| {
        bin.constantness = bin.left.getConstantness().mix(bin.right.getConstantness());
        bin.type = typ;

      } else {

        try self.diagnostics.pushError(
          "Types '{}' and '{}' cannot be coerced into a type fitting both.", 
          .{ left_type, right_type },
          bin.getStartLocation(),
          bin.getEndLocation()
        );
      }
    }
  }
}



pub const Error = IdentifierStorage.BindingError || Diagnostics.Error;
