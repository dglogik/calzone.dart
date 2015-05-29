library calpatcher;

import "package:args/args.dart";

import "dart:io";

// Use like this
// calpatcher something.js --target={browser,node}

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

  var index = data.length;
  for(var line in data.reversed) {
    index--;
    if(line.contains("// END invoke [main].")) {
      data.insertAll(index, new File(results["wrapper"]).readAsLinesSync());
      break;
    }
  }

  print(data.join("\n"));
}