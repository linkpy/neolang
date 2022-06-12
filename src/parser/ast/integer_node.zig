/// Structure representing an integer.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../../nl.zig");
const flags = nl.parser.ast.flags;
const Location = nl.diagnostic.Location;
const Type =  nl.types.Type;

const IntegerNode = @This();



/// Value of the integer.
value: i64, // TODO use bigint
/// Type flag of the integer.
type_flag: TypeFlag, 

/// Start location of the integer.
start_location: Location,
/// End location of the integer.
end_location: Location,



/// Gets the start location of the node.
///
pub fn getStartLocation(
  self: IntegerNode
) Location {
  return self.start_location;
}

/// Gets the end location of the node.
///
pub fn getEndLocation(
  self: IntegerNode
) Location {
  return self.end_location;
}



/// Gets the type of the expression node.
///
pub fn getType(
  self: IntegerNode
) ?Type {
  return switch( self.type_flag ) {
    .ct => Type.CtInt,
    .i1 => Type.I1,
    .i2 => Type.I2,
    .i4 => Type.I4,
    .i8 => Type.I8,
    .u1 => Type.U1,
    .u2 => Type.U2,
    .u4 => Type.U4,
    .u8 => Type.U8,
    .iptr => Type.IPtr,
    .uptr => Type.UPtr,
  };
}



/// Available type flags.
///
pub const TypeFlag = enum {
  ct, 
  i1, i2, i4, i8,
  u1, u2, u4, u8,
  iptr, uptr
};
