part of calzone.compiler;

final RegExp _FIELD_REGEX = new RegExp(r"[A-Za-z_0-9$]+(?=[^:A-Za-z]|$),*");

class Class extends _SymbolTypes implements Renderable {
  // used by the analysis part of calzone
  final Map<String, List<Parameter>> functions = {}; 
  
  final String name;
  final String libraryName;

  final List<String> staticFields;
  final List<String> getters;
  final List<String> setters;

  // list of classes that this class inherits from
  final List<String> inheritedFrom;
  
  // data from .info.json
  Map<String, dynamic> data;

  Class(this.name, this.libraryName,
      {this.staticFields: const [],
      this.getters: const [],
      this.setters: const [],
      this.inheritedFrom: const []});
      
  renderConstructor(StringBuffer output, String name) {
    
  }

  renderDefinition(StringBuffer output, String name,
      StringBuffer constructor, StringBuffer prototype,
      List<StringBuffer> methodChecks) {
    
    output.write("""
      mdex.$name = function() {
        $constructor

        this[$symDartObj][$symBackup] = {};
        this[$symDartObj][$symJsObj] = this;
        
        var proto = mdex.$name.prototype;
        if(Object.getPrototypeOf(this) !== proto) {
    """);
    
    methodChecks.forEach((check) => output.write(check.toString()));
    
    output.write("""
        }
      };
    """);

    final proto = prototype.toString();

    if (proto.length > 0) {
      // cut off trailing comma
      output.write("""
        mdex.$name.prototype = {
          ${proto.substring(0, proto.length - 1)}
        };
      """);
    }
  
    output.write("mdex.$name.prototype[$symIsWrapped] = true;");

    output.write("""
      mdex.$name.class = function() {
        function $name() {
          mdex.$name.apply(this, arguments);
          console.error('$name.class is deprecated, please change to only use $name');
        }

        $name.prototype = Object.create(mdex.$name.prototype);
        $name.prototype["constructor"] = $name;

        return $name;
    }();
    """);
  }

  render(Compiler compiler, StringBuffer output) {
    // list of function/field names in the class
    final List<String> names = [];
    final List<StringBuffer> methods = [];

    final StringBuffer constructor = new StringBuffer();
    final StringBuffer prototype = new StringBuffer();
    final StringBuffer global = new StringBuffer();

    _handleClassChildren(Class c, Map memberData, {bool isTopLevel: true}) {
      var mangledFields =
          compiler.mangledNames.getClassFields(c.libraryName, c.name);
      if (mangledFields == null) mangledFields = [];

      final List<String> accessors = [];
      final Map<String, Map> getters = {};
      final Map<String, Map> setters = {};

      final List<Map<String, dynamic>> childData = memberData["children"]
          .map((f) => compiler.info.getElement(f.split("/")[0], f.split("/")[1]))
          .toList();

      int index = 0;
      for (final _ in memberData["children"]) {
        final data = childData[index++];
        
        final type = data["kind"];
        String name = data["name"];

        if (type == "function") {
          if (names.contains(name) || name.startsWith("_")) continue;

          // name replacements for operator overloading functions
          if (NAME_REPLACEMENTS.containsKey(data["name"])) {
            var nameReplacement = NAME_REPLACEMENTS[data["name"]];
            
            if (names.contains(nameReplacement) ||
                childData.map((data) => data["name"]).contains(nameReplacement))
              continue;
                
            name = nameReplacement;
            data["name"] = name;
          }

          names.add(name);

          final bool isDefaultConstructor = name == this.data["name"];
          final bool isConstructor = isDefaultConstructor || name.startsWith("${this.data["name"]}.");
          
          if (isConstructor && !isTopLevel) continue;
          
          final params = _getParamsFromInfo(compiler, data,
              compiler.analyzer.getFunctionParameters(
                  c.libraryName, isConstructor ? this.data["name"] : data["name"],
                  memberData["name"]));

          // if unnamed or named constructor
          if (isConstructor) {
            var buf = isDefaultConstructor ? constructor : global;
            
            if (isDefaultConstructor) {
              buf.write("this[$symDartObj] = ");
            } else {
              final String className = this.data["name"];
              final String constructorName = name.substring(className.length + 1);
              
              buf.write("""
                mdex.$className.$constructorName = function() {
                  var classObj = Object.create(mdex.$className.prototype);
                  classObj[$symDartObj] = 
              """);
            }

            final code = data["code"] == null || data["code"].length == 0
                ? "function(){}"
                : "${compiler.mangledNames.getLibraryObject(libraryName)}.${data["code"].split(":")[0].trim()}";
            
            (new Func(data,
                    params,
                    code: code,
                    withSemicolon: false,
                    transform: FunctionTransformation.NONE))
                .render(compiler, buf);
                
            buf.write(".apply(this, arguments);");
            
            if (isDefaultConstructor)
              continue;
              
            buf.write("""
                classObj[$symDartObj][$symBackup] = {};
                classObj[$symDartObj][$symJsObj] = this;
                return classObj;
              };
            """);
            
            continue;
          }

          // defer handling of getters/setters
          
          if (c != null && c.getters.contains(data["name"]) &&
              params.length == 0) {
            if (!accessors.contains(name)) accessors.add(name);
            getters[name] = data;
            continue;
          }

          if (c != null && c.setters.contains(data["name"]) &&
              params.length == 1) {
            if (!accessors.contains(name)) accessors.add(name);
            setters[name] = data;
            continue;
          }

          if (data["code"].length > 0) {
            if (data["modifiers"]["static"] || data["modifiers"]["factory"]) {
              if (isTopLevel) {
                (new Func(data, params,
                        code: "init.allClasses.${data["code"].split(":")[0]}",
                        prefix: "mdex.${this.data["name"]}"))
                    .render(compiler, global);
              }
            } else {
              if (data["name"] == "get" || data["name"] == "set") {
                (new Func(data, params,
                        binding: "this[$symDartObj]",
                        prefix: "mdex.${this.data["name"]}.prototype",
                        code: "this[$symDartObj].${data["code"].split(":")[0]}"))
                    .render(compiler, global);
              } else {
                prototype.write("$name: ");
                (new Func(data, params,
                        binding: "this[$symDartObj]",
                        code: """
                          (this[$symDartObj][$symBackup].${data["code"].split(":")[0]} ||
                            this[$symDartObj].${data["code"].split(":")[0]})
                        """,
                        withSemicolon: false))
                    .render(compiler, prototype);
                prototype.write(",");
              }

              StringBuffer buf = new StringBuffer();

              // extracts the number of arguments in the function
              // used in case we need to shift arguments when overriding
              // a Dart function
              var length = _FUNCTION_REGEX
                  .firstMatch(data["code"])
                  .group(1)
                  .split(',')
                  .length;

              var dartName = data["code"].split(":")[0];
              buf.write("overrideFunc(this, proto, '$name', '$dartName', ${length - params.length});");

              methods.add(buf);
            }
          }
        }

        if (type == "field") {
          if (names.contains(name) || name.startsWith("_")) continue;
          names.add(name);

          // TODO: static fields
          if (c == null || c.staticFields.contains(name)) continue;
          
          final codeParts = data["code"]
              .split("\n")
              .where((name) =>
                  name.length > 0 &&
                  !name.contains(" ") &&
                  name.contains(_FIELD_REGEX))
              .map((name) {
                try {
                  if (name.contains(":"))
                    name = name.substring(name.indexOf(":") + 1);
                  return _FIELD_REGEX.firstMatch(name).group(0);
                } catch (e) {
                  throw name;
                }
              })
              .toList();
            
          final mangledName = codeParts.firstWhere((name) => mangledFields.contains(name));

          if (mangledName == null) {
            throw "$name: $code: $mangledFields";
          }
            
          prototype.write("get $name() {");
          compiler.baseTransformer.handleReturn(
              prototype, "this[$symDartObj].$mangledName", data["type"]);
          prototype.write("},");

          prototype.write("set $name(v) {");
          compiler.baseTransformer.transformTo(prototype, "v", data["type"]);
          prototype.write("this[$symDartObj].$mangledName = v;},");
        }
      }

      for (var accessor in accessors) {
        if (getters[accessor] != null) {
          prototype.write("get $accessor() {");

          var pOutput = new StringBuffer();
          pOutput.write("(");
          
          (new Func(getters[accessor],
                  _getParamsFromInfo(compiler, getters[accessor]),
                  binding: "this[$symDartObj]",
                  transform: FunctionTransformation.NONE,
                  withSemicolon: false))
              .render(compiler, pOutput);
          pOutput.write(").apply(this, arguments)");

          compiler.baseTransformer
              .handleReturn(prototype, pOutput.toString(), getters[accessor]);
          prototype.write("},");
        }

        if (setters[accessor] != null) {
          prototype.write("set $accessor(v) {");
          
          compiler.baseTransformer
              .transformTo(prototype, "v", setters[accessor]["type"]);
        
          prototype.write("(");
          
          (new Func(setters[accessor],
                  _getParamsFromInfo(compiler, setters[accessor]),
                  binding: "this[clOb]", withSemicolon: false))
              .render(compiler, prototype);
          
          prototype.write(").call(this, v);},");
        } else if (getters[accessor] != null) {
          // workaround to make any accessor settable
          // needed in some scenarios
          prototype.write("set $accessor(v) {");
          compiler.baseTransformer
              .transformTo(prototype, "v", getters[accessor]["type"]);
          prototype.write("""
            this[$symDartObj].${getters[accessor]['code'].split(':')[0]} =
              function() { return v; };
            },
          """);
        }
      }
    }

    _handleClassChildren(this, data);

    this.inheritedFrom.forEach((superClass) {
      var classObj = compiler.analyzer.getClass(null, superClass);
      if (classObj != null)
        _handleClassChildren(
            classObj,
            compiler.classes[superClass] != null
                ? compiler.classes[superClass].key.data
                : compiler
                    .classes[classObj.libraryName + "." + superClass].key.data,
            isTopLevel: false);
    });
    
    renderDefinition(output, name, constructor, prototype, methods);

    output.write(global.toString());
  }
}
