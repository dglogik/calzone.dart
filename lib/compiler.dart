library calzone.compiler;

import "package:calzone/util.dart";

import "dart:io";
import "dart:convert";

// TODO: Add ~/ ~ << % >> once I figure out names for them
Map<String, String> _nameReplacements = {
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

Map<String, String> _globals = {
  "objEach": """
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
  """
};

List _primitives = ["String", "int", "Integer", "bool", "Boolean"];

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

class Compiler {
  final Map<String, dynamic> file;

  List<TypeTransformer> typeTransformers = [];

  Map<String, Map> _wrappedClasses = {};
  List<String> _globalList = [];

  Compiler(this.file);

  Compiler.fromPath(String path)
      : this.file = JSON.decode(new File(path).readAsStringSync());

  _jsToDart(output, name, type) {
    if (_primitives.contains(type)) return;

    if (_wrappedClasses.containsKey(type)) {
      output.write("$name = $name.obj;");
      return;
    }

    _handleTree(tree) {
      if (tree[0] == "Map") {
        if (tree.length > 2) {
          if (!_globalList.contains(_globals["objEach"])) _globalList
              .add(_globals["objEach"]);
          output.write("objEach(a, function(a, i) {");
          // _handleTree(tree[1]);
          _handleTree(tree[2]);
          output.write("}, a);");
        }

        var k = "P.String";
        var v = "null";

        if (tree.length > 2) {
          if (tree[1][0] != "dynamic") k = "init.allClasses.${tree[1][0]}";
          if (tree[2][0] != "dynamic") v = "init.allClasses.${tree[2][0]}";
        }

        output.write(
            "var elms = Object.keys(a).reduce(function(arr, key) { arr.push(key); arr.push(a[key]); return arr; }, []);");
        output.write(
            "this[i] = new P.LinkedHashMap_LinkedHashMap\$_literal(elms,$k,$v);");
      } else if (tree[0] == "List" && tree.length > 1) {
        output.write("a.forEach(function(a, i) {");
        _handleTree(tree[1]);
        output.write("}, a);");
      } else {
        _jsToDart(output, "this[i]", tree[0]);
      }
    }

    var tree = _getTypeTree(type);

    for (TypeTransformer transformer in typeTransformers) {
      if (transformer.types.contains(tree[0])) output
          .write(transformer.transformTo(name, tree));
    }

    if (tree[0] == "Map") {
      if (tree.length > 2) {
        if (!_globalList.contains(_globals["objEach"])) _globalList
            .add(_globals["objEach"]);
        output.write("objEach($name, function(a, i) {");
        // _handleTree(tree[1]);
        _handleTree(tree[2]);
        output.write("}, $name);");
      }

      var k = "P.String";
      var v = "null";

      if (tree.length > 2) {
        if (tree[1][0] != "dynamic") k = "init.allClasses." + tree[1][0];
        if (tree[2][0] != "dynamic") v = "init.allClasses." + tree[2][0];
      }

      output.write(
          "var elms = Object.keys($name).reduce(function(arr, key) { arr.push(key); arr.push($name[key]); return arr; }, []);");
      output.write(
          "$name = new P.LinkedHashMap_LinkedHashMap\$_literal(elms,$k,$v);");
    } else if (tree[0] == "List" && tree.length > 1) {
      output.write("$name.forEach(function(a, i) {");
      _handleTree(tree[1]);
      output.write("}, $name);");
    }
  }

  _dartToJS(output, name, type) {
    if (_primitives.contains(type)) return;

    if (_wrappedClasses.containsKey(type)) {
      output.write("$name = Object.create(module.exports.$name.prototype)");

      _handleClassField(output, {"name": "isWrapped", "value": "true"}, name);

      _handleClassField(output, {
        "name": "obj",
        "value": "Object.create(init.allClasses.$name.prototype)"
      }, name);

      var data = _wrappedClasses[type];
      for (var child in data["children"]) {
        child = child.split("/");

        var type = child[0];
        var id = child[1];

        if (type != "field") continue;

        _handleClassField(output, file["elements"][type][id], name);
      }

      return;
    }

    _handleTree(tree, [binding = "a"]) {
      if (tree[0] == "List" && tree.length > 1) {
        output.write("this[i] = a.map(function(a, i) {");
        _handleTree(tree[1]);
        output.write("}, $binding);");
      } else if (tree[0] == "Map") {
        output.write("$binding = (function(a) {");
        output.write(
            "var keys = a.get\$keys(); var values = a.get\$values(); a = {};");
        if (tree.length > 2) _handleTree(tree[2], "a");
        output.write(
            "keys.forEach(function(key, index) { a[key] = values[index]; });");
        output.write("return a;");
        output.write("}($binding))");
      } else {
        _dartToJS(output, "this[i]", tree[0]);
      }
    }

    var tree = _getTypeTree(type);

    for (TypeTransformer transformer in typeTransformers) {
      if (transformer.types.contains(tree[0])) output
          .write(transformer.transformTo(name, tree));
    }

    if (tree[0] == "List" && tree.length > 1) {
      output.write("$name = $name.forEach(function(a, i) {");
      _handleTree(tree[1]);
      output.write("}, $name);");
    } else if (tree[0] == "Map") {
      // TODO: ES6 Maps.
      // TODO: K of Map being non-String (requires ES6 Maps)
      output.write(
          "var keys = $name.get\$keys(); var values = $name.get\$values(); $name = {};");
      if (tree.length > 2) _handleTree(tree[2], "values");
      output.write(
          "keys.forEach(function(key, index) { $name[key] = values[index]; });");
    }
  }

  _handleFunction(output, data, [prefix, binding = "this", codeStr]) {
    if (prefix == null) output.write("function(");
    else output.write("$prefix.${data["name"]} = function(");

    List<Map> parameters = data["parameters"];
    if (parameters.length == 0) {
      // needs work
      String name = "\$n";
      var type = data["type"].split(" -> ")[0];
      var isOptional = false;
      var isPositional = false;
      List<String> p = type
          .substring(1, type.length - 1)
          .split(",")
          .removeWhere((piece) => piece.length == 0);
      if (p == null) {
        parameters = [];
      } else {
        parameters = p.map((String piece) {
          piece = piece.trim();

          if (piece.startsWith("[")) {
            isPositional = true;
            piece = piece.substring(1);
          }
          if (piece.endsWith("]")) {
            isPositional = false;
            piece = piece.substring(0, piece.length - 1);
          }
          if (piece.startsWith("{")) {
            isOptional = true;
            piece = piece.substring(1);
          }
          if (piece.endsWith("}")) {
            isOptional = false;
            piece = piece.substring(0, piece.length - 1);
          }

          var actualName = null;
          if (piece.contains(" ")) {
            actualName = piece.split(" ")[0];
            piece = piece.split(" ")[1];
          } else {
            name += "n";
          }
          return {
            "name": actualName != null ? actualName : name,
            "declaredType": piece,
            "isPositional": isPositional,
            "isOptional": isOptional
          };
        });
      }
    }
    var paramString = parameters.map((param) {
      return param["name"];
    }).join(",");
    output.write("$paramString");
    if (parameters.any(
        (param) => param.containsKey("isOptional") && param["isOptional"])) {
      if (paramString.length > 0) output.write(",");
      output.write("_optObj_");
    }
    output.write("){");

    String code = data["code"];
    if (codeStr != null || code != null && code.length > 0) {
      for (var param in parameters) {
        var name = param["name"];
        var declaredType = param["declaredType"];

        if (param.containsKey("isPositional") && param["isPositional"]) output
            .write("$name = typeof($name) === 'undefined' ? null : $name;");
        if (param.containsKey("isOptional") && param["isOptional"]) output.write(
            "var $name = typeof(_optObj_[$name]) === 'undefined' ? null : _optObj_[$name]");

        _jsToDart(output, name, declaredType);
      }

      output.write("var returned=(" +
          (codeStr != null ? codeStr : code.substring(code.indexOf(":") + 2)) +
          ").call($binding${paramString.length > 0 ? "," : ""}$paramString);");
      _dartToJS(output, "returned", data["type"].split(" -> ")[1]);
      output.write("return returned;};");
    }
  }

  _handleClassField(output, data, [prefix = "this"]) {
    var name = data["name"];
    output.write("Object.defineProperty($prefix, $name, {");

    if (data["value"] != null) {
      output.write("enumerable: false");
      output.write(",value: ${data["value"]}");
    } else {
      output.write("enumerable: ${(!name.startsWith("_"))}");
      output.write(",get: function() { var returned = this.obj.$name;");
      _dartToJS(output, "returned", data["type"]);
      output.write("return returned;},set: function(v) {");
      _jsToDart(output, "v", data["type"]);
      output.write("this.obj.$name = v;}");
    }

    output.write("});");
  }

  _handleClass(output, data, prefix) {
    var name = data["name"];
    output.write("$prefix.$name = function $name() {");

    _handleClassField(output, {"name": "isWrapped", "value": "true"});

    _handleClassField(output, {
      "name": "obj",
      "value": "Object.create(init.allClasses.$name.prototype)"
    });

    var functions = [];
    for (var child in data["children"]) {
      child = child.split("/");

      var type = child[0];
      var id = child[1];

      if (type == "function") {
        var data = file["elements"][type][id];

        if (data["kind"] == "constructor") {
          if (data["code"] == null || data["code"].length == 0) continue;
          _handleFunction(output, data);
          output.write(").apply(this.obj, arguments);");
          continue;
        }

        functions.add(data);
      }

      if (type == "field") {
        var data = file["elements"][type][id];
        _handleClassField(output, data);
      }
    }
    output.write("};");

    for (var func in functions) {
      if (_nameReplacements.containsKey(func["name"]) &&
          !functions
              .map((f) => f["name"])
              .contains(_nameReplacements[func["name"]])) func["name"] =
          _nameReplacements[func["name"]];
      if (func["modifiers"]["static"] || func["modifiers"]["factory"]) {
        _handleFunction(output, func, "module.exports.$name", "this",
            "init.allClasses.$name.${func["code"].split(":")[0]}");
      } else {
        _handleFunction(output, func, "module.exports.$name.prototype",
            "this.obj", "this.obj.${func["code"].split(":")[0]}");
      }
    }
  }

  String compile(List<String> libraries) {
    StringBuffer output = new StringBuffer();

    var children = [];
    for (var library in file["elements"]["library"].values) {
      if (!libraries.contains(library["name"])) continue;

      children.addAll(library["children"]);
    }

    for (var child in children) {
      if (child.split("/")[0] == "class") {
        _wrappedClasses[file["elements"]["class"][child.split("/")[1]][
            "name"]] = file["elements"]["class"][child.split("/")[1]];
      }
    }

    for (var child in children) {
      child = child.split("/");

      var type = child[0];
      var id = child[1];

      if (type == "function") {
        _handleFunction(output, file["elements"][type][id], "module.exports");
      }

      if (type == "class") {
        _handleClass(output, file["elements"][type][id], "module.exports");
      }
    }

    return _globalList.join() + output.toString();
  }
}
