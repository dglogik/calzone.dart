part of calzone.compiler;

class Func implements Renderable {
  final Map<String, dynamic> data;

  final List<Parameter> parameters;
  final FunctionTransformation transform;

  final String _code;
  final String _binding;
  final String _prefix;

  final bool _withSemicolon;

  Func(this.data, this.parameters, {this.transform: FunctionTransformation.NORMAL, String code, String binding: "this", String prefix, bool withSemicolon: true}):
    _code = code,
    _binding = binding,
    _prefix = prefix,
    _withSemicolon = withSemicolon;

  render(Compiler compiler, StringBuffer output) {
    if (_prefix == null) output.write("function(");
    else output.write("$_prefix.${data["name"]} = function(");

    var paramStringList = []..addAll(parameters);
    paramStringList.removeWhere((param) => param.kind == ParameterKind.NAMED);

    var paramString = paramStringList.map((param) => param.name).join(",");
    output.write("$paramString");
    if (parameters.any((param) => param.kind == ParameterKind.NAMED)) {
      if (paramString.length > 0) output.write(",");
      output.write("_optObj_){_optObj_ = _optObj_ || {};");
    } else {
      output.write("){");
    }

    String code = data["code"];
    if (this._code != null || code != null && code.length > 0) {
      for (var param in parameters) {
        var name = param.name;
        var declaredType = param.type;

        if (param.kind == ParameterKind.POSITIONAL) output.write("$name = typeof($name) === 'undefined' ? ${param.defaultValue} : $name;");
        if (param.kind == ParameterKind.NAMED) output
            .write("var $name = typeof(_optObj_.$name) === 'undefined' ? ${param.defaultValue} : _optObj_.$name;");

        if (param.kind != ParameterKind.REQUIRED) output.write("if($name !== null) {");

        if (transform != FunctionTransformation.REVERSED) compiler.baseTransformer.transformTo(output, name, declaredType);
        else compiler.baseTransformer.transformFrom(output, name, declaredType);

        if (param.kind != ParameterKind.REQUIRED) output.write("}");
      }

      code = _code != null
          ? _code
          : (code.trim().startsWith(":") == false ? "$_binding." + code.substring(0, code.indexOf(":")) : code.substring(code.indexOf(":") + 2));

      var fullParamString = parameters.map((p) => p.name).join(",");

      StringBuffer tOutput = new StringBuffer();

      var returnType = _TYPE_REGEX.firstMatch(data["type"]).group(2);
      if (transform == FunctionTransformation.NORMAL) compiler.baseTransformer.transformFrom(tOutput, "returned", returnType);
      else if (transform == FunctionTransformation.REVERSED) compiler.baseTransformer.transformTo(tOutput, "returned", returnType);

      output.write(tOutput.length > 0 ? "var returned = " : "return ");
      output.write("($code).call($_binding${fullParamString.length > 0 ? "," : ""}$fullParamString);");
      output.write(tOutput.length > 0 ? tOutput.toString() + "return returned;}" : "}");

      if (_withSemicolon) output.write(";");
    }
  }
}
