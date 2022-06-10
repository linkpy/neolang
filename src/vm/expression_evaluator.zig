
const std = @import("std");
const ast = @import("../parser/ast.zig");
const Type = @import("../type/type.zig").Type;
const Diagnostics = @import("../diagnostic/diagnostics.zig");

const Allocator = std.mem.Allocator;
const ExpressionEvaluator = @This();



alloc: Allocator,
diagnostics: *Diagnostics,



pub fn init(
  alloc: Allocator,
  diags: *Diagnostics
) ExpressionEvaluator {
  return ExpressionEvaluator {
    .alloc = alloc,
    .diagnostics = diags
  };
}



pub fn evaluate(
  self: *ExpressionEvaluator,
  expr: *const ast.ExpressionNode
) Error!EvaluationResult {
  return switch( expr.* ) {
    .integer => |int| return EvaluationResult { .integer = int.value },
    .string => |str| return EvaluationResult { .string = .{ 
      .value = str.value,
      .allocated = false,
    }},
    .binary =>|bin| {
      // TODO handle types better
      if( bin.getType() ) |typ| {
        switch( typ ) {
          .integer => {
            const left = bin.left.integer.value;
            const right = bin.right.integer.value;
            // TODO handle bin operators
            return EvaluationResult{ .integer = left + right };
          }, 
          else => @panic("NYI"),
        }
      } else {
        try self.diagnostics.pushError(
          "Trying to evaluate a binary expression with unknown result type.", .{},
          bin.getStartLocation(), bin.getEndLocation(),
        );
        return Error.invalid_type;
      }
    },
    else => @panic("NYI"), // TODO implement scope & identifier evaluation
  };
}



pub const EvaluationResult = union(enum) {
  integer: i64,
  string: struct {
    value: []const u8,
    allocated: bool,
  },
  boolean: bool,



  pub fn deinit(
    self: *EvaluationResult,
    alloc: Allocator
  ) void {
    switch( self.* ) {
      .string => |str| if( str.allocated ) alloc.free(str.value),
      else => {}
    }
  }
};



pub const Error = error {
  invalid_type,
} || Diagnostics.Error || Allocator.Error;
