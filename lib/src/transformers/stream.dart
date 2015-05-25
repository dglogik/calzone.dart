part of calzone.transformers;

// Node.js Stream <-> Dart Stream
class StreamTransformer implements TypeTransformer {
  final List<String> types = ["Stream"];

  StreamTransformer();

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name, List typeTree, List<String> globals) {
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name, List typeTree, List<String> globals) {
  }
}