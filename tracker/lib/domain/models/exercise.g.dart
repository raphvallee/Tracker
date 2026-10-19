// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetExerciseCollection on Isar {
  IsarCollection<Exercise> get exercises => this.collection();
}

const ExerciseSchema = CollectionSchema(
  name: r'Exercise',
  id: 2972066467915231902,
  properties: {
    r'description': PropertySchema(
      id: 0,
      name: r'description',
      type: IsarType.string,
    ),
    r'equipment': PropertySchema(
      id: 1,
      name: r'equipment',
      type: IsarType.byteList,
      enumMap: _ExerciseequipmentEnumValueMap,
    ),
    r'movementPattern': PropertySchema(
      id: 2,
      name: r'movementPattern',
      type: IsarType.byte,
      enumMap: _ExercisemovementPatternEnumValueMap,
    ),
    r'primaryMuscle': PropertySchema(
      id: 3,
      name: r'primaryMuscle',
      type: IsarType.byteList,
      enumMap: _ExerciseprimaryMuscleEnumValueMap,
    ),
    r'secondaryMuscle': PropertySchema(
      id: 4,
      name: r'secondaryMuscle',
      type: IsarType.byteList,
      enumMap: _ExercisesecondaryMuscleEnumValueMap,
    ),
    r'title': PropertySchema(id: 5, name: r'title', type: IsarType.string),
  },

  estimateSize: _exerciseEstimateSize,
  serialize: _exerciseSerialize,
  deserialize: _exerciseDeserialize,
  deserializeProp: _exerciseDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _exerciseGetId,
  getLinks: _exerciseGetLinks,
  attach: _exerciseAttach,
  version: '3.4.1',
);

int _exerciseEstimateSize(
  Exercise object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.description;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.equipment.length;
  bytesCount += 3 + object.primaryMuscle.length;
  {
    final value = object.secondaryMuscle;
    if (value != null) {
      bytesCount += 3 + value.length;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _exerciseSerialize(
  Exercise object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.description);
  writer.writeByteList(
    offsets[1],
    object.equipment.map((e) => e.index).toList(),
  );
  writer.writeByte(offsets[2], object.movementPattern.index);
  writer.writeByteList(
    offsets[3],
    object.primaryMuscle.map((e) => e.index).toList(),
  );
  writer.writeByteList(
    offsets[4],
    object.secondaryMuscle?.map((e) => e.index).toList(),
  );
  writer.writeString(offsets[5], object.title);
}

Exercise _exerciseDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Exercise(
    description: reader.readStringOrNull(offsets[0]),
    equipment:
        reader
            .readByteList(offsets[1])
            ?.map(
              (e) => _ExerciseequipmentValueEnumMap[e] ?? Equipment.dumbbell,
            )
            .toList() ??
        [],
    movementPattern:
        _ExercisemovementPatternValueEnumMap[reader.readByteOrNull(
          offsets[2],
        )] ??
        MovementPattern.unspecified,
    primaryMuscle:
        reader
            .readByteList(offsets[3])
            ?.map(
              (e) => _ExerciseprimaryMuscleValueEnumMap[e] ?? Muscle.abdominals,
            )
            .toList() ??
        [],
    secondaryMuscle: reader
        .readByteList(offsets[4])
        ?.map(
          (e) => _ExercisesecondaryMuscleValueEnumMap[e] ?? Muscle.abdominals,
        )
        .toList(),
    title: reader.readString(offsets[5]),
  );
  object.id = id;
  return object;
}

P _exerciseDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader
                  .readByteList(offset)
                  ?.map(
                    (e) =>
                        _ExerciseequipmentValueEnumMap[e] ?? Equipment.dumbbell,
                  )
                  .toList() ??
              [])
          as P;
    case 2:
      return (_ExercisemovementPatternValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              MovementPattern.unspecified)
          as P;
    case 3:
      return (reader
                  .readByteList(offset)
                  ?.map(
                    (e) =>
                        _ExerciseprimaryMuscleValueEnumMap[e] ??
                        Muscle.abdominals,
                  )
                  .toList() ??
              [])
          as P;
    case 4:
      return (reader
              .readByteList(offset)
              ?.map(
                (e) =>
                    _ExercisesecondaryMuscleValueEnumMap[e] ??
                    Muscle.abdominals,
              )
              .toList())
          as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _ExerciseequipmentEnumValueMap = {
  'dumbbell': 0,
  'barbell': 1,
  'machine': 2,
  'bodyweight': 3,
  'cable': 4,
};
const _ExerciseequipmentValueEnumMap = {
  0: Equipment.dumbbell,
  1: Equipment.barbell,
  2: Equipment.machine,
  3: Equipment.bodyweight,
  4: Equipment.cable,
};
const _ExercisemovementPatternEnumValueMap = {
  'unspecified': 0,
  'push': 1,
  'pull': 2,
  'legs': 3,
  'core': 4,
  'fullBody': 5,
};
const _ExercisemovementPatternValueEnumMap = {
  0: MovementPattern.unspecified,
  1: MovementPattern.push,
  2: MovementPattern.pull,
  3: MovementPattern.legs,
  4: MovementPattern.core,
  5: MovementPattern.fullBody,
};
const _ExerciseprimaryMuscleEnumValueMap = {
  'abdominals': 0,
  'obliques': 1,
  'biceps': 2,
  'triceps': 3,
  'frontDelts': 4,
  'sideDelts': 5,
  'rearDelts': 6,
  'lowerBack': 7,
  'lats': 8,
  'traps': 9,
  'chest': 10,
  'glutes': 11,
  'gastroc': 12,
  'soleus': 13,
  'hamstrings': 14,
  'quadriceps': 15,
};
const _ExerciseprimaryMuscleValueEnumMap = {
  0: Muscle.abdominals,
  1: Muscle.obliques,
  2: Muscle.biceps,
  3: Muscle.triceps,
  4: Muscle.frontDelts,
  5: Muscle.sideDelts,
  6: Muscle.rearDelts,
  7: Muscle.lowerBack,
  8: Muscle.lats,
  9: Muscle.traps,
  10: Muscle.chest,
  11: Muscle.glutes,
  12: Muscle.gastroc,
  13: Muscle.soleus,
  14: Muscle.hamstrings,
  15: Muscle.quadriceps,
};
const _ExercisesecondaryMuscleEnumValueMap = {
  'abdominals': 0,
  'obliques': 1,
  'biceps': 2,
  'triceps': 3,
  'frontDelts': 4,
  'sideDelts': 5,
  'rearDelts': 6,
  'lowerBack': 7,
  'lats': 8,
  'traps': 9,
  'chest': 10,
  'glutes': 11,
  'gastroc': 12,
  'soleus': 13,
  'hamstrings': 14,
  'quadriceps': 15,
};
const _ExercisesecondaryMuscleValueEnumMap = {
  0: Muscle.abdominals,
  1: Muscle.obliques,
  2: Muscle.biceps,
  3: Muscle.triceps,
  4: Muscle.frontDelts,
  5: Muscle.sideDelts,
  6: Muscle.rearDelts,
  7: Muscle.lowerBack,
  8: Muscle.lats,
  9: Muscle.traps,
  10: Muscle.chest,
  11: Muscle.glutes,
  12: Muscle.gastroc,
  13: Muscle.soleus,
  14: Muscle.hamstrings,
  15: Muscle.quadriceps,
};

Id _exerciseGetId(Exercise object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _exerciseGetLinks(Exercise object) {
  return [];
}

void _exerciseAttach(IsarCollection<dynamic> col, Id id, Exercise object) {
  object.id = id;
}

extension ExerciseQueryWhereSort on QueryBuilder<Exercise, Exercise, QWhere> {
  QueryBuilder<Exercise, Exercise, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ExerciseQueryWhere on QueryBuilder<Exercise, Exercise, QWhereClause> {
  QueryBuilder<Exercise, Exercise, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ExerciseQueryFilter
    on QueryBuilder<Exercise, Exercise, QFilterCondition> {
  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'description'),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'description'),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> descriptionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  descriptionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> descriptionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> descriptionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'description',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> descriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> descriptionContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> descriptionMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'description',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  equipmentElementEqualTo(Equipment value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'equipment', value: value),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  equipmentElementGreaterThan(Equipment value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'equipment',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  equipmentElementLessThan(Equipment value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'equipment',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  equipmentElementBetween(
    Equipment lower,
    Equipment upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'equipment',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  equipmentLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'equipment', length, true, length, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> equipmentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'equipment', 0, true, 0, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  equipmentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'equipment', 0, false, 999999, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  equipmentLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'equipment', 0, true, length, include);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  equipmentLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'equipment', length, include, 999999, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  equipmentLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'equipment',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  movementPatternEqualTo(MovementPattern value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'movementPattern', value: value),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  movementPatternGreaterThan(MovementPattern value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'movementPattern',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  movementPatternLessThan(MovementPattern value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'movementPattern',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  movementPatternBetween(
    MovementPattern lower,
    MovementPattern upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'movementPattern',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  primaryMuscleElementEqualTo(Muscle value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'primaryMuscle', value: value),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  primaryMuscleElementGreaterThan(Muscle value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'primaryMuscle',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  primaryMuscleElementLessThan(Muscle value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'primaryMuscle',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  primaryMuscleElementBetween(
    Muscle lower,
    Muscle upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'primaryMuscle',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  primaryMuscleLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'primaryMuscle', length, true, length, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  primaryMuscleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'primaryMuscle', 0, true, 0, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  primaryMuscleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'primaryMuscle', 0, false, 999999, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  primaryMuscleLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'primaryMuscle', 0, true, length, include);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  primaryMuscleLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'primaryMuscle', length, include, 999999, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  primaryMuscleLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'primaryMuscle',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'secondaryMuscle'),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'secondaryMuscle'),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleElementEqualTo(Muscle value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'secondaryMuscle', value: value),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleElementGreaterThan(Muscle value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'secondaryMuscle',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleElementLessThan(Muscle value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'secondaryMuscle',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleElementBetween(
    Muscle lower,
    Muscle upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'secondaryMuscle',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'secondaryMuscle', length, true, length, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'secondaryMuscle', 0, true, 0, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'secondaryMuscle', 0, false, 999999, true);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'secondaryMuscle', 0, true, length, include);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'secondaryMuscle',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition>
  secondaryMuscleLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'secondaryMuscle',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> titleContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> titleMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }
}

extension ExerciseQueryObject
    on QueryBuilder<Exercise, Exercise, QFilterCondition> {}

extension ExerciseQueryLinks
    on QueryBuilder<Exercise, Exercise, QFilterCondition> {}

extension ExerciseQuerySortBy on QueryBuilder<Exercise, Exercise, QSortBy> {
  QueryBuilder<Exercise, Exercise, QAfterSortBy> sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> sortByMovementPattern() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'movementPattern', Sort.asc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> sortByMovementPatternDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'movementPattern', Sort.desc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension ExerciseQuerySortThenBy
    on QueryBuilder<Exercise, Exercise, QSortThenBy> {
  QueryBuilder<Exercise, Exercise, QAfterSortBy> thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> thenByMovementPattern() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'movementPattern', Sort.asc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> thenByMovementPatternDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'movementPattern', Sort.desc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<Exercise, Exercise, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension ExerciseQueryWhereDistinct
    on QueryBuilder<Exercise, Exercise, QDistinct> {
  QueryBuilder<Exercise, Exercise, QDistinct> distinctByDescription({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Exercise, Exercise, QDistinct> distinctByEquipment() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'equipment');
    });
  }

  QueryBuilder<Exercise, Exercise, QDistinct> distinctByMovementPattern() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'movementPattern');
    });
  }

  QueryBuilder<Exercise, Exercise, QDistinct> distinctByPrimaryMuscle() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'primaryMuscle');
    });
  }

  QueryBuilder<Exercise, Exercise, QDistinct> distinctBySecondaryMuscle() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'secondaryMuscle');
    });
  }

  QueryBuilder<Exercise, Exercise, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }
}

extension ExerciseQueryProperty
    on QueryBuilder<Exercise, Exercise, QQueryProperty> {
  QueryBuilder<Exercise, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Exercise, String?, QQueryOperations> descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<Exercise, List<Equipment>, QQueryOperations>
  equipmentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'equipment');
    });
  }

  QueryBuilder<Exercise, MovementPattern, QQueryOperations>
  movementPatternProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'movementPattern');
    });
  }

  QueryBuilder<Exercise, List<Muscle>, QQueryOperations>
  primaryMuscleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'primaryMuscle');
    });
  }

  QueryBuilder<Exercise, List<Muscle>?, QQueryOperations>
  secondaryMuscleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'secondaryMuscle');
    });
  }

  QueryBuilder<Exercise, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }
}
