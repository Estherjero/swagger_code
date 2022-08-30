import 'package:swagger_dart_code_generator/src/code_generators/swagger_models_generator.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/swagger_root.dart';

class SwaggerModelsGeneratorV3 extends SwaggerModelsGenerator {
  SwaggerModelsGeneratorV3(GeneratorOptions options) : super(options);

  @override
  String generate(SwaggerRoot root, String fileName) {
    final components = root.components;
    final schemas = components?.schemas;

    return generateBase(root, fileName, schemas ?? {});
  }
}
