part of calzone.compiler;

class Compiler {
  final Map<String, dynamic> file;

  List<TypeTransformer> typeTransformers = [];

  BaseTypeTransformer _base;
  Map<String, Map> _wrappedClasses = {};
  List<String> _globals = [];

  Compiler(this.file) {
    _base = new BaseTypeTransformer(this);
  }

  Compiler.fromPath(String path): this(JSON.decode(new File(path).readAsStringSync()));

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

        _base.transformTo(output, name, declaredType);
      }

      output.write("var returned=(" +
      (codeStr != null ? codeStr : code.substring(code.indexOf(":") + 2)) +
      ").call($binding${paramString.length > 0 ? "," : ""}$paramString);");
      _base.transformFrom(output, "returned", data["type"].split(" -> ")[1]);
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
      _base.transformFrom(output, "returned", data["type"]);
      output.write("return returned;},set: function(v) {");
      _base.transformTo(output, "v", data["type"]);
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
      if (_NAME_REPLACEMENTS.containsKey(func["name"]) &&
      !functions
      .map((f) => f["name"])
      .contains(_NAME_REPLACEMENTS[func["name"]])) func["name"] =
      _NAME_REPLACEMENTS[func["name"]];
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

    return _globals.join() + output.toString();
  }
}