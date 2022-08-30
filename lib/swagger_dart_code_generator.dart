import 'dart:convert';

import 'package:build/build.dart';
import 'package:swagger_dart_code_generator/src/extensions/file_name_extensions.dart';
import 'package:swagger_dart_code_generator/src/extensions/yaml_extensions.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:swagger_dart_code_generator/src/swagger_code_generator.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/swagger_root.dart';
import 'package:universal_io/io.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' show join, normalize;
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

///Returns instance of SwaggerDartCodeGenerator
SwaggerDartCodeGenerator swaggerCodeBuilder(BuilderOptions options) =>
    SwaggerDartCodeGenerator(options);

const _inputFileExtensions = ['.swagger', '.json', '.yaml'];

const String _outputFileExtension = '.swagger.dart';
const String _outputEntityFileExtension = '.entity.swagger.dart';

String additionalResultPath = '';
Set<String> allFiledList = {};

String normal(String path) => AssetId('', path).path;

String _getAdditionalResultPath(GeneratorOptions options) {
  final filesList = Directory(normalize(options.inputFolder)).listSync();

  if (filesList.isNotEmpty) return filesList.first.path;

  if (options.inputUrls.isNotEmpty) {
    final path = normalize(
        '${options.inputFolder}${getFileNameBase(options.inputUrls.first)}');
    File(path).createSync();
    return path;
  }

  return Directory(normalize(options.inputFolder)).listSync().first.path;
}

Map<String, List<String>> _generateExtensions(GeneratorOptions options) {
  final result = <String, Set<String>>{};

  final filesList = Directory(normalize(options.inputFolder)).listSync().where(
      (FileSystemEntity file) =>
          _inputFileExtensions.any((ending) => file.path.endsWith(ending)));

  additionalResultPath =
      _getAdditionalResultPath(options).replaceAll('\\', '/');

  File(additionalResultPath).createSync();

  var out = normalize(options.outputFolder);

  final filesPaths = filesList.map((e) => e.path.replaceAll('\\', '/'));
  final fileNames = filesList.map((e) => getFileNameBase(e.path));

  allFiledList.addAll(filesPaths);
  allFiledList.addAll(options.inputUrls);

  result[additionalResultPath] = {};

  for (var url in filesPaths) {
    final name = removeFileExtension(getFileNameBase(url));
    if (name == additionalResultPath) continue;

    result[url] = {};
    result[url]!.add(join(out, '$name$_outputFileExtension'));
    result[url]!.add(join(out, '$name$_outputEntityFileExtension'));
  }

  for (var url in options.inputUrls) {
    if (fileNames.contains(getFileNameBase(url))) continue;

    final name = removeFileExtension(getFileNameBase(url));

    result[additionalResultPath]!.add(join(out, '$name$_outputFileExtension'));
    result[additionalResultPath]!
        .add(join(out, '$name$_outputEntityFileExtension'));
  }

  return result.map((key, value) => MapEntry(key, value.toList()));
}

///Root library entry
class SwaggerDartCodeGenerator implements Builder {
  SwaggerDartCodeGenerator(BuilderOptions builderOptions) {
    options = GeneratorOptions.fromJson(builderOptions.config);
  }

  @override
  Map<String, List<String>> get buildExtensions =>
      _buildExtensionsCopy ??= _generateExtensions(options);

  Map<String, List<String>>? _buildExtensionsCopy;

  late GeneratorOptions options;

  final DartFormatter _formatter = DartFormatter();

  @override
  Future<void> build(BuildStep buildStep) async {
    if (buildStep.inputId.path == additionalResultPath) {
      for (final url in options.inputUrls) {
        final fileNameWithExtension = getFileNameBase(url);

        final contents = await _download(url);

        final filePath = join(options.inputFolder, fileNameWithExtension);
        await File(filePath).create();
        await File(filePath).writeAsString(contents);
      }
    }
    final file = File(buildStep.inputId.path);
    var contents = await file.readAsString();

    Map<String, dynamic> contentMap;

    if (buildStep.inputId.path.endsWith('.yaml')) {
      final t = loadYaml(contents) as YamlMap;
      contentMap = t.toMap();
    } else {
      contentMap = jsonDecode(contents) as Map<String, dynamic>;
    }

    final SwaggerRoot parsed = SwaggerRoot.fromJson(contentMap);

    final fileNameWithExtension = getFileNameBase(buildStep.inputId.path);
    final fileNameWithoutExtension = removeFileExtension(fileNameWithExtension);

    await _generateAndWriteFile(
      contents: parsed,
      buildStep: buildStep,
      fileNameWithExtension: fileNameWithExtension,
      fileNameWithoutExtension: fileNameWithoutExtension,
    );
  }

  Future<void> _generateAndWriteFile({
    required SwaggerRoot contents,
    required String fileNameWithoutExtension,
    required String fileNameWithExtension,
    required BuildStep buildStep,
  }) async {
    final codeGenerator = SwaggerCodeGenerator();

    final models = codeGenerator.generateModels(
        contents, removeFileExtension(fileNameWithExtension), options);

    final entities = codeGenerator.generateEntities(
        contents, removeFileExtension(fileNameWithExtension), options);

    final imports = codeGenerator.generateImportsContent(
      fileNameWithoutExtension,
      models.isNotEmpty,
      options.buildOnlyModels,
      options.separateModels,
      options,
    );

    final copyAssetId = AssetId(
        buildStep.inputId.package,
        join(options.outputFolder,
            '$fileNameWithoutExtension$_outputFileExtension'));

    final entityAssetId = AssetId(
        buildStep.inputId.package,
        join(options.outputFolder,
            '$fileNameWithoutExtension$_outputEntityFileExtension'));

    if (!options.separateModels || !options.buildOnlyModels) {
      await buildStep.writeAsString(
          copyAssetId,
          _generateFileContent(
            imports,
            options.separateModels ? '' : models,
          ));

      await buildStep.writeAsString(
        entityAssetId,
        _generateEntityFileContent(entities),
      );
    }
  }

  String _generateFileContent(
    String imports,
    String models,
  ) {
    final result = """
$imports


$models
""";

    return _tryFormatCode(result);
  }

  String _generateEntityFileContent(String entities) {
    final result = """
import 'package:equatable/equatable.dart';

$entities
""";
    return result;
  }

  String _tryFormatCode(String code) {
    try {
      final formattedResult = _formatter.format(code);
      return formattedResult;
    } catch (e) {
      print('''[WARNING] Code formatting failed.
          Please raise an issue on https://github.com/epam-cross-platform-lab/swagger-dart-code-generator/issues/
          Reason: $e''');
      return code;
    }
  }
}

Future<String> _download(String url) async {
  var response = await http.get(Uri.parse(url));

  return response.body;
}
