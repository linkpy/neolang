/// Structure used to resolves identifiers in the AST.
///

// TODO remove order dependence

const std = @import("std");

const nl = @import("../nl.zig");
const ast = nl.ast;
const Diagnostics = nl.diagnostic.Diagnostics;
const IdentifierStorage = nl.storage.Identifier;

const IdentifierResolver = @This();



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
) IdentifierResolver {
  return IdentifierResolver {
    .diagnostics = diags,
    .identifiers = ids,
    .errors = 0,
  };
}



/// Resolves the identifiers in a constant declaration.
///
pub fn resolveConstant(
  self: *IdentifierResolver,
  cst: *ast.ConstantNode,
  scope: *IdentifierStorage.Scope
) Error!void {
  var id: ?IdentifierStorage.IdentifierID = null;

  if( scope.hasBinding(cst.name.parts[0]) ) {
    try self.diagnostics.pushError(
      "The declaration of '{s}' overshadows a previous declaration.",
      .{ cst.name.parts[0] },
      cst.name.getStartLocation(),
      cst.name.getEndLocation(),
    );

    self.errors += 1;
  } else{
    var id_entry = try scope.bindEntry(cst.name.parts[0]);

    id_entry.start_location = cst.name.getStartLocation();
    id_entry.end_location = cst.name.getEndLocation();

    cst.name.identifier_id = id_entry.id;
    id_entry.is_being_defined = true;
    
    id = id_entry.id;
  }

  if( cst.type ) |*typ|
    try self.resolveExpression(typ, scope);
  
  try self.resolveExpression(&cst.value, scope);

  if( id ) |i| {
    var entry = self.identifiers.getEntry(i).?;
    entry.is_being_defined = false;
  }
}



/// Resolves the identifiers in an expression node.
///
pub fn resolveExpression(
  self: *IdentifierResolver,
  expr: *ast.ExpressionNode,
  scope: *IdentifierStorage.Scope
) Error!void {
  switch( expr.* ) {
    .integer, .string => {},
    .identifier => |*id| try self.resolveIdentifier(id, scope),
    .unary => |*una| try self.resolveExpression(una.child, scope),
    .binary => |*bin| {
      try self.resolveExpression(bin.left, scope);
      try self.resolveExpression(bin.right, scope);
    },
    .call => |*call| try self.resolveCallExpression(call, scope),
    .group => |*grp| try self.resolveExpression(grp.child, scope),
  }
}

/// Resolves the identifier in an identifier node.
///
pub fn resolveIdentifier(
  self: *IdentifierResolver,
  id_expr: *ast.IdentifierNode,
  scope: *IdentifierStorage.Scope
) Error!void {
  if( id_expr.isSegmented() ) {
    @panic("NYI");
  } else {

    if( scope.getBinding(id_expr.parts[0]) ) |id| {
      const entry = self.identifiers.getEntry(id).?;

      if( entry.is_being_defined ) {
        try self.diagnostics.pushError(
          "Invalid recursive use of '{s}'.",
          .{ id_expr.parts[0] },
          id_expr.getStartLocation(),
          id_expr.getEndLocation(),
        );

        try self.diagnostics.pushNote(
          "Recursive declaration of this:",
          .{}, false,
          entry.start_location, 
          entry.end_location
        );
      } else {
        id_expr.identifier_id = id;
      }
    } else {
      try self.diagnostics.pushError(
        "Usage of undeclared identifier '{s}'.",
        .{ id_expr.parts[0] },
        id_expr.getStartLocation(),
        id_expr.getEndLocation(),
      );

      self.errors += 1;
    }

  }
}

/// Resolves the identifiers in a function call expression node.
///
pub fn resolveCallExpression(
  self: *IdentifierResolver,
  call: *ast.CallExpressionNode,
  scope: *IdentifierStorage.Scope
) Error!void {
  try self.resolveExpression(call.function, scope);

  for( call.arguments ) |*argument| {
    try self.resolveExpression(argument, scope);
  }
}



pub const Error = IdentifierStorage.BindingError || Diagnostics.Error;