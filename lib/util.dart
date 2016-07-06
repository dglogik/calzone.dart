library calzone.util;

import "package:logging/logging.dart";

import "package:calzone/compiler.dart";
export "package:calzone/compiler.dart" show Compiler, InfoData, MangledNames;

final Logger LOGGER = new Logger("calzone.dart");

/**
 * TypeTransformer is a class that handles dynamically converting one type to
 * another type at runtime. Please use the calzone.transformers package right
 * now for examples on how to use transformers.
 */
abstract class TypeTransformer {
  void transformToDart(Compiler compiler, StringBuffer output);
  void transformFromDart(Compiler compiler, StringBuffer output);
}

// for when types cannot be converted at runtime by dynamicTo/dynamicFrom
abstract class StaticTypeTransformer {
  List<String> get types;

  void staticTransformTo(Compiler compiler, StringBuffer output, String name, List tree);
  void staticTransformFrom(Compiler compiler, StringBuffer output, String name, List tree);
}

class Duo<K, V> {
  final K key;
  final V value;

  Duo(this.key, this.value);
}

class MutableDuo<K, V> implements Duo<K, V> {
  K key;
  V value;

  MutableDuo(this.key, this.value);
}
