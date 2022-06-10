/// Namespace containing all of the AST nodes.
///



pub const IdentifierNode = @import("./ast/identifier_node.zig");
pub const IntegerNode = @import("./ast/integer_node.zig");
pub const StringNode = @import("./ast/string_node.zig");
pub const BinaryExpressionNode = @import("./ast/binary_expression_node.zig");
pub const UnaryExpressionNode = @import("./ast/unary_expression_node.zig");
pub const CallExpressionNode = @import("./ast/call_expression_node.zig");
pub const ExpressionNode = @import("./ast/expression_node.zig").ExpressionNode;
pub const ConstantNode = @import("./ast/constant_node.zig");

const flags = @import("./flags");
pub const ConstantExpressionFlag = flags.ConstantExpressionFlag;
