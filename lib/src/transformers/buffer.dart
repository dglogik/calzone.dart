part of calzone.transformers;

// node.js Buffer (or Browserify equivelent) to ByteBuffer, and back.
class BufferTransformer implements TypeTransformer {
  final List<String> types = ["ByteBuffer"];

  BufferTransformer();

  @override
  dynamicTransformTo(StringBuffer output, List<String> globals) {
    output.write("""
      if(obj instanceof Buffer) {
        var length = obj.length;
        var returned = new init.allClasses.ByteData(length);
        for(var index = 0; index < length; index++) {
          returned.setUint8\$2(index, obj.readUInt8(index));
        }
        return returned.get\$buffer();
      }
    """);
  }

  @override
  dynamicTransformFrom(StringBuffer output, List<String> globals) {
    output.write("""
      if(obj instanceof init.allClasses.ByteBuffer) {
        var length = obj.get\$lengthInBytes();
        var buffer = new Buffer(length);

        var view = new init.allClasses.ByteData.view(obj, 0, length);
        for(var index = 0; index < length; index++) {
          buffer.writeUInt8(view.getUint8\$1(index), index);
        }
        return buffer;
      }
    """);
  }

  @override
  transformToDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    output.write("var _$name = $name; $name = new init.allClasses.ByteData(_$name.length);");
    output.write("for(var index = 0; index < _$name.length; index++) { $name.setUint8\$2(index, _$name.readUInt8(index)); }");
    output.write("$name = $name.get\$buffer();");
  }

  @override
  transformFromDart(StringBuffer output, TypeTransformer base, String name, List tree, List<String> globals) {
    output.write("""
    var _length = obj.get\$lengthInBytes();
    var _view = new init.allClasses.ByteData.view($name, 0, _length);
    $name = new Buffer(_length);

    for(var index = 0; index < _length; index++) {
      buffer.writeUInt8(_view.getUint8\$1(index), index);
    }
    """);
  }
}
