import 'package:recase/recase.dart';
import 'package:swagger_dart_code_generator/src/code_generators/constants.dart';
import 'package:swagger_dart_code_generator/src/code_generators/swagger_generator_base.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/responses/swagger_schema.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/swagger_root.dart';

import 'constants.dart';

abstract class SwaggerEntitiesGenerator extends SwaggerGeneratorBase {
  final GeneratorOptions _options;

  @override
  GeneratorOptions get options => _options;

  SwaggerEntitiesGenerator(this._options);

  String generate(SwaggerRoot root, String fileName);

  String generateEntityClassContent(
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
    SwaggerRoot root,
    String fileName,
    Map<String, SwaggerSchema> classes,
  ) {
    final classesFromInnerClasses = getClassesFromInnerClasses(classes);

    classes.addAll(classesFromInnerClasses);

    if (classes.isEmpty) return '';

    final generatedClasses = classes.keys.map((String className) {
      final allClasses = {
        ...root.definitions,
        ...root.components?.schemas ?? {},
      };

      return generateEntityClassContent(
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
      isModelClass: false,
    );

    final generatedProperties = generatePropertiesContent(
      root,
      properties,
      schemas,
      className,
      defaultValues,
      classesWithNullableLists,
      requiredProperties,
      allClasses,
    );

    final validatedClassName =
        '${getValidatedClassName(className)}${options.modelPostfix}Entity';

    List keys = [];
    for (var elm in properties.keys) {
      (options.nullableModels.contains(className) ||
              !requiredProperties.contains(elm) ||
              schema.isNullable == true)
          ? keys.add(elm + '!')
          : keys.add(elm);
    }

    final generatedClass = '''
class $validatedClassName extends Equatable{
$generatedProperties\n
\tconst $validatedClassName($generatedConstructorProperties);

  @override
  List<Object> get props => $keys;
}
''';

    return generatedClass;
  }
}
