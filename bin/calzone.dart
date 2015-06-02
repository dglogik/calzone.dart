import "package:calzone/compiler.dart";
import "package:calzone/transformers.dart";

import "dart:io";

main(List<String> args) {
  var compiler = new Compiler.fromPath(args[1], args[0]);
  var include = new File(args[2]).readAsLinesSync().where((line) => line.trim().length > 0 && !line.trim().startsWith("#"));

  compiler.typeTransformers.addAll([
    new CollectionsTransformer(true),
    new PromiseTransformer(true),
    new ClosureTransformer()
  ]);

  var str = compiler.compile(include);

  print(str);
}
