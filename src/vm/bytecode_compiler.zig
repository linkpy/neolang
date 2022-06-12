/// Structure used to compile compile-time expressions into bytecode.
///



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



/// Diagnostics used in case of error.
diagnostics: *Diagnostics,
/// Identifier storage.
identifiers: *IdentifierStorage,

/// Bytecode writer used to write the code;
writer: BytecodeWriter,



/// Initialises a new instance.
///
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

/// Deinitialises the compiler.
///
pub fn deinit(
  self: *BytecodeCompiler
) void {
  self.writer.deinit();
}



/// Commits the writen bytecode into an executable state.
///
pub fn commit(
  self: *BytecodeCompiler
) Error!bc.State {
  return try self.writer.commit();
}



/// Compiles an expression node, adding a potential type case if a type hint is
/// given.
///
pub fn compileExpression(
  self: *BytecodeCompiler,
  expr: *const ast.ExpressionNode,
  type_hint: ?Type,
) Error!Type {
  // stack : (-- x)

  return switch( expr.* ) {
    .identifier => |id| try self.compileIdentifier(&id, type_hint),
    .integer => |int| try self.compileInteger(&int, type_hint),
    .string => @panic("NYI"),
    .binary => |bin| try self.compileBinaryExpr(&bin, type_hint),
    .unary => @panic("NYI"), // TODO support unary expr
    .call => @panic("NYI"), // TODO support call expr
    .group => |grp| try self.compileExpression(grp.child, type_hint)
  };
}

/// Compiles an identifier, adding a potential type case if a type hint is
/// given.
///
pub fn compileIdentifier(
  self: *BytecodeCompiler,
  id_expr: *const ast.IdentifierNode,
  type_hint: ?Type,
) Error!Type {
  // stack : (-- x)

  // the ID was resolved
  if( id_expr.identifier_id == null ) {
    try self.diagnostics.pushError(
      "[BUG] Trying to compile an unresolved identifier.", .{},
      id_expr.getStartLocation(), id_expr.getEndLocation()
    );

    return Error.incomplete_code;
  }

  const id = id_expr.identifier_id.?;

  // the ID is constant
  if( id_expr.constantness != .constant ) {
    try self.diagnostics.pushError(
      "[BUG] Trying to compile non-constant code.", .{},
      id_expr.getStartLocation(),
      id_expr.getEndLocation(),
    );

    return Error.non_constant_code;
  }

  // the ID has a type
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
    try self.emitTypeCoercion(
      id_type, typ, 
      id_expr.getStartLocation(), id_expr.getEndLocation()
    );

    return typ;
  }

  return id_type;

}

/// Compiles an integer, adding a potential type cast if a type hint is given.
///
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
    try self.emitTypeCoercion(
      vtype, typ,
      int.getStartLocation(), int.getEndLocation()
    );

    return typ;
  }

  return vtype;
}

/// Compiles a binary expression, adding a potential type cast if a type hint is 
/// given.
///
pub fn compileBinaryExpr(
  self: *BytecodeCompiler,
  bin: *const ast.BinaryExpressionNode,
  type_hint: ?Type,
) Error!Type {
  // the expression is contant
  if( bin.constantness != .constant ) {
    try self.diagnostics.pushError(
      "[BUG] Trying to compile a non-constant expression.", .{},
      bin.getStartLocation(), bin.getEndLocation(),
    );

    return Error.non_constant_code;
  }

  // the expression is typed
  if( bin.type == null ) {
    try self.diagnostics.pushError(
      "[BUG] Trying to compile an untyped expression.", .{},
      bin.getStartLocation(), bin.getEndLocation(),
    );

    return Error.incomplete_code;
  }

  const typ = bin.type.?;

  // compiles the left hand side
  const left_type = try self.compileExpression(bin.left, null);

  if( !left_type.isSameAs(typ) ) {
    try self.emitTypeCoercion(
      left_type, typ,
      bin.left.getStartLocation(), bin.left.getEndLocation()
    );
  }

  // compiles the right hand side
  const right_type = try self.compileExpression(bin.right, null);

  if( !right_type.isSameAs(typ) ) {
    try self.emitTypeCoercion(
      right_type, typ,
      bin.right.getStartLocation(), bin.right.getEndLocation()
    );
  }


  // gets the result type
  const res_type = left_type.peerResolution(right_type) orelse {
    try self.diagnostics.pushError(
      "[BUG] Unable to do peer type resolution on a fully resolved binary expression.", .{},
      bin.getStartLocation(), bin.getEndLocation(),
    );

    return Error.incomplete_code;
  };


  // we make sure it's the right type
  if( !typ.isSameAs(res_type) ) {
    try self.diagnostics.pushError(
      "[BUG] Inconsistent typing. The AST says the expression is of type '{}', but peer type resolution says '{}'.",
      .{ typ, res_type },
      bin.getStartLocation(), bin.getEndLocation()
    );

    return Error.incomplete_code;
  }


  // we write the operation
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

  // optional cast for the type hint
  if( type_hint ) |ty| {
    try self.emitTypeCoercion(
      res_type, ty,
      bin.getStartLocation(), bin.getEndLocation()
    );

    return typ;
  }

  return res_type;
}



/// Emits instructions to ensure the last element in the stack is of the wanted
/// type.
///
fn emitTypeCoercion(
  self: *BytecodeCompiler,
  from: Type,
  to: Type,
  start_loc: nl.diagnostic.Location,
  end_loc: nl.diagnostic.Location,
) Error!void {
  if( !from.canBeCoercedTo(to) ) {
    try self.diagnostics.pushError(
      "A value of type '{}' cannot be coerced to '{}'.",
      .{ from, to },
      start_loc,
      end_loc,
    );

    return Error.type_resolution_failed;
  }

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
