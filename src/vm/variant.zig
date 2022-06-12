
const nl = @import("../nl.zig");
const Type = nl.types.Type;



/// Union representing a compile-time value.
///
pub const Variant = union(enum) {
  /// No value.
  none: void,

  // TODO: find a better way of handling integer types

  /// Compile-time integer.
  ct_int: i64, // TODO use bigint

  /// Signed integers.
  i1: i8, i2: i16, i4: i32, i8: i64,
  /// Unsigned integers.
  u1: u8, u2: u16, u4: u32, u8: u64,
  /// Pointer-sized integers.
  iptr: isize, uptr: usize, // TODO use bigint

  /// Boolean
  bool: bool,

  /// Type.
  type: Type,



  /// Gets the type of the variant;
  ///
  pub fn getType(
    self: Variant
  ) ?Type {
    return switch( self ) {
      .none => null,
      .ct_int => Type.CtInt,
      .i1 => Type.I1, .i2 => Type.I2, .i4 => Type.I4, .i8 => Type.I8,
      .u1 => Type.U1, .u2 => Type.U2, .u4 => Type.U4, .u8 => Type.U8,
      .iptr => Type.IPtr, .uptr => Type.UPtr,
      .bool => Type.Bool,
      .type => Type.TypeT,
    };
  }


};
