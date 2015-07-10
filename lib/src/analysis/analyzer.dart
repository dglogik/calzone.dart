part of calzone.analysis;

class Dictionary {
  final Map<String, LibraryTuple> libraries = {};
  final Map<String, List<LibraryTuple>> imports = {};
  final SourceCrawler _crawler;

  Dictionary({List packageRoots}):
    _crawler = new SourceCrawler(packageRoots: packageRoots, allowedDartPaths: []);

  String searchForGlobalProp(String name, {String libraryName, LibraryTuple library}) {
    String _getName(CompilationUnit astUnit) {
      String name;
      astUnit.directives
          .where((e) => e is PartOfDirective || e is LibraryDirective)
          .forEach((e) => name = e is PartOfDirective ? e.libraryName.name : e.name.name);
      return name;
    }

    if(library == null)
      library = libraries[libraryName];

    var astUnits = [];

    astUnits.addAll(library.astUnits);

    for(var import in imports[library.name]) {
      astUnits.addAll(import.astUnits);
    }

    for(var astUnit in astUnits) {
      if(searchForProp(astUnit, name) != null)
        return _getName(astUnit);
    }

    return null;
  }

  AstNode searchForProp(CompilationUnit unit, String property) {
    for(var d in unit.declarations) {
      if(d is NamedCompilationUnitMember && d.name.toString() == property
          || d is TopLevelVariableDeclaration && d.variables.variables.any((v) => v.name.toString() == property))
        return d;
    }

    return null;
  }

  crawl(String path) {
    var libs = _crawler(path);
    imports[libs.first.name] = libs;
    libs.forEach((library) {
      if(libraries.containsKey(library.name))
        return;
      libraries[library.name] = library;
    });
  }
}

class Analyzer {
  final Compiler compiler;

  Dictionary dictionary;

  Map<String, Map<String, dynamic>> _nodeTree = {};
  String _packageRoot;

  Analyzer(this.compiler, String file) {
    _packageRoot = Uri.base.path + '/packages';

    dictionary = new Dictionary(packageRoots: [_packageRoot]);
    dictionary.crawl(file);
  }

  buildLibrary(String library, [bool deep = true]) {
    if (!dictionary.libraries.containsKey(library) || _nodeTree.containsKey(library)) return;

    var isDartLibrary = dictionary.libraries[library].name.startsWith("dart.");
    if(!isDartLibrary) {
      var libPath = dictionary.libraries[library].path;
      dictionary.crawl(libPath);
    }

    if (!deep) {
      dictionary.imports[library].forEach((lib) => buildLibrary(lib.name, true));
    }

    _nodeTree[library] = {};
    var visitor = new AnalyzerVisitor(this, library, _nodeTree[library]);

    dictionary.libraries[library].astUnits.forEach((u) => u.visitChildren(visitor));

    if(!isDartLibrary) {
      var overflowQueue = <Class>[];
      var wasIterated = <String, bool>{};

      iterateClass(Class c, [bool overflow = true]) {
        if (c.inheritedFrom.length <= 0) return;

        buildLibrary(c.libraryName, false);

        for(var type in []..addAll(c.inheritedFrom)) {
          var prop = dictionary.searchForGlobalProp(type, libraryName: c.libraryName);

          if(prop != null && _nodeTree.containsKey(prop)) {
            var nodeTree = _nodeTree[prop];

            if(nodeTree.containsKey(type)) {
              if(prop == c.libraryName && !wasIterated.containsKey(type) && overflow) {
                overflowQueue.add(c);
                return;
              }

              c.inheritedFrom.addAll(nodeTree[type].inheritedFrom);
            }
          }
        }

        wasIterated[c.name] = true;
      }


      _nodeTree[library].forEach((_, c) {
        if(c is Class)
          iterateClass(c);
      });
      overflowQueue.forEach((c) => iterateClass(c, false));
    }
  }

  List<Parameter> getFunctionParameters(String library, String function, [String c]) {
    buildLibrary(library);
    if (function == c) function = "";

    if (c != null) {
      if (!_nodeTree[library].containsKey(c)) return [];
      var cNode = _nodeTree[library][c];

      if (!cNode.functions.containsKey(function)) return [];

      return cNode.functions[function];
    }

    if (!_nodeTree[library].containsKey(function)) return [];
    return _nodeTree[library][function];
  }

  Class getClass(String library, String c) {
    if (library == null) {
      var length = _nodeTree.values.where((value) => value.containsKey(c));
      if (length.length > 0) return length.first[c];
      return null;
    }

    buildLibrary(library);

    if (!_nodeTree[library].containsKey(c)) return null;
    return _nodeTree[library][c];
  }
}
