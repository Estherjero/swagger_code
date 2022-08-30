import 'package:swagger_dart_code_generator/src/code_generators/swagger_generator_base.dart';
import 'package:swagger_dart_code_generator/src/extensions/file_name_extensions.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';

///Generates index file content, converter and additional methods
class SwaggerAdditionsGenerator extends SwaggerGeneratorBase {
  final GeneratorOptions _options;

  @override
  GeneratorOptions get options => _options;

  SwaggerAdditionsGenerator(this._options);

  ///Generates index.dart for all generated services
  String generateIndexes(List<String> fileNames) {
    final importsList = fileNames.map((key) {
      final actualFileName = getFileNameBase(key);
      final fileName = actualFileName
          .replaceAll('-', '_')
          .replaceAll('.json', '.swagger')
          .replaceAll('.yaml', '.swagger');
      final className = getClassNameFromFileName(actualFileName);

      return 'export \'$fileName.dart\' show $className;';
    }).toList();

    importsList.sort();

    return importsList.join('\n');
  }

  ///Generated imports for concrete service
  String generateImportsContent(
    String swaggerFileName,
    bool hasModels,
    bool buildOnlyModels,
    bool separateModels,
  ) {
    final result = StringBuffer();

    if (hasModels && !separateModels) {
      result.writeln("""
// ignore_for_file: type=lint

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import './$swaggerFileName.entity.swagger.dart';
""");
    }

    if (hasModels && separateModels) {
      result.write("import '$swaggerFileName.models.swagger.dart';");
    }

    if (hasModels && separateModels) {
      result.write("export '$swaggerFileName.models.swagger.dart';");
    }

    result.write('\n\n');

    result.write("""
      part '$swaggerFileName.swagger.freezed.dart';
      part '$swaggerFileName.swagger.g.dart';""");

    return result.toString();
  }
}
