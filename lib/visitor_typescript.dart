library calzone.visitor_typescript;

import "package:analyzer/analyzer.dart" show ParameterKind;

import "package:calzone/compiler.dart";
import "package:calzone/util.dart";

final Map<dynamic, String> _baseTypes = <String, String>{
  "dynamic": "any",
  "String": "string",
  "bool": "boolean",
  "int": "number",
  "num": "number",
  "DateTime": "Date",
  "Function": "Function",
  "Map": "any",
  "LinkedHashMap": "any",
  "Object": "any"
};

class _ClassStringBuffer {
  final String name;
  final String inherits;
  
  StringBuffer prefix = new StringBuffer();
  
  StringBuffer variables = new StringBuffer();
  StringBuffer constructor = new StringBuffer();
  StringBuffer content = new StringBuffer();
  
  _ClassStringBuffer(this.name, this.inherits);
  
  writelnPrefix(String text) => prefix.writeln(text);
  
  writelnVariables(String text) => variables.writeln(text);
  writelnConstructor(String text) => constructor.writeln(text);
  writeln(String text) => content.writeln(text);
  
  String toString() {
    StringBuffer output = new StringBuffer();
    
    if (!prefix.isEmpty) {
      output.write("\n$prefix");
    }
    
    var classDef = "class $name";
    if (inherits.isNotEmpty) {
      classDef += " extends $inherits";
    }
    
    output.write("\n\t$classDef {");
    
    if (!variables.isEmpty) {
      output.write("\n$variables");
    }
    
    if (!constructor.isEmpty) {
      output.write("\n$constructor");
    }
    
    if (!content.isEmpty) {
      output.write("\n$content");
    }
    
    output.write("\t}");
    return output.toString();
  }
}

class TypeScriptCompilerVisitor extends CompilerVisitor {
  final String moduleName;
  final String mixinTypes;
  
  String _output;
  String get output => _output;
  bool get hasOutput => _output != null;
    
  Compiler _compiler;
  StringBuffer _buffer;
  
  _ClassStringBuffer _classBuffer;
  
  Map<dynamic, String> _types; 
  
  TypeScriptCompilerVisitor(this.moduleName, { this.mixinTypes : "" });
  
  startCompilation(Compiler compiler) {
    _compiler = compiler;
    _buffer = new StringBuffer();
    _buffer.writeln("declare namespace __$moduleName {");
    
    if (!mixinTypes.isEmpty) {
      _buffer.write("$mixinTypes\n");
    }
    
    _types = new Map.from(_baseTypes);
    
    for (TypeTransformer transformer in compiler.typeTransformers) {
      if (transformer is! NamedTypeTransformer) {
        continue;
      }

      var n = transformer as NamedTypeTransformer;
      for (var input in n.types) {
        _types[input] = n.output;
      }
    }
  }
  
  stopCompilation() {
    _buffer.writeln("""
}
      
declare module "$moduleName" {
\texport = __$moduleName;
}
    """);
    
    _output = _buffer.toString();
    _buffer = null;
  }
  
  String _handleType(String type) {
    final tree = getTypeTree(type);
    final firstType = tree[0];
    
    if (firstType == null) {
      return "void";
    }

    if (_types.containsKey(firstType)) {
      return _types[firstType];
    }
        
    if (const ["List", "Iterable"].contains(firstType)) {
      if (tree.length > 1) {
        return "${_handleType(tree[1])}[]";
      } else {
        return "any[]";
      }
    }
    
    final obj = _compiler.analyzer.getClass(null, firstType);
    if (obj == null)
      return "any";
      
    if(!_compiler.includeDeclaration.contains(obj.libraryName + "." + firstType) &&
        !_compiler.includeDeclaration.contains(obj.libraryName)) {
      return "any";
    }    
    
    return firstType;
  }
  
  String _handleParams(List<Parameter> parameters,
      String optName, StringBuffer optBuffer) {
    List<String> paramList = [];
    
    StringBuffer options = new StringBuffer();
    
    for (var param in parameters) {
      if (param.kind == ParameterKind.NAMED) {
        if (options.isEmpty) {
          options.writeln("\tinterface $optName {");
        }
        
        options.writeln("\t\t${param.name}?: ${_handleType(param.type)};");
        continue;
      }
      
      var suffix = param.kind == ParameterKind.POSITIONAL ? "?" : "";      
      
      paramList.add("${param.name}$suffix: ${_handleType(param.type)}");
    }
    
    if (!options.isEmpty) {
      paramList.add("_opt?: $optName");
      options.write("\t}");
      
      optBuffer.writeln(options);
    }

    return paramList.join(", ");
  }
  
  String _makeFunction(Map<String, dynamic> data, List<Parameter> parameters, String returnType,
      String optName, StringBuffer optBuffer, { String subName }) {
    var name = subName != null ? subName : data["name"];
    
    returnType = _handleType(returnType);
    var paramStr = _handleParams(parameters, optName, optBuffer);
    
    return "$name($paramStr): $returnType;";
  }
  
  addTopLevelFunction(Map<String, dynamic> data, List<Parameter> parameters, String returnType) {   
    final str = _makeFunction(data, parameters, returnType, "_${data["name"]}_options", _buffer); 
    _buffer.writeln("\tfunction $str");
  }
  
  addAbstractClass(Map<String, dynamic> data) {
    _buffer.writeln("\n\tclass ${data["name"]} {\n\t}");
  }
  
  startClass(Map<String, dynamic> data, List<String> inheritedFrom) {
    _classBuffer = new _ClassStringBuffer(data["name"], inheritedFrom.isNotEmpty ? inheritedFrom[0] : "");
  }
  
  stopClass() {    
    _buffer.writeln(_classBuffer);
    _classBuffer = null;
  }
  
  addClassConstructor(Map<String, dynamic> data, List<Parameter> parameters) {
    final paramList = _handleParams(parameters, "_${_classBuffer.name}_options", _classBuffer.prefix);
    _classBuffer.writelnConstructor("\t\tconstructor($paramList);");
  }
  
  addClassStaticFunction(Map<String, dynamic> data, List<Parameter> parameters, String returnType) {
    var name = data["name"].contains(_classBuffer.name + ".") ?
      (data["name"] as String).substring(_classBuffer.name.length + 1) :
      data["name"];
    final str = _makeFunction(data, parameters, returnType,
        "_${_classBuffer.name}_${name}_options", _classBuffer.prefix,
        subName: name); 
    _classBuffer.writelnConstructor("\t\tstatic $str");
  }
  
  addClassFunction(Map<String, dynamic> data, List<Parameter> parameters, String returnType) {
    final str = _makeFunction(data, parameters, returnType,
        "_${_classBuffer.name}_${data["name"]}_options", _classBuffer.prefix); 
    _classBuffer.writeln("\t\t$str");
  }
  
  addClassStaticMember(Map<String, dynamic> data) {
    final name = data["name"];
    final type = data["type"];
    
    _classBuffer.writelnVariables("\t\tstatic $name: ${_handleType(type)};");
  }
  
  addClassMember(Map<String, dynamic> data) {
    final name = data["name"];
    final type = data["type"];
    
    _classBuffer.writelnVariables("\t\t$name: ${_handleType(type)};");
  }
}