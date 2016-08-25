part of calzone.compiler;

class Compiler {
  // instance of dartanalyzer visitor
  Analyzer analyzer;

  // *.info.json
  final InfoData info;

  // JSON that contains mangledNames if minified
  final MangledNames mangledNames;

  // list of TypeTransformers used within the Compiler instance
  final List<TypeTransformer> typeTransformers;

  final List<CompilerVisitor> compilerVisitors;

  // the base (or god, it's kind of a god object) type transformer
  BaseTypeTransformer baseTransformer;

  // a list of all classes in the *.info.json
  Map<String, Duo<InfoParent, bool>> classes = {};

  // list of 'globals', prefixes to inject into the wrapper before the wrapper itself
  List<String> globals = [];

  bool isMinified;

  Compiler(String dartFile, dynamic infoFile, dynamic mangledFile,
      {this.typeTransformers: const [],
        this.compilerVisitors: const [],
        this.isMinified: false})
      : info = new InfoData(infoFile is String
            ? JSON.decode(new File(infoFile).readAsStringSync())
            : infoFile),
        mangledNames = new MangledNames(mangledFile is String
            ? JSON.decode(new File(mangledFile).readAsStringSync())
            : mangledFile) {
    analyzer = new Analyzer(this, dartFile);
    baseTransformer = new BaseTypeTransformer(this);
  }

  // used for testing
  Compiler.empty(String dartFile)
      : info = new InfoData(null),
        mangledNames = new MangledNames(null),
        typeTransformers = const [],
        compilerVisitors = const [],
        isMinified = false {
    analyzer = new Analyzer(this, dartFile);
    baseTransformer = new BaseTypeTransformer(this);
  }

  String compile(List<String> include) {
    StringBuffer output = new StringBuffer();
    
    for (CompilerVisitor visitor in compilerVisitors) {
      visitor.startCompilation(this);
    }

    List<Renderable> children = [];
    for (var library in info.getLibraries()) {
      for (var child in library["children"]) {
        child = child.split("/");

        var type = child[0];
        var id = child[1];

        var childData = info.getElement(type, id);

        var isIncluded =
            include.contains(library["name"] + "." + childData["name"]) ||
                include.contains(library["name"]);

        if (type == "class") {
          classes[isIncluded
                  ? childData["name"]
                  : library["name"] + "." + childData["name"]] =
              new Duo(new InfoParent(info, childData), isIncluded);
          if (isIncluded) {
            var c = analyzer.getClass(library["name"], childData["name"]);
            c.data = childData;
            children.add(c);
          }
        }

        if (type == "function" && isIncluded) {
          if (childData["name"].startsWith("_"))
          {
            continue;
          }
          
          var params = _getParamsFromInfo(
              this,
              childData,
              analyzer.getFunctionParameters(
                  library["name"], childData["name"]));

          final _returnType = _TYPE_REGEX.firstMatch(childData["type"]).group(2);          
          for (CompilerVisitor visitor in compilerVisitors) {
            visitor.addTopLevelFunction(childData, params, _returnType);
          }
                  
          children.add(new Func(childData, params,
              binding: "init.globalFunctions",
              prefix: "mdex",
              code:
                  "init.globalFunctions.${childData["code"].split(":")[0].trim()}().${isMinified ? "\$" + params.length.toString() : "call\$" + params.length.toString()}"));
        }
      }
    }

    output.write(_OBJ_EACH_PREFIX);
    output.write(_OVERRIDE_PREFIX);

    output.write(
        "var stat = ${isMinified ? "I.p" : r"Isolate.$isolateProperties"};");

    output.write(
        "function dynamicTo(obj) {if(typeof(obj) === 'undefined' || obj === null) { return obj; }");
    baseTransformer.transformToDart(this, output);
    for (var transformer in typeTransformers) {
      transformer.transformToDart(this, output);
    }
    output.write("return obj;}");

    output.write(
        "function dynamicFrom(obj) {if(typeof(obj) === 'undefined' || obj === null) { return obj; }");
    baseTransformer.transformFromDart(this, output);
    for (var transformer in typeTransformers) {
      transformer.transformFromDart(this, output);
    }
    output.write("return obj;}");

    output.write("""if(sSym) {
      var symTo = Symbol.for("calzone.dynamicTo");
      var symFrom = Symbol.for("calzone.dynamicFrom");

      module.exports[symTo] = dynamicTo;
      module.exports[symFrom] = dynamicFrom;
    }""");

    children.forEach((c) {
      if (!c.data["name"].startsWith("_")) c.render(this, output);
    });

    for (CompilerVisitor visitor in compilerVisitors) {
      visitor.stopCompilation();
    }

    return globals.join() + output.toString();
  }
}
