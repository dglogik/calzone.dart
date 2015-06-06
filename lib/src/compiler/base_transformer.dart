part of calzone.compiler;

class BaseTypeTransformer implements TypeTransformer {
  final List<String> types = [];
  final Compiler _compiler;

  BaseTypeTransformer(this._compiler);

  dynamicTransformTo(StringBuffer output, List<String> globals) =>
    output.write("if(obj.__isWrapped__) { return obj.__obj__; }");

  dynamicTransformFrom(StringBuffer output, List<String> globals) =>
    output.write("""
      if(typeof(module.exports[obj.constructor.name]) !== 'undefined' && module.exports[obj.constructor.name]._) {
        return module.exports[obj.constructor.name].fromObj(obj);
      }
    """);

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) =>
      transformTo(output, name, tree);

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) =>
      transformFrom(output, name, tree);

  transformTo(StringBuffer output, String name, tree) {
    if(tree is String)
      tree = _getTypeTree(tree);

    var type = tree[0];
    if (PRIMITIVES.contains(type)) return;

    if (_compiler._classes.containsKey(type) && _compiler._classes[type].value) {
      output.write("if(!$name.__isWrapped__) { $name = $name.__obj__; }");
    }

    if (type == "dynamic") {
      output.write("$name = dynamicTo($name);");
    }

    for (TypeTransformer transformer in _compiler.typeTransformers) {
      if (transformer.types.contains(type)) {
        transformer.transformToDart(output, this, name, tree, _compiler._globals);
      }
    }
  }

  transformFrom(StringBuffer output, String name, tree) {
    var type = tree[0];
    if (PRIMITIVES.contains(type)) return;

    if (_compiler._classes.containsKey(type) && _compiler._classes[type].value) {
      output.write("if(!$name.__isWrapped__) {");
      output.write("var _type = typeof(module.exports[$name.constructor.name]) === 'undefined' ? '$type' : $name.constructor.name;");
      output.write("$name = module.exports[_type].fromObj($name); }");
    }

    if (type == "dynamic") {
      output.write("$name = dynamicFrom($name);");
    }

    for (TypeTransformer transformer in _compiler.typeTransformers) {
      if (transformer.types.contains(tree[0])) {
        transformer.transformFromDart(output, this, name, tree, _compiler._globals);
      }
    }
  }
}
