
const std = @import("std");
const Location = @import("../diagnostic/location.zig");

const IdentifierStorage = @This();

const Allocator = std.mem.Allocator;
const IdentifierMap = std.AutoHashMap(IdentifierID, Entry);
const BindingMap = std.StringHashMap(IdentifierID);



alloc: Allocator,

next_id: usize = 0,
identifiers: IdentifierMap,



pub fn init(
  alloc: Allocator
) IdentifierStorage {
  return IdentifierStorage {
    .alloc = alloc,
    .next_id = 0,
    .identifiers = IdentifierMap.init(alloc),
  };
}

pub fn deinit(
  self: *IdentifierStorage
) void {
  self.identifiers.deinit();
}



pub fn newID(
  self: *IdentifierStorage
) Allocator.Error!IdentifierID {
  const entry = Entry {
    .id = self.next_id,
    .start_location = undefined,
    .end_location = undefined
  };

  try self.identifiers.put(entry.id, entry);

  self.next_id += 1;
  return entry.id;
}

pub fn newEntry(
  self: *IdentifierStorage
) Allocator.Error!*Entry {
  const id = try self.newID();
  var ptr = self.identifiers.getPtr(id).?;
  return ptr;
}



pub fn getEntry(
  self: *IdentifierStorage,
  id: IdentifierID
) ?*Entry {
  return self.identifiers.getPtr(id);
}



pub fn scope(
  self: *IdentifierStorage
) Scope {
  return Scope {
    .storage = self,
    .parent_scope = null,
    .bindings = BindingMap.init(self.alloc)
  };
}



pub const IdentifierID = usize;

pub const Scope = struct {
  storage: *IdentifierStorage,
  parent_scope: ?*const Scope,

  bindings: BindingMap,



  pub fn deinit(
    self: *Scope
  ) void {
    self.bindings.deinit();
  }



  pub fn scope(
    self: *const Scope
  ) Scope {
    return Scope {
      .storage = self.storage,
      .parent_scope = self,
      .bindings = BindingMap.init(self.storage.alloc)
    };
  }



  pub fn hasBinding(
    self: Scope,
    name: []const u8,
  ) bool {
    if( self.bindings.contains(name) )
      return true;
    
    if( self.parent_scope ) |parent|
      return parent.hasBinding(name);
    
    return false;
  }

  pub fn getBinding(
    self: Scope,
    name: []const u8
  ) ?IdentifierID {
    if( self.bindings.get(name) ) |id|
      return id;
    
    if( self.parent_scope ) |parent|
      return parent.getBinding(name);
    
    return null;
  }



  pub fn bindID(
    self: *Scope,
    name: []const u8
  ) BindingError!IdentifierID {
    if( self.hasBinding(name) )
      return BindingError.binding_already_exists;

    const id = try self.storage.newID();
    try self.bindings.put(name, id);

    return id;
  }

  pub fn bindEntry(
    self: *Scope,
    name: []const u8
  ) BindingError!*Entry {
    if( self.hasBinding(name) )
      return BindingError.binding_already_exists;
    
    var entry = try self.storage.newEntry();
    try self.bindings.put(name, entry.id);

    return entry;
  }

};



pub const Entry = struct {
  id: IdentifierID,

  start_location: Location,
  end_location: Location,

  is_being_defined: bool = false,
};



pub const BindingError = error {
  binding_already_exists,
} || Allocator.Error;
