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

List<Parameter> mergeParameters(List<Parameter> one, List<Parameter> two) {
  one.forEach((Parameter param) {
    var matches = two.where((p) => p.name == param.name);
    if(matches.length > 0 && matches.first.type != ParameterKind.REQUIRED) {
      one[one.indexOf(param)] = new Parameter(param.kind, param.type, param.name, matches.first.defaultValue);
    }
  });

  return one;
}

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
