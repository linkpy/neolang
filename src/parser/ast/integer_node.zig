/// Structure representing an integer.
///



const std = @import("std");
const Location = @import("../../diagnostic/location.zig");
const Token = @import("../lexer.zig").Token;

const flags = @import("./flags.zig");

const Allocator = std.mem.Allocator;
const IntegerNode = @This();



/// Value of the integer.
value: i64, // TODO use bigint

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
