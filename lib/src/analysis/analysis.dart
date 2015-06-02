part of calzone.analysis;

VisitorBuilder _VISITOR = new VisitorBuilder()
  ..where(ClassDeclaration, (Map<String, dynamic> output, ClassDeclaration node) {
    var tree = [];

    if(node.extendsClause != null)
      tree.add(node.extendsClause.superclass.toString());

    if(node.withClause != null)
      tree.addAll(node.withClause.mixinTypes.map((type) => type.toString()));

    if(node.implementsClause != null)
      tree.addAll(node.implementsClause.interfaces.map((type) => type.toString()));

    output[node.name.toString()] = new Class(node.name.toString(), tree);
  })
  ..where(FormalParameterList, (Map<String, dynamic> output, FormalParameterList node) {
    var f = node.parent;
    var c = f.parent;

    if((c is NamedExpression || c is ClassDeclaration) && c.parent is CompilationUnit) {
      if(f is ClassMember) {
        var cNode = output[c.name.toString()];

        var name = f.name.toString();
        if(NAME_REPLACEMENTS.contains(name))
          name = NAME_REPLACEMENTS[name];

        cNode.functions[name] = [];
        node.visitChildren(_PARAM_VISITOR.build(cNode.functions[name]));
      } else {
        var name = c.name.toString();
        if(NAME_REPLACEMENTS.contains(name))
          name = NAME_REPLACEMENTS[name];

        output[c.name.toString()] = [];
        node.visitChildren(_PARAM_VISITOR.build(output[c.name.toString()]));
      }

      return true;
    }
    return false;
  });

VisitorBuilder _PARAM_VISITOR = new VisitorBuilder()
  ..where(FormalParameter, (output, FormalParameter node) {
    var norm = node;
    if(node is DefaultFormalParameter)
      norm = norm.parameter;

    if(norm is FunctionTypedFormalParameter) {
      var types = [];
      var params = [];
      norm.parameters.visitChildren(_PARAM_VISITOR.build(params));
      for(var param in params) {
        types.add(param.type != null ? param.type : "dynamic");
      }

      types.add(norm.returnType != null ? norm.returnType.toString() : "void");

      output.add(new Parameter(norm.kind, "Function<${types.join(",")}>", norm.identifier.toString()));
      return;
    }

    output.add(new Parameter(norm.kind,
        norm.type.toString(),
        norm.identifier.toString(),
        node is DefaultFormalParameter && node.defaultValue is Literal ? node.defaultValue.toString() : "null"));
    return;
  });

class Analyzer {
  Map<String, dynamic> _units = {};
  Map<String, Map<String, dynamic>> _nodeTree = {};

  Analyzer(String file) {
    SourceCrawler crawler = new SourceCrawler(packageRoots: [(new File(file)).parent.parent.path + '/packages']);
    var libraries = crawler(file);

    for(LibraryTuple library in libraries) {
      var name;
      library.astUnit.directives
        .where((e) => e is PartOfDirective || e is LibraryDirective)
        .forEach((e) => name = e is PartOfDirective ? e.libraryName.name : e.name.name);
      if(name != null) {
        if(_units.containsKey(name)) {
          if(_units[name] is List)
            _units[name].add(library.astUnit);
          else
            _units[name] = [_units[name], library.astUnit];
        } else {
          _units[name] = library.astUnit;
        }
      }
    }
  }

  buildLibrary(String library) {
    if(!_units.containsKey(library) || _nodeTree.containsKey(library))
      return;

    _nodeTree[library] = {};
    var visitor = _VISITOR.build(_nodeTree[library]);

    if(_units[library] is List) {
      _units[library].forEach((u) => u.visitChildren(visitor));
    } else {
      _units[library].visitChildren(visitor);
    }
  }

  List<Parameter> getFunctionParameters(String library, String function, [String c]) {
    buildLibrary(library);

    if(c != null) {
      if(!_nodeTree[library].containsKey(c))
        return [];
      var cNode = _nodeTree[library][c];

      if(!cNode.functions.containsKey(function))
        return [];

      return cNode.functions[function];
    }

    if(!_nodeTree[library].containsKey(function))
      return [];
    return _nodeTree[library][function];
  }
}
