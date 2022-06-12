
const std = @import("std");

const nl = @import("../nl.zig");
const Variant = nl.vm.Variant;
const IdentifierStorage = nl.storage.Identifier;



/// Structure representing a bytecode instruction.
///
pub const Instruction = struct {
  /// Opcode of the instruction.
  opcode: Opcode,
  /// Data of the instruction.
  data: Data,
};

/// Structure representing data for an instruction.
///
pub const Data = union(enum) {
  variant: Variant,
  id: usize,
};

/// Available opcodes.
///
pub const Opcode = enum(u32) {
  // -- ()
  noop,

  // -- x:? (id: ID)
  // loads the value of an identifier
  load_id,
  // -- x:? (id: ID)
  // loads the value of a parameter
  load_param,
  // -- x:? (id: ID)
  // loads the value of a local variable
  load_local,
  // -- x:? (x: Variant)
  // pushes the data of the opcode on the stack
  load_data,
  // x:? -- (id: ID)
  // writes the value of a local variable
  write_local,

  // -- ()
  // returns from the evaluation without a value
  end,
  // x:? -- ()
  // returns from the evaluation with the given value
  ret,
  // -- ()
  // returns from the evaluation with an error
  err,

  // x:?...N -- (N: u16)
  // drops `N` item from the stack 
  drop, 
  // x:? -- x:? x:?...N (N: u16)
  // dups the top item of the stack `N` times
  dup, 
  // a:? b:? -- b:? a:?
  // swaps the last top items on the stack 
  swap,

  // x:T -- y:U (T: u4, U: u4)
  // casts the int at the top of the stack to the given type
  cast_int, 

  // a:T b:T -- c:T (T: u8)
  add_int,
  // a:T b:T -- c:T (T: u8)
  sub_int,
  // a:T b:T -- c:T (T: u8)
  mul_int,
  // a:T b:T -- c:T (T: u8)
  div_int,
  // a:T b:T -- c:T (T: u8)
  mod_int,

  // a:T b:T -- c:bool (T: u8)
  eq_int,
  // a:T b:T -- c:bool (T: u8)
  ne_int,
  // a:T b:T -- c:bool (T: u8)
  lt_int,
  // a:T b:T -- c:bool (T: u8)
  le_int,
  // a:T b:T -- c:bool (T: u8)
  gt_int,
  // a:T b:T -- c:bool (T: u8)
  ge_int,

  // a:T b:T -- c:T (T: u8)
  shl_int,
  // a:T b:T -- c:T (T: u8)
  shr_int,
  // a:T b:T -- c:T (T: u8)
  band_int,
  // a:T b:T -- c:T (T: u8)
  bor_int,
  // a:T b:T -- c:T (T: u8)
  bxor_int,

  // TODO add unary int ops

  // a:bool b:bool -- c:bool ()
  land,
  // a:bool b:bool -- c:bool ()
  lor,
};

/// Structure representing a runnable state of a bytecode buffer.
///
pub const State = struct {
  /// Identifier storage.
  identifiers: *IdentifierStorage,
  /// Parameters of the code.
  params: []const Variant,
  /// Locals used by the code.
  locals: []Variant,
  /// Stack used by the code.
  stack: []Variant,
  /// Bytecode.
  code: []const Instruction,

  /// Stack pointer.
  stack_index: usize,
  /// Code pointer.
  code_index: usize,



  /// Deinitialises the state.
  ///
  pub fn deinit(
    self: *State,
    alloc: std.mem.Allocator,
  ) void {
    alloc.free(self.params);
    alloc.free(self.locals);
    alloc.free(self.stack);
    alloc.free(self.code);
  }



  /// Runs a single instruction from the code.
  ///
  pub fn step(
    self: *State
  ) StepResult {
    const instruction = self.code[self.code_index];
    self.code_index += 1;

    const handler = opcode_handlers[@enumToInt(instruction.opcode)];
    return handler(self, instruction);
  }

  /// Runs the code until an `END`, `RET`, or `ERR` instructions is executed.
  ///
  pub fn run(
    self: *State
  ) anyerror!Variant {
    while( true ) {
      const r = self.step();

      switch( r ) {
        .not_finished => continue,
        .finished => |v| return v,
        .failed => |err| return err,
      }
    }
  }



  /// Pushes a variant to the stack.
  ///
  fn push(
    self: *State,
    v: Variant
  ) void {
    self.stack[self.stack_index] = v;
    self.stack_index += 1;
  }

  /// Pops a variant from the stack.
  ///
  fn pop(
    self: *State
  ) Variant {
    self.stack_index -= 1;
    return self.stack[self.stack_index];
  }

  /// Peeks the top variant from the stack.
  ///
  fn peek(
    self: *State
  ) Variant {
    return self.stack[self.stack_index - 1];
  }



  /// Result returned by the execution of a single instruction.
  ///
  pub const StepResult = union(enum) {
    /// The code hasn't finished executing
    not_finished: void,
    /// The code has finished executing, returning the given Variant;
    finished: Variant,
    /// The code has failed.
    failed: anyerror,
  };

};



pub const IntTypes = struct {
  pub const CtInt: u4 = 0;
  pub const I1: u4 = 1;
  pub const I2: u4 = 2;
  pub const I4: u4 = 3;
  pub const I8: u4 = 4;
  pub const U1: u4 = 5;
  pub const U2: u4 = 6;
  pub const U4: u4 = 7;
  pub const U8: u4 = 8;
  pub const IPtr: u4 = 9;
  pub const UPtr: u4 = 10;
};



const InstructionHandler = fn(*State, Instruction) State.StepResult;

const opcode_handlers = [_]InstructionHandler {
  ophNoop,
  ophLoadId,
  ophLoadParam,
  ophLoadLocal,
  ophLoadData,
  ophWriteLocal,
  ophEnd,
  ophRet,
  ophErr,
  ophDrop,
  ophDup,
  ophSwap,
  ophCastInt,
  ophAddInt,
  ophSubInt,
  ophMulInt,
  ophDivInt,
  ophModInt,
  ophEqInt,
  ophNeInt,
  ophLtInt,
  ophLeInt,
  ophGtInt,
  ophGeInt,
  ophShlInt,
  ophShrInt,
  ophBandInt,
  ophBorInt,
  ophBxorInt,
  ophLand,
  ophLor,
};


fn ophNoop(
  state: *State,
  inst: Instruction
) State.StepResult {
  _ = state;
  _ = inst;
  return .{ .not_finished = {} };
}

fn ophLoadId(
  state: *State,
  inst: Instruction
) State.StepResult {
  const id = inst.data.id;
  const value = state.identifiers.getEntry(id).?.value;
  state.push(value);
  return .{ .not_finished = {} };
}

fn ophLoadParam(
  state: *State,
  inst: Instruction
) State.StepResult {
  const index = inst.data.id;
  const value = state.params[index];
  state.push(value);
  return .{ .not_finished = {} };
}

fn ophLoadLocal(
  state: *State,
  inst: Instruction
) State.StepResult {
  const index = inst.data.id;
  const value = state.locals[index];
  state.push(value);
  return .{ .not_finished = {} };
}

fn ophLoadData(
  state: *State,
  inst: Instruction
) State.StepResult {
  state.push( inst.data.variant );
  return .{ .not_finished = {} };
}

fn ophWriteLocal(
  state: *State,
  inst: Instruction
) State.StepResult {
  const index = inst.data.id;
  state.locals[index] = state.pop();
  return .{ .not_finished = {} };
}

fn ophEnd(
  state: *State,
  inst: Instruction
) State.StepResult {
  _ = state;
  _ = inst;
  return .{ .finished = .{ .none = {} } };
}

fn ophRet(
  state: *State,
  inst: Instruction
) State.StepResult {
  _ = inst;
  return .{ .finished = state.pop() };
}

fn ophErr(
  state: *State,
  inst: Instruction
) State.StepResult {
  _ = state;
  _ = inst;
  return .{ .failed = error.failed };
}

fn ophDrop(
  state: *State,
  inst: Instruction
) State.StepResult {
  const n = inst.data.variant.u2;
  var i: u16 = 0;
  while( i < n ) : ( i += 1 ) {
    _ = state.pop();
  }
  return .{ .not_finished = {} };
}

fn ophDup(
  state: *State,
  inst: Instruction
) State.StepResult {
  const n = inst.data.variant.u2;
  const v = state.peek();
  var i: u16 = 0;
  while( i < n ) : ( i += 1 ) {
    state.push(v);
  }
  return .{ .not_finished = {} };
}

fn ophSwap(
  state: *State,
  inst: Instruction
) State.StepResult {
  _ = inst;
  const b = state.pop();
  const a = state.pop();
  state.push(b);
  state.push(a);
  return .{ .not_finished = {} };
}

fn ophCastInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const f = castIntMap[@intCast(usize, t)];
  state.push(f(state.pop()));
  return .{ .not_finished = {} };
}

fn ophAddInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .ct_int = a.ct_int + b.ct_int },
    1 => Variant { .i1 = a.i1 + b.i1 },
    2 => Variant { .i2 = a.i2 + b.i2 },
    3 => Variant { .i4 = a.i4 + b.i4 },
    4 => Variant { .i8 = a.i8 + b.i8 },
    5 => Variant { .u1 = a.u1 + b.u1 },
    6 => Variant { .u2 = a.u2 + b.u2 },
    7 => Variant { .u4 = a.u4 + b.u4 },
    8 => Variant { .u8 = a.u8 + b.u8 },
    9 => Variant { .iptr = a.iptr + b.iptr },
    10 => Variant { .uptr = a.uptr + b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophSubInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .ct_int = a.ct_int - b.ct_int },
    1 => Variant { .i1 = a.i1 - b.i1 },
    2 => Variant { .i2 = a.i2 - b.i2 },
    3 => Variant { .i4 = a.i4 - b.i4 },
    4 => Variant { .i8 = a.i8 - b.i8 },
    5 => Variant { .u1 = a.u1 - b.u1 },
    6 => Variant { .u2 = a.u2 - b.u2 },
    7 => Variant { .u4 = a.u4 - b.u4 },
    8 => Variant { .u8 = a.u8 - b.u8 },
    9 => Variant { .iptr = a.iptr - b.iptr },
    10 => Variant { .uptr = a.uptr - b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophMulInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .ct_int = a.ct_int * b.ct_int },
    1 => Variant { .i1 = a.i1 * b.i1 },
    2 => Variant { .i2 = a.i2 * b.i2 },
    3 => Variant { .i4 = a.i4 * b.i4 },
    4 => Variant { .i8 = a.i8 * b.i8 },
    5 => Variant { .u1 = a.u1 * b.u1 },
    6 => Variant { .u2 = a.u2 * b.u2 },
    7 => Variant { .u4 = a.u4 * b.u4 },
    8 => Variant { .u8 = a.u8 * b.u8 },
    9 => Variant { .iptr = a.iptr * b.iptr },
    10 => Variant { .uptr = a.uptr * b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophDivInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .ct_int = @divFloor(a.ct_int, b.ct_int) },
    1 => Variant { .i1 = @divFloor(a.i1, b.i1) },
    2 => Variant { .i2 = @divFloor(a.i2, b.i2) },
    3 => Variant { .i4 = @divFloor(a.i4, b.i4) },
    4 => Variant { .i8 = @divFloor(a.i8, b.i8) },
    5 => Variant { .u1 = @divFloor(a.u1, b.u1) },
    6 => Variant { .u2 = @divFloor(a.u2, b.u2) },
    7 => Variant { .u4 = @divFloor(a.u4, b.u4) },
    8 => Variant { .u8 = @divFloor(a.u8, b.u8) },
    9 => Variant { .iptr = @divFloor(a.iptr, b.iptr) },
    10 => Variant { .uptr = @divFloor(a.uptr, b.uptr) },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophModInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .ct_int = @mod(a.ct_int, b.ct_int) },
    1 => Variant { .i1 = @mod(a.i1, b.i1) },
    2 => Variant { .i2 = @mod(a.i2, b.i2) },
    3 => Variant { .i4 = @mod(a.i4, b.i4) },
    4 => Variant { .i8 = @mod(a.i8, b.i8) },
    5 => Variant { .u1 = @mod(a.u1, b.u1) },
    6 => Variant { .u2 = @mod(a.u2, b.u2) },
    7 => Variant { .u4 = @mod(a.u4, b.u4) },
    8 => Variant { .u8 = @mod(a.u8, b.u8) },
    9 => Variant { .iptr = @mod(a.iptr, b.iptr) },
    10 => Variant { .uptr = @mod(a.uptr, b.uptr) },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophEqInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .bool = a.ct_int >= b.ct_int },
    1 => Variant { .bool = a.i1 >= b.i1 },
    2 => Variant { .bool = a.i2 >= b.i2 },
    3 => Variant { .bool = a.i4 >= b.i4 },
    4 => Variant { .bool = a.i8 >= b.i8 },
    5 => Variant { .bool = a.u1 >= b.u1 },
    6 => Variant { .bool = a.u2 >= b.u2 },
    7 => Variant { .bool = a.u4 >= b.u4 },
    8 => Variant { .bool = a.u8 >= b.u8 },
    9 => Variant { .bool = a.iptr >= b.iptr },
    10 => Variant { .bool = a.uptr >= b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophNeInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .bool = a.ct_int != b.ct_int },
    1 => Variant { .bool = a.i1 != b.i1 },
    2 => Variant { .bool = a.i2 != b.i2 },
    3 => Variant { .bool = a.i4 != b.i4 },
    4 => Variant { .bool = a.i8 != b.i8 },
    5 => Variant { .bool = a.u1 != b.u1 },
    6 => Variant { .bool = a.u2 != b.u2 },
    7 => Variant { .bool = a.u4 != b.u4 },
    8 => Variant { .bool = a.u8 != b.u8 },
    9 => Variant { .bool = a.iptr != b.iptr },
    10 => Variant { .bool = a.uptr != b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophLtInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .bool = a.ct_int < b.ct_int },
    1 => Variant { .bool = a.i1 < b.i1 },
    2 => Variant { .bool = a.i2 < b.i2 },
    3 => Variant { .bool = a.i4 < b.i4 },
    4 => Variant { .bool = a.i8 < b.i8 },
    5 => Variant { .bool = a.u1 < b.u1 },
    6 => Variant { .bool = a.u2 < b.u2 },
    7 => Variant { .bool = a.u4 < b.u4 },
    8 => Variant { .bool = a.u8 < b.u8 },
    9 => Variant { .bool = a.iptr < b.iptr },
    10 => Variant { .bool = a.uptr < b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophLeInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .bool = a.ct_int <= b.ct_int },
    1 => Variant { .bool = a.i1 <= b.i1 },
    2 => Variant { .bool = a.i2 <= b.i2 },
    3 => Variant { .bool = a.i4 <= b.i4 },
    4 => Variant { .bool = a.i8 <= b.i8 },
    5 => Variant { .bool = a.u1 <= b.u1 },
    6 => Variant { .bool = a.u2 <= b.u2 },
    7 => Variant { .bool = a.u4 <= b.u4 },
    8 => Variant { .bool = a.u8 <= b.u8 },
    9 => Variant { .bool = a.iptr <= b.iptr },
    10 => Variant { .bool = a.uptr <= b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophGtInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .bool = a.ct_int > b.ct_int },
    1 => Variant { .bool = a.i1 > b.i1 },
    2 => Variant { .bool = a.i2 > b.i2 },
    3 => Variant { .bool = a.i4 > b.i4 },
    4 => Variant { .bool = a.i8 > b.i8 },
    5 => Variant { .bool = a.u1 > b.u1 },
    6 => Variant { .bool = a.u2 > b.u2 },
    7 => Variant { .bool = a.u4 > b.u4 },
    8 => Variant { .bool = a.u8 > b.u8 },
    9 => Variant { .bool = a.iptr > b.iptr },
    10 => Variant { .bool = a.uptr > b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophGeInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .bool = a.ct_int >= b.ct_int },
    1 => Variant { .bool = a.i1 >= b.i1 },
    2 => Variant { .bool = a.i2 >= b.i2 },
    3 => Variant { .bool = a.i4 >= b.i4 },
    4 => Variant { .bool = a.i8 >= b.i8 },
    5 => Variant { .bool = a.u1 >= b.u1 },
    6 => Variant { .bool = a.u2 >= b.u2 },
    7 => Variant { .bool = a.u4 >= b.u4 },
    8 => Variant { .bool = a.u8 >= b.u8 },
    9 => Variant { .bool = a.iptr >= b.iptr },
    10 => Variant { .bool = a.uptr >= b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophShlInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .ct_int = a.ct_int << @intCast(u6, b.ct_int) },
    1 => Variant { .i1 = a.i1 << @intCast(u3, b.i1) },
    2 => Variant { .i2 = a.i2 << @intCast(u4, b.i2) },
    3 => Variant { .i4 = a.i4 << @intCast(u5, b.i4) },
    4 => Variant { .i8 = a.i8 << @intCast(u6, b.i8) },
    5 => Variant { .u1 = a.u1 << @intCast(u3, b.u1) },
    6 => Variant { .u2 = a.u2 << @intCast(u4, b.u2) },
    7 => Variant { .u4 = a.u4 << @intCast(u5, b.u4) },
    8 => Variant { .u8 = a.u8 << @intCast(u6, b.u8) },
    9 => Variant { .iptr = a.iptr << @intCast(u6, b.iptr) },
    10 => Variant { .uptr = a.uptr << @intCast(u6, b.uptr) },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophShrInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .ct_int = a.ct_int >> @intCast(u6, b.ct_int) },
    1 => Variant { .i1 = a.i1 >> @intCast(u3, b.i1) },
    2 => Variant { .i2 = a.i2 >> @intCast(u4, b.i2) },
    3 => Variant { .i4 = a.i4 >> @intCast(u5, b.i4) },
    4 => Variant { .i8 = a.i8 >> @intCast(u6, b.i8) },
    5 => Variant { .u1 = a.u1 >> @intCast(u3, b.u1) },
    6 => Variant { .u2 = a.u2 >> @intCast(u4, b.u2) },
    7 => Variant { .u4 = a.u4 >> @intCast(u5, b.u4) },
    8 => Variant { .u8 = a.u8 >> @intCast(u6, b.u8) },
    9 => Variant { .iptr = a.iptr >> @intCast(u6, b.iptr) },
    10 => Variant { .uptr = a.uptr >> @intCast(u6, b.uptr) },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophBandInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .ct_int = a.ct_int & b.ct_int },
    1 => Variant { .i1 = a.i1 & b.i1 },
    2 => Variant { .i2 = a.i2 & b.i2 },
    3 => Variant { .i4 = a.i4 & b.i4 },
    4 => Variant { .i8 = a.i8 & b.i8 },
    5 => Variant { .u1 = a.u1 & b.u1 },
    6 => Variant { .u2 = a.u2 & b.u2 },
    7 => Variant { .u4 = a.u4 & b.u4 },
    8 => Variant { .u8 = a.u8 & b.u8 },
    9 => Variant { .iptr = a.iptr & b.iptr },
    10 => Variant { .uptr = a.uptr & b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophBorInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .ct_int = a.ct_int | b.ct_int },
    1 => Variant { .i1 = a.i1 | b.i1 },
    2 => Variant { .i2 = a.i2 | b.i2 },
    3 => Variant { .i4 = a.i4 | b.i4 },
    4 => Variant { .i8 = a.i8 | b.i8 },
    5 => Variant { .u1 = a.u1 | b.u1 },
    6 => Variant { .u2 = a.u2 | b.u2 },
    7 => Variant { .u4 = a.u4 | b.u4 },
    8 => Variant { .u8 = a.u8 | b.u8 },
    9 => Variant { .iptr = a.iptr | b.iptr },
    10 => Variant { .uptr = a.uptr | b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophBxorInt(
  state: *State,
  inst: Instruction
) State.StepResult {
  const t = inst.data.variant.u1;
  const b = state.pop();
  const a = state.pop();

  const r = switch( t ) {
    0 => Variant { .ct_int = a.ct_int ^ b.ct_int },
    1 => Variant { .i1 = a.i1 ^ b.i1 },
    2 => Variant { .i2 = a.i2 ^ b.i2 },
    3 => Variant { .i4 = a.i4 ^ b.i4 },
    4 => Variant { .i8 = a.i8 ^ b.i8 },
    5 => Variant { .u1 = a.u1 ^ b.u1 },
    6 => Variant { .u2 = a.u2 ^ b.u2 },
    7 => Variant { .u4 = a.u4 ^ b.u4 },
    8 => Variant { .u8 = a.u8 ^ b.u8 },
    9 => Variant { .iptr = a.iptr ^ b.iptr },
    10 => Variant { .uptr = a.uptr ^ b.uptr },
    else => return .{ .failed = error.invalid_instruction_data },
  };

  state.push(r);

  return .{ .not_finished = {} };
}

fn ophLand(
  state: *State,
  inst: Instruction
) State.StepResult {
  _ = inst;
  const b = state.pop();
  const a = state.pop();

  const r = Variant { .bool = a.bool and b.bool };
  state.push(r);

  return .{ .not_finished = {} };
}

fn ophLor(
  state: *State,
  inst: Instruction
) State.StepResult {
  _ = inst;
  const b = state.pop();
  const a = state.pop();

  const r = Variant { .bool = a.bool or b.bool };
  state.push(r);

  return .{ .not_finished = {} };
}




const castIntFn = fn(a: Variant) Variant;

const castIntMap = [_]castIntFn {
  // 0000       0000 
  // ct_int ->  ct_int
  castIntNoop,
  // 0000       0001 
  // ct_int ->  i1
  castIntGen("ct_int", "i1"),
  // 0000       0010 
  // ct_int ->  i2
  castIntGen("ct_int", "i2"),
  // 0000       0011 
  // ct_int ->  i4
  castIntGen("ct_int", "i4"),
  // 0000       0100 
  // ct_int ->  i8
  castIntGen("ct_int", "i8"),
  // 0000       0101 
  // ct_int ->  u1
  castIntGen("ct_int", "u1"),
  // 0000       0110
  // ct_int ->  u2
  castIntGen("ct_int", "u2"),
  // 0000       0111 
  // ct_int ->  u4
  castIntGen("ct_int", "u4"),
  // 0000       1000
  // ct_int ->  u8
  castIntGen("ct_int", "u8"),
  // 0000       1001
  // ct_int ->  iptr
  castIntGen("ct_int", "iptr"),
  // 0000       1010
  // ct_int ->  uptr
  castIntGen("ct_int", "uptr"),
  // 0000 1011 (invalid)
  castIntInvalid,
  // 0000 1100 (invalid)
  castIntInvalid,
  // 0000 1101 (invalid)
  castIntInvalid,
  // 0000 1110 (invalid)
  castIntInvalid,
  // 0000 1111 (invalid)
  castIntInvalid,
  // 0001       0000 
  // i1     ->  ct_int
  castIntGen("i1", "ct_int"),
  // 0001       0001 
  // i1     ->  i1
  castIntNoop,
  // 0001       0010 
  // i1     ->  i2
  castIntGen("i1", "i2"),
  // 0001       0011 
  // i1     ->  i4
  castIntGen("i1", "i4"),
  // 0001       0100 
  // i1     ->  i8
  castIntGen("i1", "i8"),
  // 0001       0101 
  // i1     ->  u1
  castIntGen("i1", "u1"),
  // 0001       0110
  // i1     ->  u2
  castIntGen("i1", "u2"),
  // 0001       0111 
  // i1     ->  u4
  castIntGen("i1", "u4"),
  // 0001       1000
  // i1     ->  u8
  castIntGen("i1", "u8"),
  // 0001       1001
  // i1     ->  iptr
  castIntGen("i1", "iptr"),
  // 0001       1010
  // i1     ->  uptr
  castIntGen("i1", "uptr"),
  // 0001 1011 (invalid)
  castIntInvalid,
  // 0001 1100 (invalid)
  castIntInvalid,
  // 0001 1101 (invalid)
  castIntInvalid,
  // 0001 1110 (invalid)
  castIntInvalid,
  // 0001 1111 (invalid)
  castIntInvalid,
  // 0010       0000 
  // i2     ->  ct_int
  castIntGen("i2", "ct_int"),
  // 0010       0001 
  // i2     ->  i1
  castIntGen("i2", "i1"),
  // 0010       0010 
  // i2     ->  i2
  castIntNoop,
  // 0010       0011 
  // i2     ->  i4
  castIntGen("i2", "i4"),
  // 0010       0100 
  // i2     ->  i8
  castIntGen("i2", "i8"),
  // 0010       0101 
  // i2     ->  u1
  castIntGen("i2", "u1"),
  // 0010       0110
  // i2     ->  u2
  castIntGen("i2", "u2"),
  // 0010       0111 
  // i2     ->  u4
  castIntGen("i2", "u4"),
  // 0010       1000
  // i2     ->  u8
  castIntGen("i2", "u8"),
  // 0010       1001
  // i2     ->  iptr
  castIntGen("i2", "iptr"),
  // 0010       1010
  // i2     ->  uptr
  castIntGen("i2", "uptr"),
  // 0010 1011 (invalid)
  castIntInvalid,
  // 0010 1100 (invalid)
  castIntInvalid,
  // 0010 1101 (invalid)
  castIntInvalid,
  // 0010 1110 (invalid)
  castIntInvalid,
  // 0010 1111 (invalid)
  castIntInvalid,
  // 0011       0000 
  // i4     ->  ct_int
  castIntGen("i4", "ct_int"),
  // 0011       0001 
  // i4     ->  i1
  castIntGen("i4", "i1"),
  // 0011       0010 
  // i4     ->  i2
  castIntGen("i4", "i2"),
  // 0011       0011 
  // i4     ->  i4
  castIntNoop,
  // 0011       0100 
  // i4     ->  i8
  castIntGen("i4", "i8"),
  // 0011       0101 
  // i4     ->  u1
  castIntGen("i4", "u1"),
  // 0011       0110
  // i4     ->  u2
  castIntGen("i4", "u2"),
  // 0011       0111 
  // i4     ->  u4
  castIntGen("i4", "u4"),
  // 0011       1000
  // i4     ->  u8
  castIntGen("i4", "u8"),
  // 0011       1001
  // i4     ->  iptr
  castIntGen("i4", "iptr"),
  // 0011       1010
  // i4     ->  uptr
  castIntGen("i4", "uptr"),
  // 0011 1011 (invalid)
  castIntInvalid,
  // 0011 1100 (invalid)
  castIntInvalid,
  // 0011 1101 (invalid)
  castIntInvalid,
  // 0011 1110 (invalid)
  castIntInvalid,
  // 0011 1111 (invalid)
  castIntInvalid,
  // 0100       0000 
  // i8     ->  ct_int
  castIntGen("i8", "ct_int"),
  // 0100       0001 
  // i8     ->  i1
  castIntGen("i8", "i1"),
  // 0100       0010 
  // i8     ->  i2
  castIntGen("i8", "i2"),
  // 0100       0011 
  // i8     ->  i4
  castIntGen("i8", "i4"),
  // 0100       0100 
  // i8     ->  i8
  castIntNoop,
  // 0100       0101 
  // i8     ->  u1
  castIntGen("i8", "u1"),
  // 0100       0110
  // i8     ->  u2
  castIntGen("i8", "u2"),
  // 0100       0111 
  // i8     ->  u4
  castIntGen("i8", "u4"),
  // 0100       1000
  // i8     ->  u8
  castIntGen("i8", "u8"),
  // 0100       1001
  // i8     ->  iptr
  castIntGen("i8", "iptr"),
  // 0100       1010
  // i8     ->  uptr
  castIntGen("i8", "uptr"),
  // 0100 1011 (invalid)
  castIntInvalid,
  // 0100 1100 (invalid)
  castIntInvalid,
  // 0100 1101 (invalid)
  castIntInvalid,
  // 0100 1110 (invalid)
  castIntInvalid,
  // 0100 1111 (invalid)
  castIntInvalid,
  // 0101       0000 
  // u1     ->  ct_int
  castIntGen("u1", "ct_int"),
  // 0101       0001 
  // u1     ->  i1
  castIntGen("u1", "i1"),
  // 0101       0010 
  // u1     ->  i2
  castIntGen("u1", "i2"),
  // 0101       0011 
  // u1     ->  i4
  castIntGen("u1", "i4"),
  // 0101       0100 
  // u1     ->  i8
  castIntGen("u1", "i8"),
  // 0101       0101 
  // u1     ->  u1
  castIntNoop,
  // 0101       0110
  // u1     ->  u2
  castIntGen("u1", "u2"),
  // 0101       0111 
  // u1     ->  u4
  castIntGen("u1", "u4"),
  // 0101       1000
  // u1     ->  u8
  castIntGen("u1", "u8"),
  // 0101       1001
  // u1     ->  iptr
  castIntGen("u1", "iptr"),
  // 0101       1010
  // u1     ->  uptr
  castIntGen("u1", "uptr"),
  // 0101 1011 (invalid)
  castIntInvalid,
  // 0101 1100 (invalid)
  castIntInvalid,
  // 0101 1101 (invalid)
  castIntInvalid,
  // 0101 1110 (invalid)
  castIntInvalid,
  // 0101 1111 (invalid)
  castIntInvalid,
  // 0110       0000 
  // u2     ->  ct_int
  castIntGen("u2", "ct_int"),
  // 0110       0001 
  // u2     ->  i1
  castIntGen("u2", "i1"),
  // 0110       0010 
  // u2     ->  i2
  castIntGen("u2", "i2"),
  // 0110       0011 
  // u2     ->  i4
  castIntGen("u2", "i4"),
  // 0110       0100 
  // u2     ->  i8
  castIntGen("u2", "i8"),
  // 0110       0101 
  // u2     ->  u1
  castIntGen("u2", "u1"),
  // 0110       0110
  // u2     ->  u2
  castIntNoop,
  // 0110       0111 
  // u2     ->  u4
  castIntGen("u2", "u4"),
  // 0110       1000
  // u2     ->  u8
  castIntGen("u2", "u8"),
  // 0110       1001
  // u2     ->  iptr
  castIntGen("u2", "iptr"),
  // 0110       1010
  // u2     ->  uptr
  castIntGen("u2", "uptr"),
  // 0110 1011 (invalid)
  castIntInvalid,
  // 0110 1100 (invalid)
  castIntInvalid,
  // 0110 1101 (invalid)
  castIntInvalid,
  // 0110 1110 (invalid)
  castIntInvalid,
  // 0110 1111 (invalid)
  castIntInvalid,
  // 0111       0000 
  // u4     ->  ct_int
  castIntGen("u4", "ct_int"),
  // 0111       0001 
  // u4     ->  i1
  castIntGen("u4", "i1"),
  // 0111       0010 
  // u4     ->  i2
  castIntGen("u4", "i2"),
  // 0111       0011 
  // u4     ->  i4
  castIntGen("u4", "i4"),
  // 0111       0100 
  // u4     ->  i8
  castIntGen("u4", "i8"),
  // 0111       0101 
  // u4     ->  u1
  castIntGen("u4", "u1"),
  // 0111       0110
  // u4     ->  u2
  castIntGen("u4", "u2"),
  // 0111       0111 
  // u4     ->  u4
  castIntNoop,
  // 0111       1000
  // u4     ->  u8
  castIntGen("u4", "u8"),
  // 0111       1001
  // u4     ->  iptr
  castIntGen("u4", "iptr"),
  // 0111       1010
  // u4     ->  uptr
  castIntGen("u4", "uptr"),
  // 0111 1011 (invalid)
  castIntInvalid,
  // 0111 1100 (invalid)
  castIntInvalid,
  // 0111 1101 (invalid)
  castIntInvalid,
  // 0111 1110 (invalid)
  castIntInvalid,
  // 0111 1111 (invalid)
  castIntInvalid,
  // 1000       0000 
  // u8     ->  ct_int
  castIntGen("u8", "ct_int"),
  // 1000       0001 
  // u8     ->  i1
  castIntGen("u8", "i1"),
  // 1000       0010 
  // u8     ->  i2
  castIntGen("u8", "i2"),
  // 1000       0011 
  // u8     ->  i4
  castIntGen("u8", "i4"),
  // 1000       0100 
  // u8     ->  i8
  castIntGen("u8", "i8"),
  // 1000       0101 
  // u8     ->  u1
  castIntGen("u8", "u1"),
  // 1000       0110
  // u8     ->  u2
  castIntGen("u8", "u2"),
  // 1000       0111 
  // u8     ->  u4
  castIntGen("u8", "u4"),
  // 1000       1000
  // u8     ->  u8
  castIntNoop,
  // 1000       1001
  // u8     ->  iptr
  castIntGen("u8", "iptr"),
  // 1000       1010
  // u8     ->  uptr
  castIntGen("u8", "uptr"),
  // 1000 1011 (invalid)
  castIntInvalid,
  // 1000 1100 (invalid)
  castIntInvalid,
  // 1000 1101 (invalid)
  castIntInvalid,
  // 1000 1110 (invalid)
  castIntInvalid,
  // 1000 1111 (invalid)
  castIntInvalid,
  // 1001       0000 
  // iptr   ->  ct_int
  castIntGen("iptr", "ct_int"),
  // 1001       0001 
  // iptr   ->  i1
  castIntGen("iptr", "i1"),
  // 1001       0010 
  // iptr   ->  i2
  castIntGen("iptr", "i2"),
  // 1001       0011 
  // iptr   ->  i4
  castIntGen("iptr", "i4"),
  // 1001       0100 
  // iptr   ->  i8
  castIntGen("iptr", "i8"),
  // 1001       0101 
  // iptr   ->  u1
  castIntGen("iptr", "u1"),
  // 1001       0110
  // iptr   ->  u2
  castIntGen("iptr", "u2"),
  // 1001       0111 
  // iptr   ->  u4
  castIntGen("iptr", "u4"),
  // 1001       1000
  // iptr   ->  u8
  castIntGen("iptr", "u8"),
  // 1001       1001
  // iptr   ->  iptr
  castIntNoop,
  // 1001       1010
  // iptr   ->  uptr
  castIntGen("iptr", "uptr"),
  // 1001 1011 (invalid)
  castIntInvalid,
  // 1001 1100 (invalid)
  castIntInvalid,
  // 1001 1101 (invalid)
  castIntInvalid,
  // 1001 1110 (invalid)
  castIntInvalid,
  // 1001 1111 (invalid)
  castIntInvalid,
  // 1010       0000 
  // uptr   ->  ct_int
  castIntGen("uptr", "ct_int"),
  // 1010       0001 
  // uptr   ->  i1
  castIntGen("uptr", "i1"),
  // 1010       0010 
  // uptr   ->  i2
  castIntGen("uptr", "i2"),
  // 1010       0011 
  // uptr   ->  i4
  castIntGen("uptr", "i4"),
  // 1010       0100 
  // uptr   ->  i8
  castIntGen("uptr", "i8"),
  // 1010       0101 
  // uptr   ->  u1
  castIntGen("uptr", "u1"),
  // 1010       0110
  // uptr   ->  u2
  castIntGen("uptr", "u2"),
  // 1010       0111 
  // uptr   ->  u4
  castIntGen("uptr", "u4"),
  // 1010       1000
  // uptr   ->  u8
  castIntGen("uptr", "u8"),
  // 1010       1001
  // uptr   ->  iptr
  castIntGen("uptr", "iptr"),
  // 1010       1010
  // uptr   ->  uptr
  castIntNoop,
};

fn castIntNoop(a: Variant) Variant {
  return a;
}

fn castIntInvalid(a: Variant) Variant {
  _ = a;
  @panic("invalid castInt data.");
}

fn castIntGen(
  comptime A: []const u8,
  comptime B: []const u8
) castIntFn {
  const gen = struct {
    fn f(a: Variant) Variant {
      var res: Variant = undefined;
      const T = @TypeOf(@field(res, B));
      res = @unionInit(Variant, B, @intCast(T, @field(a, A)));
      return res;
    }
  }.f;
  return gen;
}

