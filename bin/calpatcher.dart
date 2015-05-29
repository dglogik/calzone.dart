library calpatcher;

import "package:args/args.dart";

import "dart:io";

main(List<String> args) async {
  var parser = new ArgParser();

  parser.addOption("target", abbr: "t", defaultsTo: "browser", allowed: ["browser", "node"]);
  parser.addOption("file", abbr: "f");
  parser.addOption("wrapper", abbr: "w");

  if(args.length == 0) {
    print(parser.usage);
    return;
  }

  var results = parser.parse(args);
  var file = new File(results["file"]);

  List<String> data = file.readAsLinesSync();

  data.insertAll(data.indexOf("// END invoke [main]."), new File(results["wrapper"]).readAsLinesSync());
  print(data.join("\n"));
}