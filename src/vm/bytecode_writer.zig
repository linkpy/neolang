
const std = @import("std");

const nl = @import("../nl.zig");
const bc = nl.vm.bytecode;
const IdentifierStorage = nl.storage.Identifier;
const Type = nl.types.Type;
const Variant = nl.vm.Variant;

const BytecodeWriter = @This();



alloc: std.mem.Allocator,

identifiers: *IdentifierStorage,
params: usize,
locals: usize,
stack: usize,
code: std.ArrayList(bc.Instruction),



pub fn init(
  alloc: std.mem.Allocator,
  ids: *IdentifierStorage,
  params: usize,
) BytecodeWriter {
  return BytecodeWriter {
    .alloc = alloc,
    .identifiers = ids,
    .params = params,
    .locals = 0,
    .stack = 32,
    .code = std.ArrayList(bc.Instruction).init(alloc),
  };
}

pub fn deinit(
  self: *BytecodeWriter
) void {
  self.code.deinit();
}



pub fn commit(
  self: *BytecodeWriter
) Error!bc.State {
  var params = try self.alloc.alloc(Variant, self.params);
  errdefer self.alloc.free(params);

  var locals = try self.alloc.alloc(Variant, self.locals);
  errdefer self.alloc.free(locals);

  var stack = try self.alloc.alloc(Variant, self.stack);
  errdefer self.alloc.free(stack);

  return bc.State {
    .identifiers = self.identifiers,
    .params = params,
    .locals = locals,
    .stack = stack,
    .code = self.code.toOwnedSlice(),
    .stack_index = 0,
    .code_index = 0,
  };
}



pub fn writeNoop(
  self: *BytecodeWriter
) Error!void {
  try self.writeDatalessOp(.noop);
}

pub fn writeLoadId(
  self: *BytecodeWriter,
  id: usize,
) Error!void {
  try self.writeIdOp(.load_id, id);
}

pub fn writeLoadParam(
  self: *BytecodeWriter,
  id: usize
) Error!void {
  if( id >= self.params )
    return Error.param_out_of_bounds;
  
  try self.writeIdOp(.load_params, id);
}

pub fn writeLoadLocal(
  self: *BytecodeWriter,
  id: usize
) Error!void {
  self.locals = @maximum(self.locals, id+1);

  try self.writeIdOp(.load_local, id);
}

pub fn writeLoadData(
  self: *BytecodeWriter,
  v: Variant
) Error!void {
  try self.code.append(.{
    .opcode = .load_data,
    .data = .{ .variant = v }
  });
}

pub fn writeWriteLocal(
  self: *BytecodeWriter,
  id: usize
) Error!void {
  self.locals = @maximum(self.locals, id+1);

  try self.writeIdOp(.write_local, id);
}

pub fn writeEnd(
  self: *BytecodeWriter,
) Error!void {
  try self.writeDatalessOp(.end);
}

pub fn writeRet(
  self: *BytecodeWriter
) Error!void {
  try self.writeDatalessOp(.ret);
}

pub fn writeErr(
  self: *BytecodeWriter
) Error!void {
  try self.writeDatalessOp(.err);
}

pub fn writeDrop(
  self: *BytecodeWriter,
  n: u16
) Error!void {
  try self.code.append(.{
    .opcode = .drop,
    .data = .{ .variant = .{ .i2 = n }},
  });
}

pub fn writeDup(
  self: *BytecodeWriter,
  n: u16
) Error!void {
  try self.code.append(.{
    .opcode = .dup,
    .data = .{ .variant = .{ .i2 = n }},
  });
}

pub fn writeSwap(
  self: *BytecodeWriter
) Error!void {
  try self.writeDatalessOp(.swap);
}

pub fn writeCastInt(
  self: *BytecodeWriter,
  from: Type.Integer,
  to: Type.Integer
) Error!void {
  const from_idx = indexOfIntType(from) orelse return Error.unsupported_integer_type;
  const to_idx = indexOfIntType(to) orelse return Error.unsupported_integer_type;
  const data = (@intCast(u8, from_idx) << 4) | @intCast(u8, to_idx);

  try self.code.append(.{
    .opcode = .cast_int,
    .data = .{ .variant = .{ .u1 = data }}
  });
}

pub fn writeAddInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .add_int);
}

pub fn writeSubInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .sub_int);
}

pub fn writeMulInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .mul_int);
}

pub fn writeDivInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .div_int);
}

pub fn writeModInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .mod_int);
}

pub fn writeEqInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .eq_int);
}

pub fn writeNeInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .ne_int);
}

pub fn writeLtInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .lt_int);
}

pub fn writeLeInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .le_int);
}

pub fn writeGtInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .gt_int);
}

pub fn writeGeInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .ge_int);
}

pub fn writeShlInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .shl_int);
}

pub fn writeShrInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .shr_int);
}

pub fn writeBandInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .band_int);
}

pub fn writeBorInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .bor_int);
}

pub fn writeBxorInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .bxor_int);
}

pub fn writeLand(
  self: *BytecodeWriter
) Error!void {
  try self.code.append(.{
    .opcode = .land,
    .data = .{ .variant = .{ .none  = {} }},
  });
}

pub fn writeLor(
  self: *BytecodeWriter
) Error!void {
  try self.code.append(.{
    .opcode = .lor,
    .data = .{ .variant = .{ .none = {} }},
  });
}



fn writeIdOp(
  self: *BytecodeWriter,
  op: bc.Opcode,
  id: usize
) Error!void {
  try self.code.append(.{
    .opcode = op,
    .data = .{ .id = id }
  });
}

fn writeDatalessOp(
  self: *BytecodeWriter,
  op: bc.Opcode
) Error!void {
  try self.code.append(.{
    .opcode = op,
    .data = .{ .variant = .{ .none = {} }},
  });
}

fn writeIntBinOp(
  self: *BytecodeWriter,
  typ: Type.Integer,
  op: bc.Opcode
) Error!void {
  const typ_idx = indexOfIntType(typ) orelse return Error.unsupported_integer_type;
  try self.code.append(.{
    .opcode = op,
    .data = .{ .variant = .{ .u1 = @intCast(u8, typ_idx) }}
  });
}


fn indexOfIntType(
  t: Type.Integer
) ?u4 {
  return switch( t.width ) {
    .dynamic => bc.IntTypes.CtInt,
    .bytes => |b| 
      if( t.signed )
        switch( b ) {
          1 => bc.IntTypes.I1,
          2 => bc.IntTypes.I2,
          4 => bc.IntTypes.I4,
          8 => bc.IntTypes.I8,
          else => null,
        }
      else
        switch( b ) {
          1 => bc.IntTypes.U1,
          2 => bc.IntTypes.U2,
          4 => bc.IntTypes.U4,
          8 => bc.IntTypes.U8,
          else => null,
        },
      .pointer =>
        if( t.signed )
          bc.IntTypes.IPtr
        else
          bc.IntTypes.UPtr,
  };
}



pub const Error = error {
  param_out_of_bounds,
  unsupported_integer_type,
} || std.mem.Allocator.Error;
