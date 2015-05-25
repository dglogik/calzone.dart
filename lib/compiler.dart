library calzone.compiler;

import "package:calzone/util.dart";

import "dart:io";
import "dart:convert";

part "src/compiler/base_transformer.dart";
part "src/compiler/compiler.dart";

// TODO: Add ~/ ~ << % >> once I figure out names for them
Map<String, String> _NAME_REPLACEMENTS = {
  "[]": "get",
  "[]=": "set",
  "==": "equals",
  "+": "add",
  "-": "minus",
  "*": "multiply",
  "/": "divide",
  "^": "power",
  "|": "or",
  "&": "and",
  "<": "lessThan",
  "=<": "lessThanOrEqual",
  ">": "greaterThan",
  ">=": "greaterThanOrEqual"
};

List _PRIMITIVES = ["String", "int", "Integer", "bool", "Boolean"];

List _getTypeTree(String type) {
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