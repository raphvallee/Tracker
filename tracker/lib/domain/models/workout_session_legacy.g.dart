// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_session_legacy.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetWorkoutSessionLegacyCollection on Isar {
  IsarCollection<WorkoutSessionLegacy> get workoutSessionLegacys =>
      this.collection();
}

const WorkoutSessionLegacySchema = CollectionSchema(
  name: r'WorkoutSession',
  id: 3465719098422617094,
  properties: {
    r'endTime': PropertySchema(
      id: 0,
      name: r'endTime',
      type: IsarType.dateTime,
    ),
    r'gymId': PropertySchema(id: 1, name: r'gymId', type: IsarType.long),
    r'sets': PropertySchema(
      id: 2,
      name: r'sets',
      type: IsarType.objectList,

      target: r'WorkoutSet',
    ),
    r'startTime': PropertySchema(
      id: 3,
      name: r'startTime',
      type: IsarType.dateTime,
    ),
    r'title': PropertySchema(id: 4, name: r'title', type: IsarType.string),
  },

  estimateSize: _workoutSessionLegacyEstimateSize,
  serialize: _workoutSessionLegacySerialize,
  deserialize: _workoutSessionLegacyDeserialize,
  deserializeProp: _workoutSessionLegacyDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {r'WorkoutSet': LegacyWorkoutSetSchema},

  getId: _workoutSessionLegacyGetId,
  getLinks: _workoutSessionLegacyGetLinks,
  attach: _workoutSessionLegacyAttach,
  version: '3.4.1',
);

int _workoutSessionLegacyEstimateSize(
  WorkoutSessionLegacy object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.sets.length * 3;
  {
    final offsets = allOffsets[LegacyWorkoutSet]!;
    for (var i = 0; i < object.sets.length; i++) {
      final value = object.sets[i];
      bytesCount += LegacyWorkoutSetSchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _workoutSessionLegacySerialize(
  WorkoutSessionLegacy object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.endTime);
  writer.writeLong(offsets[1], object.gymId);
  writer.writeObjectList<LegacyWorkoutSet>(
    offsets[2],
    allOffsets,
    LegacyWorkoutSetSchema.serialize,
    object.sets,
  );
  writer.writeDateTime(offsets[3], object.startTime);
  writer.writeString(offsets[4], object.title);
}

WorkoutSessionLegacy _workoutSessionLegacyDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WorkoutSessionLegacy(
    endTime: reader.readDateTimeOrNull(offsets[0]),
    gymId: reader.readLongOrNull(offsets[1]),
    sets:
        reader.readObjectList<LegacyWorkoutSet>(
          offsets[2],
          LegacyWorkoutSetSchema.deserialize,
          allOffsets,
          LegacyWorkoutSet(),
        ) ??
        const [],
    startTime: reader.readDateTime(offsets[3]),
    title: reader.readStringOrNull(offsets[4]) ?? 'Workout',
  );
  object.id = id;
  return object;
}

P _workoutSessionLegacyDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readObjectList<LegacyWorkoutSet>(
                offset,
                LegacyWorkoutSetSchema.deserialize,
                allOffsets,
                LegacyWorkoutSet(),
              ) ??
              const [])
          as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset) ?? 'Workout') as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _workoutSessionLegacyGetId(WorkoutSessionLegacy object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _workoutSessionLegacyGetLinks(
  WorkoutSessionLegacy object,
) {
  return [];
}

void _workoutSessionLegacyAttach(
  IsarCollection<dynamic> col,
  Id id,
  WorkoutSessionLegacy object,
) {
  object.id = id;
}

extension WorkoutSessionLegacyQueryWhereSort
    on QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QWhere> {
  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WorkoutSessionLegacyQueryWhere
    on QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QWhereClause> {
  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterWhereClause>
  idNotEqualTo(Id id) {
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

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterWhereClause>
  idBetween(
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

extension WorkoutSessionLegacyQueryFilter
    on
        QueryBuilder<
          WorkoutSessionLegacy,
          WorkoutSessionLegacy,
          QFilterCondition
        > {
  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  endTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'endTime'),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  endTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'endTime'),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  endTimeEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'endTime', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  endTimeGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'endTime',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  endTimeLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'endTime',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  endTimeBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'endTime',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  gymIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'gymId'),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  gymIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'gymId'),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  gymIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'gymId', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  gymIdGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'gymId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  gymIdLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'gymId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  gymIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'gymId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  idBetween(
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  setsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'sets', length, true, length, true);
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  setsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'sets', 0, true, 0, true);
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  setsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'sets', 0, false, 999999, true);
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  setsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'sets', 0, true, length, include);
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  setsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'sets', length, include, 999999, true);
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  setsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sets',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  startTimeEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'startTime', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  startTimeGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'startTime',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  startTimeLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'startTime',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  startTimeBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'startTime',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  titleEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  titleGreaterThan(
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  titleLessThan(
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  titleBetween(
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  titleStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  titleEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  titleContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  titleMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }
}

extension WorkoutSessionLegacyQueryObject
    on
        QueryBuilder<
          WorkoutSessionLegacy,
          WorkoutSessionLegacy,
          QFilterCondition
        > {
  QueryBuilder<
    WorkoutSessionLegacy,
    WorkoutSessionLegacy,
    QAfterFilterCondition
  >
  setsElement(FilterQuery<LegacyWorkoutSet> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'sets');
    });
  }
}

extension WorkoutSessionLegacyQueryLinks
    on
        QueryBuilder<
          WorkoutSessionLegacy,
          WorkoutSessionLegacy,
          QFilterCondition
        > {}

extension WorkoutSessionLegacyQuerySortBy
    on QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QSortBy> {
  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  sortByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  sortByEndTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  sortByGymId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gymId', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  sortByGymIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gymId', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  sortByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  sortByStartTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension WorkoutSessionLegacyQuerySortThenBy
    on QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QSortThenBy> {
  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  thenByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  thenByEndTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  thenByGymId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gymId', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  thenByGymIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gymId', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  thenByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  thenByStartTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QAfterSortBy>
  thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension WorkoutSessionLegacyQueryWhereDistinct
    on QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QDistinct> {
  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QDistinct>
  distinctByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endTime');
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QDistinct>
  distinctByGymId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'gymId');
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QDistinct>
  distinctByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startTime');
    });
  }

  QueryBuilder<WorkoutSessionLegacy, WorkoutSessionLegacy, QDistinct>
  distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }
}

extension WorkoutSessionLegacyQueryProperty
    on
        QueryBuilder<
          WorkoutSessionLegacy,
          WorkoutSessionLegacy,
          QQueryProperty
        > {
  QueryBuilder<WorkoutSessionLegacy, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WorkoutSessionLegacy, DateTime?, QQueryOperations>
  endTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endTime');
    });
  }

  QueryBuilder<WorkoutSessionLegacy, int?, QQueryOperations> gymIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'gymId');
    });
  }

  QueryBuilder<WorkoutSessionLegacy, List<LegacyWorkoutSet>, QQueryOperations>
  setsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sets');
    });
  }

  QueryBuilder<WorkoutSessionLegacy, DateTime, QQueryOperations>
  startTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startTime');
    });
  }

  QueryBuilder<WorkoutSessionLegacy, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

const LegacyWorkoutSetSchema = Schema(
  name: r'WorkoutSet',
  id: -5974587475565306185,
  properties: {
    r'exerciseId': PropertySchema(
      id: 0,
      name: r'exerciseId',
      type: IsarType.long,
    ),
    r'isWarmup': PropertySchema(id: 1, name: r'isWarmup', type: IsarType.bool),
    r'order': PropertySchema(id: 2, name: r'order', type: IsarType.long),
    r'reps': PropertySchema(id: 3, name: r'reps', type: IsarType.long),
    r'type': PropertySchema(
      id: 4,
      name: r'type',
      type: IsarType.byte,
      enumMap: _LegacyWorkoutSettypeEnumValueMap,
    ),
    r'weight': PropertySchema(id: 5, name: r'weight', type: IsarType.double),
  },

  estimateSize: _legacyWorkoutSetEstimateSize,
  serialize: _legacyWorkoutSetSerialize,
  deserialize: _legacyWorkoutSetDeserialize,
  deserializeProp: _legacyWorkoutSetDeserializeProp,
);

int _legacyWorkoutSetEstimateSize(
  LegacyWorkoutSet object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _legacyWorkoutSetSerialize(
  LegacyWorkoutSet object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.exerciseId);
  writer.writeBool(offsets[1], object.isWarmup);
  writer.writeLong(offsets[2], object.order);
  writer.writeLong(offsets[3], object.reps);
  writer.writeByte(offsets[4], object.type.index);
  writer.writeDouble(offsets[5], object.weight);
}

LegacyWorkoutSet _legacyWorkoutSetDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LegacyWorkoutSet(
    exerciseId: reader.readLongOrNull(offsets[0]) ?? 0,
    order: reader.readLongOrNull(offsets[2]) ?? 0,
    reps: reader.readLongOrNull(offsets[3]) ?? 0,
    type:
        _LegacyWorkoutSettypeValueEnumMap[reader.readByteOrNull(offsets[4])] ??
        SetType.working,
    weight: reader.readDoubleOrNull(offsets[5]) ?? 0,
  );
  return object;
}

P _legacyWorkoutSetDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 3:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 4:
      return (_LegacyWorkoutSettypeValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              SetType.working)
          as P;
    case 5:
      return (reader.readDoubleOrNull(offset) ?? 0) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _LegacyWorkoutSettypeEnumValueMap = {'warmup': 0, 'working': 1};
const _LegacyWorkoutSettypeValueEnumMap = {
  0: SetType.warmup,
  1: SetType.working,
};

extension LegacyWorkoutSetQueryFilter
    on QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QFilterCondition> {
  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  exerciseIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'exerciseId', value: value),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  exerciseIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'exerciseId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  exerciseIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'exerciseId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  exerciseIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'exerciseId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  isWarmupEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isWarmup', value: value),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  orderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'order', value: value),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  orderGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'order',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  orderLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'order',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  orderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'order',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  repsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reps', value: value),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  repsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'reps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  repsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'reps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  repsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'reps',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  typeEqualTo(SetType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: value),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  typeGreaterThan(SetType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'type',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  typeLessThan(SetType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'type',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  typeBetween(
    SetType lower,
    SetType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  weightEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'weight',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  weightGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'weight',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  weightLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'weight',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QAfterFilterCondition>
  weightBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'weight',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }
}

extension LegacyWorkoutSetQueryObject
    on QueryBuilder<LegacyWorkoutSet, LegacyWorkoutSet, QFilterCondition> {}
