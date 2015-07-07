part of calzone.transformers;

// node.js Buffer (or Browserify equivelent) to ByteData, and back.
class BufferTransformer implements TypeTransformer {
  BufferTransformer();

  @override
  transformToDart(Compiler compiler, StringBuffer output) {
    output.write("""
      if(obj instanceof Buffer) {
        function toArrayBuffer(buffer) {
          var ab = new ArrayBuffer(buffer.length);
          var view = new Uint8Array(ab);
          for (var i = 0; i < buffer.length; ++i) {
            view[i] = buffer[i];
          }
          return ab;
        }

        return new DataView(toArrayBuffer(obj));
      }
    """);
  }

  @override
  transformFromDart(Compiler compiler, StringBuffer output) {
    output.write("""
      if(obj instanceof DataView) {
        function toBuffer(ab) {
          var buffer = new Buffer(ab.byteLength);
          var view = new Uint8Array(ab);
          for (var i = 0; i < buffer.length; ++i) {
            buffer[i] = view[i];
          }
          return buffer;
        }
        return toBuffer(obj.buffer);
      }
    """);
  }
}
