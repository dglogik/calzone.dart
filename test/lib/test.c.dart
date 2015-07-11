library calzone.test.c;

@MirrorsUsed(
    targets: const [
  "calzone.test.a",
  "calzone.test.b",
  "calzone.test.c",
  "dart.async.Completer",
  "dart.async.Future",
  "dart.collection.LinkedHashMap"
])
import "dart:mirrors";
import "dart:async";
import "dart:collection";
import "dart:typed_data";

import "test.a.dart";

const int ONE = 1;

main(List<String> args) {
  var a = new Symbol(args.length.toString());

  reflectClass(a).getField(a);
  reflectClass(a).invoke(a, []);
  currentMirrorSystem().findLibrary(a).getField(a);
}

int getOne([int one = ONE]) {
  return one;
}
