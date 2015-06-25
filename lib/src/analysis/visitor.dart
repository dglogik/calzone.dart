part of calzone.analysis;

typedef bool VisitorFunction(Analyzer analzyer, data, AstNode ast);

class Visitor extends GeneralizingAstVisitor<dynamic> {
  final Map<Type, List<VisitorFunction>> _visitors;
  final Analyzer _analyzer;
  final data;

  Visitor(this._analyzer, this.data, this._visitors);

  @override
  visitNode(AstNode node) {
    bool shouldVisitChildren = true;
    if (_visitors.containsKey(node.runtimeType)) {
      _visitors[node.runtimeType].forEach((visitor) {
        if (visitor(_analyzer, data, node)) shouldVisitChildren = false;
      });
    }

    if (shouldVisitChildren) node.visitChildren(this);
  }
}

class VisitorBuilder {
  final Map<Type, List<VisitorFunction>> _visitors = {};

  void where(types, VisitorFunction visitor) {
    if (types is Iterable<Type>) {
      for (var type in types) {
        if (_visitors.containsKey(type)) _visitors[type].add(visitor);
        else _visitors[type] = [visitor];
      }
      return;
    }

    if (_visitors.containsKey(types)) _visitors[types].add(visitor);
    else _visitors[types] = [visitor];
  }

  Visitor build(Analyzer analyzer, data) {
    return new Visitor(analyzer, data, _visitors);
  }
}
