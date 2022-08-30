import 'package:swagger_dart_code_generator/src/code_generators/swagger_additions_generator.dart';
import 'package:swagger_dart_code_generator/src/code_generators/swagger_models_generator.dart';
import 'package:swagger_dart_code_generator/src/code_generators/v2/swagger_models_generator_v2.dart';
import 'package:swagger_dart_code_generator/src/code_generators/v3/swagger_models_generator_v3.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/swagger_root.dart';

import 'code_generators/swagger_entities_generator.dart';
import 'code_generators/v2/swagger_entities_generator_v2.dart';
import 'code_generators/v3/swagger_entities_generator_v3.dart';

class SwaggerCodeGenerator {
  Map<int, SwaggerModelsGenerator> _getModelsMap(GeneratorOptions options) {
    return <int, SwaggerModelsGenerator>{
      2: SwaggerModelsGeneratorV2(options),
      3: SwaggerModelsGeneratorV3(options)
    };
  }

  Map<int, SwaggerEntitiesGenerator> _getEntitiesMap(GeneratorOptions options) {
    return <int, SwaggerEntitiesGenerator>{
      2: SwaggerEntitiesGeneratorV2(options),
      3: SwaggerEntitiesGeneratorV3(options)
    };
  }

  int _getApiVersion(SwaggerRoot root) {
    final openApi = root.openapiVersion;
    return openApi != null ? 3 : 2;
  }

  String generateImportsContent(
    String swaggerFileName,
    bool hasModels,
    bool buildOnlyModels,
    bool separateModels,
    GeneratorOptions options,
  ) =>
      _getSwaggerAdditionsGenerator(options).generateImportsContent(
        swaggerFileName,
        hasModels,
        buildOnlyModels,
        separateModels,
      );

  String generateModels(
          SwaggerRoot root, String fileName, GeneratorOptions options) =>
      _getSwaggerModelsGenerator(root, options).generate(root, fileName);

  String generateEntities(
          SwaggerRoot root, String fileName, GeneratorOptions options) =>
      _getSwaggerEntitiesGenerator(root, options).generate(root, fileName);

  SwaggerAdditionsGenerator _getSwaggerAdditionsGenerator(
          GeneratorOptions options) =>
      SwaggerAdditionsGenerator(options);

  SwaggerModelsGenerator _getSwaggerModelsGenerator(
    SwaggerRoot root,
    GeneratorOptions options,
  ) =>
      _getModelsMap(options)[_getApiVersion(root)]!;

  SwaggerEntitiesGenerator _getSwaggerEntitiesGenerator(
    SwaggerRoot root,
    GeneratorOptions options,
  ) =>
      _getEntitiesMap(options)[_getApiVersion(root)]!;
}
