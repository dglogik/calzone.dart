part of calzone.transformers;

// Closure transformer to Dart closures
class ClosureTransformer implements TypeTransformer {
  final List<String> types = ["Function"];

  ClosureTransformer();

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
