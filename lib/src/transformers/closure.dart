part of calzone.transformers;

// Closure transformer to Dart closures
class ClosureTransformer implements TypeTransformer {
  final List<String> types = ["Function"];

  ClosureTransformer();

  dynamicTransformTo(StringBuffer output, List<String> globals) {
    output.write(r"""
      if(typeof obj === 'function') {
        var argCount = (new RegExp(/function[^]*\(([^]*)\)/)).exec(obj.toString())[1].split(',').length;
        var returned = {};
        returned['call$' + argCount] = function() {
          var args = Array.prototype.slice.call(arguments);
          args.forEach(function(arg, index) {
            args[index] = dynamicFrom(arg);
          });
          return dynamicTo(obj.apply(this, args));
        };
        return returned;
      }
    """);
  }

  // TODO
  dynamicTransformFrom(StringBuffer output, List<String> globals) {}

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    // TODO
    if(tree.length < 2)
      return;
    List<List> types = tree.sublist(1, tree.length - 1);
    output.write("$name = {call\$${types.length}: function() {");

    var index = 0;
    for(var type in types) {
      base.transformToDart(output, base, "arguments[$index]", type, globals);
      index++;
    }

    output.write("var returned = $name.apply(this, arguments);");
    if(tree[tree.length - 1] != "void") {
      base.transformFromDart(output, base, "returned", tree[tree.length - 1], globals);
    }

    output.write("return returned;}};");
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    // TODO
  }
}
