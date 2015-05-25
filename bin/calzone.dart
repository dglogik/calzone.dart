import "package:calzone/compiler.dart";

main(List<String> args) {
  var compiler = new Compiler.fromPath(args[0]);
  print(compiler.compile(args.sublist(1)));
}
