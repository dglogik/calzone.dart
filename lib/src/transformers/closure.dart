part of calzone.transformers;

// Closure transformer to Dart closures
class ClosureTransformer implements TypeTransformer {
  final List<String> types = ["Function"];

  ClosureTransformer();

  transformToDart(Compiler compiler, StringBuffer output) {
    output.write("""
      if(typeof obj === 'function') {
        var argCount = (new RegExp(/function[^]*\(([^]*)\)/)).exec(obj.toString())[1].split(',').length;
        var returned = {};
        returned['${compiler.isMinified ? "\$" : "call\$"}' + argCount] = function() {
          var args = new Array(arguments.length);
          for(var i = 0; i < args.length; ++i) {
            args[i] = dynamicFrom(arguments[i]);
          }
          return dynamicTo(obj.apply(this, args));
        };
        return returned;
      }
    """);
  }

  // TODO
  transformFromDart(Compiler compiler, StringBuffer output) {}
}
