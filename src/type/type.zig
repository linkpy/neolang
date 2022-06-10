
pub const Type = union(Type.Kind) {
  pub const Integer = Type{ .integer = {} };
  pub const String = Type{ .string = {} };
  pub const Boolean = Type{ .boolean = {} };



  integer: void,
  string: void,
  boolean: void,



  pub fn isSameAs(
    self: Type,
    other: Type
  ) bool {
    return @as(Kind, self) == @as(Kind, other);
  }



  pub const Kind = enum {
    integer,
    string, 
    boolean, 
  };
};
