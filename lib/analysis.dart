library calzone.analysis;

import "package:calzone_source_crawler/analysis.dart";
import "package:analyzer/analyzer.dart";

import "package:path/path.dart" as path;

import "package:calzone/util.dart";
import "package:calzone/compiler.dart" show Parameter, Class, MangledNames;

import "dart:io";

part 'src/analysis/visitor.dart';
part 'src/analysis/analyzer.dart';
