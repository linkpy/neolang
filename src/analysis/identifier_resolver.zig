/// Structure used to resolves identifiers in the AST.
///

// TODO remove order dependence

const std = @import("std");

const nl = @import("../nl.zig");
const ast = nl.ast;
const trv = nl.ast.traverser;
const Diagnostics = nl.diagnostic.Diagnostics;
const IdentifierStorage = nl.storage.Identifier;
const Scope = IdentifierStorage.Scope;

const IdentifierResolver = @This();



/// Diagnostics used in case of error.
diagnostics: *Diagnostics,
/// Registered identifiers.
identifiers: *IdentifierStorage,

/// Scopes.
scopes: std.ArrayList(Scope),
/// Number of errors detected.
errors: usize = 0,



/// Initialises a new instance.
///
pub fn init(
  alloc: std.mem.Allocator,
  diags: *Diagnostics,
  ids: *IdentifierStorage
) IdentifierResolver {
  return IdentifierResolver {
    .diagnostics = diags,
    .identifiers = ids,
    .scopes = std.ArrayList(Scope).init(alloc)
  };
}

pub fn deinit(
  self: *IdentifierResolver
) void {
  for( self.scopes.items ) |*i| i.deinit();
  self.scopes.deinit();
}


/// Resolves all of the identifiers in a file
///
pub fn processFile(
  self: *IdentifierResolver,
  stmts: []ast.StatementNode
) Error!bool {
  self.errors = 0;

  var root_scope = self.identifiers.scope();
  try root_scope.bindBuiltins();

  try self.scopes.append(root_scope);


  defer {
    for( self.scopes.items ) |*scope| scope.deinit();
    self.scopes.clearAndFree();
  }

  try self.scoutFile(stmts);

  if( self.errors > 0 )
    return false;

  root_scope.clearBindings();
  try root_scope.bindBuiltins();

  try self.resolveFile(stmts);

  return self.errors == 0;
}



fn scoutFile(
  self: *IdentifierResolver,
  stmts: []ast.StatementNode
) Error!void {
  for( stmts ) |*stmt| {
    try trv.traverseStatement(scoutFns, self, stmt);
  }
}

const scoutFns: TraverserFns = .{
  .enterFunctionScope = enterFunctionScope,
  .exitFunction = exitFunction,
  .visitIdentifierDefinition = scoutIdentifierDefinition,
};

fn scoutIdentifierDefinition(
  self: *IdentifierResolver,
  id: *ast.IdentifierNode
) Error!void {
  var scope = &self.scopes.items[self.scopes.items.len - 1];

  if( scope.hasBinding(id.name) ) {
    try self.diagnostics.pushError(
      "Declaration of '{s}' overshadows a previous declaration.",
      .{ id.name },
      id.getStartLocation(), id.getEndLocation()
    );

    self.errors += 1;

  } else {
    var entry = try scope.bindEntry(id.name);
    entry.start_location = id.getStartLocation();
    entry.end_location = id.getEndLocation();

    id.identifier_id = entry.id;
  }
}



fn resolveFile(
  self: *IdentifierResolver,
  stmts: []ast.StatementNode
) Error!void {
  for( stmts ) |*stmt| {
    try trv.traverseStatement(resolveFns, self, stmt);
  }
}

const resolveFns: TraverserFns = .{
  .enterFunctionScope = enterFunctionScope,
  .exitFunction = exitFunction,
  .enterConstant = resolveEnterConstant,
  .exitConstant = resolveExitConstant,
  .visitIdentifierDefinition = resolveIdentifierDefinition,
  .visitIdentifierUsage = resolveIdentifierUsage,
};

fn resolveEnterConstant(
  self: *IdentifierResolver,
  cst: *ast.ConstantNode
) Error!void {
  if( cst.name.identifier_id ) |id| {
    var entry = self.identifiers.getEntry(id).?;

    entry.is_being_defined = true;
  }
}

fn resolveExitConstant(
  self: *IdentifierResolver,
  cst: *ast.ConstantNode
) Error!void {
  if( cst.name.identifier_id ) |id| {
    var entry = self.identifiers.getEntry(id).?;

    entry.is_being_defined = false;
  }
}

fn resolveIdentifierDefinition(
  self: *IdentifierResolver,
  id_node: *ast.IdentifierNode
) Error!void {
  var scope: *Scope = &self.scopes.items[self.scopes.items.len - 1];

  if( id_node.identifier_id ) |id| {
    try scope.bindWith(id_node.name, id);
  }
}

fn resolveIdentifierUsage(
  self: *IdentifierResolver,
  id_node: *ast.IdentifierNode
) Error!void {
  var scope = &self.scopes.items[self.scopes.items.len - 1];

  if( scope.getBinding(id_node.name) ) |id| {
    const entry = self.identifiers.getEntry(id).?;

    if( entry.is_being_defined ) {
      try self.diagnostics.pushError(
        "Invalid recursive use of '{s}'.", .{ id_node.name },
        id_node.getStartLocation(), id_node.getEndLocation()
      );

      try self.diagnostics.pushNote(
        "Recursive declaration of this:", .{}, false,
        entry.start_location, entry.end_location
      );

      self.errors += 1;

    } else {

      id_node.identifier_id = id;
    }

  } else {

    try self.diagnostics.pushError(
      "Usage of undeclared identifier '{s}'.", .{ id_node.name },
      id_node.getStartLocation(), id_node.getEndLocation()
    );

    self.errors += 1;
  }
}



fn enterFunctionScope(
  self: *IdentifierResolver,
  fun: *ast.FunctionNode
) Error!void {
  _ = fun;

  var parent_scope: *Scope = &self.scopes.items[self.scopes.items.len - 1];
  var scope = parent_scope.scope();

  try self.scopes.append(scope);
}

fn exitFunction(
  self: *IdentifierResolver,
  fun: *ast.FunctionNode
) Error!void {
  _ = fun;

  var scope = self.scopes.pop();
  scope.deinit();
}



const TraverserFns = trv.TraverserFns(*IdentifierResolver, Error, true);



pub const Error = IdentifierStorage.BindingError || Diagnostics.Error;
