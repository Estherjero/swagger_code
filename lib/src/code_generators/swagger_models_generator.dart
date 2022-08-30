import 'package:recase/recase.dart';
import 'package:swagger_dart_code_generator/src/code_generators/constants.dart';
import 'package:swagger_dart_code_generator/src/code_generators/swagger_generator_base.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/responses/swagger_schema.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/swagger_root.dart';

import 'constants.dart';

abstract class SwaggerModelsGenerator extends SwaggerGeneratorBase {
  final GeneratorOptions _options;

  @override
  GeneratorOptions get options => _options;

  SwaggerModelsGenerator(this._options);

  String generate(SwaggerRoot root, String fileName);

  String generateModelClassContent(
    SwaggerRoot root,
    String className,
    SwaggerSchema schema,
    Map<String, SwaggerSchema> schemas,
    List<DefaultValueMap> defaultValues,
    List<String> classesWithNullableLists,
    Map<String, SwaggerSchema> allClasses,
  ) {
    if (kBasicTypes.contains(schema.type.toLowerCase())) return '';

    if (schema.hasRef) return 'class $className {}';

    return generateModelClassString(
      root,
      className,
      schema,
      schemas,
      defaultValues,
      classesWithNullableLists,
      allClasses,
    );
  }

  String generateBase(
      SwaggerRoot root, String fileName, Map<String, SwaggerSchema> classes) {
    final classesFromInnerClasses = getClassesFromInnerClasses(classes);

    classes.addAll(classesFromInnerClasses);

    if (classes.isEmpty) return '';

    final generatedClasses = classes.keys.map((String className) {
      final allClasses = {
        ...root.definitions,
        ...root.components?.responses ?? {},
        ...root.components?.schemas ?? {},
      };

      return generateModelClassContent(
        root,
        className.pascalCase,
        classes[className]!,
        classes,
        options.defaultValuesMap,
        options.classesWithNullabeLists,
        allClasses,
      );
    }).join('\n');

    var results = generatedClasses;

    return results;
  }

  String generateModelClassString(
    SwaggerRoot root,
    String className,
    SwaggerSchema schema,
    Map<String, SwaggerSchema> schemas,
    List<DefaultValueMap> defaultValues,
    List<String> classesWithNullableLists,
    Map<String, SwaggerSchema> allClasses,
  ) {
    final properties = getModelProperties(schema, schemas, allClasses);
    final requiredProperties = getRequired(schema, schemas);

    final generatedConstructorProperties = generateConstructorPropertiesContent(
      className: className,
      entityMap: properties,
      defaultValues: defaultValues,
      requiredProperties: requiredProperties,
      isModelClass: true,
    );

    final validatedClassName =
        '${getValidatedClassName(className)}${options.modelPostfix}';
    final fromJson = generatedFromJson(schema, validatedClassName);

    final generatedClass = '''
@Freezed()
class $validatedClassName extends ${validatedClassName}Entity with _\$$validatedClassName{
\tfactory $validatedClassName($generatedConstructorProperties) = _$validatedClassName;\n
\t$fromJson\n
}

''';

    return generatedClass;
  }

  String generatedFromJson(SwaggerSchema schema, String validatedClassName) {
    return 'factory $validatedClassName.fromJson(Map<String, dynamic> json) => _\$${validatedClassName}FromJson(json);';
  }
}
