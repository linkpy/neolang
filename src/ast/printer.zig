
const std = @import("std");


const nl = @import("../nl.zig");
const ast = nl.ast;



/// Prints the AST of the given statement node.
///
pub fn printStatementNode(
  writer: anytype,
  stmt: *const ast.StatementNode,
  indent: usize,
  show_metadata: bool
) !void {
  switch( stmt.* ) {
    .constant => |*cst|
      try printConstantNode( writer, cst, indent, show_metadata ),
    .function => |*fun|
      try printFunctionNode( writer, fun, indent, show_metadata ),
  }
}

/// Prints the AST of the given constant node.
///
pub fn printConstantNode(
  writer: anytype,
  cst: *const ast.ConstantNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "{s}+ ConstantNode{s}\n", .{
    node_style, reset
  });

  if( show_metadata )
    try printWithIndent(
      writer, indent, "{s}  Metadata: <no metadata to show>{s}\n",
      .{ meta_style, reset }
    );

  try printWithIndent(writer, indent, "  Name:\n", .{});
  try printIdentifierNode(writer, &cst.name, indent+2, show_metadata);

  if( cst.type ) |typ| {
    try printWithIndent(writer, indent, "  Type:\n", .{});
    try printExpressionNode(writer, &typ, indent+2, show_metadata);
  } else {
    try printWithIndent(writer, indent, "  Type: <inferred>\n", .{});
  }

  try printWithIndent(writer, indent, "  Value:\n", .{});
  try printExpressionNode(writer, &cst.value, indent+2, show_metadata);
}

/// Prints the AST of the given function node.
///
pub fn printFunctionNode(
  writer: anytype,
  fun: *const ast.FunctionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "{s}+ FunctionNode{s}\n", .{
    node_style, reset
  });

  if( show_metadata ) {
    try printWithIndent(writer, indent, "{s}  Metadata:\n", .{ meta_style });
    try printWithIndent(writer, indent+2, "- Recursive? {}\n", .{
      fun.metadata.is_recursive
    });
    try printWithIndent(writer, indent+2, "- Entry point? {}{s}\n", .{
      fun.metadata.is_entry_point, reset
    });
  }

  try printWithIndent(writer, indent, "  Name:\n", .{});
  try printIdentifierNode(writer, &fun.name, indent+2, show_metadata);

  if( fun.return_type ) |*expr| {
    try printWithIndent(writer, indent, "  Return type:\n", .{});
    try printExpressionNode(writer, expr, indent+2, show_metadata);
  } else {
    try printWithIndent(writer, indent, "  Return type: <none>\n", .{});
  }

  if( fun.arguments.len == 0 ) {
    try printWithIndent(writer, indent, "  Arguments: <none>\n", .{});
  } else {
    try printWithIndent(writer, indent, "  Arguments:\n", .{});

    for( fun.arguments ) |*arg| {
      // TODO write a printArgumentNode
      try printWithIndent(writer, indent+2, "{s}+ ArgumentNode{s}\n", .{
        node_style, reset
      });
      try printWithIndent(writer, indent+2, "  Name:\n", .{});
      try printIdentifierNode(writer, &arg.name, indent+4, show_metadata);
      try printWithIndent(writer, indent+2, "  Type:\n", .{});
      try printExpressionNode(writer, &arg.type, indent+4, show_metadata);
    }
  }

  if( fun.body.len == 0 ) {
    try printWithIndent(writer, indent, "  Body: <empty>\n", .{});
  } else {
    try printWithIndent(writer, indent, "  Body:\n", .{});

    for( fun.body ) |*stmt| {
      try printStatementNode(writer, stmt, indent+2, show_metadata);
    }
  }
}



/// Prints the AST of the given expression node.
///
pub fn printExpressionNode(
  writer: anytype,
  expr: *const ast.ExpressionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  switch( expr.* ) {
    .identifier => |*id|
      try printIdentifierNode( writer, id, indent, show_metadata ),
    .integer => |*int|
      try printIntegerNode(writer, int, indent, show_metadata),
    .string => |*str|
      try printStringNode(writer, str, indent, show_metadata),
    .binary => |*bin|
      try printBinaryExpressionNode(writer, bin, indent, show_metadata),
    .unary => |*una|
      try printUnaryExpressionNode(writer, una, indent, show_metadata),
    .call => |*call|
      try printCallExpressionNode(writer, call, indent, show_metadata),
    .group => |*grp|
      try printGroupExpressionNode(writer, grp, indent, show_metadata),
    .field => |*fa|
      try printFieldAccessNode(writer, fa, indent, show_metadata),
  }
}

/// Prints the AST of the given identifier node.
///
pub fn printIdentifierNode(
  writer: anytype,
  id: *const ast.IdentifierNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "{s}+ IdentifierNode: {s}{s}\n", .{
    node_style, id.name, reset
  });

  if( show_metadata ) {
    try printWithIndent(writer, indent, "{s}  Metadata:\n", .{ meta_style });
    try printWithIndent(writer, indent+2, "- ID: {}\n", .{ id.identifier_id });
    try printWithIndent(writer, indent+2, "- Constantness: {s}\n", .{
      @tagName( id.constantness )
    });
    try printWithIndent(writer, indent+2, "- Type: {}{s}\n", .{
      id.type, reset
    });
  }
}

/// Prints the AST of the given integer node.
///
pub fn printIntegerNode(
  writer: anytype,
  int: *const ast.IntegerNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "{s}+ IntegerNode: {} ({s}){s}\n", .{
    node_style, int.value, @tagName(int.type_flag), reset
  });

  if( show_metadata ) {
    try printWithIndent(
      writer, indent, "{s}  Metadata: <no metadata to show>{s}\n",
      .{ meta_style, reset }
    );
  }
}

/// Prints the AST of the given string node.
///
pub fn printStringNode(
  writer: anytype,
  str: *const ast.StringNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "{s}+ StringNode: \"{s}\"{s}\n", .{
    node_style, str.value, reset
  });

  if( show_metadata )
    try printWithIndent(
      writer, indent, "{s}  Metadata: <no metadata to show>{s}\n", .{
        meta_style, reset
    });
}

/// Prints the AST of the given binary expression node.
///
pub fn printBinaryExpressionNode(
  writer: anytype,
  bin: *const ast.BinaryExpressionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(
    writer, indent, "{s}+ BinaryExpressionNode: {s}{s}\n",
    .{ node_style, @tagName(bin.operator), reset }
  );

  if( show_metadata ) {
    try printWithIndent(writer, indent, "{s}  Metadata:\n", .{ meta_style });
    try printWithIndent(writer, indent+2, "- Constantness: {s}\n", .{
      @tagName( bin.constantness )
    });
    try printWithIndent(writer, indent+2, "- Type: {}{s}\n", .{
      bin.type, reset
    });
  }
  
  try printWithIndent(writer, indent, "  Left-hand side:\n", .{ });
  try printExpressionNode(writer, bin.left, indent+2, show_metadata);

  try printWithIndent(writer, indent, "  Right-hand side:\n", .{ });
  try printExpressionNode(writer, bin.right, indent+2, show_metadata);

}

/// Prints the AST of the given unary expression node.
///
pub fn printUnaryExpressionNode(
  writer: anytype,
  una: *const ast.UnaryExpressionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "{s}+ UnaryExpressionNode: {s}{s}\n", .{
    node_style, @tagName(una.operator), reset
  });

  if( show_metadata ) {
    try printWithIndent(writer, indent, "{s}  Metadata:\n", .{ meta_style });
    try printWithIndent(writer, indent+2, "- Constantness: {s}\n", .{
      @tagName( una.constantness )
    });
    try printWithIndent(writer, indent+2, "- Type: {}{s}\n", .{
      una.type, reset
    });
  }

  try printWithIndent(writer, indent, "  Child:\n", .{});
  try printExpressionNode(writer, una.child, indent+2, show_metadata);

}

/// Prints the AST of the given call expression node.
///
pub fn printCallExpressionNode(
  writer: anytype,
  call: *const ast.CallExpressionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "{s}+ CallExpressionNode{s}\n", .{
    node_style, reset
  });

  if( show_metadata )
    try printWithIndent(
      writer, indent, "{s}  Metadata: <no metadata to show>{s}\n",
      .{ meta_style, reset }
    );


  if( call.arguments.len > 0 ) {
    try printWithIndent(writer, indent, "  Argument(s):\n", .{});

    for( call.arguments ) |*arg|
      try printExpressionNode(writer, arg, indent+2, show_metadata);
  } else {
    try printWithIndent(writer, indent, "  Argument(s): <no arguments>\n", .{});
  }
}

/// Prints the AST of the given group node.
///
pub fn printGroupExpressionNode(
  writer: anytype,
  grp: *const ast.GroupExpressionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "{s}+ GroupExpressionNode{s}\n", .{
    node_style, reset
  });

  if( show_metadata )
    try printWithIndent(
      writer, indent, "{s}  Metadata: <no metadata to show>{s}\n",
      .{ meta_style, reset }
    );


  try printWithIndent(writer, indent, "  Child:\n", .{});
  try printExpressionNode(writer, grp.child, indent+2, show_metadata);
}

/// Prints the AST of the given field access node.
///
pub fn printFieldAccessNode(
  writer: anytype,
  fa: *const ast.FieldAccessNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "{s}+ FieldAccessNode{s}\n", .{
    node_style, reset
  });

  if( show_metadata ) {
    try printWithIndent(writer, indent, "{s}  Metadata:\n", .{ meta_style });
    try printWithIndent(writer, indent+2, "- Constantness: {s}\n", .{
      @tagName(fa.getConstantness())
    });
    try printWithIndent(writer, indent+2, "- Type: {}{s}\n", .{
      fa.getType(), reset
    });
  }

  try printWithIndent(writer, indent, "  Storage:\n", .{});
  try printExpressionNode(writer, fa.storage, indent+2, show_metadata);

  try printWithIndent(writer, indent, "  Field:\n", .{});
  try printIdentifierNode(writer, &fa.field, indent+2, show_metadata);
}



/// Prints a formated string with the given indent.
///
fn printWithIndent(
  writer: anytype,
  indent: usize,
  comptime fmt: []const u8,
  args: anytype,
) @TypeOf(writer).Error!void {
  try writer.writeByteNTimes(' ', indent);
  try writer.print(fmt, args);
}


const reset = "\x1b[0m";
const node_style = "\x1b[1;35m";
const meta_style = "\x1b[2;34m";
