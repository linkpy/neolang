const std = @import("std");

const FileStorage = @import("./storage/file.zig");
const IdStorage = @import("./storage/identifier.zig");

const Diagnostic = @import("./diagnostic/diagnostic.zig");
const Diagnostics = @import("./diagnostic/diagnostics.zig");
const Renderer = @import("./diagnostic/renderer.zig");

const Lexer = @import("./parser/lexer.zig");
const Parser = @import("./parser/parser.zig");
const ast = @import("./parser/ast.zig");

const IdResolver = @import("./phases/identifier_resolver.zig");
const TypeResolver = @import("./phases/type_resolver.zig");



pub fn main() anyerror!void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
  defer _ = gpa.deinit();

  var alloc = gpa.allocator();

  var file_storage = FileStorage.init(alloc);
  defer file_storage.deinit();

  var id_storage = IdStorage.init(alloc);
  defer id_storage.deinit();

  var file_id = try file_storage.addDiskFile("sketchs/1.nl");

  var renderer = Renderer.init(std.io.getStdOut().writer(), .{});
  var diags = Diagnostics.init(alloc);
  defer {
    renderer.renderAll(&file_storage, diags) catch {};

    diags.deinit();
  }

  var lexer = try Lexer.fromFileStorage(&file_storage, file_id, &diags);
  var parser = Parser.init(alloc, &lexer);


  var cst0 = try parser.parseConstant();
  defer cst0.deinit(alloc);

  var cst1 = try parser.parseConstant();
  defer cst1.deinit(alloc);

  var cst2 = try parser.parseConstant();
  defer cst2.deinit(alloc);

  var id_resolver = IdResolver.init(&diags, &id_storage);
  var scope = id_storage.scope();
  defer scope.deinit();

  try id_resolver.resolveConstant(&cst0, &scope);
  try id_resolver.resolveConstant(&cst1, &scope);
  try id_resolver.resolveConstant(&cst2, &scope);


  var type_resolver = TypeResolver.init(&diags, &id_storage);
  try type_resolver.resolveConstant(&cst0);
  try type_resolver.resolveConstant(&cst1);
  try type_resolver.resolveConstant(&cst2);
}



fn printCst(
  alloc: std.mem.Allocator,
  cst: *const ast.ConstantNode,
  i: usize
) !void {
  var list = std.ArrayList(u8).init(alloc);
  defer list.deinit();

  try list.appendNTimes(' ', i);

  std.debug.print("{s}ConstantNode\n", .{ list.items });
  std.debug.print("{s}- Name:\n", .{ list.items });
  try printIdentifier(alloc, &cst.name, i+2);
  std.debug.print("{s}- Value:\n", .{ list.items });
  try printExpr(alloc, &cst.value, i+2);
}

fn printExpr(
  alloc: std.mem.Allocator,
  expr: *const ast.ExpressionNode,
  i: usize
) anyerror!void {
  switch( expr.* ) {
    .identifier => |*id| try printIdentifier(alloc, id, i),
    .integer => |*int| try printInteger(alloc, int, i),
    .string => |*str| try printStr(alloc, str, i),
    .binary => |*bin| try printBin(alloc, bin, i),
    .unary => |*un| try printUna(alloc, un, i),
    .call => |*call| try printCall(alloc, call, i),
    .group => |*grp| try printExpr(alloc, grp.child, i),
  }
}

fn printIdentifier(
  alloc: std.mem.Allocator,
  id: *const ast.IdentifierNode,
  i: usize
) !void {
  var list = std.ArrayList(u8).init(alloc);
  defer list.deinit();

  try list.appendNTimes(' ', i);
  try list.appendSlice("IdentifierNode( ");

  for( id.parts ) |part, j| {
    try list.appendSlice(part);

    if( j != id.parts.len - 1 )
      try list.append('/');
  }

  std.debug.print("{s} )\n", .{ list.items });
}

fn printInteger(
  alloc: std.mem.Allocator,
  int: *const ast.IntegerNode,
  i: usize
) !void {
  var list = std.ArrayList(u8).init(alloc);
  defer list.deinit();

  try list.appendNTimes(' ', i);

  std.debug.print("{s}IntegerNode( {} )\n", .{ list.items, int.value });
}

fn printStr(
  alloc: std.mem.Allocator,
  str: *const ast.StringNode,
  i: usize
) !void {
  var list = std.ArrayList(u8).init(alloc);
  defer list.deinit();

  try list.appendNTimes(' ', i);

  std.debug.print("{s}StringNode( {s} )\n", .{ list.items, str.value });
}

fn printBin(
  alloc: std.mem.Allocator,
  bin: *const ast.BinaryExpressionNode,
  i: usize
) !void {
  var list = std.ArrayList(u8).init(alloc);
  defer list.deinit();

  try list.appendNTimes(' ', i);

  std.debug.print("{s}BinaryExpressionNode( {s} )\n", .{ list.items, @tagName(bin.operator) });
  try printExpr(alloc, bin.left, i+2);
  try printExpr(alloc, bin.right, i+2);
}

fn printUna(
  alloc: std.mem.Allocator,
  una: *const ast.UnaryExpressionNode,
  i: usize
) !void {
  var list = std.ArrayList(u8).init(alloc);
  defer list.deinit();

  try list.appendNTimes(' ', i);

  std.debug.print("{s}UnaryExpressionNode( {s} )\n", .{ list.items, @tagName(una.operator) });
  try printExpr(alloc, una.child, i+2);
}

fn printCall(
  alloc: std.mem.Allocator,
  call: *const ast.CallExpressionNode,
  i: usize
) !void {
  var list = std.ArrayList(u8).init(alloc);
  defer list.deinit();

  try list.appendNTimes(' ', i);

  std.debug.print("{s}CallExpressionNode\n", .{ list.items });
  std.debug.print("{s}- Function:\n", .{ list.items });
  try printExpr(alloc, call.function, i+2);

  if( call.arguments.len > 0 ) {
    std.debug.print("{s}- Argument(s):\n", .{ list.items });
    for( call.arguments ) |*arg| {
      try printExpr(alloc, arg, i+2);
    }
  }
}