library calzone.util;

import "package:analyzer/analyzer.dart" show ParameterKind;

const Map<String, String> NAME_REPLACEMENTS = const {
  "[]": "get",
  "[]=": "set",
  "==": "equals",
  "+": "add",
  "-": "subtract",
  "*": "multiply",
  "/": "divide",
  "|": "bitwiseOr",
  "&": "bitwiseAnd",
  "<": "lessThan",
  "<=": "lessThanOrEqual",
  ">": "greaterThan",
  ">=": "greaterThanOrEqual",
  "~/": "divideTruncate",
  "~": "bitwiseNegate",
  "<<": "shiftLeft",
  ">>": "shiftRight",
  "%": "modulo",
  "^": "bitwiseExclusiveOr"
};

const List<String> PRIMITIVES = const ["String", "Number", "num", "double", "int", "Integer", "bool", "Boolean"];

abstract class TypeTransformer {
  List<String> get types;

  void dynamicTransformTo(StringBuffer output, List<String> globals);
  void dynamicTransformFrom(StringBuffer output, List<String> globals);

  void transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals);
  void transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals);
}

class Duo<K, V> {
  final K key;
  final V value;

  Duo(this.key, this.value);
}

class Parameter {
  final String type;
  final String name;
  final String defaultValue;

  final ParameterKind kind;

  Parameter(this.kind, [this.type = "dynamic", this.name, this.defaultValue]);
}
