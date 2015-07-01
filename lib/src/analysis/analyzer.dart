part of calzone.analysis;

class AnalyzerVisitor extends Visitor<Map> {
  AnalyzerVisitor(analyzer, library, data): super(analyzer, library, data);

  bool visit(AstNode node) {
    if(node is ClassDeclaration) {
      var staticFields = [];
      var getters = [];
      var setters = [];

      var tree = [];

      if (node.extendsClause != null) tree.add(node.extendsClause.superclass.toString());

      if (node.implementsClause != null) tree.addAll(node.implementsClause.interfaces.map((type) => type.toString()));

      if (node.withClause != null) tree.addAll(node.withClause.mixinTypes.map((type) => type.toString()));

      var fields = node.members.where((member) => member is FieldDeclaration && member.isStatic);
      for (var field in fields) {
        staticFields.addAll(field.fields.variables.map((variable) => variable.name.toString()));
      }

      for (var member in node.members) {
        if(member is MethodDeclaration) {
          if (member.isGetter)
            getters.add(member.name.toString());
          if (member.isSetter)
            setters.add(member.name.toString());
        }
      }

      if (tree.length > 0) analyzer.buildLibrary(libraryName, false);

      var copy = []..addAll(tree);
      copy.forEach((type) {
        var vals = analyzer._nodeTree.values.where((val) => val.keys.contains(type));
        if (vals.length > 0) {
          tree.addAll(vals.first[type].inheritedFrom);
          staticFields.addAll(vals.first[type].staticFields);
        }
      });

      data[node.name.toString()] = new Class(node.name.toString(), libraryName,
          staticFields: staticFields,
          inheritedFrom: tree,
          getters: getters,
          setters: setters);
    }

    if(node is FormalParameterList) {
      var f = node.parent;
      var c = f.parent;

      if ((c is NamedExpression || c is ClassDeclaration) && c.parent is CompilationUnit) {
        if (f is ClassMember) {
          var cNode = data[c.name.toString()];

          var name = f.name.toString();
          if (name == "null") name = "";

          cNode.functions[name] = [];
          node.visitChildren(new ParamVisitor(analyzer, libraryName, cNode.functions[name]));
        } else {
          data[c.name.toString()] = [];
          node.visitChildren(new ParamVisitor(analyzer, libraryName, data[c.name.toString()]));
        }

        return true;
      }
    }

    return false;
  }
}

class ParamVisitor extends Visitor<List<Parameter>> {
  ParamVisitor(analyzer, library, data): super(analyzer, library, data);

  bool visit(AstNode node) {
    if(node is FormalParameter) {
      var norm = node;
      if (node is DefaultFormalParameter) norm = norm.parameter;

      if (norm is FunctionTypedFormalParameter) {
        var types = [];
        var params = [];
        norm.parameters.visitChildren(new ParamVisitor(analyzer, libraryName, params));
        for (var param in params) {
          types.add(param.type != null ? param.type : "dynamic");
        }

        types.add(norm.returnType != null ? norm.returnType.toString() : "void");

        data.add(new Parameter(norm.kind, "Function<${types.join(",")}>", norm.identifier.toString()));
        return true;
      }

      String defaultValue = "null";
      if(node is DefaultFormalParameter && node.defaultValue != null) {
        var primitiveVisitor = new PrimitiveVisitor(analyzer, libraryName, "");
        primitiveVisitor.visitNode(node.defaultValue);
        if(primitiveVisitor.data.length > 0)
          defaultValue = primitiveVisitor.data;
      }

      data.add(new Parameter(norm.kind, norm.type.toString(),
          norm.identifier.toString(),
          defaultValue));
    }

    return false;
  }
}

class PrimitiveVisitor extends Visitor<String> {
  PrimitiveVisitor(analyzer, library, data): super(analyzer, library, data);

  bool visit(AstNode node) {
    if(node is PropertyAccess || node is SimpleIdentifier) {
      var parts;

      if(node is PropertyAccess) {
        try {
          var visitor = new PropertyVisitor(analyzer, libraryName, []);
          visitor.visitNode(node);

          parts = visitor.data.reversed;
        } catch(e) {}
      }

      if(node is SimpleIdentifier)
        parts = [node.toString()];

      if(parts.length > 0) {
      }

      return true;
    }

    if(node is ListLiteral) {
      data += "[";

      node.elements.forEach((element) => visit(element));

      data += "]";
      return true;
    }

    if(node is MapLiteral) {
      data += "{";

      node.entries.forEach((MapLiteralEntry entry) {
        visit(entry.key);
        data += ":";
        visit(entry.value);
      });

      data += "}";
      return true;
    }

    if(node is Literal) {
      data += node.toString();
      return true;
    }

    return false;
  }
}

class PropertyVisitor extends Visitor<List<String>> {
  PropertyVisitor(analyzer, library, data): super(analyzer, library, data);

  // node should always be an instance of PropertyAccess
  // or SimpleIdentifier
  bool visit(AstNode node) {
    if(node is PropertyAccess) {
      data.add(node.propertyName.toString());
      visit(node.target);

      return true;
    }

    if(node is SimpleIdentifier) {
      data.add(node.toString());
    }

    // if not, destroy the entire tree
    data.removeRange(0, data.length);
    throw new StateError("node did not access property");

    return false;
  }
}

class Analyzer {
  final MangledNames mangledNames;

  Map<String, dynamic> _units = {};
  Map<String, Map<String, dynamic>> _nodeTree = {};
  String _packageRoot;

  Analyzer(this.mangledNames, String file) {
    _packageRoot = new File(file).parent.path + '/packages';
    SourceCrawler crawler = new SourceCrawler(packageRoots: [_packageRoot]);
    _handleLibraries(crawler(file));
  }

  _handleLibraries(List<LibraryTuple> libraries, [Function cb]) {
    for (LibraryTuple library in libraries) {
      var name = library.name;
      if (name != null) {
        if (_units.containsKey(name)) {
          if (_units[name] is List) {
            if (!_units[name].any((unit) => unit.path == library.path)) _units[name].add(library);
          } else {
            _units[name] = [_units[name], library];
          }
        } else {
          _units[name] = library;
        }
      }
      if (cb != null) cb(library);
    }
  }

  buildLibrary(String library, [bool deep = true]) {
    if (!_units.containsKey(library) || _nodeTree.containsKey(library)) return;

    SourceCrawler crawler = new SourceCrawler(packageRoots: [_packageRoot]);

    var libPath = _units[library] is List ? _units[library].first.path : _units[library].path;
    if (!deep) _handleLibraries(crawler(libPath), (LibraryTuple lib) => buildLibrary(lib.name, true));

    _nodeTree[library] = {};
    var visitor = new AnalyzerVisitor(this, library, _nodeTree[library]);

    if (_units[library] is List) {
      _units[library].forEach((u) => u.astUnit.visitChildren(visitor));
    } else {
      _units[library].astUnit.visitChildren(visitor);
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
    buildLibrary(library);

    if (library == null) {
      var length = _nodeTree.values.where((value) => value.containsKey(c));
      if (length.length > 0) return length.first[c];
      return null;
    }

    if (!_nodeTree[library].containsKey(c)) return null;
    return _nodeTree[library][c];
  }
}
