
const std = @import("std");


const nl = @import("../nl.zig");
const ast = nl.ast;



pub fn printStatementNode(
  writer: anytype,
  stmt: *const ast.ConstantNode, // TODO use statement union,
  indent: usize,
  show_metadata: bool
) !void {
  try printConstantNode(writer, stmt, indent, show_metadata);
}



pub fn printConstantNode(
  writer: anytype,
  cst: *const ast.ConstantNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "+ ConstantNode\n", .{});

  if( show_metadata ) {
    try printWithIndent(writer, indent, "- Metadata: <no metadata to show>\n", .{});
  }

  try printWithIndent(writer, indent, "- Name:\n", .{});
  try printIdentifierNode(writer, &cst.name, indent+2, show_metadata);

  if( cst.type ) |typ| {
    try printWithIndent(writer, indent, "- Type:\n", .{});
    try printExpressionNode(writer, &typ, indent+2, show_metadata);
  } else {
    try printWithIndent(writer, indent, "- Type: <inferred>\n", .{});
  }

  try printWithIndent(writer, indent, "- Value:\n", .{});
  try printExpressionNode(writer, &cst.value, indent+2, show_metadata);

}



pub fn printExpressionNode(
  writer: anytype,
  expr: *const ast.ExpressionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  switch( expr.* ) {
    .identifier => |*id| try printIdentifierNode(writer, id, indent, show_metadata),
    .integer => |*int| try printIntegerNode(writer, int, indent, show_metadata),
    .string => |*str| try printStringNode(writer, str, indent, show_metadata),
    .binary => |*bin| try printBinaryExpressionNode(writer, bin, indent, show_metadata),
    .unary => |*una| try printUnaryExpressionNode(writer, una, indent, show_metadata),
    .call => |*call| try printCallExpressionNode(writer, call, indent, show_metadata),
    .group => |*grp| try printGroupExpressionNode(writer, grp, indent, show_metadata),
  }
}

pub fn printIdentifierNode(
  writer: anytype,
  id: *const ast.IdentifierNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "+ IdentifierNode: ", .{});

  for( id.parts ) |part, i| {
    try writer.writeAll(part);
    
    if( i != id.parts.len - 1 )
      try writer.writeByte('/');
  }

  try writer.writeByte('\n');

  if( show_metadata ) {
    try printWithIndent(writer, indent, "- Metadata:\n", .{});
    try printWithIndent(writer, indent+2, "- ID: {}\n", .{ id.identifier_id });
    try printWithIndent(writer, indent+2, "- Constantness: {s}\n", .{ @tagName( id.constantness ) });
    try printWithIndent(writer, indent+2, "- Type: {}\n", .{ id.type });
  }
}

pub fn printIntegerNode(
  writer: anytype,
  int: *const ast.IntegerNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "+ IntegerNode\n", .{});
  try printWithIndent(writer, indent, "- Value: {}\n", .{ int.value });
  try printWithIndent(writer, indent, "- Type flag: {s}\n", .{ @tagName(int.type_flag) });

  if( show_metadata ) {
    try printWithIndent(writer, indent, "- Metadata: <no metadata to show>\n", .{});
  }
}

pub fn printStringNode(
  writer: anytype,
  str: *const ast.StringNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "+ StringNode\n", .{});
  try printWithIndent(writer, indent, "- Value: {s}\n", .{ str.value });

  if( show_metadata ) {
    try printWithIndent(writer, indent, "- Metadata: <no metadata to show>\n", .{});
  }
}

pub fn printBinaryExpressionNode(
  writer: anytype,
  bin: *const ast.BinaryExpressionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "+ BinaryExpressionNode\n", .{});
  try printWithIndent(writer, indent, "- Operator: {s}\n", .{ @tagName(bin.operator) });

  if( show_metadata ) {
    try printWithIndent(writer, indent, "- Metadata:\n", .{});
    try printWithIndent(writer, indent+2, "- Constantness: {s}\n", .{ @tagName( bin.constantness ) });
    try printWithIndent(writer, indent+2, "- Type: {}\n", .{ bin.type });
  }
  
  try printWithIndent(writer, indent, "- Left-hand side:\n", .{ });
  try printExpressionNode(writer, bin.left, indent+2, show_metadata);

  try printWithIndent(writer, indent, "- Right-hand side:\n", .{ });
  try printExpressionNode(writer, bin.right, indent+2, show_metadata);

}

pub fn printUnaryExpressionNode(
  writer: anytype,
  una: *const ast.UnaryExpressionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "+ UnaryExpressionNode\n", .{});
  try printWithIndent(writer, indent, "- Operator: {s}\n", .{ @tagName(una.operator) });

  if( show_metadata ) {
    try printWithIndent(writer, indent, "- Metadata:\n", .{});
    try printWithIndent(writer, indent+2, "- Constantness: {s}\n", .{ @tagName( una.constantness ) });
    try printWithIndent(writer, indent+2, "- Type: {}\n", .{ una.type });
  }

  try printWithIndent(writer, indent, "- Child:\n", .{});
  try printExpressionNode(writer, una.child, indent+2, show_metadata);

}

pub fn printCallExpressionNode(
  writer: anytype,
  call: *const ast.CallExpressionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "+ CallExpressionNode\n", .{});

  if( show_metadata ) {
    try printWithIndent(writer, indent, "- Metadata: <no metadata to show>\n", .{});
  }

  if( call.arguments.len > 0 ) {
    try printWithIndent(writer, indent, "+ Argument(s):\n", .{});

    for( call.arguments ) |*arg|
      try printExpressionNode(writer, arg, indent+2, show_metadata);
  } else {
    try printWithIndent(writer, indent, "+ Argument(s): <no arguments>\n", .{});
  }
}

pub fn printGroupExpressionNode(
  writer: anytype,
  grp: *const ast.GroupExpressionNode,
  indent: usize,
  show_metadata: bool
) @TypeOf(writer).Error!void {
  try printWithIndent(writer, indent, "+ GroupExpressionNode\n", .{});

  if( show_metadata ) {
    try printWithIndent(writer, indent, "- Metadata: <no metadata to show>\n", .{});
  }

  try printWithIndent(writer, indent, "- Child:\n", .{});
  try printExpressionNode(writer, grp.child, indent+2, show_metadata);
}



fn printWithIndent(
  writer: anytype,
  indent: usize,
  comptime fmt: []const u8,
  args: anytype,
) @TypeOf(writer).Error!void {
  try writer.writeByteNTimes(' ', indent);
  try writer.print(fmt, args);
}