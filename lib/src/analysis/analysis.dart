part of calzone.analysis;

VisitorBuilder _VISITOR = new VisitorBuilder()
  ..where(FormalParameterList, (output, FormalParameterList node) {
    var f = node.parent;
    var c = f.parent;

    var name = "";
    if((c is NamedExpression || c is ClassDeclaration) && c.parent is CompilationUnit) {
      name += c.name.toString();

      if(f is ClassMember) {
        if(f.name != null) {
          if(NAME_REPLACEMENTS.containsKey(f.name.toString()))
            name += NAME_REPLACEMENTS[f.name.toString()];
          else
            name += "." + f.name.toString();
        }
      }

      output[name] = [];

      node.visitChildren(_PARAM_VISITOR.build(output[name]));
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
  Map<String, Map<String, Parameter>> _functions = {};

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

  List<Parameter> getFunctionParameters(String library, String function) {
    if(!_units.containsKey(library))
      return null;

    if(!_functions.containsKey(library)) {
      _functions[library] = {};
      var visitor = _VISITOR.build(_functions[library]);

      if(_units[library] is List)
        _units[library].forEach((u) => u.visitChildren(visitor));
      else
        _units[library].visitChildren(visitor);
    }

    var functions = _functions[library];
    if(functions.containsKey(function)) {
      return functions[function];
    }
    return [];
  }
}
