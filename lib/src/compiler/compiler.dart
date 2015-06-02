part of calzone.compiler;

class Compiler {
  final Analyzer analyzer;
  final Map<String, dynamic> _info;

  List<TypeTransformer> typeTransformers = [];

  BaseTypeTransformer _base;
  List<String> _allClasses = [];
  Map<String, Map> _wrappedClasses = {};
  List<String> _globals = [];

  Compiler(String dartFile, this._info): analyzer = new Analyzer(dartFile) {
    _base = new BaseTypeTransformer(this);
  }

  Compiler.fromPath(String dartFile, String path)
      : this(dartFile, JSON.decode(new File(path).readAsStringSync()));

  List<Parameter> _getParamsFromInfo(String typeStr) {
    String type = _TYPE_REGEX.firstMatch(typeStr).group(1);

    int paramNameIndex = 1;

    var isOptional = false;
    var isPositional = false;

    if (type.length <= 0)
      return [];

    List<String> p = type.split(_COMMA_REGEX)
      ..removeWhere((piece) => piece.trim().length == 0);
    if (p == null || p.length == 0)
      return [];
    return p.map((String piece) {
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
        List functionParams =
            match
                .group(1)
                .split(",")
                .map((e) => e.replaceAll(r"[\[\]\{\}]", "").trim())
                .where((e) => e.length > 0)
                .map((e) => e.contains(" ")
                    ? e.split(" ")[0]
                    : (_allClasses.contains(_getTypeTree(e)[0])
                        ? e
                        : "dynamic"))
                .toList();

        var name = "";
        var groupParts = match.group(2).split(" ");
        if (groupParts.length > 1 &&
            !groupParts.last.contains(">") &&
            !groupParts.last.contains(")")) {
          name = " " + groupParts.last;
          groupParts = groupParts.sublist(0, groupParts.length - 1);
        }

        functionParams.add(groupParts.join(" "));
        piece = piece.substring(0, match.start) +
            "Function<${functionParams.join(",")}>$name" +
            piece.substring(match.end);
      }

      var actualName = null;
      var split = piece.split(_SPACE_REGEX);
      if (split.length > 1) {
        if (split[1].endsWith(">")) throw new StateError(piece);
        piece = split[0];
        actualName = split[1];
      } else {
        var c = _getTypeTree(split[0])[0];
        if (c != "Function" && !_allClasses.contains(c)) {
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
  }


  _handleFunction(StringBuffer output, Map data, List<Parameter> parameters, [String prefix, String binding = "this", String codeStr,
      withSemicolon = true, transformResult = true]) {
    if (prefix == null) output.write("function(");
    else output.write("$prefix.${data["name"]} = function(");

    var paramStringList = []..addAll(parameters);
    paramStringList.removeWhere(
        (param) => param.kind == ParameterKind.NAMED);

    var paramString = paramStringList.map((param) => param.name).join(",");
    output.write("$paramString");
    if (parameters.any(
        (param) => param.kind == ParameterKind.NAMED)) {
      if (paramString.length > 0) output.write(",");
      output.write("_optObj_){_optObj_ = _optObj_ || {};");
    } else {
      output.write("){");
    }

    String code = data["code"];
    if (codeStr != null || code != null && code.length > 0) {
      for (var param in parameters) {
        var name = param.name;
        var declaredType = param.type;

        if (param.kind == ParameterKind.POSITIONAL)
          output.write("$name = typeof($name) === 'undefined' ? ${param.defaultValue} : $name;");
        if (param.kind == ParameterKind.NAMED)
          output.write("var $name = typeof(_optObj_.$name) === 'undefined' ? ${param.defaultValue} : _optObj_.$name;");

        if (param.kind != ParameterKind.REQUIRED) output.write("if($name !== null) {");

        _base.transformTo(output, name, declaredType);

        if (param.kind != ParameterKind.REQUIRED) output.write("}");
      }

      code = codeStr != null
          ? codeStr
          : (code.trim().startsWith(":") == false
              ? "$binding." + code.substring(0, code.indexOf(":"))
              : code.substring(code.indexOf(":") + 2));

      var fullParamString = parameters.map((p) => p.name).join(",");

      output.write("var returned=($code).call($binding${paramString.length > 0 ? "," : ""}$fullParamString);");
      if (transformResult) _base.transformFrom(output, "returned", _TYPE_REGEX.firstMatch(data["type"]).group(2));
      output.write("return returned;}");
      if (withSemicolon) output.write(";");
    }
  }

  _handleClassField(StringBuffer output, Map data, [String prefix = "this"]) {
    var name = data["name"];
    output.write("Object.defineProperty($prefix, \"$name\", {");

    if (data["value"] != null) {
      output.write("enumerable: false");
      output.write(",value: ${data["value"]}");
    } else {
      output.write("enumerable: ${(!name.startsWith("_"))}");
      output.write(",get: function() { var returned = this.__obj__.$name;");
      _base.transformFrom(output, "returned", data["type"]);
      output.write("return returned;},set: function(v) {");
      _base.transformTo(output, "v", data["type"]);
      output.write("this.__obj__.$name = v;}");
    }

    output.write("});");
  }

  _handleClass(StringBuffer output, String library, Map data, String prefix) {
    var classData = data;
    var name = data["name"];
    if (name.startsWith("_")) return;

    var functions = [];
    _handleClassChildren([isFromObj = false]) {
      List<String> accessors = [];
      Map<String, Map> getters = {};
      Map<String, Map> setters = {};

      for (var child in data["children"]) {
        child = child.split("/");

        var type = child[0];
        var id = child[1];

        if (type == "function" && !isFromObj) {
          var data = _info["elements"][type][id];
          var name = data["name"];

          if (name.startsWith("_")) continue;

          if (data["kind"] == "constructor") {
            output.write("Object.defineProperty(this, '__obj__', {");
            output.write("enumerable: false, value: (");
            var code = data["code"] == null || data["code"].length == 0
                ? "function(){}"
                : "(" + data["code"].substring(data["code"].indexOf(":") + 2) + "[0])";
            var func = classData["name"];
            if(data["name"] != null && data["name"].length > 0) {
              func += "." + data["name"];
            }
            _handleFunction(output, data, mergeParameters(_getParamsFromInfo(data["type"]), analyzer.getFunctionParameters(library, func)), null, "this", code, false, false);
            output.write(").apply(this, arguments)");
            output.write("});");
            continue;
          }

          if (data["code"].startsWith("set\$")) {
            if (!accessors.contains(name)) accessors.add(name);
            setters[name] = data;
            continue;
          }

          if (data["code"].startsWith("get\$")) {
            if (!accessors.contains(name)) accessors.add(name);
            getters[name] = data;
            continue;
          }

          if (data["code"].length > 0) functions.add(data);
        }

        if (type == "field") {
          var data = _info["elements"][type][id];
          if (!data["name"].startsWith("_")) _handleClassField(output, data);
        }
      }

      for (var accessor in accessors) {
        output.write("Object.defineProperty(this, \"$accessor\", {");

        output.write("enumerable: true");
        if (getters[accessor] != null) {
          output.write(",get: function() { var returned = (");
          _handleFunction(output, getters[accessor], _getParamsFromInfo(getters[accessor]["type"]), null, "this.__obj__", null, false);
          output.write(").apply(this, arguments);");
          _base.transformFrom(output, "returned", getters[accessor]["type"]);
          output.write("return returned;}");
        }

        if (setters[accessor] != null) {
          output.write(",set: function(v) {");
          _base.transformTo(output, "v", setters[accessor]["type"]);
          output.write("(");
          _handleFunction(output, setters[accessor], _getParamsFromInfo(setters[accessor]["type"]), null, "this.__obj__", null, false);
          output.write(").call(this, v);}");
        }

        output.write("});");
      }
    }

    output.write("$prefix.$name = function $name() {");

    _handleClassField(output, {"name": "__isWrapped__", "value": "true"});

    _handleClassChildren();

    output.write("};");

    for (var func in functions) {
      if (NAME_REPLACEMENTS.containsKey(func["name"]) &&
          !functions
              .map((f) => f["name"])
              .contains(NAME_REPLACEMENTS[func["name"]])) func["name"] = NAME_REPLACEMENTS[func["name"]];
      if (func["modifiers"]["static"] || func["modifiers"]["factory"]) {
        _handleFunction(output, func,
            mergeParameters(_getParamsFromInfo(func["type"]), analyzer.getFunctionParameters(library, "${data["name"]}.${func["name"]}")),
            "module.exports.$name", "this", "init.allClasses.$name.${func["code"].split(":")[0]}");
      } else {
        _handleFunction(output, func,
            mergeParameters(_getParamsFromInfo(func["type"]), analyzer.getFunctionParameters(library, "${data["name"]}.${func["name"]}")),
            "module.exports.$name.prototype", "this.__obj__", "this.__obj__.${func["code"].split(":")[0]}");
      }
    }

    output.write(
        "$prefix.$name.fromObj = function $name(__obj__) {var returned = Object.create($prefix.$name.prototype);");
    output.write("(function() {");

    _handleClassField(output, {"name": "__isWrapped__", "value": "true"});

    _handleClassField(output, {"name": "__obj__", "value": "__obj__"});

    _handleClassChildren(true);

    output.write("}.bind(returned))();");
    output.write("return returned;};");
  }

  String compile(List<String> include) {
    StringBuffer output = new StringBuffer();

    List<Duo<String, Map>> children = [];
    for (var library in _info["elements"]["library"].values) {
      for (var child in library["children"]) {
        child = child.split("/");

        var type = child[0];
        var id = child[1];

        var childData = _info["elements"][type][id];

        if (type == "class") {
          _allClasses.add(childData["name"]);
        }

        if (include.contains(library["name"] + "." + childData["name"]) || include.contains(library["name"])) {
          if(type == "class")
            _wrappedClasses[childData["name"]] = childData;
          children.add(new Duo(library["name"], childData));
        }
      }
    }

    output.write("function dynamicTo(obj) {if(typeof(obj) === 'undefined' || obj === null) { return obj; }");
    _base.dynamicTransformTo(output, _globals);
    for(var transformer in typeTransformers) {
      transformer.dynamicTransformTo(output, _globals);
    }
    output.write("return obj;}");

    output.write("function dynamicFrom(obj) {if(typeof(obj) === 'undefined' || obj === null) { return obj; }");
    _base.dynamicTransformFrom(output, _globals);
    for(var transformer in typeTransformers) {
      transformer.dynamicTransformFrom(output, _globals);
    }
    output.write("return obj;}");

    for (var child in children) {
      var type = child.value["kind"];

      if (type == "function") {
        _handleFunction(output, child.value,
            mergeParameters(_getParamsFromInfo(child.value["type"]), analyzer.getFunctionParameters(child.key, child.value["name"])), "module.exports");
      }

      if (type == "class") {
        _handleClass(output, child.key, child.value, "module.exports");
      }
    }

    return _globals.join() + output.toString();
  }
}
