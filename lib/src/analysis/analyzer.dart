part of calzone.analysis;

VisitorBuilder _VISITOR = new VisitorBuilder()
  ..where(ClassDeclaration, (Analyzer analyzer, Duo duo, ClassDeclaration node) {
    Map data = duo.value;

    var staticFields = [];
    var getters = [];
    var setters = [];

    var tree = [];

    _handleClass(ClassDeclaration c) {
      if (c.extendsClause != null) tree.add(c.extendsClause.superclass.toString());

      if (c.implementsClause != null) tree.addAll(c.implementsClause.interfaces.map((type) => type.toString()));

      if (c.withClause != null) tree.addAll(c.withClause.mixinTypes.map((type) => type.toString()));

      var fields = c.members.where((member) => member is FieldDeclaration && member.isStatic);
      for (var field in fields) {
        staticFields.addAll(field.fields.variables.map((variable) => variable.name.toString()));
      }

      for (var member in c.members) {
        if(member is MethodDeclaration) {
          if (member.isGetter) getters.add(member.name.toString());
          if (member.isSetter) setters.add(member.name.toString());
        }
      }

      if (tree.length > 0) analyzer.buildLibrary(duo.key, false);

      var copy = []..addAll(tree);
      copy.forEach((type) {
        var vals = analyzer._nodeTree.values.where((val) => val.keys.contains(type));
        if (vals.length > 0) {
          tree.addAll(vals.first[type].inheritedFrom);
          staticFields.addAll(vals.first[type].staticFields);
        }
      });
    }

    _handleClass(node);

    data[node.name.toString()] = new Class(node.name.toString(), duo.key, staticFields: staticFields, inheritedFrom: tree);
  })
  ..where(FormalParameterList, (Analyzer analyzer, Duo duo, FormalParameterList node) {
    Map data = duo.value;

    var f = node.parent;
    var c = f.parent;

    if ((c is NamedExpression || c is ClassDeclaration) && c.parent is CompilationUnit) {
      if (f is ClassMember) {
        var cNode = data[c.name.toString()];

        var name = f.name.toString();
        if (name == "null") name = "";

        cNode.functions[name] = [];
        node.visitChildren(_PARAM_VISITOR.build(analyzer, cNode.functions[name]));
      } else {
        data[c.name.toString()] = [];
        node.visitChildren(_PARAM_VISITOR.build(analyzer, data[c.name.toString()]));
      }

      return true;
    }
    return false;
  });

VisitorBuilder _PARAM_VISITOR = new VisitorBuilder()
  ..where([DefaultFormalParameter, SimpleFormalParameter, FunctionTypedFormalParameter], (Analyzer analyzer, List output, FormalParameter node) {
    var norm = node;
    if (node is DefaultFormalParameter) norm = norm.parameter;

    if (norm is FunctionTypedFormalParameter) {
      var types = [];
      var params = [];
      norm.parameters.visitChildren(_PARAM_VISITOR.build(analyzer, params));
      for (var param in params) {
        types.add(param.type != null ? param.type : "dynamic");
      }

      types.add(norm.returnType != null ? norm.returnType.toString() : "void");

      output.add(new Parameter(norm.kind, "Function<${types.join(",")}>", norm.identifier.toString()));
      return;
    }

    output.add(new Parameter(norm.kind, norm.type.toString(), norm.identifier.toString(),
        node is DefaultFormalParameter && node.defaultValue is Literal ? node.defaultValue.toString() : "null"));
    return;
  });

class Analyzer {
  Map<String, dynamic> _units = {};
  Map<String, Map<String, dynamic>> _nodeTree = {};
  String _packageRoot;

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

  Analyzer(String file) {
    _packageRoot = new File(file).parent.path + '/packages';
    SourceCrawler crawler = new SourceCrawler(packageRoots: [_packageRoot]);
    _handleLibraries(crawler(file));
  }

  buildLibrary(String library, [bool deep = true]) {
    if (!_units.containsKey(library) || _nodeTree.containsKey(library)) return;

    SourceCrawler crawler = new SourceCrawler(packageRoots: [_packageRoot]);

    var libPath = _units[library] is List ? _units[library].first.path : _units[library].path;
    if (!deep) _handleLibraries(crawler(libPath), (LibraryTuple lib) => buildLibrary(lib.name, true));

    _nodeTree[library] = {};
    var visitor = _VISITOR.build(this, new Duo(library, _nodeTree[library]));

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
