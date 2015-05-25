part of calzone.transformers;

final String _PROMISE_PREFIX = "var \$Promise = Promise || require('es6-promises');";

// ES6 Promise <-> Future
class PromiseTransformer implements TypeTransformer {
  final List<String> types = ["Future"];

  PromiseTransformer();

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name, List typeTree, List<String> globals) {
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name, List typeTree, List<String> globals) {
  }
}