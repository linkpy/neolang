/// Structure constructing an abstract syntax tree from a `Lexer`.
///



const std = @import("std");

const nl = @import("../nl.zig");
const ast = nl.parser.ast;
const Lexer = nl.parser.Lexer;
const FileStorage = nl.storage.File;
const Diagnostics = nl.diagnostic.Diagnostics;
const Location = nl.diagnostic.Location;

const FileID = FileStorage.FileID;
const Token = Lexer.Token;

const Parser = @This();



/// Allocator used for allocating AST nodes.
alloc: std.mem.Allocator,
/// Diagnostics used in case of error.
diagnostics: *Diagnostics,

/// Lexer used to obtain the tokens.
lexer: *Lexer,
/// Single token buffer.
token: ?Token,



/// Initialises a new parser.
///
/// #### Parameters
///
/// - `alloc`: Allocator to use for AST node allocations.
/// - `lexer`: Lexer to use for retreiving tokens.
///
pub fn init(
  alloc: std.mem.Allocator,
  lexer: *Lexer,
) Parser {
  return Parser {
    .alloc = alloc,
    .lexer = lexer,
    .token = null,
    .diagnostics = lexer.diagnostics,
  };
}



// == Declarations == //

// TODO handle documentation for documentable nodes.

/// Parses a constant declaration.
///
/// Supports fast-forwarding in case of error.
///
pub fn parseConstant(
  self: *Parser
) Error!ast.ConstantNode {
  try self.skipWhitespace();

  const const_token = try self.expectToken(.kw_const);

  // in case of error, fast-forward until the dot at the end of the const 
  // declaration
  errdefer self.skipTokensUntil(.semicolon) catch {};

  try self.skipWhitespace();

  var id_node = try self.parseIdentifier();
  errdefer id_node.deinit(self.alloc);

  if( id_node.isSegmented() ) {
    try self.diagnostics.pushError(
      "Only simple identifiers are allowed for constant's names.", .{},
      id_node.getStartLocation(),
      id_node.getEndLocation()
    );
    return Error.unexpected_segmented_identifier;
  }

  try self.skipWhitespace();

  var type_expr: ?ast.ExpressionNode = null;
  errdefer if( type_expr ) |*expr| expr.deinit(self.alloc);

  if( try self.checkToken(.colon) ) {
    self.nextToken();

    try self.skipWhitespace();

    type_expr = try self.parseExpressionAtom();

    try self.skipWhitespace();
  }

  _ = try self.expectToken(.equal);

  try self.skipWhitespace();

  var value_node = try self.parseCallExpression();
  errdefer value_node.deinit(self.alloc);

  try self.skipWhitespace();

  const semicolon_token = try self.expectToken(.semicolon);

  return ast.ConstantNode {
    .name = id_node,
    .type = type_expr,
    .value = value_node,
    .start_location = const_token.start_location,
    .end_location = semicolon_token.end_location,
  };
}



// == Composite expressions == //



/// Parses a call expression.
///
/// Initially parses an unary expression node. After that, if more expression
/// nodes are detected, turns the unary expression node into a call node.
///
pub fn parseCallExpression(
  self: *Parser
) Error!ast.ExpressionNode {
  var function = try self.parseUnaryExpression();
  errdefer function.deinit(self.alloc);

  try self.skipWhitespace();

  const token = (try self.peekToken()) orelse return function;

  switch( token.kind ) {
    .exclam => {
      self.nextToken();

      return ast.ExpressionNode { .call = .{
        .function = try self.heapify(function),
        .arguments = &[0]ast.ExpressionNode {},
        .exclam_location = token.end_location,
      }};
    },
    .integer, .identifier => {
      var list = std.ArrayList(ast.ExpressionNode).init(self.alloc);
      errdefer {
        for( list.items ) |*arg| arg.deinit(self.alloc);
        list.deinit();
      }

      while( true ) {
        try self.skipWhitespace();

        var arg = try self.parseCallExpression();
        errdefer arg.deinit(self.alloc);

        try list.append(arg);

        try self.skipWhitespace();

        if( self.isAtEnd() or !try self.checkToken(.comma) ) {
          break;
        }
      }

      return ast.ExpressionNode { .call = .{
        .function = try self.heapify(function),
        .arguments = list.toOwnedSlice(),
        .exclam_location = undefined,
      }};
    },
    else => {
      return self.parseBinaryExpression(function);
    }
  }
}

/// Parses a binary expression.
///
/// If no initial left-hand side node is given, tries to parse an unary 
/// expression node. 
/// If no binary operator is detected, returns the left-hand side expression 
/// node alone.
///
/// There is no operator precedence. Expressions are parsed left to right, 
/// meaning the left-most binary expression is executed first.
///
pub fn parseBinaryExpression(
  self: *Parser,
  initial_left_node: ?ast.ExpressionNode,
) Error!ast.ExpressionNode {
  var left_node = initial_left_node orelse try self.parseUnaryExpression();
  errdefer if( initial_left_node == null ) 
    left_node.deinit(self.alloc);

  while( try self.parseBinaryOperator() ) |op| {
    try self.skipWhitespace();

    var right_node = try self.parseUnaryExpression();
    errdefer right_node.deinit(self.alloc);

    const left_node_heap = try self.heapify(left_node);
    errdefer self.alloc.destroy(left_node_heap);

    const right_node_heap = try self.heapify(right_node);
    errdefer self.alloc.destroy(right_node_heap);

    left_node = ast.ExpressionNode { .binary = .{
      .left = left_node_heap,
      .right = right_node_heap,
      .operator = op,
    }};
  }

  return left_node;
}

/// Parses a binary operator.
///
/// If the input doesn't match a binary operator, returns null.
///
pub fn parseBinaryOperator(
  self: *Parser
) Error!?ast.BinaryExpressionNode.Operator {
  try self.skipWhitespace();

  const token = (try self.peekToken()) orelse return null;

  switch( token.kind ) {
    .plus => {
      self.nextToken();
      return .add;
    },
    .minus => {
      self.nextToken();
      return .sub;
    },
    .star => {
      self.nextToken();
      return .mul;
    },
    .slash => {
      self.nextToken();
      return .div;
    },
    .percent => {
      self.nextToken();
      return .mod;
    },
    .equal => {
      self.nextToken();
      _ = try self.expectToken(.equal);
      return .eq;
    },
    .left_ang => {
      self.nextToken();
      const next_token = (try self.peekToken()) orelse {
        self.nextToken();
        return .lt;
      };

      switch( next_token.kind ) {
        .left_ang => {
          self.nextToken();
          return .shl;
        },
        .right_ang => {
          self.nextToken();
          return .ne;
        },
        .equal => {
          self.nextToken();
          return .le;
        },
        else => {
          return .lt;
        }
      }
    },
    .right_ang => {
      self.nextToken();
      const next_token = (try self.peekToken()) orelse {
        self.nextToken();
        return .gt;
      };

      switch( next_token.kind ) {
        .right_ang => {
          self.nextToken();
          return .shr;
        },
        .equal => {
          self.nextToken();
          return .ge;
        },
        else => {
          return .gt;
        }
      }
    },
    .kw_and => {
      self.nextToken();
      return .land;
    },
    .kw_or => {
      self.nextToken();
      return .lor;
    },
    .ampersand => {
      self.nextToken();
      return .band;
    },
    .pipe => {
      self.nextToken();
      return .bor;
    },
    .charet => {
      self.nextToken();
      return .bxor;
    },
    else => return null,
  }
}



/// Parses an unary expression.
///
/// If no unary operator are detected, defaults to parsing an expression atom.
///
pub fn parseUnaryExpression(
  self: *Parser
) Error!ast.ExpressionNode {
  const token = try self.peekTokenNoEOF("an expression");
  const start_loc = token.start_location;

  if( try self.parseUnaryOperator() ) |op| {
    var child_node = try self.parseUnaryExpression();
    errdefer child_node.deinit(self.alloc);

    const child_node_heap = try self.heapify(child_node);
    errdefer self.alloc.destroy(child_node_heap);

    return ast.ExpressionNode { .unary = .{
      .child = child_node_heap,
      .operator = op,
      .start_location = start_loc,
    }};
  }

  return try self.parseExpressionAtom();
}

/// Parses the operator of an unary expression.
///
/// If the input doesn't match an unary operator, return null.
///
pub fn parseUnaryOperator(
  self: *Parser
) Error!?ast.UnaryExpressionNode.Operator {
  try self.skipWhitespace();

  const token = (try self.peekToken()) orelse return null;

  switch( token.kind ) {
    .plus => {
      self.nextToken();
      return .id;
    },
    .minus => {
      self.nextToken();
      return .neg;
    },
    .kw_not => {
      self.nextToken();
      return .lnot;
    },
    .tilde => {
      self.nextToken();
      return .bnot;
    },
    else => return null,
  }
}



// == Expression atoms == // 



/// Parses an expression atom, which can be :
/// - an identifier 
/// - an integer
/// - a string 
/// - an expression wrapped in `(` and `)`
///
pub fn parseExpressionAtom(
  self: *Parser
) Error!ast.ExpressionNode {
  const token = try self.peekTokenNoEOF("an expression");

  switch( token.kind ) {
    .identifier => {
      const id = try self.parseIdentifier();
      return ast.ExpressionNode { .identifier = id };
    },
    .integer => {
      const int = try self.parseInteger();
      return ast.ExpressionNode { .integer = int };
    },
    .string => {
      const str = try self.parseString();
      return ast.ExpressionNode { .string = str };
    },
    .left_par => {
      const grp = try self.parseGroup();
      return ast.ExpressionNode { .group = grp };
    },
    else => {
      try self.diagnostics.pushError(
        "Expected an expression, but got a '{s}' token.",
        .{ @tagName(token.kind) },
        token.start_location,
        token.end_location
      );

      return Error.unexpected_token;
    }
  }
}

/// Parses a segmented identifier.
///
pub fn parseIdentifier(
  self: *Parser
) Error!ast.IdentifierNode {
  var list = std.ArrayList([]u8).init(self.alloc);
  errdefer {
    for( list.items ) |item| self.alloc.free(item);

    list.deinit();
  }

  var start_loc: Location = undefined;
  var end_loc: Location = undefined;

  while( true ) {
    const token = try self.expectToken(.identifier);

    if( list.items.len == 0 )
      start_loc = token.start_location;

    try list.append(
      try self.alloc.dupe(u8, token.value)
    );

    if( !try self.checkToken(.slash) ) {
      end_loc = token.end_location;
      break;
    }
    
    // skip the /
    self.nextToken();
  }

  return ast.IdentifierNode {
    .parts = list.toOwnedSlice(),
    .start_location = start_loc,
    .end_location = end_loc
  };
}

/// Parses an integer node, converting it to an actual integer and parsing its
/// optional type flag.
///
pub fn parseInteger(
  self: *Parser
) Error!ast.IntegerNode {
  const token = try self.expectToken(.integer);
  var type_flag = ast.IntegerNode.TypeFlag.ct;
  var end_loc = token.end_location;

  if( try self.peekToken() ) |tok| {
    if( tok.kind == .identifier ) {
      const TypeFlag = ast.IntegerNode.TypeFlag;
      const eql = std.mem.eql;
      const val = tok.value;

      var valid_type_flag = false;
      end_loc = tok.end_location;

      self.nextToken();

      const map = .{
        .{ "ct", TypeFlag.ct },
        .{ "i1", TypeFlag.i1 },
        .{ "i2", TypeFlag.i2 },
        .{ "i4", TypeFlag.i4 },
        .{ "i8", TypeFlag.i8 },
        .{ "u1", TypeFlag.u1 },
        .{ "u2", TypeFlag.u2 },
        .{ "u4", TypeFlag.u4 },
        .{ "u8", TypeFlag.u8 },
        .{ "iptr", TypeFlag.iptr },
        .{ "uptr", TypeFlag.uptr },
      };

      inline for( map ) |entry| {
        if( eql(u8, val, entry.@"0") ) {
          type_flag = entry.@"1";
          valid_type_flag = true;
          break;
        }
      }

      if( !valid_type_flag ) {
        try self.diagnostics.pushError(
          "'{s}' isn't a valid integer type flag.",
          .{ tok.value },
          tok.start_location,
          tok.end_location
        );
      }
    }
  }

  return ast.IntegerNode {
    .value = std.fmt.parseInt(i64, token.value, 10) catch unreachable,
    .type_flag = type_flag,
    .start_location = token.start_location,
    .end_location = end_loc
  };
}

/// Parses a string node, evaluating the potential escaped characted contained
/// in it.
///
pub fn parseString(
  self: *Parser
) Error!ast.StringNode {
  // TODO handle escaped characters
  const token = try self.expectToken(.string);
  const value = try self.alloc.dupe(u8, token.value[1..token.value.len-1]);

  return ast.StringNode {
    .value = value,
    .start_location = token.start_location,
    .end_location = token.end_location,
  };
}

/// Parses a group expression node.
///
pub fn parseGroup(
  self: *Parser
) Error!ast.GroupExpressionNode {
  const start_loc = (try self.expectToken(.left_par)).start_location;

  var expr = try self.parseCallExpression();
  errdefer expr.deinit(self.alloc);

  const end_loc = (try self.expectToken(.right_par)).end_location;

  return ast.GroupExpressionNode {
    .child = try self.heapify(expr),
    .start_location = start_loc,
    .end_location = end_loc,
  };
}



// == Token utilities == // 



/// Peeks a token from the input. 
///
/// If there is no token in the cache, retrieve a new token from the input then
/// cache it.
/// If there is a token in the cache, return it.
/// If the end of file was reached, returns null.
///
fn peekToken(
  self: *Parser
) Lexer.Error!?Token {
  if( self.token ) |token| {
    return token;
  } else if( try self.lexer.readToken() ) |token| {
    self.token = token;
    return token;
  } else {
    return null;
  }
}

/// Peeks a token from the input, returning an error if the end of file was 
/// reached.
/// 
fn peekTokenNoEOF(
  self: *Parser,
  comptime expected_name: []const u8,
) Error!Token {
  return (try self.peekToken()) orelse {
    try self.diagnostics.pushError(
      "Expected " ++ expected_name ++ ", but reached the end of file instead.",
      .{},
      self.lexer.reader.location,
      self.lexer.reader.location
    );

    return Error.unexpected_end_of_file;
  };
}

/// Clears the token cache, forcing the next call to `peekChar` to obtain the 
/// next token from the input.
///
fn nextToken(
  self: *Parser
) void {
  self.token = null;
}

/// Checks if the current token is of the kind `kind`. Never consumes the token
/// from the input.
///
/// If the end of file is reached, return false.
///
fn checkToken(
  self: *Parser,
  kind: Token.Kind,
) Lexer.Error!bool {
  const token = (try self.peekToken()) orelse return false;

  return token.kind == kind;
}

/// Expects the current token to be of the same kind as `kind` and returns 
/// the obtained token after consuming it from the input.
///
/// If the current token isn't, a diagnostic is pushed and an error returned.
/// If the end of file is reached, ditto.
///
fn expectToken(
  self: *Parser,
  kind: Token.Kind
) Error!Token {
  if( try self.peekToken() ) |token| {
    if( token.kind == kind ) {
      self.nextToken();
      return token;
    }
    
    try self.diagnostics.pushError(
      "Expected a '{s}' token, but got a '{s}' token.", 
      .{ @tagName(kind), @tagName(token.kind) },
      token.start_location,
      token.end_location
    );

    return Error.unexpected_token;

  } else {

    try self.diagnostics.pushError(
      "Expected a '{s}' token, but reached end of file.",
      .{ @tagName(kind) },
      self.lexer.reader.location,
      self.lexer.reader.location,
    );

    return Error.unexpected_end_of_file;
  }
}



/// Skips whitespace and comment tokens.
///
fn skipWhitespace(
  self: *Parser
) Lexer.Error!void {
  while( try self.peekToken() ) |token| {
    if( token.kind != .whitespace and token.kind != .comment )
      break;
    
    self.nextToken();
  }
}

/// Skips tokens until the given token kind is found. 
/// If a token with the given token kind is found, it is skipped as well.
///
/// Used in case of errors in order to put the parser in a valid state after an
/// invalid syntax. It takes into account parenthesis, square brackets, and 
/// blocks (pairs of `begin` and `end` token), returning only when the given 
/// token is found outside of any parenthesis or square brackets pairs and 
/// outside blocks.
///
/// It is also robust to invalid input (characters not recognized as tokens) in
/// the source, and simply skips them.
/// 
fn skipTokensUntil(
  self: *Parser,
  kind: Token.Kind
) Lexer.Error!void {
  // closing parenthesis, square brackets, and `end` tokens are just ignored 
  // if no matching opening one is detected while skipping (since the error 
  // causing this function to be called might be in one or more pairs already).

  var par_count: usize = 0; // number of parathesis opened
  var sqr_count: usize = 0; // number of square brackets opened
  var blk_count: usize = 0; // number of blocks opened

  while( true ) {
    if( self.peekToken() ) |opt_token| {
      const token = opt_token orelse break;

      self.nextToken();

      if( token.kind == kind and par_count == 0 and sqr_count == 0 and blk_count == 0 )
        break;
      
      switch( token.kind ) {
        .left_par => par_count += 1,
        .right_par => par_count -|= 1,
        .left_sqr => sqr_count += 1,
        .right_sqr => sqr_count -|= 1,
        .kw_begin => blk_count += 1,
        .kw_end => blk_count -|= 1,
        else => {}
      }
    } else |err| {
      if( err != error.unrecognized_input )
        return err;
    }
  }
}




/// Checks if the end of file was reached.
///
fn isAtEnd(
  self: Parser
) bool {
  if( self.token != null )
    return false;
  
  return self.lexer.reader.isEndOfFile();
}

/// Moves the given value to the heap.
///
fn heapify(
  self: Parser,
  value: anytype
) Error!*@TypeOf(value) {
  var result = try self.alloc.create(@TypeOf(value));
  result.* = value;
  return result;
}



pub const Error = error {
  unexpected_token,
  unexpected_end_of_file,
  unexpected_segmented_identifier,
} || Diagnostics.Error || Lexer.Error;
