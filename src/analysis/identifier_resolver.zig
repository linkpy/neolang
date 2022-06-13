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

/// Number of identifier resolved.
resolved: usize = 0,
/// Number of identifier unresolved.
unresolved: usize = 0,
/// Number of errors detected.
errors: usize = 0,



/// Initialises a new instance.
///
pub fn init(
  diags: *Diagnostics,
  ids: *IdentifierStorage
) IdentifierResolver {
  return IdentifierResolver {
    .diagnostics = diags,
    .identifiers = ids,
  };
}



pub fn resolveFile(
  self: *IdentifierResolver,
  stmts: []ast.StatementNode,
) Error!bool {
  var scope = self.identifiers.scope();
  defer scope.deinit();

  try scope.bindBuiltins();

  self.resolved = 0;
  self.unresolved = 0;

  var last_resolved: usize = 0;
  var last_unresolved: usize = 0;

  while( true ) {
    for( stmts ) |*stmt| {
      try self.resolveStatement(stmt, &scope, false);
    }

    // stalemate
    if( self.resolved == last_resolved and self.unresolved == last_unresolved ) {
      // nothing in the file
      if( self.resolved == 0 and self.unresolved == 0 )
        return true
      else {
        for( stmts ) |*stmt| {
          try self.resolveStatement(stmt, &scope, true);
        }

        return self.unresolved == 0 and self.errors == 0;
      }
    }

    last_resolved = self.resolved;
    last_unresolved = self.unresolved;
  }
}



/// Resolves the identifiers in a statement node.
///
pub fn resolveStatement(
  self: *IdentifierResolver,
  stmt: *ast.StatementNode,
  scope: *IdentifierStorage.Scope,
  add_diags: bool
) Error!void {
  switch( stmt.* ) {
    .constant => |*cst| try self.resolveConstant(cst, scope, add_diags),
  }
}

/// Resolves the identifiers in a constant declaration.
///
pub fn resolveConstant(
  self: *IdentifierResolver,
  cst: *ast.ConstantNode,
  scope: *IdentifierStorage.Scope,
  add_diags: bool,
) Error!void {
  var id: ?IdentifierStorage.IdentifierID = null;

  if( !cst.name.id_resolver_md.resolved ) {
    if( scope.hasBinding(cst.name.parts[0]) ) {

      if( add_diags ) {
        try self.diagnostics.pushError(
          "The declaration of '{s}' overshadows a previous declaration.",
          .{ cst.name.parts[0] },
          cst.name.getStartLocation(),
          cst.name.getEndLocation(),
        );
      }

      if( !cst.name.id_resolver_md.errored ) {
        cst.name.id_resolver_md.errored = true;
        self.errors += 1;
      }

    } else {
      var id_entry = try scope.bindEntry(cst.name.parts[0]);

      id_entry.start_location = cst.name.getStartLocation();
      id_entry.end_location = cst.name.getEndLocation();

      cst.name.identifier_id = id_entry.id;
      id_entry.is_being_defined = true;
      
      id = id_entry.id;

      cst.name.id_resolver_md.resolved = true;
    }
  }

  if( cst.type ) |*typ|
    try self.resolveExpression(typ, scope, add_diags);
  
  try self.resolveExpression(&cst.value, scope, add_diags);

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
  scope: *IdentifierStorage.Scope,
  add_diags: bool,
) Error!void {
  switch( expr.* ) {
    .integer, .string => {},
    .identifier => |*id| try self.resolveIdentifier(id, scope, add_diags),
    .unary => |*una| try self.resolveExpression(una.child, scope, add_diags),
    .binary => |*bin| {
      try self.resolveExpression(bin.left, scope, add_diags);
      try self.resolveExpression(bin.right, scope, add_diags);
    },
    .call => |*call| try self.resolveCallExpression(call, scope, add_diags),
    .group => |*grp| try self.resolveExpression(grp.child, scope, add_diags),
  }
}

/// Resolves the identifier in an identifier node.
///
pub fn resolveIdentifier(
  self: *IdentifierResolver,
  id_expr: *ast.IdentifierNode,
  scope: *IdentifierStorage.Scope,
  add_diags: bool,
) Error!void {
  if( id_expr.isSegmented() ) {
    @panic("NYI");

  } else {

    if( !id_expr.id_resolver_md.resolved ) {

      if( scope.getBinding(id_expr.parts[0]) ) |id| {
        const entry = self.identifiers.getEntry(id).?;

        if( entry.is_being_defined ) {
          if( add_diags ) {
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
          }

          if( !id_expr.id_resolver_md.errored ) {
            id_expr.id_resolver_md.errored = true;
            self.errors += 1;
          }

        } else {

          id_expr.identifier_id = id;
          id_expr.id_resolver_md.resolved = true;

          self.resolved += 1;

          if( id_expr.id_resolver_md.unresolved ) {
            id_expr.id_resolver_md.unresolved = false;
            self.unresolved -= 1;
          }
        }

      } else {

        if( add_diags ) {
          try self.diagnostics.pushError(
            "Usage of undeclared identifier '{s}'.",
            .{ id_expr.parts[0] },
            id_expr.getStartLocation(),
            id_expr.getEndLocation(),
          );
        }

        if( !id_expr.id_resolver_md.unresolved ) {
          id_expr.id_resolver_md.unresolved = true;
          self.unresolved += 1;
        }

      }
    }
  }
}

/// Resolves the identifiers in a function call expression node.
///
pub fn resolveCallExpression(
  self: *IdentifierResolver,
  call: *ast.CallExpressionNode,
  scope: *IdentifierStorage.Scope,
  add_diags: bool,
) Error!void {
  try self.resolveExpression(call.function, scope, add_diags);

  for( call.arguments ) |*argument| {
    try self.resolveExpression(argument, scope, add_diags);
  }
}



pub const Error = IdentifierStorage.BindingError || Diagnostics.Error;
