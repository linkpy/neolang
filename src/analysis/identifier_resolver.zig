/// Structure used to resolves identifiers in the AST.
///

// TODO remove order dependence

const std = @import("std");

const nl = @import("../nl.zig");
const ast = nl.ast;
const Diagnostics = nl.diagnostic.Diagnostics;
const IdentifierStorage = nl.storage.Identifier;
const Scope = IdentifierStorage.Scope;

const IdNodeList = std.ArrayList(*ast.IdentifierNode);

const IdentifierResolver = @This();



alloc: std.mem.Allocator,
/// Diagnostics used in case of error.
diagnostics: *Diagnostics,
/// Registered identifiers.
identifiers: *IdentifierStorage,

/// Number of errors detected.
errors: usize = 0,
/// List of unresolved identifiers in the current scope.
unresolved: IdNodeList,



/// Initialises a new instance.
///
pub fn init(
  alloc: std.mem.Allocator,
  diags: *Diagnostics,
  ids: *IdentifierStorage
) IdentifierResolver {
  return IdentifierResolver {
    .alloc = alloc,
    .diagnostics = diags,
    .identifiers = ids,
    .unresolved = IdNodeList.init(alloc),
  };
}



/// Resolves all of the identifiers in a file
///
pub fn processFile(
  self: *IdentifierResolver,
  stmts: []ast.StatementNode
) Error!bool {
  self.errors = 0;

  self.unresolved = IdNodeList.init(self.alloc);
  defer self.unresolved.deinit();

  var root_scope = self.identifiers.scope();
  defer root_scope.deinit();

  try root_scope.bindBuiltins();

  // initial pass to register all identifier definitions
  for( stmts ) |*stmt| {
    try self.resolveStatement(stmt, &root_scope);
  }


  var unresolved = self.unresolved.toOwnedSlice();
  defer self.alloc.free(unresolved);

  // try to resolve all of the previously unresolved identifiers due to their
  // definition being after their usage
  for( unresolved ) |id_node| {
    try self.resolveIdentifier(id_node, &root_scope);
  }


  // if they are still unresolved identifiers, they are errors.
  for( self.unresolved.items ) |id_node| {
    try self.diagnostics.pushError(
      "Usage of undefined identifier '{s}'.", .{ id_node.name },
      id_node.getStartLocation(), id_node.getEndLocation(),
    );

    self.errors += 1;
  }


  return self.errors == 0;
}



/// Resolves the identifiers within the given statement.
///
fn resolveStatement(
  self: *IdentifierResolver,
  stmt: *ast.StatementNode,
  scope: *Scope,
) Error!void {
  switch( stmt.* ) {
    .constant => |*cst| try self.resolveConstant(cst, scope),
    .function => @panic("NYI"), // TODO
  }
}

/// Resolves identifiers within the given constant node.
///
fn resolveConstant(
  self: *IdentifierResolver,
  cst: *ast.ConstantNode,
  scope: *Scope,
) Error!void {
  const name = cst.name.name;

  if( scope.hasBinding(name) ) {
    try self.diagnostics.pushError(
      "Declaration of '{s}' overshadows a previous declaration.",
      .{ name },
      cst.name.getStartLocation(), cst.name.getEndLocation()
    );

    // TODO add diagnostic showing previous decl

    self.errors += 1;

  } else {

    var entry = try scope.bindEntry(name);
    entry.start_location = cst.name.getStartLocation();
    entry.end_location = cst.name.getEndLocation();

    cst.name.identifier_id = entry.id;
  }

  if( cst.type ) |*type_expr|
    try self.resolveExpression(type_expr, scope);

  try self.resolveExpression(&cst.value, scope);
}



/// Resolves the identifiers within the given expression.
///
fn resolveExpression(
  self: *IdentifierResolver,
  expr: *ast.ExpressionNode,
  scope: *Scope
) Error!void {
  switch( expr.* ) {
    .identifier => |*id| try self.resolveIdentifier(id, scope),
    .integer,
    .string => {},
    .binary => |*bin| {
      try self.resolveExpression(bin.left, scope);
      try self.resolveExpression(bin.right, scope);
    },
    .unary => |*una| try self.resolveExpression(una.child, scope),
    .call => @panic("NYI"),
    .group => |*grp| try self.resolveExpression(grp.child, scope),
    .field => @panic("NYI"),
  }
}

/// Resolves the given identifier.
///
fn resolveIdentifier(
  self: *IdentifierResolver,
  id_node: *ast.IdentifierNode,
  scope: *Scope
) Error!void {
  const name = id_node.name;

  if( scope.getBinding(name) ) |id| {
    id_node.identifier_id = id;

  } else {
    try self.unresolved.append(id_node);
  }
}



pub const Error = IdentifierStorage.BindingError || Diagnostics.Error;
