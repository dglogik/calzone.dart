part of calzone.transformers;

/**
 * A transformer that handles convertions between Dart's ByteData class
 * and Buffer from node.js.
 *
 * To use this transformer, you need to import "dart:typed_data" into
 * your stub file, and "dart.typed_data.ByteData" to your @MirrorsUsed
 * declaration.
 */
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
