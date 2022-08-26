import 'package:swagger_dart_code_generator/src/extensions/string_extension.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/swagger_root.dart';

import '../swagger_entities_generator.dart';

class SwaggerEntitiesGeneratorV2 extends SwaggerEntitiesGenerator {
  SwaggerEntitiesGeneratorV2(GeneratorOptions options) : super(options);

  @override
  String generate(SwaggerRoot root, String fileName) {
    final definitions = root.definitions;
    return generateBase(root, fileName, definitions, true);
  }

  @override
  List<String> getAllListEnumNames(SwaggerRoot root) {
    final results = getEnumsFromRequests(root).map((e) => e.name).toList();

    final definitions = root.definitions;

    definitions.forEach((className, definition) {
      if (definition.isListEnum) {
        results.add(getValidatedClassName(className.capitalize));
        return;
      }
    });

    final resultsWithPrefix = results.map((element) {
      return 'enums.$element';
    }).toList();

    return resultsWithPrefix;
  }
}
