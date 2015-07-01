part of calzone.analysis;

abstract class Visitor<T> extends GeneralizingAstVisitor<dynamic> {
  final Analyzer analyzer;
  final String libraryName;
  
  T data;

  Visitor(this.analyzer, this.libraryName, this.data);

  @override
  visitNode(AstNode node) {
    if (!visit(node)) node.visitChildren(this);
  }

  bool visit(AstNode node);
}
