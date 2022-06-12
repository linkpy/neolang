/// Structure used to write bytecode instructions.
///



const std = @import("std");

const nl = @import("../nl.zig");
const bc = nl.vm.bytecode;
const IdentifierStorage = nl.storage.Identifier;
const Type = nl.types.Type;
const Variant = nl.vm.Variant;

const BytecodeWriter = @This();



/// Allocator used;
alloc: std.mem.Allocator,

/// Identifier storage.
identifiers: *IdentifierStorage,
/// Number of parameters.
params: usize,
/// Number of locals.
locals: usize,
/// Stack size.
stack: usize,
/// Code buffer.
code: std.ArrayList(bc.Instruction),



/// Initialises a new instance.
/// 
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

/// Deinitialises the writer.
///
pub fn deinit(
  self: *BytecodeWriter
) void {
  self.code.deinit();
}



/// Commits the writed instructions into a runnable state.
///
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



/// Writes a NOOP instruction.
///
/// Stack pattern: (--)
///
pub fn writeNoop(
  self: *BytecodeWriter
) Error!void {
  try self.writeDatalessOp(.noop);
}

/// Writes a LOAD_ID instruction, pushing on stack the value of an identifier 
/// from the identifier storage.
///
/// Stack pattern: (-- x)
///
pub fn writeLoadId(
  self: *BytecodeWriter,
  id: usize,
) Error!void {
  try self.writeIdOp(.load_id, id);
}

/// Writes a LOAD_PARAM instruction, pushing on the stack the value of a 
/// parameter (stored in the runnable state).
///
/// Stack pattern: (-- x)
///
pub fn writeLoadParam(
  self: *BytecodeWriter,
  id: usize
) Error!void {
  if( id >= self.params )
    return Error.param_out_of_bounds;
  
  try self.writeIdOp(.load_params, id);
}

/// Writes a LOAD_LOCAL instruction, pushing on the stack the value of a local
/// stored in the runnable state.
///
/// Stack pattern: (-- x)
///
pub fn writeLoadLocal(
  self: *BytecodeWriter,
  id: usize
) Error!void {
  self.locals = @maximum(self.locals, id+1);

  try self.writeIdOp(.load_local, id);
}

/// Writes a LOAD_DATA instruction, pushing on the stack the given variant.
///
/// Stack pattern: (-- x)
///
pub fn writeLoadData(
  self: *BytecodeWriter,
  v: Variant
) Error!void {
  try self.code.append(.{
    .opcode = .load_data,
    .data = .{ .variant = v }
  });
}

/// Writes a WRITE_LOCAL instruction, poping the top variant from the stack to 
/// store it in the given local stored in the runnable state.
///
/// Stack pattern: (a --)
///
pub fn writeWriteLocal(
  self: *BytecodeWriter,
  id: usize
) Error!void {
  self.locals = @maximum(self.locals, id+1);

  try self.writeIdOp(.write_local, id);
}

/// Writes a END instruction, terminating the execution of the state.
///
/// Stack pattern: (--)
///
pub fn writeEnd(
  self: *BytecodeWriter,
) Error!void {
  try self.writeDatalessOp(.end);
}

/// Writes a RET instruction, terminating the execution of the state and 
/// retuning the top value of the stack.
///
/// Stack pattern: (a --)
///
pub fn writeRet(
  self: *BytecodeWriter
) Error!void {
  try self.writeDatalessOp(.ret);
}

/// Writes a ERR instruction, terminating the execution of the state and 
/// returning an error.
///
/// Stack pattern: (--)
///
pub fn writeErr(
  self: *BytecodeWriter
) Error!void {
  try self.writeDatalessOp(.err);
}

/// Writes a DROP instruction, dropping N variants from the top of the stack.
///
/// Stack pattern: (a...N --)
///
pub fn writeDrop(
  self: *BytecodeWriter,
  n: u16
) Error!void {
  try self.code.append(.{
    .opcode = .drop,
    .data = .{ .variant = .{ .i2 = n }},
  });
}

/// Writes a DUP instruction, duplicating the top variant from the stack N 
/// times.
///
/// Stack pattern: (a -- a a...N)
///
pub fn writeDup(
  self: *BytecodeWriter,
  n: u16
) Error!void {
  try self.code.append(.{
    .opcode = .dup,
    .data = .{ .variant = .{ .i2 = n }},
  });
}

/// Writes a SWAP instruction, swapping the two top variants from the stack.
///
/// Stack pattern: (a b -- b a)
///
pub fn writeSwap(
  self: *BytecodeWriter
) Error!void {
  try self.writeDatalessOp(.swap);
}

/// Writes a CAST_INT instruction, converting the top variant from the stack 
/// into the given integer type.
///
/// Stack pattern: (a -- a)
///
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

/// Writes a ADD_INT instruction, adding the two top-most integers from the 
/// stack.
/// 
/// Stack pattern: (a b -- x) with x = a + b
///
pub fn writeAddInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .add_int);
}

/// Writes a SUB_INT instruction, substracting the two top-most integers from the 
/// stack.
/// 
/// Stack pattern: (a b -- x) with x = a - b
///
pub fn writeSubInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .sub_int);
}

/// Writes a MUL_INT instruction, multiplying the two top-most integers from the 
/// stack.
/// 
/// Stack pattern: (a b -- x) with x = a * b
///
pub fn writeMulInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .mul_int);
}

/// Writes a DIV_INT instruction, dividing the two top-most integers from the 
/// stack.
/// 
/// Stack pattern: (a b -- x) with x = @divFloor(a, b)
///
pub fn writeDivInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .div_int);
}

/// Writes a MOD_INT instruction, modulo'ing the two top-most integers from the 
/// stack.
/// 
/// Stack pattern: (a b -- x) with x = @mod(a, b)
///
pub fn writeModInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .mod_int);
}

/// Writes a EQ_INT instruction, pushing true to the stack if both integers 
/// are the same.
/// 
/// Stack pattern: (a b -- x) with x = a == b
///
pub fn writeEqInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .eq_int);
}

/// Writes a NE_INT instruction, pushing true to the stack if both integers 
/// are different.
/// 
/// Stack pattern: (a b -- x) with x = a != b
///
pub fn writeNeInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .ne_int);
}

/// Writes a LT_INT instruction, pushing true to the stack if the 2nd integer
/// is less than the first.
/// 
/// Stack pattern: (a b -- x) with x = a < b
///
pub fn writeLtInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .lt_int);
}

/// Writes a LE_INT instruction, pushing true to the stack if the 2nd integer
/// is less than or equal to the first.
/// 
/// Stack pattern: (a b -- x) with x = a <= b
///
pub fn writeLeInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .le_int);
}

/// Writes a GT_INT instruction, pushing true to the stack if the 2nd integer
/// is greater than the first.
/// 
/// Stack pattern: (a b -- x) with x = a > b
///
pub fn writeGtInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .gt_int);
}

/// Writes a GE_INT instruction, pushing true to the stack if the 2nd integer
/// is greater than or equal to the first.
/// 
/// Stack pattern: (a b -- x) with x = a >= b
///
pub fn writeGeInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .ge_int);
}

/// Writes a SHL_INT instruction.
/// 
/// Stack pattern: (a b -- x) with x = a << b
///
pub fn writeShlInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .shl_int);
}

/// Writes a SHR_INT instruction.
/// 
/// Stack pattern: (a b -- x) with x = a >> b
///
pub fn writeShrInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .shr_int);
}

/// Writes a BAND_INT instruction.
/// 
/// Stack pattern: (a b -- x) with x = a & b
///
pub fn writeBandInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .band_int);
}

/// Writes a BOR_INT instruction.
/// 
/// Stack pattern: (a b -- x) with x = a | b
///
pub fn writeBorInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .bor_int);
}

/// Writes a BXOR_INT instruction.
/// 
/// Stack pattern: (a b -- x) with x = a ^ b
///
pub fn writeBxorInt(
  self: *BytecodeWriter,
  typ: Type.Integer
) Error!void {
  try self.writeIntBinOp(typ, .bxor_int);
}

/// Writes a LAND instruction.
/// 
/// Stack pattern: (a b -- x) with x = a and b
///
pub fn writeLand(
  self: *BytecodeWriter
) Error!void {
  try self.code.append(.{
    .opcode = .land,
    .data = .{ .variant = .{ .none  = {} }},
  });
}

/// Writes a LOR instruction.
/// 
/// Stack pattern: (a b -- x) with x = a or b
///
pub fn writeLor(
  self: *BytecodeWriter
) Error!void {
  try self.code.append(.{
    .opcode = .lor,
    .data = .{ .variant = .{ .none = {} }},
  });
}



/// Writes an instruction taking an ID as data.
///
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

/// Writes an instruction that takes no data.
///
fn writeDatalessOp(
  self: *BytecodeWriter,
  op: bc.Opcode
) Error!void {
  try self.code.append(.{
    .opcode = op,
    .data = .{ .variant = .{ .none = {} }},
  });
}

/// Writes an integer binary operation.
///
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



/// Converts an integer type to the VM's integer type index.
///
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
