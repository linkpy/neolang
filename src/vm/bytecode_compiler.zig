
const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const ast = nl.parser.ast;
const bc = nl.vm.bytecode;
const Type = nl.types.Type;
const Diagnostics = nl.diagnostic.Diagnostics;
const IdentifierStorage = nl.storage.Identifier;
const Variant = nl.vm.Variant;
const BytecodeWriter = nl.vm.BytecodeWriter;

const BytecodeCompiler = @This();



diagnostics: *Diagnostics,
identifiers: *IdentifierStorage,

writer: BytecodeWriter,



pub fn init(
  diags: *Diagnostics,
  ids: *IdentifierStorage,
  alloc: Allocator,
  params: usize,
) BytecodeCompiler {
  return BytecodeCompiler {
    .diagnostics = diags,
    .identifiers = ids,
    .writer = BytecodeWriter.init(alloc, ids, params)
  };
}

pub fn deinit(
  self: *BytecodeCompiler
) void {
  self.writer.deinit();
}



pub fn commit(
  self: *BytecodeCompiler
) Error!bc.State {
  return try self.writer.commit();
}



pub fn compileExpression(
  self: *BytecodeCompiler,
  expr: *const ast.ExpressionNode,
  type_hint: ?Type,
) Error!Type {
  return switch( expr.* ) {
    .identifier => |id| try self.compileIdentifier(&id, type_hint),
    .integer => |int| try self.compileInteger(&int, type_hint),
    .string => @panic("NYI"),
    .binary => |bin| try self.compileBinaryExpr(&bin, type_hint),
    .unary => @panic("NYI"),
    .call => @panic("NYI"),
    .group => |grp| try self.compileExpression(grp.child, type_hint)
  };
}

pub fn compileIdentifier(
  self: *BytecodeCompiler,
  id_expr: *const ast.IdentifierNode,
  type_hint: ?Type,
) Error!Type {
  if( id_expr.identifier_id ) |id| {

    if( id_expr.constantness != .constant ) {
      try self.diagnostics.pushError(
        "Trying to compile non-constant code.", .{},
        id_expr.getStartLocation(),
        id_expr.getEndLocation(),
      );

      return Error.non_constant_code;
    }

    if( id_expr.type == null ) {
      try self.diagnostics.pushError(
        "[BUG] Identifier was resolved but has no type.", .{},
        id_expr.getStartLocation(),
        id_expr.getEndLocation(),
      );

      return Error.incomplete_code;
    }

    const id_type = id_expr.type.?;

    try self.writer.writeLoadId(id);

    if( type_hint ) |typ| {
      if( !id_type.canBeCoercedTo(typ) ) {
        try self.diagnostics.pushError(
          "A value of type '{}' cannot be coerced to '{}'.",
          .{ id_type, typ },
          id_expr.getStartLocation(),
          id_expr.getStartLocation(),
        );

        return Error.type_resolution_failed;
      }

      try self.compileTypeCoercion(id_type, typ);
      return typ;
    }

    return id_type;

  } else {
    try self.diagnostics.pushError(
      "[BUG] Trying to compile an unresolved identifier.", .{},
      id_expr.getStartLocation(), id_expr.getEndLocation()
    );

    return Error.incomplete_code;
  }
}

pub fn compileInteger(
  self: *BytecodeCompiler,
  int: *const ast.IntegerNode,
  type_hint: ?Type,
) Error!Type {
  const variant = switch( int.type_flag ) {
    .ct => Variant { .ct_int = int.value },
    .i1 => Variant { .i1 = @intCast(i8, int.value) },
    .i2 => Variant { .i2 = @intCast(i16, int.value) },
    .i4 => Variant { .i4 = @intCast(i32, int.value) },
    .i8 => Variant { .i8 = @intCast(i64, int.value) },
    .u1 => Variant { .u1 = @intCast(u8, int.value) },
    .u2 => Variant { .u2 = @intCast(u16, int.value) },
    .u4 => Variant { .u4 = @intCast(u32, int.value) },
    .u8 => Variant { .u8 = @intCast(u64, int.value) },
    .iptr => Variant { .iptr = @intCast(isize, int.value) },
    .uptr => Variant { .uptr = @intCast(usize, int.value) },
  };

  try self.writer.writeLoadData(variant);

  const vtype = variant.getType().?;

  if( type_hint ) |typ| {
    if( !vtype.canBeCoercedTo(typ) ) {
      try self.diagnostics.pushError(
        "A value of type '{}' cannot be coerced to '{}'.",
        .{ vtype, typ },
        int.getStartLocation(),
        int.getStartLocation(),
      );

      return Error.type_resolution_failed;
    }

    try self.compileTypeCoercion(vtype, typ);
    return typ;
  }

  return vtype;
}

pub fn compileBinaryExpr(
  self: *BytecodeCompiler,
  bin: *const ast.BinaryExpressionNode,
  type_hint: ?Type,
) Error!Type {
  const left_type = try self.compileExpression(bin.left, null);
  const right_type = try self.compileExpression(bin.right, null);
  const res_type = left_type.peerResolution(right_type) orelse {
    try self.diagnostics.pushError(
      "[BUG] Unable to do peer resolution on a fully resolved binary expression.", .{},
      bin.getStartLocation(), bin.getEndLocation(),
    );

    return Error.incomplete_code;
  };

  if( !right_type.isSameAs(res_type) ) {
    try self.compileTypeCoercion(right_type, res_type);
  }

  if( !left_type.isSameAs(res_type) ) {
    try self.writer.writeSwap();
    try self.compileTypeCoercion(left_type, res_type);
    try self.writer.writeSwap();
  }

  switch( bin.operator ) {
    .add => try self.writer.writeAddInt(res_type.integer),
    .sub => try self.writer.writeSubInt(res_type.integer),
    .mul => try self.writer.writeMulInt(res_type.integer),
    .div => try self.writer.writeDivInt(res_type.integer),
    .mod => try self.writer.writeModInt(res_type.integer),
    .eq => try self.writer.writeEqInt(res_type.integer),
    .ne => try self.writer.writeNeInt(res_type.integer),
    .lt => try self.writer.writeLtInt(res_type.integer),
    .le => try self.writer.writeLeInt(res_type.integer),
    .gt => try self.writer.writeGtInt(res_type.integer),
    .ge => try self.writer.writeGeInt(res_type.integer),
    .land => try self.writer.writeLand(),
    .lor => try self.writer.writeLor(),
    .shl => try self.writer.writeShlInt(res_type.integer),
    .shr => try self.writer.writeShrInt(res_type.integer),
    .band => try self.writer.writeBandInt(res_type.integer),
    .bor => try self.writer.writeBorInt(res_type.integer),
    .bxor => try self.writer.writeBxorInt(res_type.integer),
  }

  if( type_hint ) |typ| {
    if( !res_type.canBeCoercedTo(typ) ) {
      try self.diagnostics.pushError(
        "A value of type '{}' cannot be coerced to '{}'.",
        .{ res_type, typ },
        bin.getStartLocation(),
        bin.getStartLocation(),
      );

      return Error.type_resolution_failed;
    }

    try self.compileTypeCoercion(res_type, typ);
    return typ;
  }

  return res_type;
}



fn compileTypeCoercion(
  self: *BytecodeCompiler,
  from: Type,
  to: Type
) Error!void {
  switch( from ) {
    .integer => |from_i| switch( to ) {
      .integer => |to_i| try self.writer.writeCastInt(from_i, to_i),
      else => unreachable,
    },
    else => unreachable,
  }
}


pub const Error = error {
  incomplete_code,
  non_constant_code,
  type_resolution_failed,
} || BytecodeWriter.Error || Diagnostics.Error;
