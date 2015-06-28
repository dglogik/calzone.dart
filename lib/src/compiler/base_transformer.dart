part of calzone.compiler;

class BaseTypeTransformer implements TypeTransformer {
  final List<String> types = [];
  final Compiler _compiler;

  BaseTypeTransformer(this._compiler);

  @override
  transformToDart(Compiler compiler, StringBuffer output) =>
    output.write("if(obj[clIw]) { return obj[clOb]; }");

  @override
  transformFromDart(Compiler compiler, StringBuffer output) =>
    output.write("""
      if(typeof(module.exports[obj.constructor.name]) !== 'undefined' && module.exports[obj.constructor.name][clCl]) {
        return module.exports[obj.constructor.name][clCl](obj);
      }
    """);

  transformTo(StringBuffer output, String name, tree) {
    tree = _getTypeTree(tree);
    if (tree is String) tree = [tree];

    var type = tree[0];
    if (PRIMITIVES.contains(type)) return;

    if (_compiler.classes.containsKey(type) && _compiler.classes[type].value) {
      output.write("if(!$name[clIw]) { $name = $name[clOb]; }");
      return;
    }

    output.write("$name = dynamicTo($name);");
  }

  transformFrom(StringBuffer output, String name, tree) {
    tree = _getTypeTree(tree);
    if (tree is String) tree = [tree];

    var type = tree[0];
    if (PRIMITIVES.contains(type)) return;

    if (_compiler.classes.containsKey(type) && _compiler.classes[type].value) {
      output.write("if(!$name[clIw]) {");
      output.write("var _type = typeof(module.exports[$name.constructor.name]) === 'undefined' ? '$type' : $name.constructor.name;");
      output.write("$name = module.exports[_type][clCl]($name); }");
      return;
    }

    output.write("$name = dynamicFrom($name);");
  }
}
