library calzone.compiler;

import "package:analyzer/analyzer.dart" show ParameterKind;
import "package:calzone/analysis.dart" show Analyzer;
import "package:calzone/util.dart";

import "dart:io";
import "dart:convert";

part "src/compiler/base_transformer.dart";
part "src/compiler/compiler.dart";

final String _OBJ_EACH_PREFIX = """
  function objEach(obj, cb, thisArg) {
    if(typeof thisArg !== 'undefined') {
      cb = cb.bind(thisArg);
    }

    var count = 0;
    var keys = Object.keys(obj);
    var length = keys.length;

    for(; count < length; count++) {
      var key = keys[count];
      cb(obj[key], key, obj);
    }
  }
""";

RegExp _TYPE_REGEX = new RegExp(r"\(([^]*)\) -> ([^]+)");
RegExp _TREE_REGEX = new RegExp(r"([A-Za-z]+)(?:\<([\w\s,]+)\>)*");
RegExp _COMMA_REGEX = new RegExp(r",(?!([^(<]+[)>]))");
RegExp _SPACE_REGEX = new RegExp(r" (?!([^(<]+[)>]))");

enum FunctionTransformation {
  NORMAL,
  REVERSED,
  NONE
}

List<dynamic> _getTypeTree(String type) {
  var tree = [];

  Match match = _TREE_REGEX.firstMatch(type);
  if (match == null) return tree;
  tree.add(match.group(1));

  if (match.group(2) != null && match.group(2).trim().length > 0 && match.group(2) != type) {
    for (var group in match.group(2).split(r"[\,]{1}\s*"))
      tree.addAll(_getTypeTree(group));
  }

  return tree;
}
