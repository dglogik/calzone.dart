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

  if(results["target"] == "node") {
    // node preamble
    data.insert(0, """
    global.location = { href: "file://" + process.cwd() + "/" };
    global.scheduleImmediate = setImmediate;
    global.self = global;
    global.require = require;

    // Support for deferred loading.
    global.dartDeferredLibraryLoader = function(uri, successCallback, errorCallback) {
      try {
        load(uri);
        successCallback();
      } catch (error) {
        errorCallback(error);
      }
    };
    """);
  }

  var index = data.length;
  for(var line in data.reversed) {
    index--;
    if(line.contains("// END invoke [main].")) {
      data.insertAll(index, new File(results["wrapper"]).readAsLinesSync());
      continue;
    }

    if(line.contains("main: [function(args) {")) {
      isMainRemoved = true;
      data.removeRange(index + 1, index + 4);
]     break;
    }
  }

  print(data.join("\n"));
}
