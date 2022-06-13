
const std = @import("std");

const nl = @import("../nl.zig");
const ast = nl.ast;



pub fn traverseStatement(
  fns: anytype,
  traverser: @TypeOf(fns).Traverser,
  stmt: NodePtr(ast.StatementNode, !@TypeOf(fns).isMutator)
) @TypeOf(fns).Error!void {
  if( fns.enterStatement ) |f|
    try f(traverser, stmt);

  switch( stmt.* ) {
    .constant => |*cst| try traverseConstant(fns, traverser, cst),
  }

  if( fns.exitStatement ) |f|
    try f(traverser, stmt);
}

pub fn traverseConstant(
  fns: anytype,
  traverser: @TypeOf(fns).Traverser,
  cst: NodePtr(ast.ConstantNode, !@TypeOf(fns).isMutator)
) @TypeOf(fns).Error!void {
  if( fns.enterConstant ) |f|
    try f(traverser, cst);

  if( fns.visitIdentifier ) |f|
    try f(traverser, &cst.name);
  if( fns.visitIdentifierDefinition ) |f|
    try f(traverser, &cst.name);

  if( cst.type ) |*expr|
    try traverseExpression(fns, traverser, expr);

  try traverseExpression(fns, traverser, &cst.value);

  if( fns.exitConstant ) |f|
    try f(traverser, cst);
}



pub fn traverseExpression(
  fns: anytype,
  traverser: @TypeOf(fns).Traverser,
  expr: NodePtr(ast.ExpressionNode, !@TypeOf(fns).isMutator)
) @TypeOf(fns).Error!void {
  if( fns.enterExpression ) |f|
    try f(traverser, expr);

  switch( expr.* ) {
    .identifier => |*id| {
      if( fns.visitIdentifier ) |f|
        try f(traverser, id);
      if( fns.visitIdentifierUsage ) |f|
        try f(traverser, id);
    },
    .integer => |*int|
      if( fns.visitInteger ) |f|
        try f(traverser, int),
    .string => |*str|
      if( fns.visitString ) |f|
        try f(traverser, str),
    .binary => |*bin|
      try traverseBinaryExpression(fns, traverser, bin),
    .unary => |*una|
      try traverseUnaryExpression(fns, traverser, una),
    .call => |*call|
      try traverseCallExpression(fns, traverser, call),
    .group => |*grp|
      try traverseGroupExpression(fns, traverser, grp),
  }

  if( fns.exitExpression ) |f|
    try f(traverser, expr);
}

pub fn traverseBinaryExpression(
  fns: anytype,
  traverser: @TypeOf(fns).Traverser,
  bin: NodePtr(ast.BinaryExpressionNode, !@TypeOf(fns).isMutator)
) @TypeOf(fns).Error!void {
  if( fns.enterBinaryExpression ) |f|
    try f(traverser, bin);

  try traverseExpression(fns, traverser, bin.left);
  try traverseExpression(fns, traverser, bin.right);

  if( fns.exitBinaryExpression ) |f|
    try f(traverser, bin);
}

pub fn traverseUnaryExpression(
  fns: anytype,
  traverser: @TypeOf(fns).Traverser,
  una: NodePtr(ast.UnaryExpressionNode, !@TypeOf(fns).isMutator)
) @TypeOf(fns).Error!void {
  if( fns.enterUnaryExpression ) |f|
    try f(traverser, una);

  try traverseExpression(fns, traverser, una.child);

  if( fns.exitUnaryExpression ) |f|
    try f(traverser, una);
}

pub fn traverseCallExpression(
  fns: anytype,
  traverser: @TypeOf(fns).Traverser,
  call: NodePtr(ast.CallExpressionNode, !@TypeOf(fns).isMutator)
) @TypeOf(fns).Error!void {
  if( fns.enterCallExpression ) |f|
    try f(traverser, call);

  try traverseExpression(fns, traverser, call.function);

  for( call.arguments ) |*arg| {
    try traverseExpression(fns, traverser, arg);
  }

  if( fns.exitCallExpression ) |f|
    try f(traverser, call);
}

pub fn traverseGroupExpression(
  fns: anytype,
  traverser: @TypeOf(fns).Traverser,
  grp: NodePtr(ast.GroupExpressionNode, !@TypeOf(fns).isMutator)
) @TypeOf(fns).Error!void {
  if( fns.enterGroupExpression ) |f|
    try f(traverser, grp);

  try traverseExpression(fns, traverser, grp.child);

  if( fns.exitGroupExpression ) |f|
    try f(traverser, grp);
}



pub fn TraverserFns(
  comptime T: type,
  comptime E: type,
  comptime mutator: bool,
) type {
  return struct {
    enterStatement: ?TraverserFn(T, E, ast.StatementNode, mutator) = null,
    exitStatement: ?TraverserFn(T, E, ast.StatementNode, mutator) = null,
    enterConstant: ?TraverserFn(T, E, ast.ConstantNode, mutator) = null,
    exitConstant: ?TraverserFn(T, E, ast.ConstantNode, mutator) = null,

    enterExpression: ?TraverserFn(T, E, ast.ExpressionNode, mutator) = null,
    exitExpression: ?TraverserFn(T, E, ast.ExpressionNode, mutator) = null,
    enterBinaryExpression: ?TraverserFn(T, E, ast.BinaryExpressionNode, mutator) = null,
    exitBinaryExpression: ?TraverserFn(T, E, ast.BinaryExpressionNode, mutator) = null,
    enterUnaryExpression: ?TraverserFn(T, E, ast.UnaryExpressionNode, mutator) = null,
    exitUnaryExpression: ?TraverserFn(T, E, ast.UnaryExpressionNode, mutator) = null,
    enterCallExpression: ?TraverserFn(T, E, ast.CallExpressionNode, mutator) = null,
    exitCallExpression: ?TraverserFn(T, E, ast.CallExpressionNode, mutator) = null,
    enterGroupExpression: ?TraverserFn(T, E, ast.GroupExpressionNode, mutator) = null,
    exitGroupExpression: ?TraverserFn(T, E, ast.GroupExpressionNode, mutator) = null,

    visitIdentifier: ?TraverserFn(T, E, ast.IdentifierNode, mutator) = null,
    visitIdentifierDefinition: ?TraverserFn(T, E, ast.IdentifierNode, mutator) = null,
    visitIdentifierUsage: ?TraverserFn(T, E, ast.IdentifierNode, mutator) = null,
    visitInteger: ?TraverserFn(T, E, ast.IntegerNode, mutator) = null,
    visitString: ?TraverserFn(T, E, ast.StringNode, mutator) = null,

    const isTraverserFns = true;
    const isMutator = mutator;
    const Traverser = T;
    const Error = E;
  };
}



fn TraverserFn(
  comptime T: type,
  comptime E: type,
  comptime N: type,
  comptime mutator: bool,
) type {
  return fn(T, NodePtr(N, !mutator)) E!void;
}

fn NodePtr(
  comptime T: type,
  comptime constant: bool
) type {
  return if( constant )
    *const T
  else
    *T;
}