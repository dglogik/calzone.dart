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

      data[node.name.toString()] = new Class(node.name.toString(), libraryName,
          staticFields: staticFields,
          inheritedFrom: tree,
          getters: getters,
          setters: setters);
    }

    if(node is FormalParameterList && !libraryName.startsWith("dart.")) {
      var f = node.parent;
      var c = f.parent;

      if (c is ClassDeclaration && c.parent is CompilationUnit && f is ClassMember) {
          if (f is MethodDeclaration && (f.isGetter || f.isSetter))
            return true;

          var cNode = data[c.name.toString()];

          var name = f.name.toString();
          if (name == "null") name = "";

          cNode.functions[name] = [];
          node.visitChildren(new ParamVisitor(analyzer, libraryName, new Duo(cNode.functions[name], c.name.toString())));
      } else if(c is FunctionDeclaration && c.parent is CompilationUnit) {
        data[c.name.toString()] = [];
        node.visitChildren(new ParamVisitor(analyzer, libraryName, new Duo(data[c.name.toString()], null)));
      }

      return true;
    }

    return false;
  }
}

class ParamVisitor extends Visitor<Duo<List<Parameter>, String>> {
  ParamVisitor(analyzer, library, data): super(analyzer, library, data);

  bool visit(AstNode node) {
    if(node is FormalParameter) {
      var norm = node;
      if (node is DefaultFormalParameter) norm = norm.parameter;

      if (norm is FunctionTypedFormalParameter) {
        var types = [];
        var params = [];
        norm.parameters.visitChildren(new ParamVisitor(analyzer, libraryName, new Duo(params, this.data.value)));
        for (var param in params) {
          types.add(param.type != null ? param.type : "dynamic");
        }

        types.add(norm.returnType != null ? norm.returnType.toString() : "void");

        data.key.add(new Parameter(norm.kind, "Function<${types.join(",")}>", norm.identifier.toString()));
        return true;
      }

      String defaultValue = "null";
      if(node is DefaultFormalParameter && node.defaultValue != null) {
        var primitiveVisitor = new PrimitiveVisitor(analyzer, libraryName, new MutableDuo<String, String>("", this.data.value));
        primitiveVisitor.visitNode(node.defaultValue);
        if(primitiveVisitor.data.key.length > 0)
          defaultValue = primitiveVisitor.data.key;
      }

      data.key.add(new Parameter(norm.kind, norm.type == null ? "dynamic" : norm.type.toString(),
          norm.identifier.toString(),
          defaultValue));
    }

    return true;
  }
}

// class name, output strings
class PrimitiveVisitor extends Visitor<MutableDuo<String, String>> {
  PrimitiveVisitor(analyzer, library, data): super(analyzer, library, data);

  bool visit(AstNode node) {
    if(node is Identifier) {
      var parts;

      if(node is PrefixedIdentifier)
        parts = [node.prefix.toString(), node.identifier.toString()];

      if(node is SimpleIdentifier)
        parts = [node.toString()];

      if(parts.length > 0) {
        // edge case found through testing
        if(parts.join(".") == "double.NAN") {
          data.key += "Number.NaN";
          return true;
        }

        // class scope
        if(data.value != null) {
          var fields = analyzer.compiler.mangledNames.getClassFields(this.libraryName, data.value);

          if(fields.contains(parts[0])) {
            var mangledStatic = analyzer.compiler.mangledNames.getStaticField(this.libraryName, parts[0], className: data.value);
            if(mangledStatic != null)
              data.key += "stat.$mangledStatic";

            return true;
          }
        }

        // global scope
        var libraryName = analyzer.dictionary.searchForGlobalProp(parts[0], libraryName: this.libraryName);
        if(libraryName == null)
          return true;

        var mangledName = analyzer.compiler.mangledNames.getLibraryObject(libraryName);

        var libraryObj = analyzer.dictionary.libraries[libraryName];

        AstNode node;
        for(var unit in libraryObj.astUnits) {
          node = analyzer.dictionary.searchForProp(unit, parts[0]);
          if(node != null)
            break;
        }

        if(node is ClassDeclaration || node is EnumDeclaration && parts.length == 2) {
          var c = analyzer.compiler.classes.containsKey("$libraryName.${parts[0]}")
            ? analyzer.compiler.classes["$libraryName.${parts[0]}"]
            : analyzer.compiler.classes["${parts[0]}"];

          if(c != null && c.key.children.containsKey(parts[1])) {
            data.key += c.key.getMangledName(parts[1]);
          } else {
            // must access a static variable
            var mangledStatic = analyzer.compiler.mangledNames.getStaticField(libraryName, parts[1], className: parts[0]);
            data.key += "stat.$mangledStatic";
          }
        }

        if(node is TopLevelVariableDeclaration) {
          var mangledStatic = analyzer.compiler.mangledNames.getStaticField(libraryName, parts[0]);
          data.key += "stat.$mangledStatic";
        }
      }

      return true;
    }

    if(node is ListLiteral) {
      data.key += "[";

      node.elements.forEach((element) {
        visit(element);
        if(element != node.elements.last)
          data.key += ",";
      });

      data.key += "]";
      return true;
    }

    if(node is MapLiteral) {
      data.key += "{";

      node.entries.forEach((MapLiteralEntry entry) {
        visit(entry.key);
        data.key += ":";
        visit(entry.value);
        if(entry != node.entries.last)
          data.key += ",";
      });

      data.key += "}";
      return true;
    }

    if(node is Literal) {
      data.key += node.toString();
      return true;
    }

    return false;
  }
}
