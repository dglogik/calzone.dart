part of calzone.compiler;

class BaseTypeTransformer implements StaticTypeTransformer, TypeTransformer {
  final List<String> types = [];
  final Compiler _compiler;

  BaseTypeTransformer(this._compiler);

  @override
  transformToDart(Compiler compiler, StringBuffer output) =>
    output.write("if(obj[clIw]) { return obj[clOb]; }");

  @override
  transformFromDart(Compiler compiler, StringBuffer output) =>
    output.write("""
      if(typeof(module.exports[init.mangledGlobalNames[obj.constructor.name]]) !== 'undefined' && module.exports[init.mangledGlobalNames[obj.constructor.name]][clCl]) {
        return module.exports[init.mangledGlobalNames[obj.constructor.name]][clCl](obj);
      }
    """);

  transformTo(StringBuffer output, String name, tree) {
    tree = _getTypeTree(tree);
    if (tree is String) tree = [tree];

    staticTransformTo(_compiler, output, name, tree);
  }

  transformFrom(StringBuffer output, String name, tree) {
    tree = _getTypeTree(tree);
    if (tree is String) tree = [tree];

    staticTransformFrom(_compiler, output, name, tree);
  }

  @override
  staticTransformTo(Compiler compiler, StringBuffer output, String name, List tree) {
    var type = tree[0];
    if (PRIMITIVES.contains(type)) return;

    var list = compiler.typeTransformers.where((t) => t is StaticTypeTransformer && t.types.contains(type));

    if(list.length > 0) {
      if(list.length > 1)
        throw new Error("1+ static type transformer assigned to the same type");
      list.first.staticTransformTo(compiler, output, name, tree);
    } else {
      output.write("$name = dynamicTo($name);");
    }
  }

  @override
  staticTransformFrom(Compiler compiler, StringBuffer output, String name, List tree) {
    var type = tree[0];
    if (PRIMITIVES.contains(type)) return;

    var list = compiler.typeTransformers.where((t) => t is StaticTypeTransformer && t.types.contains(type));

    if(list.length > 0) {
      if(list.length > 1)
        throw new Error("1+ static type transformer assigned to the same type");
      list.first.staticTransformFrom(compiler, output, name, tree);
    } else {
      output.write("$name = dynamicFrom($name);");
    }
  }
}
