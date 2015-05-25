library calzone.compiler;

import "package:calzone/util.dart";

import "dart:io";
import "dart:convert";

part "src/compiler/base_transformer.dart";
part "src/compiler/compiler.dart";

const Map<String, String> _NAME_REPLACEMENTS = const {
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

const List<String> _PRIMITIVES = const ["String", "int", "Integer", "bool", "Boolean"];

List<dynamic> _getTypeTree(String type) {
  RegExp regex = new RegExp(r"([A-Za-z]+)(?:\<([\w\s,]+)\>)*");
  var tree = [];

  Match match = regex.firstMatch(type);
  if (match == null) return tree;
  tree.add(match.group(0));

  if (match.group(1).trim().length > 0 && match.group(1) != type) {
    for (var group in match.group(1).split(r"[\,]{1}\s*")) tree
        .addAll(_getTypeTree(group));
  }

  return tree;
}
