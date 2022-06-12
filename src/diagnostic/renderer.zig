/// Configurable object used to render `Diagnostic` structs to the console.
///



const std = @import("std");
const Writer = std.fs.File.Writer;

const nl = @import("../nl.zig");
const Diagnostic = nl.diagnostic.Diagnostic;
const Diagnostics = nl.diagnostic.Diagnostics;
const FileStorage = nl.storage.File;

const Renderer = @This();



/// Output writer used to write the diagnostics.
writer: Writer,
/// Style configuration of the renderer.
style: Style,



/// Initialises a new instance.
///
pub fn init(
  writer: Writer,
  style: Style,
) Renderer {
  return Renderer {
    .writer = writer,
    .style = style,
  };
}



/// Renders all of the diagnostics.
///
/// #### Parameters
///
/// - `file_source`: Storage containing the files to retrieve the necessary 
///   source code.
/// - `diagnostics`: Diagnostics to render.
///
pub fn renderAll(
  self: *Renderer,
  file_storage: *FileStorage,
  diagnostics: Diagnostics
) !void {
  for( diagnostics.list.items ) |diag| {
    try self.render(file_storage, &diag);
  }
}

/// Renders the given diagnostic to the console.
///
/// #### Parameters
///
/// - `file_source`: Storage containing the files to retrieve the necessary 
///   source code.
/// - `diagnostic`: Diagnostic to render.
///
pub fn render(
  self: *Renderer,
  file_storage: *FileStorage,
  diagnostic: *const Diagnostic
) !void {
  try self.renderDiagnosticHeader(file_storage, diagnostic);
  try self.renderDiagnosticCode(file_storage, diagnostic);
}

/// Renders the header of the given diagnostic.
///
/// #### Parameters
///
/// - `file_source`: Storage containing the files to retrieve the necessary 
///   source code.
/// - `diagnostic`: Diagnostic to render.
///
fn renderDiagnosticHeader(
  self: *Renderer,
  file_storage: *FileStorage,
  diagnostic: *const Diagnostic
) !void {
  var path = try file_storage.getPath(diagnostic.start_location.file);

  try self.style.diag_location.write(self.writer);
  try std.fmt.format(self.writer, "{s}:{}:{}: ", .{ 
    path,
    diagnostic.start_location.line+1,
    diagnostic.start_location.column+1,
  });
  try CellStyle.reset(self.writer);

  var kind_style: CellStyle = undefined;
  var message_style: CellStyle = undefined;
  var kind_name: []const u8 = "";

  switch( diagnostic.kind ) {
    .error_ => {
      kind_style = self.style.diag_kind_error;
      message_style = self.style.diag_message_error;
      kind_name = "error";
    },
    .warning => {
      kind_style = self.style.diag_kind_warning;
      message_style = self.style.diag_message_warning;
      kind_name = "warning";
    },
    .note => {
      kind_style = self.style.diag_kind_note;
      message_style = self.style.diag_message_note;
      kind_name = "note";
    },
    .verbose => {
      kind_style = self.style.diag_kind_verbose;
      message_style = self.style.diag_message_verbose;
      kind_name = "verbose";
    }
  }

  try kind_style.write(self.writer);
  try std.fmt.format(self.writer, "{s}: ", .{ kind_name });
  try CellStyle.reset(self.writer);

  try message_style.write(self.writer);
  try self.writer.writeAll(diagnostic.message);
  try CellStyle.reset(self.writer);

  try self.writer.writeByte('\n');
}

/// Renders the code associated to a diagnostic.
///
/// #### Parameters
///
/// - `file_source`: Storage containing the files to retrieve the necessary 
///   source code.
/// - `diagnostic`: Diagnostic to render.
///
fn renderDiagnosticCode(
  self: *Renderer,
  file_storage: *FileStorage,
  diagnostic: *const Diagnostic
) !void {
  var lines = try file_storage.getLines(diagnostic.start_location.file, true);
  defer file_storage.alloc.free(lines);

  const offset: usize = if( diagnostic.primary ) 1 else 0;
  const start_line = diagnostic.start_location.line -| offset;
  const end_line = if( diagnostic.end_location.line == lines.len - 1 )
    diagnostic.end_location.line
  else
    diagnostic.end_location.line + offset;
  
  var i: usize = start_line;
  while( i <= end_line ) : ( i += 1 ) {
    const hl_start = blk: { 
      if( diagnostic.start_location.line < i ) {
        break :blk 0;
      } else if( diagnostic.start_location.line > i ) {
        break :blk lines[i].len;
      } else {
        break :blk diagnostic.start_location.column;
      }
    };

    const hl_end = blk: {
      if( diagnostic.end_location.line < i ) {
        break :blk 0;
      } else if( diagnostic.end_location.line > i ) {
        break :blk lines[i].len;
      } else {
        break :blk diagnostic.end_location.column;
      }
    };

    try self.renderCodeLine(diagnostic.kind, lines[i], i, hl_start, hl_end);
  }
}

/// Renders a line of code.
/// 
/// #### Parameters 
///
/// - `kind`: Kind of diagnostic.
/// - `line`: Line to be rendered.
/// - `line_number`: Index of the line rendered.
/// - `highlight_start`: Index, in the line, where highlighting starts.
/// - `highlight_end`: Index, in the line, where highlighting stops.
///
fn renderCodeLine(
  self: *Renderer,
  kind: Diagnostic.Kind,
  line: []const u8,
  line_number: usize,
  highlight_start: usize,
  highlight_end: usize,
) !void {
  // const no_hl = highlight_start > line.len or highlight_end == 0;
  // const hl_before = highlight_start == 0;
  // const hl_after = highlight_end > line.len;

  try self.style.code_line_number.write(self.writer);
  try std.fmt.format(self.writer, "{0d: >5} ", .{ line_number+1 });
  try CellStyle.reset(self.writer);

  try self.style.code_gutter.write(self.writer);
  try self.writer.writeAll("| ");
  try CellStyle.reset(self.writer);

  if( highlight_end > 0 ) {
    try self.style.code_regular.write(self.writer);
    try self.writer.writeAll(line[0..highlight_start]);
    try CellStyle.reset(self.writer);
  }

  switch( kind ) {
    .error_ => try self.style.code_highlight_error.write(self.writer),
    .warning => try self.style.code_highlight_warning.write(self.writer),
    .note => try self.style.code_highlight_note.write(self.writer),
    .verbose => try self.style.code_highlight_verbose.write(self.writer),
  }

  try self.writer.writeAll(line[highlight_start..highlight_end]);
  try CellStyle.reset(self.writer);

  if( highlight_start < line.len ) {
    try self.style.code_regular.write(self.writer);
    try self.writer.writeAll(line[highlight_end..]);
    try CellStyle.reset(self.writer);
  }

  try self.writer.writeByte('\n');
}



/// Style configuration for the renderer.
/// 
pub const Style = struct {
  diag_kind_verbose: CellStyle = .{ .bold = true, .foreground = .none },
  diag_kind_note: CellStyle = .{ .bold = true, .foreground = .green },
  diag_kind_warning: CellStyle = .{ .bold = true, .foreground = .yellow },
  diag_kind_error: CellStyle = .{ .bold = true, .foreground = .red },

  diag_message_verbose: CellStyle = .{ .faint = true },
  diag_message_note: CellStyle = .{ .bold = true },
  diag_message_warning: CellStyle = .{ .bold = true },
  diag_message_error: CellStyle = .{ .bold = true },

  code_highlight_verbose: CellStyle = .{ .underline = true },
  code_highlight_note: CellStyle = .{ .bold = true, .underline = true, .foreground = .green },
  code_highlight_warning: CellStyle = .{ .bold = true, .underline = true, .foreground = .yellow },
  code_highlight_error: CellStyle = .{ .bold = true, .underline = true, .foreground = .red },

  diag_location: CellStyle = .{ .faint = true },
  code_line_number: CellStyle = .{ .faint = true },
  code_gutter: CellStyle = .{ .foreground = .blue },
  code_regular: CellStyle = .{ .faint = true },
};



/// Console character cell style.
///
pub const CellStyle = struct {
  reset: bool = false,
  bold: bool = false,
  faint: bool = false,
  underline: bool = false,
  blink: bool = false,

  foreground: Color = .none,
  background: Color = .none,



  pub const Color = enum {
    black, red, green, yellow, blue, magenta, cyan, white, none
  };



  pub fn reset(
    writer: Writer
  ) !void {
    try (CellStyle{ .reset = true }).write(writer);
  }



  pub fn write(
    self: CellStyle,
    writer: Writer
  ) !void {
    var sep_needed = false;

    try writer.writeAll("\x1B[");

    if( self.reset ) {
      try writer.writeByte('0');
      sep_needed = true;
    }

    if( self.bold ) {
      if( sep_needed ) try writer.writeByte(';');
      try writer.writeByte('1');
      sep_needed = true;
    }

    if( self.faint ) {
      if( sep_needed ) try writer.writeByte(';');
      try writer.writeByte('2');
      sep_needed = true;
    }

    if( self.underline ) {
      if( sep_needed ) try writer.writeByte(';');
      try writer.writeByte('4');
      sep_needed = true;
    }

    if( self.blink ) {
      if( sep_needed ) try writer.writeByte(';');
      try writer.writeByte('5');
      sep_needed = true;
    }

    if( self.foreground != .none )  {
      if( sep_needed ) try writer.writeByte(';');
      try writer.writeByte('3');
      try writer.writeByte('0' + @intCast(u8, @enumToInt(self.foreground)));
      sep_needed = true;
    }

    if( self.background != .none ) {
      if( sep_needed ) try writer.writeByte(';');
      try writer.writeByte('4');
      try writer.writeByte('0' + @intCast(u8, @enumToInt(self.background)));
      sep_needed = true;
    }

    try writer.writeByte('m');
  }
};
