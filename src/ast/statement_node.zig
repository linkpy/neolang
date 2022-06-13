
const std = @import("std");
const Allocator = std.mem.Allocator;

const nl = @import("../nl.zig");
const flags = nl.ast.flags;
const Location = nl.diagnostic.Location;
const Type = nl.types.Type;
const ConstantNode = nl.ast.ConstantNode;
const FunctionNode = nl.ast.FunctionNode;



/// Union representing a statement node.
///
pub const StatementNode = union(enum) {
  constant: ConstantNode,
  function: FunctionNode,



  /// Deinitialises the statement node.
  ///
  pub fn deinit(
    self: *StatementNode,
    alloc: Allocator
  ) void {
    switch( self.* ) {
      .constant => |*cst| cst.deinit(alloc),
      .function => |*fun| fun.deinit(alloc),
    }
  }



  /// Gets the start location of the node.
  ///
  pub fn getStartLocation(
    self: StatementNode
  ) Location {
    return switch( self ) {
      .constant => |cst| cst.getStartLocation(),
      .function => |fun| fun.getStartLocation(),
    };
  }

  /// Gets the end location of the node.
  ///
  pub fn getEndLocation(
    self: StatementNode
  ) Location {
    return switch( self ) {
      .constant => |cst| cst.getEndLocation(),
      .function => |fun| fun.getEndLocation(),
    };
  }



  /// Gets the documentation associated with the node.
  ///
  pub fn getDocumentation(
    self: StatementNode
  ) ?[]const u8 {
    return switch( self ) {
      .constant => |cst| cst.documentation,
      .function => |fun| fun.documentation,
    };
  }

  /// Sets the documentation associated with the node.
  ///
  pub fn setDocumentation(
    self: *StatementNode,
    doc: ?[]const u8
  ) void {
    switch( self.* ) {
      .constant => |*cst| cst.documentation = doc,
      .function => |*fun| fun.documentation = doc,
    }
  }

  /// Gets the flags of the node.
  ///
  pub fn getStatementFlags(
    self: StatementNode
  ) flags.StatementFlags {
    return switch( self ) {
      .constant => |cst| cst.flags,
      .function => |fun| fun.statement_flags,
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
      .function => |*fun| fun.statement_flags = flag,
    }
  }

};
