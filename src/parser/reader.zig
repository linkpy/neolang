/// Object handling reading a string input, character by character.
///



const std = @import("std");

const nl = @import("../nl.zig");
const FileID = nl.storage.File.FileID;
const Location = nl.diagnostic.Location;

const Reader = @This();



/// Source used by the reader.
source: []const u8,
/// Current location of the reader in the source.
location: Location,



/// Initializes a new Reader.
///
/// #### Parameters
/// 
/// - `src`: source to be used by the reader.
/// - `file`: File ID associated with the source.
///
/// #### Returns
///
/// A new Reader.
///
pub fn init(
  src: []const u8,
  file: FileID,
) Reader {
  return Reader {
    .source = src,
    .location = .{
      .file = file,
    },
  };
}



/// Advances the reader's location by N characters.
///
/// This correctly updates the location and keep track of line and column 
/// position.
///
/// #### Notes
///
/// The location isn't updated once the reader reaches the end of 
/// the file.
///
/// #### Parameter
///
/// - `n`: Number of character to advances.
/// 
pub fn advance(
  self: *Reader,
  n: usize
) void {
  var i: usize = 0;
  while (i < n) : (i += 1) {
    const char = self.peekChar() orelse return;

    switch( char ) {
      '\n' => {
        self.location.column = 0;
        self.location.line += 1;
      },
      else => {
        self.location.column += 1;
      }
    }

    self.location.index += 1;
  }
}



/// Peeks the character at the current location of the reader.
///
/// #### Returns
///
/// The character at the current location or `null` if the reader is at the 
/// end of the file.
///
pub fn peekChar(
  self: Reader,
) ?u8 {
  if( self.isEndOfFile() )
    return null;

  return self.source[self.location.index];
}

/// Peeks the character at the given position, corresponding to the current
/// location plus the given offset.
///
/// #### Parameters
///
/// - `offset`: Offset, in characters, from the current reader location.
///
/// #### Returns
///
/// The character at the given location or `null` if the given location is at
/// the end of the file.
///
pub fn peekCharAt(
  self: Reader,
  offset: usize
) ?u8 {
  if( self.isEndOfFileAt(offset) ) 
    return null;
  
  return self.source[self.location.index + offset];
}

/// Checks if the character at the current reader location is the same as the 
/// given one. 
///
/// Both characters are equal, the reader advances for 1 characters.
///
/// #### Parameters 
///
/// - `char`: Expected character.
///
/// #### Returns
///
/// `true` if both characters are the same, `false` otherwise.
///
pub fn checkChar(
  self: *Reader,
  char: u8
) bool {
  var current_char = self.peekChar() orelse return false;

  if( current_char == char ) {
    self.advance(1);
    return true;
  }

  return false;
}



/// Obtains a slice of a given length from the source, starting at the current
/// location.
///
/// #### Note
///
/// This function doesn't check if the requested slice resides in the source and
/// thus doesn't do bound checking.
///
/// #### Parameters
///
/// - `len`: Length of the requested slice.
///
/// #### Returns 
///
/// A slice of the reader's source, starting at the current location and having
/// `len` characters in length.
///
pub fn slice(
  self: Reader,
  len: usize
) []const u8 {
  return self.source[
    self.location.index .. self.location.index + len
  ];
}

/// Obtains a slice from the source, from the given index to t he current 
/// reader location.
///
/// #### Note
///
/// This function doesn't check if the requested slice resides in the source and
/// thus doesn't do bound checking.
///
/// #### Parameters
///
/// - `idx`: starting index of the slice.
///
/// #### Returns 
///
/// A slice of the reader's source, starting at the given index and finishing
/// at the reader's current location.
///
pub fn sliceFrom(
  self: Reader,
  index: usize
) []const u8 {
  return self.source[
    index .. self.location.index
  ];
}



/// Checks if the reader has reached the end of the source.
///
/// #### Returns
///
/// `true` if the reader has reached the end of the source, `false` otherwise.
///
pub fn isEndOfFile(
  self: Reader
) bool {
  return self.location.index >= self.source.len;
}

/// Checks if the given position, represented as an offset from the current
/// reader location, is at or after the end of the file.
///
/// #### Returns
///
/// `true` if the given position is at or after end of the source, `false` 
/// otherwise.
///
pub fn isEndOfFileAt(
  self: Reader,
  offset: usize
) bool {
  return self.location.index + offset >= self.source.len;
}
