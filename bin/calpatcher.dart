library calpatcher;

import "package:calzone/patcher.dart";

import "package:args/args.dart";

main(List<String> args) async {
  var parser = new ArgParser();

  parser.addOption("target",
      abbr: "t", defaultsTo: "browser", allowed: ["browser", "node"]);
  parser.addOption("file", abbr: "f");
  parser.addOption("wrapper", abbr: "w");
  parser.addOption("info", abbr: "i");
  parser.addFlag("minified", abbr: "m", defaultsTo: false);

  if (args.length == 0) {
    print(parser.usage);
    return;
  }

  var results = parser.parse(args);
  var patcher = new Patcher(results["file"], results["info"], results["wrapper"],
      target: results["target"] == "browser"
          ? PatcherTarget.BROWSER
          : PatcherTarget.NODE,
      isMinified: results["minified"]);

  print(patcher.patch());
}
