part of calzone.compiler;

class Compiler {
  // instance of dartanalyzer visitor
  final Analyzer analyzer;

  // *.info.json
  final InfoData info;

  // JSON that contains mangledNames if minified
  final MangledNames mangledNames;

  // list of TypeTransformers used within the Compiler instance
  final List<TypeTransformer> typeTransformers;

  // the base (or god, it's kind of a god object) type transformer
  BaseTypeTransformer baseTransformer;

  // a list of all classes in the *.info.json
  Map<String, Duo<InfoParent, bool>> classes = {};

  // list of 'globals', prefixes to inject into the wrapper before the wrapper itself
  List<String> globals = [];

  bool isMinified;

  Compiler(String dartFile, dynamic infoFile, dynamic mangledFile, {this.typeTransformers: const [], this.isMinified: false}):
      analyzer = new Analyzer(dartFile),
      info = new InfoData(infoFile is String ? JSON.decode(new File(infoFile).readAsStringSync()) : infoFile),
      mangledNames = new MangledNames(mangledFile is String ? JSON.decode(new File(mangledFile).readAsStringSync()) : mangledFile) {
    baseTransformer = new BaseTypeTransformer(this);
  }

  String compile(List<String> include) {
    StringBuffer output = new StringBuffer();

    List<Renderable> children = [];
    for (var library in info.getLibraries()) {
      for (var child in library["children"]) {
        child = child.split("/");

        var type = child[0];
        var id = child[1];

        var childData = info.getElement(type, id);

        var isIncluded = include.contains(library["name"] + "." + childData["name"]) || include.contains(library["name"]);

        if (type == "class") {
          classes[isIncluded ? childData["name"] : library["name"] + "." + childData["name"]] = new Duo(new InfoParent(info, childData), isIncluded);
          if(isIncluded) {
            var c = analyzer.getClass(library["name"], childData["name"]);
            c.data = childData;
            children.add(c);
          }
        }

        if (type == "function" && isIncluded) {
          var params = _getParamsFromInfo(this, childData["type"], analyzer.getFunctionParameters(library["name"], childData["name"]));
          children.add(new Func(childData, params,
              binding: "init.globalFunctions",
              prefix: "mdex",
              code: "init.globalFunctions.${childData["code"].split(":")[0].trim()}.${isMinified ? "\$" + params.length.toString() : "call\$" + params.length.toString()}"));
        }
      }
    }

    output.write(_OBJ_EACH_PREFIX);
    output.write(_OVERRIDE_PREFIX);

    output.write("function dynamicTo(obj) {if(typeof(obj) === 'undefined' || obj === null) { return obj; }");
    baseTransformer.transformToDart(this, output);
    for (var transformer in typeTransformers) {
      transformer.transformToDart(this, output);
    }
    output.write("return obj;}");

    output.write("function dynamicFrom(obj) {if(typeof(obj) === 'undefined' || obj === null) { return obj; }");
    baseTransformer.transformFromDart(this, output);
    for (var transformer in typeTransformers) {
      transformer.transformFromDart(this, output);
    }
    output.write("return obj;}");

    children.forEach((c) => c.render(this, output));

    return globals.join() + output.toString();
  }
}
