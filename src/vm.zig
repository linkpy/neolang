
pub const bytecode = @import("./vm/bytecode.zig");

pub const BytecodeWriter = @import("./vm/bytecode_writer.zig");
pub const BytecodeCompiler = @import("./vm/bytecode_compiler.zig");
pub const Evaluator = @import("./vm/evaluator.zig");

pub const Variant = @import("./vm/variant.zig").Variant;