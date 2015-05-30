library calzone.util;

abstract class TypeTransformer {
  List<String> get types;

  void dynamicTransformTo(StringBuffer output, List<String> globals);
  void dynamicTransformFrom(StringBuffer output, List<String> globals);

  void transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals);
  void transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals);
}
