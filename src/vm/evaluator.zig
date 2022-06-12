
const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const ast = nl.parser.ast;
const bc = nl.vm.bytecode;
const Type = nl.types.Type;
const Diagnostics = nl.diagnostic.Diagnostics;
const IdentifierStorage = nl.storage.Identifier;
const Variant  = nl.vm.Variant;
const BytecodeCompiler = nl.vm.BytecodeCompiler;

const Evaluator = @This();



alloc: Allocator,
diagnostics: *Diagnostics,
identifiers: *IdentifierStorage,



pub fn init(
  alloc: Allocator,
  diags: *Diagnostics,
  ids: *IdentifierStorage
) Evaluator {
  return Evaluator {
    .alloc = alloc,
    .diagnostics = diags,
    .identifiers = ids,
  };
}



pub fn evaluateExpression(
  self: *Evaluator,
  expr: *const ast.ExpressionNode,
  type_hint: ?Type,
) Error!Variant {
  var bcc = BytecodeCompiler.init(self.diagnostics, self.identifiers, self.alloc, 0);
  defer bcc.deinit();

  _ = try bcc.compileExpression(expr, type_hint);
  try bcc.writer.writeRet();

  var state = try bcc.commit();
  defer state.deinit(self.alloc);

  if( state.run() ) |result| {
    return result;
  } else |err| {
    try self.diagnostics.pushError(
      "Evaluation failed with error '{s}'.", .{ @errorName(err) },
      expr.getStartLocation(),
      expr.getEndLocation(),
    );

    return Error.evaluation_failed;
  }
}



pub const Error = error {
  evaluation_failed,
} || BytecodeCompiler.Error;
