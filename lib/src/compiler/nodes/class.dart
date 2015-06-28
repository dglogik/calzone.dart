part of calzone.compiler;

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
    String prefix = "mdex";

    if (name.startsWith("_")) return;

    List<String> names = [];
    List<StringBuffer> methods = [];

    StringBuffer constructor = new StringBuffer();
    StringBuffer prototype = new StringBuffer();
    StringBuffer global = new StringBuffer();

    _handleClassChildren(Class c, Map memberData, {bool isTopLevel: true}) {
      var mangledFields = compiler.mangledNames.getClassFields(this.libraryName, this.name);
      if(mangledFields == null)
        mangledFields = [];

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
            var buf = isDefault ? constructor : global;
            if (!isDefault) global.write("mdex.${this.data["name"]}.$name = function() {");
            buf.write("var __obj__ = (");
            var code = data["code"] == null || data["code"].length == 0
                ? "function(){}"
                : "${compiler.mangledNames.getLibraryObject(libraryName)}.${data["code"].split(":")[0].trim()}";
            var func = this.data["name"];
            (new Func(data, _getParamsFromInfo(compiler, data["type"], compiler.analyzer.getFunctionParameters(this.libraryName, func, this.data["name"])),
                code: code,
                withSemicolon: false,
                transform: FunctionTransformation.NONE)).render(compiler, buf);
            buf.write(").apply(this, arguments);");
            if (!isDefault) global.write("return mdex.${this.data["name"]}._(__obj__);};");
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
                    code: "init.allClasses.${data["code"].split(":")[0]}",
                    prefix: "mdex.${this.data["name"]}")).render(compiler, global);
            } else {
              prototype.write(data["name"] + ": ");
              (new Func(data, params,
                  binding: "this[clOb]",
                  code: "this[clOb].${data["code"].split(":")[0]}",
                  withSemicolon: false)).render(compiler, prototype);
              prototype.write(",");

              StringBuffer buf = new StringBuffer();
              methods.add(buf);

              var dartName = data["code"].split(":")[0];

              buf.write("if(proto.$name) { overrideFunc(this, $name, $dartName); }");
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

              prototype.write("get ${data["name"]}() { var returned = this[clOb].$mangledName;");
              compiler.baseTransformer.transformFrom(prototype, "returned", data["type"]);
              prototype.write("return returned;},set ${data["name"]}(v) {");
              compiler.baseTransformer.transformTo(prototype, "v", data["type"]);
              prototype.write("this[clOb].$mangledName = v;},");
            } else {
              // TODO
              // (new ClassProperty(data, c, isStatic: true)).render(compiler, functions);
            }
          }
        }
      }

      for (var accessor in accessors) {
        if (getters[accessor] != null) {
          prototype.write("get $accessor() {");
          (new Func(getters[accessor], _getParamsFromInfo(compiler, getters[accessor]["type"]),
              binding: "this[clOb]",
              transform: FunctionTransformation.NONE,
              withSemicolon: false)).render(compiler, prototype);
          prototype.write(").apply(this, arguments);");
          compiler.baseTransformer.transformFrom(prototype, "returned", getters[accessor]["type"]);
          prototype.write("return returned;},");
        }

        if (setters[accessor] != null) {
          prototype.write("set $accessor(v) {");
          compiler.baseTransformer.transformTo(prototype, "v", setters[accessor]["type"]);
          prototype.write("(");
          (new Func(setters[accessor], _getParamsFromInfo(compiler, setters[accessor]["type"]),
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

    this.inheritedFrom.reversed.forEach((superClass) {
        var classObj = compiler.analyzer.getClass(null, superClass);
        if (classObj != null)
          _handleClassChildren(classObj,
              compiler.classes[superClass] != null ?
                  compiler.classes[superClass].key.data :
                  compiler.classes[classObj.libraryName + "." + superClass].key.data,
              isTopLevel: false);
      });

    output.write("mdex.$name = function $name() {");
    output.write(constructor.toString());

    output.write("this[clOb] = __obj__;");

    output.write("};");

    output.write("""
    mdex.$name.class = obfr(function() {
        function $name() {
          mdex.$name.apply(this, arguments);
          var proto = Object.getPrototypeOf(this);
    """);

    methods.forEach((method) => output.write(method.toString()));

    output.write("""
        }

        $name.prototype = Object.create(mdex.$name.prototype);

        return $name;
    });
    """);

    var proto = prototype.toString();
    // cut off trailing comma
    if(proto.length > 0) {
      output.write("mdex.$name.prototype = {");
      output.write(proto.substring(0, proto.length - 1));
      output.write("};");
    }
    output.write("mdex.$name.prototype[clIw] = true;");

    output.write(global.toString());

    output.write("mdex.$name[clCl] = ");
    output.write("function(__obj__) {var returned = Object.create($prefix.$name.prototype);");
    output.write("(function() {");

    output.write("this[clOb] = __obj__;");

    output.write("}.bind(returned))();");
    output.write("return returned;};");
  }
}
