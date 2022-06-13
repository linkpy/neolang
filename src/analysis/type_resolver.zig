/// Structure resolving type information in the AST.
///

// TODO remove order dependence
// TODO check that integer fits their type

const std = @import("std");

const nl = @import("../nl.zig");
const ast = nl.ast;
const trv = nl.ast.traverser;
const Diagnostics = nl.diagnostic.Diagnostics;
const IdentifierStorage = nl.storage.Identifier;
const Type = nl.types.Type;

const TypeResolver = @This();



/// Diagnostics used in case of error.
diagnostics: *Diagnostics,
/// Registered identifiers.
identifiers: *IdentifierStorage,

/// Number of error that occured during resolving.
errors: usize,

debug: bool = false,



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



/// Resolves the types in a statement node.
///
pub fn resolveStatement(
  self: *TypeResolver,
  stmt: *ast.StatementNode
) Error!void {
  switch( stmt.* ) {
    .constant => |*cst| try self.resolveConstant(cst),
  }
}

/// Resolves the type of a constant declaration node.
///
pub fn resolveConstant(
  self: *TypeResolver,
  cst: *ast.ConstantNode
) Error!void {
  if( cst.name.identifier_id ) |id| {
    
    if( cst.type ) |*type_expr| {
      try self.resolveExpression(type_expr);

      if( type_expr.getType() ) |typ| {
        if( !typ.isSameAs(Type.TypeT) ) {
          try self.diagnostics.pushError(
            "Expected a type, got a {}.",
            .{ typ },
            type_expr.getStartLocation(),
            type_expr.getEndLocation()
          );

          return;
        }
      }


    }

    try self.resolveExpression(&cst.value);


    if( cst.value.getType() ) |typ| {
      var entry = self.identifiers.getEntry(id).?;

      cst.name.constantness = cst.value.getConstantness();
      cst.name.type = typ;

      entry.data = .{ .expression = .{
        .constantness = cst.name.constantness,
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
    .string, .integer => {},
    .identifier => |*id| try self.resolveIdentifier(id),
    .unary => |*una| try self.resolveUnaryExpression(una),
    .binary => |*bin| try self.resolveBinaryExpression(bin),
    .call => @panic("NYI"),
    .group => |*grp| try self.resolveExpression(grp.child),
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

        try self.diagnostics.pushVerbose(
          "Identifier without ID", .{}, false,
          id_expr.getStartLocation(),
          id_expr.getEndLocation()
        );
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

        try self.diagnostics.pushNote(
          "The left-hand side of the expression is of type '{}'.",
          .{ left_type }, false, 
          bin.left.getStartLocation(),
          bin.left.getEndLocation(),
        );

        try self.diagnostics.pushNote(
          "The right-hand side of the expression is of type '{}'.",
          .{ right_type }, false,
          bin.right.getStartLocation(),
          bin.right.getEndLocation(),
        );

      }
    } else {
      try self.diagnostics.pushVerbose(
        "No attached type.", .{}, false,
        bin.right.getStartLocation(), 
        bin.right.getEndLocation(),
      );
    }
  } else {
    try self.diagnostics.pushVerbose(
      "No attached type.", .{}, false,
      bin.left.getStartLocation(), 
      bin.left.getEndLocation(),
    );
  }
}



const resolveFns: TraverserFns = .{
  .visitIdentifierUsage = resolveIdentifierUsage,
  .exitUnaryExpression = resolveExitUnaryExpression,
};

fn resolveIdentifierUsage(
  self: *TypeResolver,
  id_node: *ast.IdentifierNode
) Error!void {
  const id = id_node.identifier_id orelse {
    if( self.debug )
      try self.diagnostics.pushVerbose(
        "[DBG] Identifier '{}' has no ID.",
        .{ id_node }, false,
        id_node.getStartLocation(), id_node.getEndLocation()
      );


    return;
  };
  const entry = self.identifiers.getEntry(id).?;
  const data = switch( entry.data ) {
    .expression => |dat| dat,
    else => {
      if( self.debug )
        try self.diagnostics.pushVerbose(
          "[DBG] Identifier '{}' has an ID but no expression data.",
          .{ id_node }, false,
          id_node.getStartLocation(), id_node.getEndLocation()
      );

      return;
    },
  };

  id_node.constantness = data.constantness;
  id_node.type = data.type;
}

fn resolveExitUnaryExpression(
  self: *TypeResolver,
  una_node: *ast.UnaryExpressionNode
) Error!void {
  una_node.constantness = una_node.child.getConstantness();

  const child_type = una_node.child.getType() orelse return;

  if( child_type.getUnaryOperationResultType(una_node.operator) ) |typ| {
    una_node.type = typ;
  } else {
    try self.diagnostics.pushError(
      "'{}' doesn't support the '{s}' unary operation.",
      .{ child_type, @tagName(una_node.operator) },
      una_node.getStartLocation(), una_node.getEndLocation()
    );

    self.errors += 1;
  }
}



const TraverserFns = trv.TraverserFns(*TypeResolver, Error, true);



pub const Error = error {
  invalid_ast_state,
} || IdentifierStorage.BindingError || Diagnostics.Error;
