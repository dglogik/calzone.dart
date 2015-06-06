part of calzone.transformers;

// node.js Buffer (or Browserify equivelent) to ByteBuffer, and back.
class BufferTransformer implements TypeTransformer {
  final List<String> types = ["ByteBuffer"];

  BufferTransformer();

  @override
  dynamicTransformTo(StringBuffer output, List<String> globals) {
    output.write("if(obj instanceof Buffer) {");
    output.write("return new init.allClasses.ByteBuffer(); }");
  }

  @override
  dynamicTransformFrom(StringBuffer output, List<String> globals) {

  }

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    output.write("$name = new init.allClasses.ByteBuffer($name);");
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {

  }
}
