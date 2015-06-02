library calzone.compiler;

import "package:analyzer/analyzer.dart" show ParameterKind;
import "package:calzone/analysis.dart" show Analyzer;
import "package:calzone/util.dart";

import "dart:io";
import "dart:convert";

part "src/compiler/base_transformer.dart";
part "src/compiler/compiler.dart";

RegExp _TYPE_REGEX = new RegExp(r"\(([^]*)\) -> ([^]+)");
RegExp _COMMA_REGEX = new RegExp(r",(?!([^(<]+[)>]))");
RegExp _SPACE_REGEX = new RegExp(r" (?!([^(<]+[)>]))");

List<dynamic> _getTypeTree(String type) {
  RegExp regex = new RegExp(r"([A-Za-z]+)(?:\<([\w\s,]+)\>)*");
  var tree = [];

  Match match = regex.firstMatch(type);
  if (match == null) return tree;
  tree.add(match.group(1));

  if (match.group(2) != null && match.group(2).trim().length > 0 && match.group(2) != type) {
    for (var group in match.group(2).split(r"[\,]{1}\s*")) tree
        .addAll(_getTypeTree(group));
  }

  return tree;
}
