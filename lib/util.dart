library calzone.util;

import "package:calzone/compiler.dart";
export "package:calzone/compiler.dart" show Compiler, InfoData, MangledNames;

abstract class TypeTransformer {
  List<String> get types;

  void transformToDart(Compiler compiler, StringBuffer output);
  void transformFromDart(Compiler compiler, StringBuffer output);
}

class Duo<K, V> {
  final K key;
  final V value;

  Duo(this.key, this.value);
}
