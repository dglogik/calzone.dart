import "package:calzone/compiler.dart";
import "package:calzone/transformers.dart";

main(List<String> args) {
  var compiler = new Compiler.fromPath(args[0]);

  compiler.typeTransformers.addAll([new CollectionsTransformer(), new PromiseTransformer(true), new ClosureTransformer()]);

  print(
  compiler.compile(args.sublist(1))
  );
}
