part of calzone.compiler;

class Compiler {
  final Analyzer analyzer;
  final Map<String, dynamic> _info;

  final List<TypeTransformer> typeTransformers;

  BaseTypeTransformer _base;
  Map<String, Duo<Map, bool>> _classes = {};
  List<String> _globals = [];

  Compiler(String dartFile, this._info, {this.typeTransformers: const []})
      : analyzer = new Analyzer(dartFile) {
    _base = new BaseTypeTransformer(this);
  }

  Compiler.fromPath(String dartFile, String path,
      {List<TypeTransformer> typeTransformers})
      : this(dartFile, JSON.decode(new File(path).readAsStringSync()),
          typeTransformers: typeTransformers);

  List<Parameter> _getParamsFromInfo(String typeStr,
      [List<Parameter> analyzerParams]) {
    String type = _TYPE_REGEX.firstMatch(typeStr).group(1);

    int paramNameIndex = 1;

    var isOptional = false;
    var isPositional = false;

    if (type.length <= 0) return [];

    List<String> p = type.split(_COMMA_REGEX)
      ..removeWhere((piece) => piece.trim().length == 0);
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
        List functionParams =
            match
                .group(1)
                .split(",")
                .map((e) => e.replaceAll(r"[\[\]\{\}]", "").trim())
                .where((e) => e.length > 0)
                .map((e) => e.contains(" ")
                    ? e.split(" ")[0]
                    : (_classes.containsKey(_getTypeTree(e)[0])
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
        piece = split[0];
        actualName = split[1];
      } else {
        var c = _getTypeTree(split[0])[0];
        if (c != "Function" && !_classes.containsKey(c)) {
          piece = "dynamic";
          actualName = c;
        } else {
          piece = split[0];
          paramNameIndex++;
          actualName = "\$" + ("n" * paramNameIndex);
        }
      }

      ParameterKind kind = isOptional
          ? ParameterKind.NAMED
          : (isPositional ? ParameterKind.POSITIONAL : ParameterKind.REQUIRED);

      return new Parameter(kind, piece, actualName);
    }).toList();

    if (analyzerParams != null) {
      parameters.forEach((Parameter param) {
        var matches = analyzerParams.where((p) => p.name == param.name);
        if (matches.length > 0 &&
            matches.first.type != ParameterKind.REQUIRED) {
          parameters[parameters.indexOf(param)] = new Parameter(
              param.kind, param.type, param.name, matches.first.defaultValue);
        }
      });
    }

    return parameters;
  }

  _handleFunction(StringBuffer output, Map data, List<Parameter> parameters,
      {String prefix, String binding: "this", String codeStr,
      withSemicolon: true,
      FunctionTransformation transform: FunctionTransformation.NORMAL}) {
    if (prefix == null) output.write("function(");
    else output.write("$prefix.${data["name"]} = function(");

    var paramStringList = []..addAll(parameters);
    paramStringList.removeWhere((param) => param.kind == ParameterKind.NAMED);

    var paramString = paramStringList.map((param) => param.name).join(",");
    output.write("$paramString");
    if (parameters.any((param) => param.kind == ParameterKind.NAMED)) {
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

        if (param.kind == ParameterKind.POSITIONAL) output.write(
            "$name = typeof($name) === 'undefined' ? ${param.defaultValue} : $name;");
        if (param.kind == ParameterKind.NAMED) output.write(
            "var $name = typeof(_optObj_.$name) === 'undefined' ? ${param.defaultValue} : _optObj_.$name;");

        if (param.kind != ParameterKind.REQUIRED) output
            .write("if($name !== null) {");

        if (transform != FunctionTransformation.REVERSED) _base.transformTo(
            output, name, declaredType);
        else _base.transformFrom(output, name, declaredType);

        if (param.kind != ParameterKind.REQUIRED) output.write("}");
      }

      code =
          codeStr != null
              ? codeStr
              : (code.trim().startsWith(":") == false
                  ? "$binding." + code.substring(0, code.indexOf(":"))
                  : code.substring(code.indexOf(":") + 2));

      var fullParamString = parameters.map((p) => p.name).join(",");

      StringBuffer tOutput = new StringBuffer();
      if (transform == FunctionTransformation.NORMAL)
        _base.transformFrom(tOutput, "returned", data["returnType"]);
      else if (transform == FunctionTransformation.REVERSED)
        _base.transformTo(tOutput, "returned", data["returnType"]);

      output.write(tOutput.length > 0 ? "var returned = " : "return ");
      output.write(
          "($code).call($binding${paramString.length > 0 ? "," : ""}$fullParamString);");
      output.write(
          tOutput.length > 0 ? tOutput.toString() + "return returned;}" : "}");

      if (withSemicolon) output.write(";");
    }
  }

  _handleClassField(StringBuffer output, Map data, [String prefix = "this"]) {
    var name = data["name"];
    output.write("Object.defineProperty($prefix, \"$name\", {");

    if (data["value"] != null) {
      if (data["value"] is Function) {
        output.write("enumerable: false");
        output.write(",value:(");
        data["value"]();
        output.write(")");
      } else {
        output.write("enumerable: false");
        output.write(",value: ${data["value"]}");
      }
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

    List<String> names = [];
    List<StringBuffer> methods = [];
    StringBuffer constructor = new StringBuffer();
    StringBuffer functions = new StringBuffer();
    StringBuffer fields = new StringBuffer();

    _handleClassChildren(Map memberData, {bool isTopLevel: true, Class classObj}) {
      List<String> accessors = [];
      Map<String, Map> getters = {};
      Map<String, Map> setters = {};

      for (var child in memberData["children"]) {
        child = child.split("/");

        var type = child[0];
        var id = child[1];

        if (type == "function") {
          var data = _info["elements"][type][id];
          var name = data["name"];

          if (names.contains(name)) continue;
          names.add(name);

          if (name.startsWith("_")) continue;

          if (data["kind"] == "constructor" && isTopLevel) {
            var isDefault = name.length == 0;
            var buf = isDefault ? constructor : functions;
            if (!isDefault) functions.write(
                "module.exports.${classData["name"]}.$name = function() {");
            buf.write("var __obj__ = (");
            var code = data["code"] == null || data["code"].length == 0
                ? "function(){}"
                : "(" +
                    data["code"].substring(data["code"].indexOf(":") + 2) +
                    "[0])";
            var func = classData["name"];
            _handleFunction(buf, data, _getParamsFromInfo(data["type"], analyzer
                    .getFunctionParameters(library, func, classData["name"])),
                codeStr: code,
                withSemicolon: false,
                transform: FunctionTransformation.NONE);
            buf.write(").apply(this, arguments);");
            if (!isDefault) functions.write(
                "return module.exports.${classData["name"]}._(__obj__);};");
            continue;
          }

          if (data["kind"] == "constructor" && !isTopLevel) continue;

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

          if (data["code"].length > 0) {
            if (NAME_REPLACEMENTS.containsKey(data["name"])) {
              if (memberData["children"]
                  .map((f) =>
                      _info["elements"][f.split("/")[0]][f.split("/")[1]])
                  .contains(NAME_REPLACEMENTS[data["name"]])) continue;
              data["name"] = NAME_REPLACEMENTS[data["name"]];
              name = data["name"];
            }

            if (data["modifiers"]["static"] || data["modifiers"]["factory"]) {
              if (isTopLevel) _handleFunction(functions, data,
                  _getParamsFromInfo(data["type"], analyzer
                      .getFunctionParameters(
                          library, data["name"], classData["name"])),
                  prefix: "module.exports.${classData["name"]}",
                  codeStr: "init.allClasses.${classData["name"]}.${data["code"].split(":")[0]}");
            } else {
              _handleFunction(functions, data, _getParamsFromInfo(data["type"],
                      analyzer.getFunctionParameters(
                          library, name, classData["name"])),
                  prefix: "module.exports.${classData["name"]}.prototype",
                  binding: "this.__obj__",
                  codeStr: "this.__obj__.${data["code"].split(":")[0]}");

              StringBuffer buf = new StringBuffer();
              methods.add(buf);

              var params = _getParamsFromInfo(data["type"]);
              var dartName = data["code"].split(":")[0];

              buf.write("if(proto.$name) { this.__obj__.$dartName = ");
              _handleFunction(buf, data, params,
                  codeStr: "this.$name",
                  withSemicolon: false,
                  transform: FunctionTransformation.REVERSED);
              buf.write(".bind(this);}");
            }
          }
        }

        if (type == "field") {
          var data = _info["elements"][type][id];

          if (names.contains(data["name"])) continue;
          names.add(data["name"]);

          if (!data["name"].startsWith("_")) {
            if (classObj == null ||
                !classObj.staticFields.contains(data["name"])) {
              _handleClassField(fields, data);
            } else {
              _handleClassField(functions, data, "module.exports.$name");
            }
          }
        }
      }

      for (var accessor in accessors) {
        fields.write("Object.defineProperty(this, \"$accessor\", {");

        fields.write("enumerable: true");
        if (getters[accessor] != null) {
          fields.write(",get: function() { var returned = (");
          _handleFunction(fields, getters[accessor],
              _getParamsFromInfo(getters[accessor]["type"]),
              binding: "this.__obj__",
              transform: FunctionTransformation.NONE,
              withSemicolon: false);
          fields.write(").apply(this, arguments);");
          _base.transformFrom(fields, "returned", getters[accessor]["type"]);
          fields.write("return returned;}");
        }

        if (setters[accessor] != null) {
          fields.write(",set: function(v) {");
          _base.transformTo(fields, "v", setters[accessor]["type"]);
          fields.write("(");
          _handleFunction(fields, setters[accessor],
              _getParamsFromInfo(setters[accessor]["type"]),
              binding: "this.__obj__", withSemicolon: false);
          fields.write(").call(this, v);}");
        }

        fields.write("});");
      }
    }

    Class c = analyzer.getClass(library, name);

    _handleClassChildren(data, classObj: c);

    if (c != null) {
      c.inheritedFrom.reversed.forEach((superClass) {
        var classObj = analyzer.getClass(null, superClass);
        if(classObj != null)
          _handleClassChildren(
              _classes[superClass] != null ? _classes[superClass].key : _classes[classObj.libraryName + "." + superClass].key,
              isTopLevel: false,
              classObj: classObj);
      });
    }

    output.write("module.exports.$name = function $name() {");
    output.write(constructor.toString());

    _handleClassField(output, {"name": "__isWrapped__", "value": "true"});
    _handleClassField(output, {"name": "__obj__", "value": "__obj__"});

    output.write(fields.toString());
    output.write("};");

    output.write("""
    Object.defineProperty(module.exports.$name, 'class', {
      get: function() {
        function $name() {
          module.exports.$name.apply(this, arguments);
          var proto = Object.getPrototypeOf(this);
    """);
    methods.forEach((method) => output.write(method.toString()));
    output.write("""
        }

        $name.prototype = Object.create(module.exports.$name.prototype);

        return $name;
      }
    });
    """);

    _handleClassField(output, {
      "name": "_",
      "value": () {
        output.write(
            "function $name(__obj__) {var returned = Object.create($prefix.$name.prototype);");
        output.write("(function() {");

        _handleClassField(output, {"name": "__isWrapped__", "value": "true"});
        _handleClassField(output, {"name": "__obj__", "value": "__obj__"});

        output.write(fields.toString());

        output.write("}.bind(returned))();");
        output.write("return returned;}");
      }
    }, "module.exports.$name");

    output.write(functions.toString());
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

        var isIncluded = include
                .contains(library["name"] + "." + childData["name"]) ||
            include.contains(library["name"]);

        if (type == "class") {
          _classes[isIncluded ? childData["name"] : library["name"] + "." + childData["name"]] = new Duo(childData, isIncluded);
        }

        if (isIncluded) children.add(new Duo(library["name"], childData));
      }
    }

    output.write(
        "function dynamicTo(obj) {if(typeof(obj) === 'undefined' || obj === null) { return obj; }");
    _base.dynamicTransformTo(output, _globals);
    for (var transformer in typeTransformers) {
      transformer.dynamicTransformTo(output, _globals);
    }
    output.write("return obj;}");

    output.write(
        "function dynamicFrom(obj) {if(typeof(obj) === 'undefined' || obj === null) { return obj; }");
    _base.dynamicTransformFrom(output, _globals);
    for (var transformer in typeTransformers) {
      transformer.dynamicTransformFrom(output, _globals);
    }
    output.write("return obj;}");

    for (var child in children) {
      var type = child.value["kind"];

      if (type == "function") {
        _handleFunction(output, child.value, _getParamsFromInfo(
                child.value["type"],
                analyzer.getFunctionParameters(child.key, child.value["name"])),
            prefix: "module.exports");
      }

      if (type == "class") {
        _handleClass(output, child.key, child.value, "module.exports");
      }
    }

    return _globals.join() + output.toString();
  }
}
