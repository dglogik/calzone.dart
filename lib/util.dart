library calzone.util;

abstract class TypeTransformer {
  List<String> get types;

  String transformTo(String name, List typeTree);
  String transformFrom(String name, List typeTree);
}
