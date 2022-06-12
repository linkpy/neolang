/// Structure representing a location in a source file.
///



const std = @import("std");

const nl = @import("../nl.zig");
const FileID = nl.storage.File.FileID;

const Location = @This();



/// File containing the location.
file: FileID,
/// Index from the start of the source code.
index: usize = 0,
/// Line index of the location.
line: usize = 0,
/// Column index of the location.
column: usize = 0,
