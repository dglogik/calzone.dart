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
          var args = Array.prototype.slice.call(arguments);
          args.forEach(function(arg, index) {
            args[index] = dynamicFrom(arg);
          });
          return dynamicTo(obj.apply(this, args));
        };
        return returned;
      }
    """);
  }

  // TODO
  transformFromDart(Compiler compiler, StringBuffer output) {}
}
