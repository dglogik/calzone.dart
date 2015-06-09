library calpatcher;

import "package:args/args.dart";

import "dart:io";

main(List<String> args) async {
  var parser = new ArgParser();

  parser.addOption("target",
      abbr: "t", defaultsTo: "browser", allowed: ["browser", "node"]);
  parser.addOption("file", abbr: "f");
  parser.addOption("wrapper", abbr: "w");

  if (args.length == 0) {
    print(parser.usage);
    return;
  }

  var results = parser.parse(args);
  var file = new File(results["file"]);

  List<String> data = file.readAsLinesSync();

  if (results["target"] == "node") {
    // node preamble
    data.insert(0, """
global.location = { href: "file://" + process.cwd() + "/" };
global.scheduleImmediate = setImmediate;
global.self = global;
global.require = require;
global.process = process;

global.dartMainRunner = function(main, args) {
  main(args.slice(Math.min(args.length, 2)));
};

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
  var reversed = []..addAll(data.reversed);

  var foundTypeCheck = false;
  var foundMain = false;

  for (var line in reversed) {
    index--;
    if (line.contains("// END invoke [main].")) {
      data.insertAll(index, new File(results["wrapper"]).readAsLinesSync());
      continue;
    }

    if (line.contains("buildFunctionType: function(returnType, parameterTypes, optionalParameterTypes) {")) {
      data[index + 1] = "var proto = Object.create(new H.RuntimeFunctionType(returnType, parameterTypes, optionalParameterTypes, null)); proto._isTest\$1 = function() { return true; }; return proto;";
      foundTypeCheck = true;
      if(foundMain && foundTypeCheck)
        break;
    }

    if (line.contains("main: [function(args) {")) {
      data.removeRange(index + 1, index + 4);
      foundMain = true;
      if(foundMain && foundTypeCheck)
        break;
    }
  }

  print(data.join("\n"));
}
