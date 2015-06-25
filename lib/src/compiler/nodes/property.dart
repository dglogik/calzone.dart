part of calzone.compiler;

class ClassProperty implements Renderable {
  final Map<String, dynamic> data;

  final Class _class;
  String _prefix;

  final dynamic value;
  final String mangledName;

  ClassProperty(this.data, this._class, {bool isStatic: false, this.value, this.mangledName}) {
    _prefix = isStatic ? "module.exports.${_class.name}" : "this";
  }

  render(Compiler compiler, StringBuffer output) {
    var name = data["name"];
    output.write("Object.defineProperty($_prefix, \"$name\", {");

    if (data["value"] != null) {
      if (data["value"] is Function) {
        output.write("enumerable: false");
        output.write(",value:(");
        data["value"]();
        output.write(")");
      } else {
        output.write("enumerable: false");
        output.write(",value: ${data["value"]}");
      }
    } else {
      output.write("enumerable: ${(!name.startsWith("_"))}");
      output.write(",get: function() { var returned = this.__obj__.${mangledName != null ? mangledName : name};");
      compiler.baseTransformer.transformFrom(output, "returned", data["type"]);
      output.write("return returned;},set: function(v) {");
      compiler.baseTransformer.transformTo(output, "v", data["type"]);
      output.write("this.__obj__.${mangledName != null ? mangledName : name} = v;}");
    }

    output.write("});");
  }
}
