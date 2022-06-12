/// Structure storing the files used by the compiler.
///



const std = @import("std");
const Allocator = std.mem.Allocator;

const FileList = std.ArrayList(File);

const FileStorage = @This();



/// Allocator used.
alloc: Allocator,
/// List of files.
files: FileList,



/// Initialises a new instance.
///
pub fn init(
  alloc: Allocator
) FileStorage {
  return FileStorage {
    .alloc = alloc,
    .files = FileList.init(alloc),
  };
}

/// Deinitialises the storage.
///
pub fn deinit(
  self: *FileStorage
) void {
  for( self.files.items ) |*file| {
    file.deinit(self.alloc);
  }

  self.files.deinit();
}



/// Gets the file ID associated to the given path.
///
pub fn getFileID(
  self: FileStorage,
  path: []const u8
) ?FileID {
  for( self.files.items ) |file, i| {
    const eql = std.mem.eql;

    if( eql(u8, path, file.getPath()) ) {
      return i;
    }
  }

  return null;
}



/// Adds a in-memory file. 
///
/// Mostly used for debugging and isn't well integrated with the other files.
///
pub fn addMemoryFile(
  self: *FileStorage,
  name: []const u8,
  source: []const u8
) Error!FileID {
  if( self.getFileID(name) != null ) 
    return Error.file_already_loaded;
  
  try self.files.append(File { .memory = .{
    .name = name,
    .source = source
  }});

  return self.files.items.len - 1;
}

/// Adds a file from the disk.
///
/// The file is initially unloaded.
///
pub fn addDiskFile(
  self: *FileStorage,
  path: []const u8
) !FileID {
  if( self.getFileID(path) != null )
    return Error.file_already_loaded;
  
  var real_path = try std.fs.cwd().realpathAlloc(self.alloc, path);
  errdefer self.alloc.free(real_path);

  try self.files.append(File { .unloaded = .{
    .path = real_path,
  }});

  return self.files.items.len - 1;
}



/// Gets the path associated with the given file ID.
///
pub fn getPath(
  self: FileStorage,
  file_id: FileID
) Error![]const u8 {
  if( file_id >= self.files.items.len )
    return Error.invalid_file_id;
  
  return self.files.items[file_id].getPath();
}

/// Gets the source associated with the given file ID.
///
/// If the file is unloaded and `load` is true, the file will be loaded from 
/// disk.
pub fn getSource(
  self: *FileStorage,
  file_id: FileID,
  load: bool,
) ![]const u8 {
  if( file_id >= self.files.items.len )
    return Error.invalid_file_id;
  
  var file_entry: *File = &self.files.items[file_id];

  switch( file_entry.* ) {
    .memory => |mem| return mem.source,
    .disk => |disk| return disk.source,
    .unloaded => |unl| {
      if( !load )
        return Error.file_not_loaded;

      var file = try std.fs.cwd().openFile(unl.path, .{});
      defer file.close();

      var size = @intCast(usize, (try file.stat()).size);
      var buffer = try self.alloc.alloc(u8, size);

      _ = try file.readAll(buffer);

      file_entry.* = File { .disk = .{ 
        .path = unl.path,
        .source = buffer,
      }};

      return buffer;
    }
  }
}

/// Gets the source of the given file, splited by lines.
///
pub fn getLines(
  self: *FileStorage,
  file_id: FileID,
  load: bool
) ![][]const u8 {
  var sources = try self.getSource(file_id, load);
  var lines = std.ArrayList([]const u8).init(self.alloc);
  errdefer lines.deinit();

  var iter = std.mem.split(u8, sources, "\n");

  while( iter.next() ) |line| {
    try lines.append(line);
  }

  return lines.toOwnedSlice();
}



/// Unique identifier of a file.
pub const FileID = usize;



pub const Error = error {
  file_already_loaded,
  invalid_file_id,
  file_not_loaded,
} || Allocator.Error;



/// Represents a file in the storage.
///
const File = union(enum) {
  memory: Memory,
  disk: Disk,
  unloaded: Unloaded,



  pub fn deinit(
    self: *File,
    alloc: Allocator
  ) void {
    switch( self.* ) {
      .disk => |*disk| disk.deinit(alloc),
      .unloaded => |*unl| unl.deinit(alloc),
      else => {}
    }
  }



  pub fn getPath(
    self: File
  ) []const u8 {
    return switch( self ) {
      .memory => |mem| mem.name,
      .disk => |disk| disk.path,
      .unloaded => |unl| unl.path,
    };
  }



  /// In-memory file.
  ///
  pub const Memory = struct {
    name: []const u8,
    source: []const u8,
  };

  /// File loaded from disk.
  ///
  pub const Disk = struct {
    path: []const u8,
    source: []const u8,

    pub fn deinit(
      self: *Disk,
      alloc: Allocator
    ) void {
      alloc.free(self.path);
      alloc.free(self.source);
    }
  };

  /// File on disk, but not loaded.
  ///
  pub const Unloaded = struct {
    path: []const u8,

    pub fn deinit(
      self: *Unloaded,
      alloc: Allocator
    ) void {
      alloc.free(self.path);
    }
  };
  
};
