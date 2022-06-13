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


  var stmts = try parser.parseFile();
  defer {
    for( stmts ) |*stmt| stmt.deinit(alloc);
    alloc.free(stmts);
  }


  // var id_resolver = IdResolver.init(
  //   alloc, &diags, &id_storage
  // );
  // defer id_resolver.deinit();

  // if( id_resolver.processFile(stmts) ) |v| {
  //   std.log.info("Indentifier resolution: {} (errors: {})", .{ v, id_resolver.errors });
  // } else |err| {
  //   std.log.info("Error occured: {}", .{ err });
  // }

  for( stmts ) |stmt| {
    try nl.ast.printer.printStatementNode(
      std.io.getStdOut().writer(),
      &stmt,
      0,
     false
    );
  }

}
