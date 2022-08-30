import 'package:swagger_dart_code_generator/src/code_generators/swagger_entities_generator.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/swagger_root.dart';

class SwaggerEntitiesGeneratorV2 extends SwaggerEntitiesGenerator {
  SwaggerEntitiesGeneratorV2(GeneratorOptions options) : super(options);

  @override
  String generate(SwaggerRoot root, String fileName) {
    final definitions = root.definitions;
    return generateBase(root, fileName, definitions);
  }
}
