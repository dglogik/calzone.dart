part of calzone.compiler;

final RegExp _FIELD_REGEX = new RegExp(r"[A-Za-z_0-9$]+(?=[^:A-Za-z]|$),*");

class Class implements Renderable {
  final Map<String, List<Parameter>> functions = {};
  Map<String, dynamic> data;

  final List<String> staticFields;
  final List<String> getters;
  final List<String> setters;

  final List<String> inheritedFrom;

  final String name;
  final String libraryName;

  Class(this.name, this.libraryName, {this.staticFields: const [], this.getters: const [], this.setters: const [], this.inheritedFrom: const []});

  render(Compiler compiler, StringBuffer output) {
    List<String> names = [];
    List<StringBuffer> methods = [];

    StringBuffer constructor = new StringBuffer();
    StringBuffer prototype = new StringBuffer();
    StringBuffer global = new StringBuffer();

    _handleClassChildren(Class c, Map memberData, {bool isTopLevel: true}) {
      var mangledFields = compiler.mangledNames.getClassFields(c.libraryName, c.name);
      if(mangledFields == null)
        mangledFields = [];

      List<String> accessors = [];
      Map<String, Map> getters = {};
      Map<String, Map> setters = {};

      for (var child in memberData["children"]) {
        child = child.split("/");

        var type = child[0];
        var id = child[1];

        var data = compiler.info.getElement(type, id);
        var name = data["name"];

        if (type == "function") {
          if (names.contains(name) || name.startsWith("_")) continue;

          if (NAME_REPLACEMENTS.containsKey(data["name"])) {
            if (memberData["children"]
                .map((f) => compiler.info.getElement(f.split("/")[0], f.split("/")[1])["name"])
                .contains(NAME_REPLACEMENTS[data["name"]])) continue;
            name = NAME_REPLACEMENTS[data["name"]];
            if (names.contains(name)) continue;
            data["name"] = name;
          }

          names.add(name);

          if ((name == this.data["name"] || name.startsWith("${this.data["name"]}.")) && isTopLevel) {
            var isDefault = name == this.data["name"];
            var buf = isDefault ? constructor : global;
            if (!isDefault) buf.write("mdex.${this.data["name"]}.${name.substring(this.data["name"].length + 1)} = function() {");
            buf.write(!isDefault ? "var classObj = Object.create(mdex.${this.data["name"]}.prototype); classObj[clOb] = " : "this[clOb] = ");

            var code = data["code"] == null || data["code"].length == 0
                ? "function(){}"
                : "${compiler.mangledNames.getLibraryObject(libraryName)}.${data["code"].split(":")[0].trim()}";

            var func = this.data["name"];
            (new Func(data, _getParamsFromInfo(compiler, data, compiler.analyzer.getFunctionParameters(c.libraryName, func, memberData["name"])),
                code: code,
                withSemicolon: false,
                transform: FunctionTransformation.NONE)).render(compiler, buf);
            buf.write(".apply(this, arguments);");
            if(isDefault)
              buf.write("this[clOb][clId] = this;");
            else {
              buf.write("return classObj;};");
            }
            continue;
          }

          if ((name == this.data["name"] || name.startsWith("${this.data["name"]}.")) && !isTopLevel) continue;

          var params = _getParamsFromInfo(compiler, data, compiler.analyzer.getFunctionParameters(c.libraryName, data["name"], memberData["name"]));

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
            if (data["modifiers"]["static"] || data["modifiers"]["factory"]) {
              if (isTopLevel)
                (new Func(data, params,
                    code: "init.allClasses.${data["code"].split(":")[0]}",
                    prefix: "mdex.${this.data["name"]}")).render(compiler, global);
            } else {
              if(data["name"] == "get" || data["name"] == "set") {
                (new Func(data, params,
                    binding: "this[clOb]",
                    prefix: "mdex.${this.data["name"]}.prototype",
                    code: "this[clOb].${data["code"].split(":")[0]}")).render(compiler, global);
              } else {
                prototype.write(data["name"] + ": ");
                (new Func(data, params,
                    binding: "this[clOb]",
                    code: "this[clOb].${data["code"].split(":")[0]}",
                    withSemicolon: false)).render(compiler, prototype);
                prototype.write(",");
              }


              StringBuffer buf = new StringBuffer();
              methods.add(buf);

              var dartName = data["code"].split(":")[0];
              buf.write("overrideFunc(this, proto, '$name', '$dartName');");
            }
          }
        }

        if (type == "field") {
          if (names.contains(data["name"])) continue;
          names.add(data["name"]);

          if (c == null) continue;

          if (!c.staticFields.contains(data["name"])) {
            var code = data["code"].split("\n")
                .where((name) => name.length > 0 && !name.contains(" ") && name.contains(_FIELD_REGEX))
                .map((name) {
                  try {
                    if(name.contains(":"))
                      name = name.substring(name.indexOf(":") + 1);
                    return _FIELD_REGEX.firstMatch(name).group(0);
                  } catch(e) {
                    throw name;
                  }
                })
                .toList();
            var mangledName;
            code.forEach((name) {
              if(mangledFields.contains(name))
                mangledName = name;
            });

            if(mangledName == null)
              throw data["name"] + ": " + code.toString() + ": " + mangledFields.toString();

            if (data["name"].startsWith("_")) continue;

            prototype.write("get ${data["name"]}() {");
            compiler.baseTransformer.handleReturn(prototype, "this[clOb].$mangledName", data["type"]);
            prototype.write("},");

            prototype.write("set ${data["name"]}(v) {");
            compiler.baseTransformer.transformTo(prototype, "v", data["type"]);
            prototype.write("this[clOb].$mangledName = v;},");
          } else {
            if (data["name"].startsWith("_")) continue;

            // TODO
            // (new ClassProperty(data, c, isStatic: true)).render(compiler, functions);
          }
        }
      }

      for (var accessor in accessors) {
        if (getters[accessor] != null) {
          prototype.write("get $accessor() {");

          var pOutput = new StringBuffer();
          pOutput.write("(");
          (new Func(getters[accessor], _getParamsFromInfo(compiler, getters[accessor]),
              binding: "this[clOb]",
              transform: FunctionTransformation.NONE,
              withSemicolon: false)).render(compiler, pOutput);
          pOutput.write(").apply(this, arguments)");

          compiler.baseTransformer.handleReturn(prototype, pOutput.toString(), getters[accessor]);
          prototype.write("},");
        }

        if (setters[accessor] != null) {
          prototype.write("set $accessor(v) {");
          compiler.baseTransformer.transformTo(prototype, "v", setters[accessor]["type"]);
          prototype.write("(");
          (new Func(setters[accessor], _getParamsFromInfo(compiler, setters[accessor]),
              binding: "this[clOb]",
              withSemicolon: false)).render(compiler, prototype);
          prototype.write(").call(this, v);},");
        } else if (getters[accessor] != null) {
          prototype.write("set $accessor(v) {");
          compiler.baseTransformer.transformTo(prototype, "v", getters[accessor]["type"]);
          prototype.write("this[clOb].${getters[accessor]['code'].split(':')[0]} = function() { return v; };},");
        }
      }
    }

    _handleClassChildren(this, data);

    this.inheritedFrom.forEach((superClass) {
        var classObj = compiler.analyzer.getClass(null, superClass);
        if (classObj != null)
          _handleClassChildren(classObj,
              compiler.classes[superClass] != null ?
                  compiler.classes[superClass].key.data :
                  compiler.classes[classObj.libraryName + "." + superClass].key.data,
              isTopLevel: false);
      });

    output.write("mdex.$name = function() {");
    output.write(constructor.toString());
    output.write("};");

    var proto = prototype.toString();
    // cut off trailing comma
    if(proto.length > 0) {
      output.write("mdex.$name.prototype = {");
      output.write(proto.substring(0, proto.length - 1));
      output.write("};");
    }
    output.write("mdex.$name.prototype[clIw] = true;");

    output.write("""
    mdex.$name.class = function() {
        function $name() {
          mdex.$name.apply(this, arguments);

          var proto = mdex.$name.prototype;
    """);

    methods.forEach((method) => output.write(method.toString()));

    output.write("""
        }

        $name.prototype = Object.create(mdex.$name.prototype);
        $name.prototype["constructor"] = $name;

        return $name;
    }();
    """);

    output.write(global.toString());
  }
}
