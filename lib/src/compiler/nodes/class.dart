part of calzone.compiler;

class Class implements Renderable {
  Map<String, dynamic> data;

  final List<String> staticFields;
  final List<String> getters;
  final List<String> setters;

  final List<String> inheritedFrom;

  final String name;
  final String libraryName;

  Class(this.name, this.libraryName, {this.staticFields: const [], this.getters: const [], this.setters: const [], this.inheritedFrom: const []});

  render(Compiler compiler, StringBuffer output) {
    String prefix = "module.exports";

    if (name.startsWith("_")) return;

    List<String> names = [];
    List<StringBuffer> methods = [];

    StringBuffer constructor = new StringBuffer();
    StringBuffer functions = new StringBuffer();
    StringBuffer fields = new StringBuffer();

    _handleClassChildren(Class c, Map memberData, {bool isTopLevel: true}) {
      var mangledFields = []..addAll(compiler.mangledNames.getClassFields(this.libraryName, this.name));

      List<String> accessors = [];
      Map<String, Map> getters = {};
      Map<String, Map> setters = {};

      for (var child in memberData["children"]) {
        child = child.split("/");

        var type = child[0];
        var id = child[1];

        if (type == "function") {
          var data = compiler.info.getElement(type, id);
          var name = data["name"];

          if (names.contains(name)) continue;
          names.add(name);

          if (name.startsWith("_")) continue;

          if (data["kind"] == "constructor" && isTopLevel) {
            var isDefault = name.length == 0;
            var buf = isDefault ? constructor : functions;
            if (!isDefault) functions.write("module.exports.${this.data["name"]}.$name = function() {");
            buf.write("var __obj__ = (");
            var code = data["code"] == null || data["code"].length == 0
                ? "function(){}"
                : "(" + data["code"].substring(data["code"].indexOf(":") + 2) + "[0])";
            var func = this.data["name"];
            (new Func(data, _getParamsFromInfo(compiler, data["type"], compiler.analyzer.getFunctionParameters(this.libraryName, func, this.data["name"])),
                code: code,
                withSemicolon: false,
                transform: FunctionTransformation.NONE)).render(compiler, buf);
            buf.write(").apply(this, arguments);");
            if (!isDefault) functions.write("return module.exports.${this.data["name"]}._(__obj__);};");
            continue;
          }

          if (data["kind"] == "constructor" && !isTopLevel) continue;

          var params = _getParamsFromInfo(compiler, data["type"], compiler.analyzer.getFunctionParameters(this.libraryName, data["name"], this.data["name"]));

          if (c != null && c.getters.contains(data["name"]) && params.length == 0) {
            if (!accessors.contains(name)) accessors.add(name);
            getters[name] = data;
            continue;
          }

          if (c != null && c.setters.contains(data["name"]) && params.length == 1) {
            if (!accessors.contains(name)) accessors.add(name);
            setters[name] = data;
            continue;
          }

          if (data["code"].length > 0) {
            if (NAME_REPLACEMENTS.containsKey(data["name"])) {
              if (memberData["children"]
                  .map((f) => compiler.info.getElement(f.split("/")[0], f.split("/")[1]))
                  .contains(NAME_REPLACEMENTS[data["name"]])) continue;
              data["name"] = NAME_REPLACEMENTS[data["name"]];
              name = data["name"];
            }

            if (data["modifiers"]["static"] || data["modifiers"]["factory"]) {
              if (isTopLevel)
                (new Func(data, params,
                    code: "init.allClasses.${mangledName != null ? mangledName : this.data["name"]}.${data["code"].split(":")[0]}",
                    prefix: "module.exports.${this.data["name"]}")).render(compiler, functions);
            } else {
              (new Func(data, params,
                  prefix: "module.exports.${this.data["name"]}.prototype",
                  binding: "this.__obj__",
                  code: "this.__obj__.${data["code"].split(":")[0]}")).render(compiler, functions);

              StringBuffer buf = new StringBuffer();
              methods.add(buf);

              var dartName = data["code"].split(":")[0];

              buf.write("if(proto.$name) { this.__obj__.$dartName = ");
              (new Func(data, params,
                  code: "this.$name",
                  withSemicolon: false,
                  transform: FunctionTransformation.REVERSED)).render(compiler, buf);
              buf.write(".bind(this);}");
            }
          }
        }

        if (type == "field") {
          var data = compiler.info.getElement(type, id);

          if (names.contains(data["name"])) continue;
          names.add(data["name"]);

          if (!data["name"].startsWith("_")) {
            if (c == null || !c.staticFields.contains(data["name"])) {
              var mangledName = mangledFields.length > 0 ? mangledFields.removeAt(0) : null;
              (new ClassProperty(data, c, mangledName: mangledName)).render(compiler, fields);
            } else {
              // TODO
              // (new ClassProperty(data, c, isStatic: true)).render(compiler, functions);
            }
          }
        }
      }

      for (var accessor in accessors) {
        fields.write("Object.defineProperty(this, \"$accessor\", {");

        fields.write("enumerable: true");
        if (getters[accessor] != null) {
          fields.write(",get: function() { var returned = (");
          (new Func(getters[accessor], _getParamsFromInfo(compiler, getters[accessor]["type"]),
              binding: "this.__obj__",
              transform: FunctionTransformation.NONE,
              withSemicolon: false)).render(compiler, fields);
          fields.write(").apply(this, arguments);");
          compiler.baseTransformer.transformFrom(fields, "returned", getters[accessor]["type"]);
          fields.write("return returned;}");
        }

        if (setters[accessor] != null) {
          fields.write(",set: function(v) {");
          compiler.baseTransformer.transformTo(fields, "v", setters[accessor]["type"]);
          fields.write("(");
          (new Func(setters[accessor], _getParamsFromInfo(compiler, setters[accessor]["type"]),
              binding: "this.__obj__",
              withSemicolon: false)).render(compiler, fields);
          fields.write(").call(this, v);}");
        } else if (getters[accessor] != null) {
          fields.write(",set: function(v) {");
          compiler.baseTransformer.transformTo(fields, "v", getters[accessor]["type"]);
          fields.write("this.__obj__.${getters[accessor]['code'].split(':')[0]} = function() { return v; };}");
        }

        fields.write("});");
      }
    }

    _handleClassChildren(this, data);

    this.inheritedFrom.reversed.forEach((superClass) {
        var classObj = compiler.analyzer.getClass(null, superClass);
        if (classObj != null)
          _handleClassChildren(classObj,
              compiler._classes[superClass] != null ?
                  compiler._classes[superClass].key :
                  compiler._classes[classObj.libraryName + "." + superClass].key,
              isTopLevel: false);
      });

    output.write("module.exports.$name = function $name() {");
    output.write(constructor.toString());

    (new ClassProperty({
      "name": "__isWrapped__"
    }, this, value: "true")).render(compiler, output);

    (new ClassProperty({
      "name": "__obj__"
    }, this, value: "__obj__")).render(compiler, output);

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

    (new ClassProperty({
      "name": "_"
    }, this, isStatic: true, value: () {
      output.write("function $name(__obj__) {var returned = Object.create($prefix.$name.prototype);");
      output.write("(function() {");

      (new ClassProperty({
        "name": "__isWrapped__"
      }, this, value: "true")).render(compiler, output);

      (new ClassProperty({
        "name": "__obj__"
      }, this, value: "__obj__")).render(compiler, output);

      output.write(fields.toString());

      output.write("}.bind(returned))();");
      output.write("return returned;}");
    })).render(compiler, output);

    output.write(functions.toString());
  }
}
