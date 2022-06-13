
const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const flags = nl.ast.flags;
const Location = nl.diagnostic.Location;
const Type = nl.types.Type;
const ConstantNode = nl.ast.ConstantNode;



/// Union representing a statement node.
///
pub const StatementNode = union(enum) {
  constant: ConstantNode,



  /// Deinitialises the statement node.
  ///
  pub fn deinit(
    self: *StatementNode,
    alloc: Allocator
  ) void {
    switch( self.* ) {
      .constant => |*cst| cst.deinit(alloc),
    }
  }



  /// Gets the start location of the node.
  ///
  pub fn getStartLocation(
    self: StatementNode
  ) Location {
    return switch( self ) {
      .constant => |cst| cst.getStartLocation(),
    };
  }

  /// Gets the end location of the node.
  ///
  pub fn getEndLocation(
    self: StatementNode
  ) Location {
    return switch( self ) {
      .constant => |cst| cst.getEndLocation(),
    };
  }



  /// Gets the documentation associated with the node.
  ///
  pub fn getDocumentation(
    self: StatementNode
  ) ?[]const u8 {
    return switch( self ) {
      .constant => |cst| cst.documentation,
    };
  }

  /// Sets the documentation associated with the node.
  ///
  pub fn setDocumentation(
    self: *StatementNode,
    doc: ?[]const u8
  ) void {
    switch( self.* ) {
      .constant => |cst| cst.documentation = doc,
    }
  }

  /// Gets the flags of the node.
  ///
  pub fn getStatementFlags(
    self: StatementNode
  ) flags.StatementFlags {
    return switch( self ) {
      .constant => |cst| cst.flags,
    };
  }

  /// Sets the flags of the node.
  ///
  pub fn setStatementFlags(
    self: *StatementNode,
    flag: flags.StatementFlags
  ) void {
    switch( self.* ) {
      .constant => |*cst| cst.flags = flag,
    }
  }

};
