/// Structure resolving type information in the AST.
///

// TODO check that integer fits their type

const std = @import("std");

const nl = @import("../nl.zig");
const ast = nl.ast;
const Diagnostics = nl.diagnostic.Diagnostics;
const IdentifierStorage = nl.storage.Identifier;
const Type = nl.types.Type;
const Evaluator = nl.vm.Evaluator;
const Variant = nl.vm.Variant;

const TypeResolver = @This();



/// Diagnostics used in case of error.
diagnostics: *Diagnostics,
/// Registered identifiers.
identifiers: *IdentifierStorage,
/// Evaluator used for type expressions.
evaluator: Evaluator,

/// Number of unresolved types.
unresolved: usize,
/// Number of error that occured during resolving.
errors: usize,



/// Initialises a new instance.
///
pub fn init(
  alloc: std.mem.Allocator,
  diags: *Diagnostics,
  ids: *IdentifierStorage
) TypeResolver {
  return TypeResolver {
    .diagnostics = diags,
    .identifiers = ids,
    .evaluator = Evaluator.init(alloc, diags, ids),
    .unresolved = 0,
    .errors = 0,
  };
}



/// Resolves all of the given statements. They are considered to be part of the
/// root scope.
///
pub fn processFile(
  self: *TypeResolver,
  stmts: []ast.StatementNode
) Error!bool {
  var last_unresolved: usize = std.math.maxInt(usize);

  while( last_unresolved != 0 ) {
    self.unresolved = 0;

    for( stmts ) |*stmt| {
      try self.resolveStatement(stmt);
    }

    // the number of unresolved types should only decrease with each passes
    if( self.unresolved >= last_unresolved ) {
      @panic("may god have mercy on us. boot up lldb :c");
    }

    last_unresolved = self.unresolved;
  }

  return self.errors == 0;
}



/// Resolves the types within the given statement.
///
fn resolveStatement(
  self: *TypeResolver,
  stmt: *ast.StatementNode
) Error!void {
  const res = switch( stmt.* ) {
    .constant => |*cst| self.resolveConstant(cst),
    .function => |*fun| self.resolveFunction(fun),
  };

  res catch |err| {
    if( err == error.unresolved_type )
      self.unresolved += 1
    else
      return err;
  };
}

/// Resolves the constant's types.
///
fn resolveConstant(
  self: *TypeResolver,
  cst: *ast.ConstantNode
) Error!void {
  // if the statement was already resolved
  if( cst.name.getType() != null )
    return;


  var target_type: ?Type = null;


  if( cst.type ) |*type_expr| {
    (try self.resolveExpression(type_expr)) orelse return;
    const eval_res =
      try self.evaluator.evaluateExpression(type_expr, Type.TypeT);

    target_type = eval_res.type;
  }

  (try self.resolveExpression(&cst.value)) orelse return;
  const value_type = cst.value.getType().?;

  if( target_type != null and !value_type.canBeCoercedTo(target_type.?) ) {

    // TODO avoid adding duplicate diagnostics
    try self.diagnostics.pushError(
      "'{}' cannot be coerced to '{}'",
      .{ value_type, target_type.? },
      cst.value.getStartLocation(), cst.value.getEndLocation(),
    );

    self.errors += 1;
    return;
  }

  if( cst.value.getConstantness() != .constant ) {
    // TODO avoid adding duplicate diagnostics
    try self.diagnostics.pushError(
      "Only constant expressions are allowed as values for constants.", .{},
      cst.value.getStartLocation(), cst.value.getEndLocation()
    );

    self.errors += 1;
    return;
  }

  const name_id = cst.name.identifier_id orelse return;
  var entry = self.identifiers.getEntry(name_id).?;
  const value = try self.evaluator.evaluateExpression(&cst.value, target_type);

  cst.name.constantness = .constant;
  cst.name.type = target_type orelse value_type;
  cst.name.value = value;

  entry.expr.constantness = .constant;
  entry.expr.type = target_type orelse value_type;
  entry.expr.value = value;
}

/// Resolves the function's type and then resolves its body's statements.
///
fn resolveFunction(
  self: *TypeResolver,
  fun: *ast.FunctionNode
) Error!void {
  _ = self;
  _ = fun;
  @panic("NYI"); // TODO
}



/// Resolves the type of the given expression.
///
fn resolveExpression(
  self: *TypeResolver,
  expr: *ast.ExpressionNode,
) Error!?void {
  if( expr.getType() != null ) {
    return {};
  }

  return switch( expr.* ) {
    // should never match integers or strings as they always have a type.
    .integer, .string => unreachable,
    .identifier => |*id| try self.resolveIdentifier(id),
    .binary => |*bin| try self.resolveBinaryExpression(bin),
    .unary => |*una| try self.resolveUnaryExpression(una),
    .call => @panic("NYI"),
    .group => @panic("NYI"),
    .field => @panic("NYI"),
  };
}

/// Resolves the type of the given identifier.
///
fn resolveIdentifier(
  self: *TypeResolver,
  ident: *ast.IdentifierNode,
) Error!?void {
  // resolveExpression already checks if the node is resolved

  const id = ident.identifier_id orelse return null;
  const entry = self.identifiers.getEntry(id).?;

  // if the definition of this indentifier was resolved
  if( entry.expr.type ) |id_type| {
    ident.constantness = entry.expr.constantness;
    ident.type = id_type;

    return {};

  } else {

    self.unresolved += 1;
    return null;
  }
}

/// Resolves the type of the given unary expression.
///
fn resolveUnaryExpression(
  self: *TypeResolver,
  una: *ast.UnaryExpressionNode,
) Error!?void {
  // resolveExpression already checks if the node is resolved

  (try self.resolveExpression(una.child)) orelse return null;

  const child_type = una.child.getType() orelse unreachable;

  if( child_type.getUnaryOperationResultType(una.operator) ) |res_type| {
    una.constantness = una.child.getConstantness();
    una.type = res_type;

    return {};

  } else {

    // TODO add a thing to avoid duplicated diagnostics
    try self.diagnostics.pushError(
      "Type '{}' doesn't support the unary operation '{s}'.",
      .{ child_type, @tagName(una.operator) },
      una.getStartLocation(), una.getEndLocation(),
    );

    self.errors += 1;
    return null;
  }
}

/// Resolves the type of the given binary expression.
///
fn resolveBinaryExpression(
  self: *TypeResolver,
  bin: *ast.BinaryExpressionNode
) Error!?void {
  // resolveExpression already checks if the node is resolved

  (try self.resolveExpression(bin.left)) orelse return null;
  (try self.resolveExpression(bin.right)) orelse return null;

  const lhs_type = bin.left.getType() orelse unreachable;
  const rhs_type = bin.right.getType() orelse unreachable;

  if( lhs_type.getBinaryOperationResultType(bin.operator, rhs_type) ) |res_type| {
    const left_cstness = bin.left.getConstantness();
    const right_cstness = bin.right.getConstantness();

    bin.constantness = left_cstness.mix(right_cstness);
    bin.type = res_type;

    return {};

  } else {

    // TODO avoid adding duplicate diagnostics
    try self.diagnostics.pushError(
      "'{}' and '{}' cannot be coerced together",
      .{ lhs_type, rhs_type },
      bin.getStartLocation(), bin.getEndLocation()
    );

    self.errors += 1;
    return null;
  }
}



pub const Error = error {
  invalid_ast_state,

  unresolved_type,
} || Evaluator.Error || IdentifierStorage.BindingError || Diagnostics.Error;
