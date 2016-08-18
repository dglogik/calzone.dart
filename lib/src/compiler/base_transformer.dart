part of calzone.compiler;

class BaseTypeTransformer implements TypeTransformer {
  final Compiler _compiler;

  BaseTypeTransformer(this._compiler);

  @override
  transformToDart(Compiler compiler, StringBuffer output) =>
      output.write("if(obj[clIw]) { return obj[clOb]; }");

  @override
  transformFromDart(Compiler compiler, StringBuffer output) => output.write("""
      if(obj[clId]) {
        return obj[clId];
      }

      if(module.exports[init.mangledGlobalNames[obj.constructor.name]] !== void 0) {
        var classObj = Object.create(module.exports[init.mangledGlobalNames[obj.constructor.name]].prototype);
        classObj[clOb] = obj;
        classObj[clOb][clBk] = {};
        return classObj;
      }
    """);

  bool _transformTo(StringBuffer output, String name, tree) {
    var type = tree[0];
    if (PRIMITIVES.contains(type)) return false;

    var list = _compiler.typeTransformers
        .where((t) => t is StaticTypeTransformer && t.types.contains(type));
    if (list.length == 0) return false;

    list.forEach((t) => t.staticTransformTo(_compiler, output, name, tree));

    if (output.length == 0) return false;
    return true;
  }

  bool _transformFrom(StringBuffer output, String name, tree) {
    var type = tree[0];
    if (PRIMITIVES.contains(type)) return false;

    var list = _compiler.typeTransformers
        .where((t) => t is StaticTypeTransformer && t.types.contains(type));
    if (list.length == 0) return false;

    list.forEach((t) => t.staticTransformFrom(_compiler, output, name, tree));

    if (output.length == 0) return false;
    return true;
  }

  transformTo(StringBuffer output, String name, tree) {
    if (tree is String) tree = _getTypeTree(tree);
    if (tree is String) tree = [tree];

    var type = tree[0];

    StringBuffer tOutput = new StringBuffer();

    var shouldTransform = _transformTo(tOutput, name, tree);

    if (shouldTransform) {
      output.write(tOutput.toString());
    } else if (!PRIMITIVES.contains(type)) {
      output.write("$name = dynamicTo($name);");
    }
  }

  transformFrom(StringBuffer output, String name, tree) {
    if (tree is String) tree = _getTypeTree(tree);
    if (tree is String) tree = [tree];

    var type = tree[0];

    StringBuffer tOutput = new StringBuffer();

    var shouldTransform = _transformFrom(tOutput, name, tree);

    if (shouldTransform) {
      output.write(tOutput.toString());
    } else if (!PRIMITIVES.contains(type)) {
      output.write("$name = dynamicFrom($name);");
    }
  }

  handleReturn(StringBuffer output, String code, tree,
      {FunctionTransformation transform: FunctionTransformation.NORMAL}) {
    if (transform == FunctionTransformation.NONE) {
      output.write("return $code;");
      return;
    }

    var isNormal = transform == FunctionTransformation.NORMAL;

    if (tree is String) tree = _getTypeTree(tree);
    if (tree is String) tree = [tree];

    var type = tree[0];

    StringBuffer tOutput = new StringBuffer();

    var shouldTransform = isNormal
        ? _transformFrom(tOutput, "returned", tree)
        : _transformTo(tOutput, "returned", tree);

    if (shouldTransform) {
      output.write("var returned = $code;");
      output.write(tOutput.toString());
      output.write("return returned;");
    } else {
      if (PRIMITIVES.contains(type)) {
        output.write("return $code;");
        return;
      }

      output.write("return ${isNormal ? "dynamicFrom": "dynamicTo"}($code);");
    }
  }
}
