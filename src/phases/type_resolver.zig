/// Structure resolving type information in the AST.
///

// TODO remove order dependence

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



/// Resolves the type of a constant declaration node.
///
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

/// Resolves the types of an expression node.
///
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

/// Resolves the type of the given identifier.
///
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

/// Resolves the type of an unary expression.
///
pub fn resolveUnaryExpression(
  self: *TypeResolver,
  una: *ast.UnaryExpressionNode
) Error!void {
  try self.resolveExpression(una.child);

  // if the resolver managed to resolve the child expression's type
  if( una.child.getType() ) |typ| {
    // if the child expression type supports this unary operation
    if( typ.getUnaryOperationResultType(una.operator) ) |res_typ| {
      una.constantness = una.child.getConstantness();
      una.type = res_typ;

    } else {

      try self.diagnostics.pushError(
        "'{}' doesn't support the '{s}'' unary operation.",
        .{ typ, @tagName(una.operator) },
        una.getStartLocation(),
        una.getEndLocation()
      );
    }
  }
}

/// Resolves the type of a binary expression.
///
pub fn resolveBinaryExpression(
  self: *TypeResolver,
  bin: *ast.BinaryExpressionNode
) Error!void {
  try self.resolveExpression(bin.left);
  try self.resolveExpression(bin.right);

  // if the resolver managed to resolve the left expression's type
  if( bin.left.getType() ) |left_type| {
    // if the resolver managed to resolve the right expression's type
    if( bin.right.getType() ) |right_type| {

      // if the binary operation between both types is valid
      if( left_type.getBinaryOperationResultType(bin.operator, right_type) ) |typ| {
        bin.constantness = bin.left.getConstantness().mix(bin.right.getConstantness());
        bin.type = typ;

      } else {

        try self.diagnostics.pushError(
          "Types '{}' and '{}' cannot be coerced together.", 
          .{ left_type, right_type },
          bin.getStartLocation(),
          bin.getEndLocation()
        );
      }
    }
  }
}



pub const Error = IdentifierStorage.BindingError || Diagnostics.Error;
