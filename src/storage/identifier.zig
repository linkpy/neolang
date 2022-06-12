/// Struct used to store identifier-related informations.
///



const std = @import("std");
const Location = @import("../diagnostic/location.zig");
const Type = @import("../type/type.zig").Type;
const Variant = @import("../vm/variant.zig").Variant;

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
    .id = self.next_id
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



pub const Builtin = enum(IdentifierID) {
  ct_int,
  i1, i2, i4, i8,
  u1, u2, u4, u8,
  iptr, uptr,
  bool,
  type,



  pub fn id(
    self: Builtin
  ) IdentifierID {
    return @enumToInt(self);
  }
};



pub fn registerBuiltins(
  self: *IdentifierStorage
) Allocator.Error!void {
  try self.newBuiltinType(Type.CtInt);
  try self.newBuiltinType(Type.I1);
  try self.newBuiltinType(Type.I2);
  try self.newBuiltinType(Type.I4);
  try self.newBuiltinType(Type.I8);
  try self.newBuiltinType(Type.U1);
  try self.newBuiltinType(Type.U2);
  try self.newBuiltinType(Type.U4);
  try self.newBuiltinType(Type.U8);
  try self.newBuiltinType(Type.IPtr);
  try self.newBuiltinType(Type.UPtr);
  try self.newBuiltinType(Type.Bool);
  try self.newBuiltinType(Type.TypeT);
}

fn newBuiltin(
  self: *IdentifierStorage,
  entry: Entry
) Allocator.Error!void {
  var e = try self.newEntry();
  const id = e.id;

  e.* = entry;

  e.id = id;
  e.builtin = true;
}

fn newBuiltinType(
  self: *IdentifierStorage,
  typ: Type
) Allocator.Error!void {

  try self.newBuiltin(Entry {
    .id = undefined,
    .data = .{ .expression = .{
      .constantness = .constant,
      .type = Type.TypeT,
    }},
    .value = Variant { .type = typ },
  });
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



  pub fn bindBuiltins(
    self: *Scope
  ) Allocator.Error!void {
    try self.bindings.put("ct_int", Builtin.ct_int.id());
    try self.bindings.put("i1", Builtin.i1.id());
    try self.bindings.put("i2", Builtin.i2.id());
    try self.bindings.put("i4", Builtin.i4.id());
    try self.bindings.put("i8", Builtin.i8.id());
    try self.bindings.put("u1", Builtin.u1.id());
    try self.bindings.put("u2", Builtin.u2.id());
    try self.bindings.put("u4", Builtin.u4.id());
    try self.bindings.put("u8", Builtin.u8.id());
    try self.bindings.put("iptr", Builtin.iptr.id());
    try self.bindings.put("uptr", Builtin.uptr.id());
    try self.bindings.put("bool", Builtin.bool.id());
    try self.bindings.put("type", Builtin.type.id());
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
  /// If true, this identifier is builtin and thus has no locations.
  builtin: bool = false,

  /// Starting location of the identifier's source.
  start_location: Location = undefined,
  /// Ending location of the identifier's source.
  end_location: Location = undefined,

  /// If true, the identifier is being defined (used for recursive declarations).
  is_being_defined: bool = false,

  /// Additional data associated with the identifier.
  data: Data = .{ .none = {} },
  /// Compile-time value of the identifier.
  value: Variant = .none,



  pub const Data = union(enum) {
    none: void,
    expression: Expression,



    pub const Expression = struct {
      const ast_flags = @import("../parser/ast/flags.zig");

      constantness: ast_flags.ConstantExpressionFlag = .unknown,
      type: ?Type,
    };
  };
};




pub const BindingError = error {
  binding_already_exists,
} || Allocator.Error;
