/// Utility structure to handle a collection of diagnostics.
///



const std = @import("std");

const nl = @import("../nl.zig");
const Diagnostic = nl.diagnostic.Diagnostic;
const Location = nl.diagnostic.Location;

const Diagnostics = @This();



/// Allocator used to render the messages.
alloc: std.mem.Allocator,
/// List of diagnostics.
list: std.ArrayList(Diagnostic),



/// Initialises a new instance.
///
pub fn init(
  alloc: std.mem.Allocator,
) Diagnostics {
  return Diagnostics {
    .alloc = alloc,
    .list = std.ArrayList(Diagnostic).init(alloc)
  };
}

/// Deinitialises the instance, freeing all of the held diagnostics and their
/// messages.
///
pub fn deinit(
  self: *Diagnostics
) void {
  self.clear();
  self.list.deinit();
}



/// Pushes an error diagnostic. Uses `std.fmt.format` for formatting.
///
/// #### Parameters
/// 
/// - `fmt`: Format string for the message.
/// - `args`: Tuple for the format string arguments.
/// - `start_loc`: Start location of the diagnostic.
/// - `end_loc`: End location of the diagnostic.
///
pub fn pushError(
  self: *Diagnostics,
  comptime fmt: []const u8,
  args: anytype,
  start_loc: Location,
  end_loc: Location,
) Error!void {
  var msg = try std.fmt.allocPrint(self.alloc, fmt, args);
  try self.pushDiagnostic(.error_, msg, true, start_loc, end_loc, false);
}

/// Pushes aa note diagnostic. Uses `std.fmt.format` for formatting.
///
/// #### Parameters
/// 
/// - `fmt`: Format string for the message.
/// - `args`: Tuple for the format string arguments.
/// - `start_loc`: Start location of the diagnostic.
/// - `end_loc`: End location of the diagnostic.
///
pub fn pushNote(
  self: *Diagnostics,
  comptime fmt: []const u8,
  args: anytype,
  primary: bool,
  start_loc: Location,
  end_loc: Location,
) Error!void {
  var msg = try std.fmt.allocPrint(self.alloc, fmt, args);
  try self.pushDiagnostic(.note, msg, primary, start_loc, end_loc, false);
}

/// Pushes a verbose diagnostic. Uses `std.fmt.format` for formatting.
///
/// #### Parameters
/// 
/// - `fmt`: Format string for the message.
/// - `args`: Tuple for the format string arguments.
/// - `start_loc`: Start location of the diagnostic.
/// - `end_loc`: End location of the diagnostic.
///
pub fn pushVerbose(
  self: *Diagnostics,
  comptime fmt: []const u8,
  args: anytype,
  primary: bool,
  start_loc: Location,
  end_loc: Location,
) Error!void {
  var msg = try std.fmt.allocPrint(self.alloc, fmt, args);
  try self.pushDiagnostic(.verbose, msg, primary, start_loc, end_loc, false);
}

/// Pushes a generic diagnostic.
///
/// #### Parameters 
///
/// - `kind`: Kind of diagnostic.
/// - `msg`: Message of the diagnostic.
/// - `start_loc`: Start location of the diagnostic.
/// - `end_loc`: End location of the diagnostic.
/// - `dupe_msg`: If true, `msg` will be duplicated on the heap.
///
pub fn pushDiagnostic(
  self: *Diagnostics,
  kind: Diagnostic.Kind,
  msg: []const u8,
  primary: bool,
  start_loc: Location,
  end_loc: Location,
  dupe_msg: bool,
) Error!void {
  const diag = Diagnostic {
    .kind = kind,
    .message = if( dupe_msg ) try self.alloc.dupe(u8, msg) else msg,
    .primary = primary,
    .start_location = start_loc,
    .end_location = end_loc
  }; 

  try self.list.append(diag);
}



/// Clears the list of diagnostics, freeing the memory they use.
///
pub fn clear(
  self: *Diagnostics
) void {
  for( self.list.items ) |*diag| {
    diag.deinit(self.alloc);
  }

  self.list.clearAndFree();
}



pub const Error = std.mem.Allocator.Error || std.fmt.AllocPrintError;