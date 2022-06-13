
/// Represents the contantness of an expression.
///
/// The flags are ordered from most constant to less constant.
///
pub const ConstantExpressionFlag = enum {
  /// The expression is constant.
  constant,
  /// The constantness of the expression is not known and requires further
  /// processing.
  unknown,
  /// The expression isn't constant.
  not_constant,



  /// Mixes two flags. Returns the less constant flag.
  ///
  pub fn mix(
    self: ConstantExpressionFlag,
    other: ConstantExpressionFlag
  ) ConstantExpressionFlag {
    return @intToEnum(ConstantExpressionFlag,
      @maximum(
        @enumToInt(self),
        @enumToInt(other)
      )
    );
  }
};



/// Optional flags associated with each statement.
///
pub const StatementFlags = struct {
  /// Show the token list making the statement.
  show_tokens: bool = false,
  /// Show the AST making the statement.
  show_ast: bool = false,
};



/// Metadata used by the IdentifierResolver.
///
pub const IdentifierResolverMetadata = struct {
  resolved: bool = false,
  unresolved: bool = false,
  errored: bool = false,
};
