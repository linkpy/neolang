/// Structure constructing an abstract syntax tree from a `Lexer`.
///



const std = @import("std");

const nl = @import("../nl.zig");
const ast = nl.ast;
const Lexer = nl.parser.Lexer;
const FileStorage = nl.storage.File;
const Diagnostics = nl.diagnostic.Diagnostics;
const Location = nl.diagnostic.Location;
const Type = nl.types.Type;

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

/// Flags for the next statement.
next_statement_flags: ast.StatementFlags = .{}, // TODO to be removed, stupid



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



// == File == //



/// Parses the file until its end.
///
pub fn parseFile(
  self: *Parser
) Error![]ast.StatementNode {
  var list = std.ArrayList(ast.StatementNode).init(self.alloc);
  errdefer {
    for( list.items ) |*i| i.deinit(self.alloc);
    list.deinit();
  }

  try self.skipWhitespace();

  while( !self.isAtEnd() ) {
    var stmt = try self.parseStatement();
    errdefer stmt.deinit(self.alloc);

    try self.skipWhitespace();

    try list.append(stmt);
  }

  return list.toOwnedSlice();
}



// == Statements == //



/// Parses a statement.
///
pub fn parseStatement(
  self: *Parser
) Error!ast.StatementNode {
  // TODO handle documentation for documentable nodes.
  try self.parseStatementFlags();
  try self.skipWhitespace();

  const token = try self.peekTokenNoEOF("a statement");

  var stmt = switch( token.kind ) {
    .kw_const => ast.StatementNode{ .constant = try self.parseConstant() },
    .kw_proc => ast.StatementNode{ .function = try self.parseFunction() },
    else => {
      try self.diagnostics.pushError(
        "Expected a statement, but got a '{s}' instead.",
        .{ @tagName(token.kind) },
        token.start_location, token.end_location,
      );

      return error.unexpected_token;
    }
  };

  errdefer stmt.deinit(self.alloc);

  stmt.setStatementFlags(self.next_statement_flags);
  self.next_statement_flags = .{};

  if( stmt.getStatementFlags().show_tokens )
    try self.printStatementTokens(&stmt);

  if( stmt.getStatementFlags().show_ast ) {
    std.log.debug("Printing the statement's AST:", .{});
    ast.printer.printStatementNode(
      std.io.getStdOut().writer(), &stmt, 0, false
    ) catch {};
  }

  return stmt;
}

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

/// Parses a function declaration.
///
/// Supports fast-forwarding in case of error.
///
pub fn parseFunction(
  self: *Parser
) Error!ast.FunctionNode {
  // TODO refactor
  try self.skipWhitespace();

  const proc_token = try self.expectToken(.kw_proc);

  errdefer self.skipTokensUntil(.kw_end) catch {};

  try self.skipWhitespace();

  var name = try self.parseIdentifier();
  var metadata = ast.FunctionNode.Metadata {};
  var arguments = std.ArrayList(ast.ArgumentNode).init(self.alloc);
  var return_type: ?ast.ExpressionNode = null;
  var content = std.ArrayList(ast.StatementNode).init(self.alloc);

  var signature_end_loc: Location = undefined;

  errdefer {
    name.deinit(self.alloc);

    for( arguments.items ) |*arg| arg.deinit(self.alloc);
    arguments.deinit();

    if( return_type ) |*expr| expr.deinit(self.alloc);

    for( content.items ) |*stmt| stmt.deinit(self.alloc);
    content.deinit();
  }

  try self.skipWhitespace();

  // TODO put signature parsing in its own function
  while( true ) {
    const token = try self.peekTokenNoEOF("a function signature");

    switch( token.kind ) {
      .kw_is => {
        self.nextToken();
        try self.skipWhitespace();

        const flag = try self.peekTokenNoEOF("a function flag");

        switch( flag.kind ) {
          .kw_recursive =>
            metadata.is_recursive = true,
          .kw_entry_point =>
            metadata.is_entry_point = true,
          else => {
            try self.diagnostics.pushError(
              "Expected a function flag, but got a '{s}' instead.",
              .{ @tagName(flag.kind) },
              flag.start_location, flag.end_location
            );

            return Error.unexpected_token;
          }
        }

        signature_end_loc = flag.end_location;
        self.nextToken();
      },
      .kw_param => {
        self.nextToken();
        try self.skipWhitespace();

        var id = try self.parseIdentifier();
        errdefer id.deinit(self.alloc);

        try self.skipWhitespace();

        var arg_type = try self.parseExpressionAtom();
        errdefer arg_type.deinit(self.alloc);

        try arguments.append(.{
          .name = id,
          .type = arg_type
        });

        signature_end_loc = arg_type.getEndLocation();
      },
      .kw_returns => {
        self.nextToken();
        try self.skipWhitespace();

        var expr = try self.parseExpressionAtom();
        return_type = expr;

        signature_end_loc = expr.getEndLocation();
      },
      .kw_begin => {
        self.nextToken();
        break;
      },
      else => {
        try self.diagnostics.pushError(
          "Unexpected '{s}' token in function signature.",
          .{ @tagName(token.kind) },
          token.start_location, token.end_location
        );

        return Error.unexpected_token;
      }
    }

    try self.skipWhitespace();
  }

  var end_loc: Location = undefined;

  // TODO put block parsing into its own function
  while( true ) {
    try self.skipWhitespace();

    const token = try self.peekTokenNoEOF("a statement");

    if( token.kind == .kw_end ) {
      end_loc = token.end_location;
      self.nextToken();
      break;
    }

    var stmt = try self.parseStatement();
    try content.append(stmt);
  }

  return ast.FunctionNode {
    .name = name,
    .arguments = arguments.toOwnedSlice(),
    .return_type = return_type,
    .body = content.toOwnedSlice(),
    .metadata = metadata,
    .start_location = proc_token.start_location,
    .end_location = end_loc,
    .signature_end_location = signature_end_loc
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

  return try self.parsePostfixExpression();
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

/// Parses a postfix expression.
///
pub fn parsePostfixExpression(
  self: *Parser
) Error!ast.ExpressionNode {
  var expr = try self.parseExpressionAtom();
  errdefer expr.deinit(self.alloc);

  while( try self.peekToken() ) |token| {
    expr = switch( token.kind ) {
      .slash => try self.parseFieldAccess(expr),
      else => break,
    };
  }

  return expr;
}

/// Parses a field access.
///
pub fn parseFieldAccess(
  self: *Parser,
  storage: ast.ExpressionNode
) Error!ast.ExpressionNode {
  _ = try self.expectToken(.slash);

  var id = try self.parseIdentifier();
  errdefer id.deinit(self.alloc);

  return ast.ExpressionNode { .field = .{
    .storage = try self.heapify(storage),
    .field = id
  }};
}



// == Expression atoms == //



/// Parses an expression atom.
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
    // TODO maybe parse postfix expr here?
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
  const token = try self.expectToken(.identifier);

  return ast.IdentifierNode {
    .name = try self.alloc.dupe(u8, token.value),
    .start_location = token.start_location,
    .end_location = token.end_location
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



// == Statement flags & statement debug utilities == //



// TODO to be removed, stupid
fn parseStatementFlags(
  self: *Parser,
) Error!void {
  if( !try self.checkToken(.pound) )
    return;

  self.nextToken();

  _ = try self.expectToken(.left_ang);

  while( true ) {
    try self.skipWhitespace();

    var id = try self.parseIdentifier();
    defer id.deinit(self.alloc);

    if( !try self.updateNextStatementFlags(&id) ) {
      try self.diagnostics.pushError(
        "Invalid statement flag.", .{},
        id.getStartLocation(), id.getEndLocation(),
      );

      return Error.invalid_statement_flag;
    }

    try self.skipWhitespace();

    if( !try self.checkToken(.comma) )
      break;

    // skip the comma
    self.nextToken();

    try self.skipWhitespace();
  }

  _ = try self.expectToken(.right_ang);
}

fn updateNextStatementFlags(
  self: *Parser,
  id: *const ast.IdentifierNode
) Error!bool {
  const eql = std.mem.eql;

  if( eql(u8, id.name, "show_tokens") )
    self.next_statement_flags.show_tokens = true
    else if( eql(u8, id.name, "show_ast") )
    self.next_statement_flags.show_ast = true
    else
    return false;

  return true;
}



fn printStatementTokens(
  self: *Parser,
  stmt: *const ast.StatementNode // TODO use statement union
) Error!void {
  var lexer = self.lexer.*;
  lexer.reader.location = stmt.getStartLocation();

  std.log.debug("Printing statement's tokens:", .{});

  while( lexer.reader.location.index < stmt.getEndLocation().index ) {
    const token = (try lexer.readToken()) orelse unreachable;

    switch( token.kind ) {
      .whitespace, .comment =>
        std.log.debug(" - {s} ({}:{} -> {}:{}) = <skipped>", .{
          @tagName(token.kind),
          token.start_location.line, token.start_location.column,
          token.end_location.line, token.end_location.column,
      }),
      else =>
        std.log.debug(" - {s} ({}:{} -> {}:{}) = '{s}'", .{
          @tagName(token.kind),
          token.start_location.line, token.start_location.column,
          token.end_location.line, token.end_location.column,
          token.value
      }),
    }
  }

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

      switch( token.kind ) {
        .left_par => par_count += 1,
        .right_par => par_count -|= 1,
        .left_sqr => sqr_count += 1,
        .right_sqr => sqr_count -|= 1,
        .kw_begin => blk_count += 1,
        .kw_end => blk_count -|= 1,
        else => {}
      }

      if( token.kind == kind and par_count == 0 and sqr_count == 0 and blk_count == 0 )
        break;
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

  invalid_statement_flag,
} || Diagnostics.Error || Lexer.Error;
