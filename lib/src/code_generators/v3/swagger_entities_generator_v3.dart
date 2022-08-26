import 'package:swagger_dart_code_generator/src/extensions/string_extension.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/swagger_root.dart';

import '../swagger_entities_generator.dart';

class SwaggerEntitiesGeneratorV3 extends SwaggerEntitiesGenerator {
  SwaggerEntitiesGeneratorV3(GeneratorOptions options) : super(options);

  @override
  String generate(SwaggerRoot root, String fileName) {
    final components = root.components;
    final schemas = components?.schemas;

    return generateBase(root, fileName, schemas ?? {}, true);
  }

  @override
  List<String> getAllListEnumNames(SwaggerRoot root) {
    final results = getEnumsFromRequests(root).map((e) => e.name).toList();

    final components = root.components;

    final schemas = components?.schemas;

    if (schemas != null) {
      schemas.forEach((className, schema) {
        if (schema.isListEnum) {
          results.add(getValidatedClassName(className.capitalize));
          return;
        }
      });
    }

    final resultsWithPrefix = results.map((element) {
      return 'enums.$element';
    }).toList();

    return resultsWithPrefix;
  }
}
