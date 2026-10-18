// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_split.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWorkoutSplitCollection on Isar {
  IsarCollection<WorkoutSplit> get workoutSplits => this.collection();
}

const WorkoutSplitSchema = CollectionSchema(
  name: r'WorkoutSplit',
  id: 656367487967778737,
  properties: {
    r'description': PropertySchema(
      id: 0,
      name: r'description',
      type: IsarType.string,
    ),
    r'order': PropertySchema(id: 1, name: r'order', type: IsarType.long),
    r'splitDays': PropertySchema(
      id: 2,
      name: r'splitDays',
      type: IsarType.objectList,

      target: r'WorkoutSplitDay',
    ),
    r'title': PropertySchema(id: 3, name: r'title', type: IsarType.string),
  },

  estimateSize: _workoutSplitEstimateSize,
  serialize: _workoutSplitSerialize,
  deserialize: _workoutSplitDeserialize,
  deserializeProp: _workoutSplitDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {
    r'WorkoutSplitDay': WorkoutSplitDaySchema,
    r'ExerciseItem': ExerciseItemSchema,
    r'PlannedSet': PlannedSetSchema,
  },

  getId: _workoutSplitGetId,
  getLinks: _workoutSplitGetLinks,
  attach: _workoutSplitAttach,
  version: '3.3.2',
);

int _workoutSplitEstimateSize(
  WorkoutSplit object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.description.length * 3;
  bytesCount += 3 + object.splitDays.length * 3;
  {
    final offsets = allOffsets[WorkoutSplitDay]!;
    for (var i = 0; i < object.splitDays.length; i++) {
      final value = object.splitDays[i];
      bytesCount += WorkoutSplitDaySchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _workoutSplitSerialize(
  WorkoutSplit object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.description);
  writer.writeLong(offsets[1], object.order);
  writer.writeObjectList<WorkoutSplitDay>(
    offsets[2],
    allOffsets,
    WorkoutSplitDaySchema.serialize,
    object.splitDays,
  );
  writer.writeString(offsets[3], object.title);
}

WorkoutSplit _workoutSplitDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WorkoutSplit(
    description: reader.readStringOrNull(offsets[0]) ?? "",
    order: reader.readLongOrNull(offsets[1]) ?? -1,
    splitDays:
        reader.readObjectList<WorkoutSplitDay>(
          offsets[2],
          WorkoutSplitDaySchema.deserialize,
          allOffsets,
          WorkoutSplitDay(),
        ) ??
        const [],
    title: reader.readStringOrNull(offsets[3]) ?? "Split",
  );
  object.id = id;
  return object;
}

P _workoutSplitDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset) ?? "") as P;
    case 1:
      return (reader.readLongOrNull(offset) ?? -1) as P;
    case 2:
      return (reader.readObjectList<WorkoutSplitDay>(
                offset,
                WorkoutSplitDaySchema.deserialize,
                allOffsets,
                WorkoutSplitDay(),
              ) ??
              const [])
          as P;
    case 3:
      return (reader.readStringOrNull(offset) ?? "Split") as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _workoutSplitGetId(WorkoutSplit object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _workoutSplitGetLinks(WorkoutSplit object) {
  return [];
}

void _workoutSplitAttach(
  IsarCollection<dynamic> col,
  Id id,
  WorkoutSplit object,
) {
  object.id = id;
}

extension WorkoutSplitQueryWhereSort
    on QueryBuilder<WorkoutSplit, WorkoutSplit, QWhere> {
  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WorkoutSplitQueryWhere
    on QueryBuilder<WorkoutSplit, WorkoutSplit, QWhereClause> {
  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterWhereClause> idBetween(
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

extension WorkoutSplitQueryFilter
    on QueryBuilder<WorkoutSplit, WorkoutSplit, QFilterCondition> {
  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  descriptionEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  descriptionGreaterThan(
    String value, {
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  descriptionLessThan(
    String value, {
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  descriptionBetween(
    String lower,
    String upper, {
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  descriptionStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  descriptionEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  descriptionContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  descriptionMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> idBetween(
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> orderEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'order', value: value),
      );
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> orderLessThan(
    int value, {
    bool include = false,
  }) {
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> orderBetween(
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  splitDaysLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'splitDays', length, true, length, true);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  splitDaysIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'splitDays', 0, true, 0, true);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  splitDaysIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'splitDays', 0, false, 999999, true);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  splitDaysLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'splitDays', 0, true, length, include);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  splitDaysLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'splitDays', length, include, 999999, true);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  splitDaysLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'splitDays',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> titleEqualTo(
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> titleLessThan(
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> titleBetween(
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> titleEndsWith(
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> titleContains(
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition> titleMatches(
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

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }
}

extension WorkoutSplitQueryObject
    on QueryBuilder<WorkoutSplit, WorkoutSplit, QFilterCondition> {
  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterFilterCondition>
  splitDaysElement(FilterQuery<WorkoutSplitDay> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'splitDays');
    });
  }
}

extension WorkoutSplitQueryLinks
    on QueryBuilder<WorkoutSplit, WorkoutSplit, QFilterCondition> {}

extension WorkoutSplitQuerySortBy
    on QueryBuilder<WorkoutSplit, WorkoutSplit, QSortBy> {
  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy>
  sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> sortByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> sortByOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension WorkoutSplitQuerySortThenBy
    on QueryBuilder<WorkoutSplit, WorkoutSplit, QSortThenBy> {
  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy>
  thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> thenByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> thenByOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.desc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension WorkoutSplitQueryWhereDistinct
    on QueryBuilder<WorkoutSplit, WorkoutSplit, QDistinct> {
  QueryBuilder<WorkoutSplit, WorkoutSplit, QDistinct> distinctByDescription({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QDistinct> distinctByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'order');
    });
  }

  QueryBuilder<WorkoutSplit, WorkoutSplit, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }
}

extension WorkoutSplitQueryProperty
    on QueryBuilder<WorkoutSplit, WorkoutSplit, QQueryProperty> {
  QueryBuilder<WorkoutSplit, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WorkoutSplit, String, QQueryOperations> descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<WorkoutSplit, int, QQueryOperations> orderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'order');
    });
  }

  QueryBuilder<WorkoutSplit, List<WorkoutSplitDay>, QQueryOperations>
  splitDaysProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'splitDays');
    });
  }

  QueryBuilder<WorkoutSplit, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const WorkoutSplitDaySchema = Schema(
  name: r'WorkoutSplitDay',
  id: 7356602560403760140,
  properties: {
    r'description': PropertySchema(
      id: 0,
      name: r'description',
      type: IsarType.string,
    ),
    r'exercises': PropertySchema(
      id: 1,
      name: r'exercises',
      type: IsarType.objectList,

      target: r'ExerciseItem',
    ),
    r'order': PropertySchema(id: 2, name: r'order', type: IsarType.long),
    r'title': PropertySchema(id: 3, name: r'title', type: IsarType.string),
  },

  estimateSize: _workoutSplitDayEstimateSize,
  serialize: _workoutSplitDaySerialize,
  deserialize: _workoutSplitDayDeserialize,
  deserializeProp: _workoutSplitDayDeserializeProp,
);

int _workoutSplitDayEstimateSize(
  WorkoutSplitDay object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.description.length * 3;
  bytesCount += 3 + object.exercises.length * 3;
  {
    final offsets = allOffsets[ExerciseItem]!;
    for (var i = 0; i < object.exercises.length; i++) {
      final value = object.exercises[i];
      bytesCount += ExerciseItemSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _workoutSplitDaySerialize(
  WorkoutSplitDay object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.description);
  writer.writeObjectList<ExerciseItem>(
    offsets[1],
    allOffsets,
    ExerciseItemSchema.serialize,
    object.exercises,
  );
  writer.writeLong(offsets[2], object.order);
  writer.writeString(offsets[3], object.title);
}

WorkoutSplitDay _workoutSplitDayDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WorkoutSplitDay(
    description: reader.readStringOrNull(offsets[0]) ?? "",
    exercises:
        reader.readObjectList<ExerciseItem>(
          offsets[1],
          ExerciseItemSchema.deserialize,
          allOffsets,
          ExerciseItem(),
        ) ??
        const [],
    order: reader.readLongOrNull(offsets[2]) ?? -1,
    title: reader.readStringOrNull(offsets[3]) ?? "Split Day",
  );
  return object;
}

P _workoutSplitDayDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset) ?? "") as P;
    case 1:
      return (reader.readObjectList<ExerciseItem>(
                offset,
                ExerciseItemSchema.deserialize,
                allOffsets,
                ExerciseItem(),
              ) ??
              const [])
          as P;
    case 2:
      return (reader.readLongOrNull(offset) ?? -1) as P;
    case 3:
      return (reader.readStringOrNull(offset) ?? "Split Day") as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension WorkoutSplitDayQueryFilter
    on QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QFilterCondition> {
  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  descriptionEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  descriptionGreaterThan(
    String value, {
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  descriptionLessThan(
    String value, {
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  descriptionBetween(
    String lower,
    String upper, {
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  descriptionStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  descriptionEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  descriptionContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  descriptionMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  exercisesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'exercises', length, true, length, true);
    });
  }

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  exercisesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'exercises', 0, true, 0, true);
    });
  }

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  exercisesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'exercises', 0, false, 999999, true);
    });
  }

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  exercisesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'exercises', 0, true, length, include);
    });
  }

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  exercisesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'exercises', length, include, 999999, true);
    });
  }

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  exercisesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'exercises',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  orderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'order', value: value),
      );
    });
  }

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
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

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }
}

extension WorkoutSplitDayQueryObject
    on QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QFilterCondition> {
  QueryBuilder<WorkoutSplitDay, WorkoutSplitDay, QAfterFilterCondition>
  exercisesElement(FilterQuery<ExerciseItem> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'exercises');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const ExerciseItemSchema = Schema(
  name: r'ExerciseItem',
  id: -5224450974621083626,
  properties: {
    r'exerciseId': PropertySchema(
      id: 0,
      name: r'exerciseId',
      type: IsarType.long,
    ),
    r'order': PropertySchema(id: 1, name: r'order', type: IsarType.long),
    r'restSeconds': PropertySchema(
      id: 2,
      name: r'restSeconds',
      type: IsarType.long,
    ),
    r'sets': PropertySchema(
      id: 3,
      name: r'sets',
      type: IsarType.objectList,

      target: r'PlannedSet',
    ),
    r'targetReps': PropertySchema(
      id: 4,
      name: r'targetReps',
      type: IsarType.long,
    ),
    r'targetSets': PropertySchema(
      id: 5,
      name: r'targetSets',
      type: IsarType.long,
    ),
  },

  estimateSize: _exerciseItemEstimateSize,
  serialize: _exerciseItemSerialize,
  deserialize: _exerciseItemDeserialize,
  deserializeProp: _exerciseItemDeserializeProp,
);

int _exerciseItemEstimateSize(
  ExerciseItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.sets.length * 3;
  {
    final offsets = allOffsets[PlannedSet]!;
    for (var i = 0; i < object.sets.length; i++) {
      final value = object.sets[i];
      bytesCount += PlannedSetSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  return bytesCount;
}

void _exerciseItemSerialize(
  ExerciseItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.exerciseId);
  writer.writeLong(offsets[1], object.order);
  writer.writeLong(offsets[2], object.restSeconds);
  writer.writeObjectList<PlannedSet>(
    offsets[3],
    allOffsets,
    PlannedSetSchema.serialize,
    object.sets,
  );
  writer.writeLong(offsets[4], object.targetReps);
  writer.writeLong(offsets[5], object.targetSets);
}

ExerciseItem _exerciseItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ExerciseItem(
    exerciseId: reader.readLongOrNull(offsets[0]) ?? 0,
    order: reader.readLongOrNull(offsets[1]) ?? 0,
    restSeconds: reader.readLongOrNull(offsets[2]),
    sets:
        reader.readObjectList<PlannedSet>(
          offsets[3],
          PlannedSetSchema.deserialize,
          allOffsets,
          PlannedSet(),
        ) ??
        const [],
    targetReps: reader.readLongOrNull(offsets[4]),
    targetSets: reader.readLongOrNull(offsets[5]),
  );
  return object;
}

P _exerciseItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 1:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readObjectList<PlannedSet>(
                offset,
                PlannedSetSchema.deserialize,
                allOffsets,
                PlannedSet(),
              ) ??
              const [])
          as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension ExerciseItemQueryFilter
    on QueryBuilder<ExerciseItem, ExerciseItem, QFilterCondition> {
  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  exerciseIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'exerciseId', value: value),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
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

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
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

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
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

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition> orderEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'order', value: value),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
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

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition> orderLessThan(
    int value, {
    bool include = false,
  }) {
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

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition> orderBetween(
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

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  restSecondsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'restSeconds'),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  restSecondsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'restSeconds'),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  restSecondsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'restSeconds', value: value),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  restSecondsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'restSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  restSecondsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'restSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  restSecondsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'restSeconds',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  setsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'sets', length, true, length, true);
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  setsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'sets', 0, true, 0, true);
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  setsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'sets', 0, false, 999999, true);
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  setsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'sets', 0, true, length, include);
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  setsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'sets', length, include, 999999, true);
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
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

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetRepsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'targetReps'),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetRepsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'targetReps'),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetRepsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'targetReps', value: value),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetRepsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'targetReps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetRepsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'targetReps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetRepsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'targetReps',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetSetsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'targetSets'),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetSetsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'targetSets'),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetSetsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'targetSets', value: value),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetSetsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'targetSets',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetSetsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'targetSets',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition>
  targetSetsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'targetSets',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ExerciseItemQueryObject
    on QueryBuilder<ExerciseItem, ExerciseItem, QFilterCondition> {
  QueryBuilder<ExerciseItem, ExerciseItem, QAfterFilterCondition> setsElement(
    FilterQuery<PlannedSet> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'sets');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const PlannedSetSchema = Schema(
  name: r'PlannedSet',
  id: 274001502372112171,
  properties: {
    r'maxReps': PropertySchema(id: 0, name: r'maxReps', type: IsarType.long),
    r'minReps': PropertySchema(id: 1, name: r'minReps', type: IsarType.long),
    r'order': PropertySchema(id: 2, name: r'order', type: IsarType.long),
  },

  estimateSize: _plannedSetEstimateSize,
  serialize: _plannedSetSerialize,
  deserialize: _plannedSetDeserialize,
  deserializeProp: _plannedSetDeserializeProp,
);

int _plannedSetEstimateSize(
  PlannedSet object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _plannedSetSerialize(
  PlannedSet object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.maxReps);
  writer.writeLong(offsets[1], object.minReps);
  writer.writeLong(offsets[2], object.order);
}

PlannedSet _plannedSetDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PlannedSet(
    maxReps: reader.readLongOrNull(offsets[0]),
    minReps: reader.readLongOrNull(offsets[1]) ?? 0,
    order: reader.readLongOrNull(offsets[2]) ?? 0,
  );
  return object;
}

P _plannedSetDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 2:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension PlannedSetQueryFilter
    on QueryBuilder<PlannedSet, PlannedSet, QFilterCondition> {
  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> maxRepsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'maxReps'),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition>
  maxRepsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'maxReps'),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> maxRepsEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'maxReps', value: value),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition>
  maxRepsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'maxReps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> maxRepsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'maxReps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> maxRepsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'maxReps',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> minRepsEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'minReps', value: value),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition>
  minRepsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'minReps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> minRepsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'minReps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> minRepsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'minReps',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> orderEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'order', value: value),
      );
    });
  }

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> orderGreaterThan(
    int value, {
    bool include = false,
  }) {
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

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> orderLessThan(
    int value, {
    bool include = false,
  }) {
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

  QueryBuilder<PlannedSet, PlannedSet, QAfterFilterCondition> orderBetween(
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
}

extension PlannedSetQueryObject
    on QueryBuilder<PlannedSet, PlannedSet, QFilterCondition> {}
