/// Object using a `Reader` to convert some code into tokens.
///



const std = @import("std");

const nl = @import("../nl.zig");
const Reader = nl.parser.Reader;
const FileStorage = nl.storage.File;
const Location = nl.diagnostic.Location;
const Diagnostics = nl.diagnostic.Diagnostics;

const FileID = FileStorage.FileID;

const Lexer = @This();



/// `Reader` used by the lexer.
reader: Reader,
/// Diagnostics used in case of error.
diagnostics: *Diagnostics,



/// Creates a new lexer from scratch.
///
/// #### Parameters
///
/// - `file_id`: ID of the file associated with the sources.
/// - `src`: Source code to tokenize.
/// - `diags`: Reference to the diagnostics used in case of error.
///
/// #### Returns
///
/// A new `Lexer`.
///
pub fn init(
  file_id: FileID,
  src: []const u8,
  diags: *Diagnostics
) Lexer {
  return Lexer {
    .reader = Reader.init(src, file_id),
    .diagnostics = diags,
  };
}

/// Creates a new lexer from a `FileStorage`.
///
/// #### Parameters
///
/// - `file_storage`: File storage used to request the file's source.
/// - `file_id`: ID of the file to be tokenized.
/// - `diags`: Reference to the diagnostics used in case of error.
///
/// #### Returns
///
/// A new `Lexer`.
///
pub fn fromFileStorage(
  file_storage: *FileStorage,
  file_id: FileID,
  diags: *Diagnostics
) !Lexer {
  return init(
    file_id,
    try file_storage.getSource(file_id, true),
    diags
  );
}



/// Raads a single token from the source.
///
/// #### Returns 
///
/// A readed token. Returns `null` when reaching the end of the file.
///
pub fn readToken(
  self: *Lexer
) Error!?Token {
  // used for unrecognized input diagnostics.
  const start_loc = self.reader.location;
  var last_loc = start_loc;

  var unrecognized_input_detected = false;

  // loops until a recognized input is detected.
  while( self.reader.peekChar() ) |char| {
    const token: ?Token = switch( char ) {
      ' ', '\t', '\n', '\r' => self.readWhitespaceToken(),
      ':' => self.readSingleCharacterToken(.colon),
      '(' => self.readSingleCharacterToken(.left_par),
      ')' => self.readSingleCharacterToken(.right_par),
      '[' => self.readSingleCharacterToken(.left_sqr),
      ']' => self.readSingleCharacterToken(.right_sqr),
      ',' => self.readSingleCharacterToken(.comma),
      ';' => self.readSingleCharacterToken(.semicolon),
      '!' => self.readSingleCharacterToken(.exclam),
      '#' => self.readSingleCharacterToken(.pound),
      '+' => self.readSingleCharacterToken(.plus),
      '-' => self.readSingleCharacterToken(.minus),
      '*' => self.readSingleCharacterToken(.star),
      '/' => self.readCommentToken() 
        orelse self.readDocumentationToken()
        orelse self.readSingleCharacterToken(.slash),
      '%' => self.readSingleCharacterToken(.percent),
      '=' => self.readSingleCharacterToken(.equal),
      '<' => self.readSingleCharacterToken(.left_ang),
      '>' => self.readSingleCharacterToken(.right_ang),
      '&' => self.readSingleCharacterToken(.ampersand),
      '|' => self.readSingleCharacterToken(.pipe),
      '~' => self.readSingleCharacterToken(.tilde),
      '^' => self.readSingleCharacterToken(.charet),
      '"' => try self.readStringToken(),
      else =>
        if( std.ascii.isDigit(char) )
          self.readIntegerToken()
        else if( std.ascii.isAlpha(char) )
          self.readKeywordOrIdentifierToken()
        else
          null,
    };

    // the input was recognized in this iteration
    if( token ) |tok| {
      // if in a previous iteration of the loop we encountered unrecognized 
      // input
      if( unrecognized_input_detected ) {
        // undo the readed token so we can return an error without skipping it.
        self.reader.location = last_loc;

        try self.diagnostics.pushError(
          "Unrecognized input.", .{ },
          start_loc,
          last_loc
        );

        return Error.unrecognized_input;
      }

      return tok;
      
    // the input wasn't recognized in this iteration
    } else {
      self.reader.advance(1);

      unrecognized_input_detected = true;
      last_loc = self.reader.location;
    }
  }

  // if we reached the end of file just after reading some unrecognized input
  if( unrecognized_input_detected ) {
    try self.diagnostics.pushError(
      "Unrecognized input.", .{ },
      start_loc,
      last_loc
    );

    return Error.unrecognized_input;
  }

  return null;
}



/// Reads a whitespace token.
///
/// #### Returns
/// 
/// The readed token.
///
fn readWhitespaceToken(
  self: *Lexer
) Token {
  const start_loc = self.reader.location;

  while( self.reader.peekChar() ) |char| {
    switch( char ) {
      ' ', '\t', '\n', '\r' => self.reader.advance(1),
      else => break,
    }
  }

  const end_loc = self.reader.location;
  return Token {
    .kind = .whitespace,
    .value = self.reader.sliceFrom(start_loc.index),
    .start_location = start_loc,
    .end_location = end_loc,
  };
}

/// Reads a comment token.
/// 
fn readCommentToken(
  self: *Lexer
) ?Token {
  const start_loc = self.reader.location;

  if( !self.checkForCommentMarker() ) 
    return null;
  
  while( self.reader.peekChar() ) |char| {
    if( char == '\n' ) {
      if( !self.checkForCommentMarker() )
        break;
    }

    self.reader.advance(1);
  }

  return Token {
    .kind = .comment,
    .value = self.reader.sliceFrom(start_loc.index),
    .start_location = start_loc,
    .end_location = self.reader.location,
  };
}

fn readDocumentationToken(
  self: *Lexer
) ?Token {
  const start_loc = self.reader.location;

  if( !self.checkForDocumentationMarker() ) 
    return null;
  
  while( self.reader.peekChar() ) |char| {
    if( char == '\n' ) {
      if( !self.checkForDocumentationMarker() )
        break;
    }

    self.reader.advance(1);
  }

  return Token {
    .kind = .documentation,
    .value = self.reader.sliceFrom(start_loc.index),
    .start_location = start_loc,
    .end_location = self.reader.location,
  };
}

/// Reads an integer token.
///
/// #### Returns
/// 
/// The readed token.
///
fn readIntegerToken(
  self: *Lexer
) Token {
  const start_loc = self.reader.location;

  while( self.reader.peekChar() ) |char| {
    if( std.ascii.isDigit(char) )
      self.reader.advance(1)
    else 
      break;
  }

  const end_loc = self.reader.location;
  return Token {
    .kind = .integer,
    .value = self.reader.sliceFrom(start_loc.index),
    .start_location = start_loc,
    .end_location = end_loc,
  };
}

/// Reads a single character token.
///
/// #### Parameters
///
/// - `kind`: The kind of the returned token.
///
/// #### Returns
/// 
/// The readed token.
///
fn readSingleCharacterToken(
  self: *Lexer, 
  kind: Token.Kind,
) Token {
  const start_loc = self.reader.location;
  const value = self.reader.slice(1);
  self.reader.advance(1);
  const end_loc = self.reader.location;

  return Token {
    .kind = kind,
    .value = value,
    .start_location = start_loc,
    .end_location = end_loc,
  };
}

/// Reads a string token.
///
/// This function can return an error if the end of file is reached while 
/// reading the string token.
///
/// #### Returns
/// 
/// The readed token.
///
fn readStringToken(
  self: *Lexer
) Error!Token {
  const start_loc = self.reader.location;

  self.reader.advance(1); // skips the first "

  while( self.reader.peekChar() ) |char| {
    self.reader.advance(1);

    if( char == '"' )
      break;
  } else {
    try self.diagnostics.pushError(
      "Unexpected end of string.", .{},
      start_loc,
      self.reader.location
    );

    return error.unfinished_string;
  }
  
  const end_loc = self.reader.location;
  return Token {
    .kind = .string,
    .value = self.reader.sliceFrom(start_loc.index),
    .start_location = start_loc,
    .end_location = end_loc
  };
}



/// Tries to read a keyword token. If no keyword are recognized, reads an 
/// identifier token.
///
/// #### Returns
/// 
/// The readed token.
///
fn readKeywordOrIdentifierToken(
  self: *Lexer
) Token {
  return
    self.checkAndReadKeywordToken(.kw_const, "const") orelse
    self.checkAndReadKeywordToken(.kw_proc, "proc") orelse
    self.checkAndReadKeywordToken(.kw_is, "is") orelse
    self.checkAndReadKeywordToken(.kw_recursive, "recursive") orelse
    self.checkAndReadKeywordToken(.kw_entry_point, "entry_point") orelse
    self.checkAndReadKeywordToken(.kw_param, "param") orelse
    self.checkAndReadKeywordToken(.kw_returns, "returns") orelse
    self.checkAndReadKeywordToken(.kw_begin, "begin") orelse
    self.checkAndReadKeywordToken(.kw_return, "return") orelse
    self.checkAndReadKeywordToken(.kw_then, "then") orelse
    self.checkAndReadKeywordToken(.kw_else, "else") orelse
    self.checkAndReadKeywordToken(.kw_end, "end") orelse
    self.checkAndReadKeywordToken(.kw_mut, "mut") orelse
    self.checkAndReadKeywordToken(.kw_imm, "imm") orelse
    self.checkAndReadKeywordToken(.kw_or, "or") orelse
    self.checkAndReadKeywordToken(.kw_and, "and") orelse
    self.checkAndReadKeywordToken(.kw_not, "not") orelse
    self.readIdentifierToken();
}

/// Checks if the input matches the given token value. 
///
/// #### Parameters 
///
/// - `kind`: Kind of the returned token.
/// - `keyword`: Value of the keyword to check.
///
/// #### Returns
///
/// If, at the current reader's location, the input matches with `keyword` (and
/// isn't a longer identifier starting with `keyword`), returns a token. 
/// Otherwise, return false.
///
fn checkAndReadKeywordToken(
  self: *Lexer,
  kind: Token.Kind,
  keyword: []const u8
) ?Token {
  if( self.reader.isEndOfFileAt(keyword.len) )
    return null;
  
  const value = self.reader.slice(keyword.len);

  if( std.mem.eql(u8, keyword, value) ) {
    // checks the keyword isn't part of a longer identifier
    if( self.reader.peekCharAt(keyword.len) ) |char| {
      if( std.ascii.isAlNum(char) or char == '_' ) {
        return null;
      }
    }

    const start_loc = self.reader.location;
    self.reader.advance(keyword.len);
    const end_loc = self.reader.location;

    return Token {
      .kind = kind,
      .value = value,
      .start_location = start_loc,
      .end_location = end_loc
    };
  }

  return null;
}

/// Reads an identifier token.
///
/// #### Returns
/// 
/// The readed token.
///
fn readIdentifierToken(
  self: *Lexer
) Token {
  const start_loc = self.reader.location;

  while( self.reader.peekChar() ) |char| {
    if( std.ascii.isAlNum(char) or char == '_' )
      self.reader.advance(1)
    else 
      break;
  }

  const end_loc = self.reader.location;
  return Token {
    .kind = .identifier,
    .value = self.reader.sliceFrom(start_loc.index),
    .start_location = start_loc,
    .end_location = end_loc,
  };
}



fn checkForCommentMarker(
  self: Lexer
) bool {
  if( self.reader.isEndOfFileAt(1) )
    return false;
  
  return std.mem.eql(u8, self.reader.slice(2), "//") 
    and (self.reader.peekCharAt(2) orelse 0) != '/';
}

fn checkForDocumentationMarker(
  self: *Lexer
) bool {
  if( self.reader.isEndOfFileAt(2) ) 
    return false;

  return std.mem.eql(u8, self.reader.slice(3), "///");
}



/// Object representing a token returned by a `Lexer`.
///
pub const Token = struct {
  /// Kind of the token.
  kind: Kind,
  /// Value of the token. It is a slice from the source.
  value: []const u8,
  /// Starting location of the token.
  start_location: Location,
  /// Ending location of the token.
  end_location: Location,



  /// Kinds of token.
  ///
  pub const Kind = enum {
    // spaces
    whitespace,
    comment,
    documentation,
    // symbols
    colon,
    left_par,
    right_par,
    left_sqr,
    right_sqr,
    semicolon,
    comma,
    exclam,
    pound,
    // operator symbols
    plus,
    minus,
    star,
    slash,
    percent,
    equal,
    left_ang, 
    right_ang,
    ampersand,
    pipe,
    tilde,
    charet,
    // atoms
    identifier,
    integer,
    string,
    // keywords
    kw_const,
    kw_proc,
    kw_is,
    kw_recursive,
    kw_entry_point,
    kw_param,
    kw_returns,
    kw_begin,
    kw_return,
    kw_then,
    kw_else,
    kw_end,
    kw_mut,
    kw_imm,
    kw_or,
    kw_and,
    kw_not,
  };
};

pub const Error = error {
  unrecognized_input,
  unfinished_string,
} || Diagnostics.Error;
