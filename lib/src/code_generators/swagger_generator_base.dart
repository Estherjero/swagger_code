import 'package:collection/collection.dart';
import 'package:recase/recase.dart';
import 'package:swagger_dart_code_generator/src/code_generators/constants.dart';
import 'package:swagger_dart_code_generator/src/exception_words.dart';
import 'package:swagger_dart_code_generator/src/extensions/string_extension.dart';
import 'package:swagger_dart_code_generator/src/models/generator_options.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/responses/swagger_schema.dart';
import 'package:swagger_dart_code_generator/src/swagger_models/swagger_root.dart';

abstract class SwaggerGeneratorBase {
  GeneratorOptions get options;

  String getValidatedClassName(
    String className,
  ) {
    if (kBasicTypes.contains(className)) return className;

    if (exceptionWords.contains(className)) return 'Object';

    if (className.isEmpty) return className;

    final words = className.split('\$');

    final result = words
        .map((e) => e.pascalCase
            .split(RegExp(r'\W+|\_'))
            .map((String str) => str.capitalize)
            .join())
        .join('\$')
        .replaceFirst(RegExp(options.cutFromModelNames), '');

    if (kKeyClasses.contains(result)) return '$result\$';

    if (result.startsWith(RegExp('[0-9]'))) return '\$$result';

    return result.replaceFirst(options.cutFromModelNames, '');
  }

  String generateFieldName(String jsonKey) {
    final forbiddenCharacters = <String>['#'];

    jsonKey = jsonKey.camelCase;

    for (var element in forbiddenCharacters) {
      if (jsonKey.startsWith(element)) {
        jsonKey = '\$forbiddenFieldName';
      }
    }

    if (jsonKey.startsWith(RegExp('[0-9]')) ||
        exceptionWords.contains(jsonKey)) {
      jsonKey = '\$' + jsonKey;
    }

    if (kBasicTypes.contains(jsonKey)) {
      jsonKey = '\$' + jsonKey;
    }

    return jsonKey;
  }

  Map<String, SwaggerSchema> getClassesFromInnerClasses(
    Map<String, SwaggerSchema> classes,
  ) {
    final result = <String, SwaggerSchema>{};

    classes.forEach((classKey, schema) {
      final properties = schema.properties;

      properties.forEach((propertyKey, propSchema) {
        final innerClassName =
            '${getValidatedClassName(classKey)}\$${getValidatedClassName(propertyKey)}';

        if (propSchema.properties.isNotEmpty) {
          result[innerClassName] = propSchema;
        }

        final items = propSchema.items;

        if (items != null && items.properties.isNotEmpty) {
          result[innerClassName] = propSchema;
        }
      });
    });

    if (result.isNotEmpty) {
      result.addAll(getClassesFromInnerClasses(result));
    }

    return result;
  }

  String generatePropertiesContent(
    SwaggerRoot root,
    Map<String, SwaggerSchema> propertiesMap,
    Map<String, SwaggerSchema> schemas,
    String className,
    List<DefaultValueMap> defaultValues,
    List<String> classesWithNullableLists,
    List<String> requiredProperties,
    Map<String, SwaggerSchema> allClasses,
  ) {
    if (propertiesMap.isEmpty) return '';

    final results = <String>[];
    final propertyNames = <String>[];

    for (var i = 0; i < propertiesMap.keys.length; i++) {
      var propertyName = propertiesMap.keys.elementAt(i);

      final prop = propertiesMap[propertyName]!;

      final propertyKey = propertyName;

      final basicTypesMap = generateBasicTypesMapFromSchemas(root);

      propertyName = propertyName.asParameterName();

      propertyName = getParameterName(propertyName, propertyNames);

      propertyNames.add(propertyName);

      if (prop.type.isNotEmpty) {
        results.add(generatePropertyContentByType(
          prop,
          propertyName,
          propertyKey,
          className,
          defaultValues,
          classesWithNullableLists,
          basicTypesMap,
          requiredProperties,
          allClasses,
          false,
        ));
      } else if (prop.allOf.isNotEmpty) {
        results.add(
          generatePropertyContentByAllOf(
            prop: prop,
            className: className,
            propertyKey: propertyKey,
            propertyName: propertyName,
            requiredProperties: requiredProperties,
            isModelClass: false,
          ),
        );
      } else if (prop.hasRef) {
        results.add(generatePropertyContentByRef(
          prop,
          propertyName,
          propertyKey,
          className,
          basicTypesMap,
          requiredProperties,
          allClasses,
          false,
        ));
      } else if (prop.schema != null) {
        results.add(generatePropertyContentBySchema(
          prop,
          propertyName,
          propertyKey,
          className,
          basicTypesMap,
          requiredProperties,
          false,
        ));
      } else {
        results.add(generatePropertyContentByDefault(
          prop,
          propertyName,
        ));
      }
    }

    return results.join('\n');
  }

  static Map<String, String> generateBasicTypesMapFromSchemas(
      SwaggerRoot root) {
    final result = <String, String>{};

    final components = root.components;

    final definitions = root.definitions;

    final schemas = components?.schemas ?? {};

    final allClasses = {
      ...definitions,
      ...schemas,
    };

    allClasses.forEach((key, value) {
      if (kBasicTypes.contains(value.type.toLowerCase()) && !value.isEnum) {
        result.addAll({key: _mapBasicTypeToDartType(value.type, value.format)});
      }

      if (value.type == kArray && value.items != null) {
        final ref = value.items!.ref;

        if (result[ref.getUnformattedRef()] != null) {
          result[key] = result[ref.getUnformattedRef()]!.asList();
        } else if (ref.isNotEmpty) {
          result[key] = ref.getRef().asList();
        }
      }
    });

    return result;
  }

  static String _mapBasicTypeToDartType(String basicType, String format) {
    if (basicType.toLowerCase() == kString &&
        (format == 'date-time' || format == 'datetime')) {
      return 'DateTime';
    }
    switch (basicType.toLowerCase()) {
      case 'string':
        return 'String';
      case 'int':
      case 'integer':
        return 'int';
      case 'double':
      case 'number':
      case 'float':
        return 'double';
      case 'bool':
      case 'boolean':
        return 'bool';
      default:
        return '';
    }
  }

  static String getValidatedParameterName(String parameterName) {
    if (parameterName.isEmpty) return parameterName;

    final words = parameterName.split('\$');

    final result = words
        .map((e) => e
            .split(RegExp(r'\W+|\_'))
            .mapIndexed(
                (int index, String str) => index == 0 ? str : str.capitalize)
            .join())
        .join('\$');

    if (exceptionWords.contains(result.camelCase) ||
        kBasicTypes.contains(result.camelCase)) return '\$$result';

    if (result.isEmpty) return kUndefinedParameter;

    return result.camelCase;
  }

  String generateDefaultValueFromMap(DefaultValueMap map) {
    switch (map.typeName) {
      case 'int':
      case 'double':
      case 'bool':
        return map.defaultValue;
      default:
        return "'${map.defaultValue}'";
    }
  }

  String generateIncludeIfNullString() {
    if (options.includeIfNull == null) return '';

    return ', includeIfNull: ${options.includeIfNull}';
  }

  String generatePropertyContentByDefault(
    SwaggerSchema prop,
    String propertyName,
  ) {
    var typeName = '';

    if (prop.hasOriginalRef) {
      typeName = getValidatedClassName(prop.originalRef);
    }

    if (typeName.isEmpty) {
      typeName = kDynamic;
    }

    if (typeName != kDynamic) {
      typeName += '?';
    }

    return '\tfinal $typeName ${generateFieldName(propertyName)};';
  }

  String generatePropertyContentByAllOf({
    required SwaggerSchema prop,
    required String propertyKey,
    required String className,
    required String propertyName,
    required List<String> requiredProperties,
    required bool isModelClass,
  }) {
    final allOf = prop.allOf;
    String typeName;

    if (allOf.length != 1) {
      typeName = kDynamic;
    } else {
      var className = allOf.first.ref.getRef();
      typeName =
          getValidatedClassName(className) + (isModelClass ? '' : 'Entity');
    }

    typeName =
        nullable(typeName, className, requiredProperties, propertyKey, prop);

    return '\tfinal $typeName $propertyName;';
  }

  String generateConstructorPropertiesContent({
    required String className,
    required Map<String, SwaggerSchema> entityMap,
    required List<DefaultValueMap> defaultValues,
    required List<String> requiredProperties,
    required bool isModelClass,
  }) {
    if (entityMap.isEmpty) return '';

    var results = '';
    final propertyNames = <String>[];

    entityMap.forEach((key, value) {
      var fieldName = getParameterName(key.asParameterName(), propertyNames);
      var typeName = getParameterTypeName(className, fieldName,
          entityMap[fieldName]!, options.modelPostfix, null);

      propertyNames.add(fieldName);

      if (options.nullableModels.contains(className) ||
          !requiredProperties.contains(key)) {
        results += isModelClass
            ? '\t\t$typeName? $fieldName,\n'
            : '\t\tthis.$fieldName,\n';
      } else {
        results += isModelClass
            ? '\t\t$kRequired $typeName $fieldName,\n'
            : '\t\t$kRequired this.$fieldName,\n';
      }
    });

    return '{\n$results\n\t}';
  }

  String generatePropertyContentByType(
    SwaggerSchema prop,
    String propertyName,
    String propertyKey,
    String className,
    List<DefaultValueMap> defaultValues,
    List<String> classesWithNullableLists,
    Map<String, String> basicTypesMap,
    List<String> requiredProperties,
    Map<String, SwaggerSchema> allClasses,
    bool isModelClass,
  ) {
    switch (prop.type) {
      case 'array':
        return generateListPropertyContent(
          propertyName,
          propertyKey,
          className,
          prop,
          classesWithNullableLists,
          basicTypesMap,
          requiredProperties,
          allClasses,
          isModelClass,
        );
      default:
        return generateGeneralPropertyContent(
          propertyName,
          propertyKey,
          className,
          defaultValues,
          prop,
          requiredProperties,
        );
    }
  }

  String generatePropertyContentByRef(
    SwaggerSchema prop,
    String propertyName,
    String propertyKey,
    String className,
    Map<String, String> basicTypesMap,
    List<String> requiredProperties,
    Map<String, SwaggerSchema> allClasses,
    bool isModelClass,
  ) {
    final parameterName = prop.ref.split('/').last;

    String typeName;
    final refSchema = allClasses[parameterName];
    if (kBasicSwaggerTypes.contains(refSchema?.type) &&
        allClasses[parameterName]?.isEnum != true) {
      if (refSchema?.format == 'datetime') {
        typeName = 'DateTime';
      } else {
        typeName = kBasicTypesMap[refSchema?.type]!;
      }
    } else if (basicTypesMap.containsKey(parameterName)) {
      typeName = basicTypesMap[parameterName]!;
    } else {
      typeName = getValidatedClassName(getParameterTypeName(
          className, propertyName, prop, options.modelPostfix, parameterName));

      typeName =
          getValidatedClassName(typeName) + (isModelClass ? '' : 'Entity');
    }
    typeName += options.modelPostfix;

    typeName =
        nullable(typeName, className, requiredProperties, propertyKey, prop);

    return '\tfinal $typeName $propertyName;';
  }

  String generatePropertyContentBySchema(
    SwaggerSchema prop,
    String propertyName,
    String propertyKey,
    String className,
    Map<String, String> basicTypesMap,
    List<String> requiredProperties,
    bool isModelClass,
  ) {
    final propertySchema = prop.schema!;
    var parameterName = propertySchema.ref.split('/').last;

    String typeName;
    if (basicTypesMap.containsKey(parameterName)) {
      typeName = basicTypesMap[parameterName]!;
    } else {
      typeName = getValidatedClassName(getParameterTypeName(
            className,
            propertyName,
            prop,
            options.modelPostfix,
            parameterName,
          )) +
          (isModelClass ? '' : 'Entity');
    }
    typeName += options.modelPostfix;

    typeName =
        nullable(typeName, className, requiredProperties, propertyKey, prop);

    return '\tfinal $typeName ${generateFieldName(propertyName)};';
  }

  String nullable(
    String typeName,
    String className,
    Iterable<String> requiredProperties,
    String propertyKey,
    SwaggerSchema prop,
  ) {
    if (options.nullableModels.contains(className) ||
        !requiredProperties.contains(propertyKey) ||
        prop.isNullable == true) {
      return typeName.makeNullable();
    }
    return typeName;
  }

  String generateListPropertyContent(
    String propertyName,
    String propertyKey,
    String className,
    SwaggerSchema prop,
    List<String> classesWithNullableLists,
    Map<String, String> basicTypesMap,
    List<String> requiredParameters,
    Map<String, SwaggerSchema> allClasses,
    bool isModelClass,
  ) {
    final typeName = generateListPropertyTypeName(
      basicTypesMap: basicTypesMap,
      className: className,
      allClasses: allClasses,
      prop: prop,
      propertyName: propertyName,
      isModelClass: isModelClass,
    );

    var listPropertyName = 'List<$typeName>';

    listPropertyName = nullable(
        listPropertyName, className, requiredParameters, propertyKey, prop);

    return 'final $listPropertyName ${generateFieldName(propertyName)};';
  }

  String generateGeneralPropertyContent(
    String propertyName,
    String propertyKey,
    String className,
    List<DefaultValueMap> defaultValues,
    SwaggerSchema prop,
    List<String> requiredProperties,
  ) {
    var typeName = '';

    if (prop.hasAdditionalProperties && prop.type == 'object') {
      typeName = kMapStringDynamic;
    } else if (prop.hasRef) {
      typeName = prop.ref.split('/').last.pascalCase + options.modelPostfix;
    } else {
      typeName = getParameterTypeName(
          className, propertyKey, prop, options.modelPostfix, null);
    }

    typeName =
        nullable(typeName, className, requiredProperties, propertyKey, prop);

    return '  final $typeName $propertyName;';
  }

  String generateListPropertyTypeName({
    required SwaggerSchema prop,
    required Map<String, String> basicTypesMap,
    required String propertyName,
    required String className,
    required Map<String, SwaggerSchema> allClasses,
    required bool isModelClass,
  }) {
    if (className.endsWith('\$Item')) return kObject.pascalCase;

    final items = prop.items;

    var typeName = '';
    if (items != null) {
      typeName = getValidatedClassName(items.originalRef);

      if (typeName.isNotEmpty &&
          !kBasicTypes.contains(typeName.toLowerCase())) {
        typeName += options.modelPostfix;
      }

      if (typeName.isEmpty) {
        if (items.hasRef) {
          typeName = items.ref.split('/').last;
        }

        if (basicTypesMap.containsKey(typeName)) {
          typeName = basicTypesMap[typeName]!;
        } else if (typeName.isNotEmpty && typeName != kDynamic) {
          typeName = typeName.pascalCase;
        }
      }

      if (typeName.isNotEmpty) {
        typeName =
            getValidatedClassName(typeName) + (isModelClass ? '' : 'Entity');
      }

      if (typeName.isEmpty) {
        if (items.type == 'array' || items.items != null) {
          return generateListPropertyTypeName(
            basicTypesMap: basicTypesMap,
            className: className,
            allClasses: allClasses,
            prop: items,
            propertyName: propertyName,
            isModelClass: isModelClass,
          ).asList();
        }
      }
    }

    if (typeName.isEmpty) {
      typeName = getParameterTypeName(
        className,
        propertyName,
        items,
        options.modelPostfix,
        null,
      );
    }

    return typeName;
  }

  String getParameterName(String name, List<String> names) {
    if (names.contains(name)) {
      final newName = '\$$name';
      return getParameterName(newName, names);
    }

    return name;
  }

  String getParameterTypeName(
    String className,
    String parameterName,
    SwaggerSchema? parameter,
    String modelPostfix,
    String? refNameParameter,
  ) {
    if (refNameParameter != null) return refNameParameter.pascalCase;

    if (parameter == null) return 'Object';

    if (parameter.properties.isNotEmpty) {
      return '${getValidatedClassName(className)}\$${getValidatedClassName(parameterName)}$modelPostfix';
    }

    if (parameter.hasRef) return parameter.ref.split('/').last.pascalCase;

    switch (parameter.type) {
      case 'integer':
      case 'int':
        if (parameter.format == kInt64) return kNum;
        return 'int';
      case 'int32':
      case 'int64':
        return 'int';
      case 'boolean':
        return 'bool';
      case 'string':
        if (parameter.format == 'date-time' || parameter.format == 'date') {
          return 'DateTime';
        }
        return 'String';
      case 'Date':
        return 'DateTime';
      case 'number':
        return 'double';
      case 'object':
        return 'Object';
      case 'array':
        final items = parameter.items;
        final typeName = getParameterTypeName(
            className, parameterName, items, modelPostfix, null);
        return 'List<$typeName>';
      default:
        return 'Object';
    }
  }

  List<String> getRequired(
      SwaggerSchema schema, Map<String, SwaggerSchema> schemas,
      [int recursionCount = 5]) {
    final required = <String>{};
    if (recursionCount == 0) return required.toList();

    for (var interface in _getInterfaces(schema)) {
      if (interface.hasRef) {
        final parentName = interface.ref.split('/').last.pascalCase;
        final parentSchema = schemas[parentName];

        required.addAll(parentSchema != null
            ? getRequired(parentSchema, schemas, recursionCount - 1)
            : []);
      }
      required.addAll(interface.required);
    }
    required.addAll(schema.required);
    return required.toList();
  }

  List<SwaggerSchema> _getInterfaces(SwaggerSchema schema) {
    if (schema.allOf.isNotEmpty) {
      return schema.allOf;
    } else if (schema.anyOf.isNotEmpty) {
      return schema.anyOf;
    } else if (schema.oneOf.isNotEmpty) {
      return schema.oneOf;
    }
    return [];
  }

  Map<String, SwaggerSchema> getModelProperties(
    SwaggerSchema schema,
    Map<String, SwaggerSchema> schemas,
    Map<String, SwaggerSchema> allClasses,
  ) {
    if (schema.allOf.isEmpty) return schema.properties;

    final allOf = schema.allOf;

    final newModelMap = allOf.firstWhereOrNull((m) => m.properties.isNotEmpty);

    final currentProperties = newModelMap?.properties ?? {};

    final refs = allOf.where((element) => element.ref.isNotEmpty).toList();
    for (var allOf in refs) {
      final allOfSchema = allClasses[allOf.ref.getUnformattedRef()];

      currentProperties.addAll(allOfSchema?.properties ?? {});
    }

    if (currentProperties.isEmpty) return {};

    final allOfRef = allOf.firstWhereOrNull((m) => m.hasRef);

    if (allOfRef != null) {
      final refString = allOfRef.ref;
      final schema = schemas[refString.getUnformattedRef()];

      if (schema != null) {
        final moreProperties = schema.properties;

        currentProperties.addAll(moreProperties);
      }
    }

    return currentProperties;
  }
}
