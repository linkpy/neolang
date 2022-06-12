
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
const _castIntMap: [256]castIntFn = blk: {
  const fields = .{
    "ct_int", "i1", "i2", "i4", "i8", "u1", "u2", "u4", "u8", "iptr", "uptr"
  };

  comptime var fns: [256]castIntFn = undefined;

  comptime var i: usize = 0;
  inline while( i < 256 ) : ( i+= 1 ) {
    const from_type = (i >> 4) & 0xF;
    const to_type = i & 0xF;

    if( from_type < fields.len and to_type < fields.len ) {
      fns[i] = if( from_type == to_type )
        castIntNoop
      else 
        castIntGen(fields[from_type], fields[to_type]);
    } else {
      fns[i] = castIntInvalid;
    }
  }

  break :blk fns;
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

