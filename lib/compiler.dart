library calzone.compiler;

import "package:analyzer/analyzer.dart" show ParameterKind;
import "package:calzone/analysis.dart" show Analyzer;
import "package:calzone/util.dart";

import "dart:io";
import "dart:convert";

part "src/compiler/base_transformer.dart";
part "src/compiler/compiler.dart";

part "src/compiler/nodes/class.dart";
part "src/compiler/nodes/function.dart";

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

abstract class Renderable {
  Map<String, dynamic> get data;

  void render(Compiler compiler, StringBuffer output);
}

const List<String> PRIMITIVES = const [
  "String",
  "Number",
  "num",
  "double",
  "int",
  "Integer",
  "bool",
  "Boolean"
];

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

final String _OVERRIDE_PREFIX = """
  var sSym = typeof(Symbol) === 'function';

  var mdex = module.exports;
  var obdp = Object.defineProperty;
  var obfr = Object.freeze;

  var clIw = sSym ? Symbol.for("calzone.isWrapped") : "__isWrapped__";
  var clOb = sSym ? Symbol.for("calzone.obj") : "__obj__";
  var clCl = sSym ? Symbol.for("calzone.constructor") : "_";

  function overrideFunc(cl, name, mangledName) {
    cl[clOb][mangledName] = function() {
      var args = new Array(arguments.length);
      var length = args.length;
      for(var i = 0; i < length; ++i) {
        // console.log(arguments[i]);
        args[i] = dynamicFrom(arguments[i]);
      }

      return dynamicTo((cl[name]).apply(cl, args));
    };
  }
""";

RegExp _TYPE_REGEX = new RegExp(r"\(([^]*)\) -> ([^]+)");
RegExp _TREE_REGEX = new RegExp(r"([A-Za-z]+)(?:\<([\w\s,]+)\>)*");
RegExp _COMMA_REGEX = new RegExp(r",(?!([^(<]+[)>]))");
RegExp _SPACE_REGEX = new RegExp(r" (?!([^(<]+[)>]))");

enum FunctionTransformation { NORMAL, REVERSED, NONE }

class _JSONWrapper {
  final Map<String, dynamic> data;

  _JSONWrapper(this.data);
}

class MangledNames extends _JSONWrapper {
  MangledNames(Map data) : super(data);

  String getClassName(String library, String className) {
    if (!data["libraries"].containsKey(library) || !data["libraries"][library]["names"].containsKey(className))
      throw className;
    return data["libraries"][library]["names"][className]["name"];
  }

  List<String> getClassFields(String library, String className) {
    if (!data["libraries"].containsKey(library) || !data["libraries"][library]["names"].containsKey(className))
      throw className;
    return data["libraries"][library]["names"][className]["fields"];
  }

  String getLibraryObject(String library) {
    if (!data["libraries"].containsKey(library))
      throw library;
    return data["libraries"][library]["obj"];
  }

  // warning: this method doesn't throw, it returns null
  String getStaticField(String library, String staticField, {String className}) {
    if(className != null)
      staticField = "$className.$staticField";

    if (!data["libraries"].containsKey(library))
      throw library;

    if (!data["libraries"][library]["staticFields"].containsKey(staticField))
      return null;

    return data["libraries"][library]["staticFields"][staticField];
  }
}

class InfoData extends _JSONWrapper {
  InfoData(Map data) : super(data);

  Map<String, dynamic> getElement(String type, String id) {
    return data["elements"][type][id.toString()];
  }

  Iterable<Map<String, dynamic>> getLibraries() {
    return data["elements"]["library"].values;
  }
}

class InfoParent extends _JSONWrapper {
  InfoData parent;
  Map<String, Map> children = {};

  InfoParent(this.parent, Map data) : super(data) {
    for (var child in data["children"]) {
      child = child.split("/");

      var type = child[0];
      var id = child[1];

      var childData = parent.getElement(type, id);
      children[childData["name"].length > 0
          ? childData["name"]
          : data["name"]] = childData;
    }
  }

  String getMangledName(String child) {
    if(children[child] == null || children[child]["code"] == null)
      throw children[child];
    return children[child]["code"].split(":")[0].trim();
  }

  String renderConditional(String name) {
    var conditionals = [];
    for(var childName in children.keys) {
      if(children[childName]["kind"] == "method" && children[childName]["code"] != null) {
        conditionals.add("$name.${getMangledName(childName)}");
      }
    }
    return conditionals.join(" && ");
  }
}

class Parameter {
  final String type;
  final String name;
  final String defaultValue;

  final ParameterKind kind;

  Parameter(this.kind, [this.type = "dynamic", this.name, this.defaultValue]);
}

List<dynamic> _getTypeTree(String type) {
  var tree = [];

  Match match = _TREE_REGEX.firstMatch(type);
  if (match == null) return tree;
  tree.add(match.group(1));

  if (match.group(2) != null &&
      match.group(2).trim().length > 0 &&
      match.group(2) != type) {
    for (var group in match.group(2).split(r"[\,]{1}\s*")) tree
        .addAll(_getTypeTree(group));
  }

  return tree;
}

// dart2js has a weird order, so reorganize entries from analyzer
List<Parameter> _getParamsFromInfo(Compiler compiler, String typeStr, [List<Parameter> analyzerParams]) {
  String type = _TYPE_REGEX.firstMatch(typeStr).group(1);

  int paramNameIndex = 1;

  var isOptional = false;
  var isPositional = false;

  if (type.length <= 0) return [];

  List<String> p = type.split(_COMMA_REGEX)..removeWhere((piece) => piece.trim().length == 0);
  if (p == null || p.length == 0) return [];
  List<Parameter> parameters = p.map((String piece) {
    piece = piece.trim();

    if (piece.startsWith("[")) {
      isPositional = true;
      piece = piece.substring(1);
    }
    if (piece.endsWith("]")) {
      piece = piece.substring(0, piece.length - 1);
    }

    if (piece.startsWith("{")) {
      isOptional = true;
      piece = piece.substring(1);
    }
    if (piece.endsWith("}")) {
      piece = piece.substring(0, piece.length - 1);
    }

    var match = _TYPE_REGEX.firstMatch(piece);
    if (match != null) {
      List functionParams = match.group(1)
          .split(",")
          .map((e) =>
              e.replaceAll(r"[\[\]\{\}]", "").trim())
          .where((e) => e.length > 0)
          .map((e) => e.contains(" ")
                  ? e.split(" ")[0]
                  : (compiler.classes.containsKey(_getTypeTree(e)[0]) || compiler.classes.keys.any((key) => key.endsWith("." + _getTypeTree(e)[0])))
              ? e : "dynamic")
          .toList();

      var name = "";
      var groupParts = match.group(2).split(" ");
      if (groupParts.length > 1 && !groupParts.last.contains(">") && !groupParts.last.contains(")")) {
        name = " " + groupParts.last;
        groupParts = groupParts.sublist(0, groupParts.length - 1);
      }

      functionParams.add(groupParts.join(" "));
      piece = piece.substring(0, match.start) + "Function<${functionParams.join(",")}>$name" + piece.substring(match.end);
    }

    var actualName = null;
    var split = piece.split(_SPACE_REGEX);
    if (split.length > 1) {
      piece = split[0];
      actualName = split[1];
    } else {
      var c = _getTypeTree(split[0])[0];
      if (c != "Function" && !compiler.classes.containsKey(c) && !compiler.classes.keys.any((key) => key.contains(".$c"))) {
        piece = "dynamic";
        actualName = c;
      } else {
        piece = split[0];
        paramNameIndex++;
        actualName = "\$" + ("n" * paramNameIndex);
      }
    }

    ParameterKind kind = isOptional ? ParameterKind.NAMED : (isPositional ? ParameterKind.POSITIONAL : ParameterKind.REQUIRED);

    return new Parameter(kind, piece, actualName);
  }).toList();

  if (analyzerParams != null) {
    parameters.forEach((Parameter param) {
      var matches = analyzerParams.where((p) => p.name == param.name);
      if (matches.length > 0 && matches.first.type != ParameterKind.REQUIRED) {
        parameters[parameters.indexOf(param)] = new Parameter(param.kind, param.type, param.name, matches.first.defaultValue);
      }
    });
  }

  return parameters;
}
