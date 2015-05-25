library calzone.util;

abstract class TypeTransformer {
  List<String> get types;

  void transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals);
  void transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals);
}