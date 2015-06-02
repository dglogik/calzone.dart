part of calzone.analysis;

typedef bool VisitorFunction(data, AstNode ast);

class Visitor extends GeneralizingAstVisitor<dynamic> {
  final Map<Type, List<VisitorFunction>> _visitors;
  final data;

  Visitor(this.data, this._visitors);

  @override
  visitNode(AstNode node) {
    bool shouldVisitChildren = true;
    if(_visitors.containsKey(node.runtimeType)) {
      _visitors[node.runtimeType].forEach((visitor) {
        if(visitor(data, node)) shouldVisitChildren = false;
      });
    }

    if(shouldVisitChildren)
      node.visitChildren(this);
  }
}

class VisitorBuilder {
  final Map<Type, List<VisitorFunction>> _visitors = [];

  void where(types, VisitorFunction visitor) {
    if(types is Iterable<Type>) {
      for(var type in types) {
        if(_visitors.containsKey(type))
          _visitors[type].add(visitor);
        else
          _visitors[type] = [visitor];
      }
      return;
    }

    if(_visitors.containsKey(types))
      _visitors[types].add(visitor);
    else
      _visitors[types] = [visitor];
  }

  Visitor build(data) {
    return new Visitor(data, _visitors);
  }
}

/*
class _ParamAstVisitor extends GeneralizingAstVisitor<dynamic> {
  final List output;

  _ParamAstVisitor(this.output);

  @override
  visitNode(AstNode node) {
    if(node is DefaultFormalParameter || node is NormalFormalParameter) {
      var norm = node;
      if(node is DefaultFormalParameter)
        norm = norm.parameter;

      if(norm is FunctionTypedFormalParameter) {
        var types = [];
        var params = [];
        norm.parameters.visitChildren(new _ParamAstVisitor(params));
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
    }
  }
}
