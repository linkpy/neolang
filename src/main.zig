const std = @import("std");
const nl = @import("./nl.zig");

const FileStorage = nl.storage.File;
const IdStorage = nl.storage.Identifier;

const Diagnostics = nl.diagnostic.Diagnostics;
const Renderer = nl.diagnostic.Renderer;

const ast = nl.parser.ast;
const Lexer = nl.parser.Lexer;
const Parser = nl.parser.Parser;

const IdResolver = nl.analysis.IdentifierResolver;
const TypeResolver = nl.analysis.TypeResolver;

const Evaluator = nl.vm.Evaluator;



pub fn main() anyerror!void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
  defer _ = gpa.deinit();

  var alloc = gpa.allocator();

  var file_storage = FileStorage.init(alloc);
  defer file_storage.deinit();

  var id_storage = IdStorage.init(alloc);
  defer id_storage.deinit();

  try id_storage.registerBuiltins();

  var file_id = try file_storage.addDiskFile("sketchs/1.nl");

  var renderer = Renderer.init(std.io.getStdOut().writer(), .{});
  var diags = Diagnostics.init(alloc);
  defer {
    renderer.renderAll(&file_storage, diags) catch {};

    diags.deinit();
  }

  var lexer = try Lexer.fromFileStorage(&file_storage, file_id, &diags);
  var parser = Parser.init(alloc, &lexer);


  var cst0 = try parser.parseStatement();
  defer cst0.deinit(alloc);

  // var cst1 = try parser.parseConstant();
  // defer cst1.deinit(alloc);

  // var cst2 = try parser.parseConstant();
  // defer cst2.deinit(alloc);

  var id_resolver = IdResolver.init(&diags, &id_storage);
  var scope = id_storage.scope();
  defer scope.deinit();

  try scope.bindBuiltins();


  try id_resolver.resolveConstant(&cst0, &scope);
  // try id_resolver.resolveConstant(&cst1, &scope);
  // try id_resolver.resolveConstant(&cst2, &scope);


  var type_resolver = TypeResolver.init(&diags, &id_storage);
  try type_resolver.resolveConstant(&cst0);
  // try type_resolver.resolveConstant(&cst1);
  // try type_resolver.resolveConstant(&cst2);

  var eval = Evaluator.init(alloc, &diags, &id_storage);
  var result = try eval.evaluateExpression(&cst0.value, null);

  try nl.ast.printer.printStatementNode(
    std.io.getStdOut().writer(), &cst0, 0, true
  );

  std.log.info("Result: {}", .{ result });
}

