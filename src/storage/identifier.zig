/// Struct used to store identifier-related informations.
///



const std = @import("std");
const Location = @import("../diagnostic/location.zig");

const IdentifierStorage = @This();

const Allocator = std.mem.Allocator;
const IdentifierMap = std.AutoHashMap(IdentifierID, Entry);
const BindingMap = std.StringHashMap(IdentifierID);



/// Allocator used.
alloc: Allocator,

/// Next available ID.
next_id: usize = 0,
/// Identifiers registered.
identifiers: IdentifierMap,



/// Initialises a new instance.
///
pub fn init(
  alloc: Allocator
) IdentifierStorage {
  return IdentifierStorage {
    .alloc = alloc,
    .next_id = 0,
    .identifiers = IdentifierMap.init(alloc),
  };
}

/// Deinitialises the instance, freeing up memory.
///
pub fn deinit(
  self: *IdentifierStorage
) void {
  self.identifiers.deinit();
}



/// Generates a new identifier ID.
///
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

/// Generates a new identifier ID and returns a pointer to the identifier entry.
/// 
pub fn newEntry(
  self: *IdentifierStorage
) Allocator.Error!*Entry {
  const id = try self.newID();
  var ptr = self.identifiers.getPtr(id).?;
  return ptr;
}



/// Gets the entry associated with the given identifier ID.
///
pub fn getEntry(
  self: *IdentifierStorage,
  id: IdentifierID
) ?*Entry {
  return self.identifiers.getPtr(id);
}



/// Creates a new root binding scope.
///
pub fn scope(
  self: *IdentifierStorage
) Scope {
  return Scope {
    .storage = self,
    .parent_scope = null,
    .bindings = BindingMap.init(self.alloc)
  };
}



/// ID used to represent an identifier.
///
pub const IdentifierID = usize;



/// Struct representing a binding scope.
///
pub const Scope = struct {
  /// Identifier storage.
  storage: *IdentifierStorage,
  /// Parent scope of this one.
  parent_scope: ?*const Scope,

  /// Registered bindings.
  bindings: BindingMap,



  /// Deinitialises the scope, freeing up memory.
  ///
  pub fn deinit(
    self: *Scope
  ) void {
    self.bindings.deinit();
  }



  /// Creates a new child scope, inheriting the bindings of the current scope.
  ///
  pub fn scope(
    self: *const Scope
  ) Scope {
    return Scope {
      .storage = self.storage,
      .parent_scope = self,
      .bindings = BindingMap.init(self.storage.alloc)
    };
  }



  /// Checks if the current scope (or one of its parent) has the given binding.
  ///
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

  /// Gets the binding from the current scope (or one of its parent).
  ///
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



  /// Creates a new binding, returning the identifier ID.
  ///
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

  /// Creates a new binding, returning the identifier entry.
  ///
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



/// Structure associated with each identifier ID.
///
pub const Entry = struct {
  /// ID associated with the entry.
  id: IdentifierID,

  /// Starting location of the identifier's source.
  start_location: Location,
  /// Ending location of the identifier's source.
  end_location: Location,

  /// If true, the identifier is being defined (used for recursive declarations).
  is_being_defined: bool = false,

  /// Additional data associated with the identifier.
  data: Data = .{ .none = {} },



  pub const Data = union(enum) {
    none: void,
    expression: Expression,



    pub const Expression = struct {
      const ast_flags = @import("../parser/ast/flags.zig");
      const Type = @import("../type/type.zig");

      constantness: ast_flags.ConstantExpressionFlag = .unknown,
      type: ?Type,
    };
  };
};




pub const BindingError = error {
  binding_already_exists,
} || Allocator.Error;
