part of calzone.compiler;

class BaseTypeTransformer implements TypeTransformer {
  final List<String> types = [];
  final Compiler _compiler;

  BaseTypeTransformer(this._compiler);

  dynamicTransformTo(StringBuffer output, List<String> globals) =>
    output.write("if(obj.__isWrapped__) { return obj.__obj__; }");

  dynamicTransformFrom(StringBuffer output, List<String> globals) =>
    output.write("""
      if(typeof(module.exports[obj.constructor.name]) !== 'undefined') {
        return module.exports[obj.constructor.name].fromObj(obj);
      }
    """);

  transformTo(StringBuffer output, String name, String type) => transformToDart(
      output, null, name, _getTypeTree(type), _compiler._globals);
  transformFrom(StringBuffer output, String name, String type) =>
      transformFromDart(
          output, null, name, _getTypeTree(type), _compiler._globals);

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name,
      List tree, List<String> globals) {
    var type = tree[0];
    if (PRIMITIVES.contains(type)) return;

    if (_compiler._wrappedClasses.containsKey(type)) {
      output.write("if(!$name.__isWrapped__) { $name = $name.__obj__; }");
      return;
    }

    if (type == "dynamic") {
      output.write("$name = dynamicTo($name);");
    }

    for (TypeTransformer transformer in _compiler.typeTransformers) {
      if (transformer.types.contains(type)) transformer.transformToDart(
          output, this, name, tree, _compiler._globals);
    }
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name,
      List tree, List<String> globals) {
    var type = tree[0];
    if (PRIMITIVES.contains(type)) return;

    if (_compiler._wrappedClasses.containsKey(type)) {
      output.write("if(!$name.__isWrapped__) {");
      output.write("var _type = typeof(module.exports[$name.constructor.name]) === 'undefined' ? '$type' : $name.constructor.name;");
      output.write("$name = module.exports[_type].fromObj($name); }");
      return;
    }

    if (type == "dynamic") {
      output.write("$name = dynamicFrom($name);");
    }

    for (TypeTransformer transformer in _compiler.typeTransformers) {
      if (transformer.types.contains(tree[0])) transformer.transformFromDart(
          output, this, name, tree, globals);
    }
  }
}
