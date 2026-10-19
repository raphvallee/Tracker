// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gym.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetGymCollection on Isar {
  IsarCollection<Gym> get gyms => this.collection();
}

const GymSchema = CollectionSchema(
  name: r'Gym',
  id: -8096571330272364008,
  properties: {
    r'description': PropertySchema(
      id: 0,
      name: r'description',
      type: IsarType.string,
    ),
    r'isPrimary': PropertySchema(
      id: 1,
      name: r'isPrimary',
      type: IsarType.bool,
    ),
    r'multiplier': PropertySchema(
      id: 2,
      name: r'multiplier',
      type: IsarType.double,
    ),
    r'name': PropertySchema(id: 3, name: r'name', type: IsarType.string),
    r'order': PropertySchema(id: 4, name: r'order', type: IsarType.long),
    r'perExerciseMultipliers': PropertySchema(
      id: 5,
      name: r'perExerciseMultipliers',
      type: IsarType.objectList,

      target: r'GymExerciseMultiplier',
    ),
  },

  estimateSize: _gymEstimateSize,
  serialize: _gymSerialize,
  deserialize: _gymDeserialize,
  deserializeProp: _gymDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {r'GymExerciseMultiplier': GymExerciseMultiplierSchema},

  getId: _gymGetId,
  getLinks: _gymGetLinks,
  attach: _gymAttach,
  version: '3.4.1',
);

int _gymEstimateSize(
  Gym object,
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
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.perExerciseMultipliers.length * 3;
  {
    final offsets = allOffsets[GymExerciseMultiplier]!;
    for (var i = 0; i < object.perExerciseMultipliers.length; i++) {
      final value = object.perExerciseMultipliers[i];
      bytesCount += GymExerciseMultiplierSchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  return bytesCount;
}

void _gymSerialize(
  Gym object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.description);
  writer.writeBool(offsets[1], object.isPrimary);
  writer.writeDouble(offsets[2], object.multiplier);
  writer.writeString(offsets[3], object.name);
  writer.writeLong(offsets[4], object.order);
  writer.writeObjectList<GymExerciseMultiplier>(
    offsets[5],
    allOffsets,
    GymExerciseMultiplierSchema.serialize,
    object.perExerciseMultipliers,
  );
}

Gym _gymDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Gym(
    description: reader.readStringOrNull(offsets[0]),
    isPrimary: reader.readBoolOrNull(offsets[1]) ?? false,
    multiplier: reader.readDoubleOrNull(offsets[2]) ?? 1.0,
    name: reader.readString(offsets[3]),
    order: reader.readLongOrNull(offsets[4]) ?? -1,
    perExerciseMultipliers:
        reader.readObjectList<GymExerciseMultiplier>(
          offsets[5],
          GymExerciseMultiplierSchema.deserialize,
          allOffsets,
          GymExerciseMultiplier(),
        ) ??
        const [],
  );
  object.id = id;
  return object;
}

P _gymDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 2:
      return (reader.readDoubleOrNull(offset) ?? 1.0) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset) ?? -1) as P;
    case 5:
      return (reader.readObjectList<GymExerciseMultiplier>(
                offset,
                GymExerciseMultiplierSchema.deserialize,
                allOffsets,
                GymExerciseMultiplier(),
              ) ??
              const [])
          as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _gymGetId(Gym object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _gymGetLinks(Gym object) {
  return [];
}

void _gymAttach(IsarCollection<dynamic> col, Id id, Gym object) {
  object.id = id;
}

extension GymQueryWhereSort on QueryBuilder<Gym, Gym, QWhere> {
  QueryBuilder<Gym, Gym, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension GymQueryWhere on QueryBuilder<Gym, Gym, QWhereClause> {
  QueryBuilder<Gym, Gym, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<Gym, Gym, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Gym, Gym, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterWhereClause> idBetween(
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

extension GymQueryFilter on QueryBuilder<Gym, Gym, QFilterCondition> {
  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'description'),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'description'),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionEqualTo(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionGreaterThan(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionLessThan(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionBetween(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionStartsWith(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionEndsWith(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionContains(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionMatches(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> isPrimaryEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isPrimary', value: value),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> multiplierEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'multiplier',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> multiplierGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'multiplier',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> multiplierLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'multiplier',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> multiplierBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'multiplier',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> orderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'order', value: value),
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition> orderGreaterThan(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> orderLessThan(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition> orderBetween(
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

  QueryBuilder<Gym, Gym, QAfterFilterCondition>
  perExerciseMultipliersLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'perExerciseMultipliers',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition>
  perExerciseMultipliersIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'perExerciseMultipliers', 0, true, 0, true);
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition>
  perExerciseMultipliersIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'perExerciseMultipliers',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition>
  perExerciseMultipliersLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'perExerciseMultipliers',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition>
  perExerciseMultipliersLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'perExerciseMultipliers',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Gym, Gym, QAfterFilterCondition>
  perExerciseMultipliersLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'perExerciseMultipliers',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension GymQueryObject on QueryBuilder<Gym, Gym, QFilterCondition> {
  QueryBuilder<Gym, Gym, QAfterFilterCondition> perExerciseMultipliersElement(
    FilterQuery<GymExerciseMultiplier> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'perExerciseMultipliers');
    });
  }
}

extension GymQueryLinks on QueryBuilder<Gym, Gym, QFilterCondition> {}

extension GymQuerySortBy on QueryBuilder<Gym, Gym, QSortBy> {
  QueryBuilder<Gym, Gym, QAfterSortBy> sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> sortByIsPrimary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPrimary', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> sortByIsPrimaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPrimary', Sort.desc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> sortByMultiplier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'multiplier', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> sortByMultiplierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'multiplier', Sort.desc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> sortByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> sortByOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.desc);
    });
  }
}

extension GymQuerySortThenBy on QueryBuilder<Gym, Gym, QSortThenBy> {
  QueryBuilder<Gym, Gym, QAfterSortBy> thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenByIsPrimary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPrimary', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenByIsPrimaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPrimary', Sort.desc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenByMultiplier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'multiplier', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenByMultiplierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'multiplier', Sort.desc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.asc);
    });
  }

  QueryBuilder<Gym, Gym, QAfterSortBy> thenByOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.desc);
    });
  }
}

extension GymQueryWhereDistinct on QueryBuilder<Gym, Gym, QDistinct> {
  QueryBuilder<Gym, Gym, QDistinct> distinctByDescription({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Gym, Gym, QDistinct> distinctByIsPrimary() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPrimary');
    });
  }

  QueryBuilder<Gym, Gym, QDistinct> distinctByMultiplier() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'multiplier');
    });
  }

  QueryBuilder<Gym, Gym, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Gym, Gym, QDistinct> distinctByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'order');
    });
  }
}

extension GymQueryProperty on QueryBuilder<Gym, Gym, QQueryProperty> {
  QueryBuilder<Gym, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Gym, String?, QQueryOperations> descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<Gym, bool, QQueryOperations> isPrimaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPrimary');
    });
  }

  QueryBuilder<Gym, double, QQueryOperations> multiplierProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'multiplier');
    });
  }

  QueryBuilder<Gym, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Gym, int, QQueryOperations> orderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'order');
    });
  }

  QueryBuilder<Gym, List<GymExerciseMultiplier>, QQueryOperations>
  perExerciseMultipliersProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'perExerciseMultipliers');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

const GymExerciseMultiplierSchema = Schema(
  name: r'GymExerciseMultiplier',
  id: -385993913356006671,
  properties: {
    r'exerciseId': PropertySchema(
      id: 0,
      name: r'exerciseId',
      type: IsarType.long,
    ),
    r'multiplier': PropertySchema(
      id: 1,
      name: r'multiplier',
      type: IsarType.double,
    ),
  },

  estimateSize: _gymExerciseMultiplierEstimateSize,
  serialize: _gymExerciseMultiplierSerialize,
  deserialize: _gymExerciseMultiplierDeserialize,
  deserializeProp: _gymExerciseMultiplierDeserializeProp,
);

int _gymExerciseMultiplierEstimateSize(
  GymExerciseMultiplier object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _gymExerciseMultiplierSerialize(
  GymExerciseMultiplier object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.exerciseId);
  writer.writeDouble(offsets[1], object.multiplier);
}

GymExerciseMultiplier _gymExerciseMultiplierDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = GymExerciseMultiplier(
    exerciseId: reader.readLongOrNull(offsets[0]) ?? 0,
    multiplier: reader.readDoubleOrNull(offsets[1]) ?? 1.0,
  );
  return object;
}

P _gymExerciseMultiplierDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 1:
      return (reader.readDoubleOrNull(offset) ?? 1.0) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension GymExerciseMultiplierQueryFilter
    on
        QueryBuilder<
          GymExerciseMultiplier,
          GymExerciseMultiplier,
          QFilterCondition
        > {
  QueryBuilder<
    GymExerciseMultiplier,
    GymExerciseMultiplier,
    QAfterFilterCondition
  >
  exerciseIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'exerciseId', value: value),
      );
    });
  }

  QueryBuilder<
    GymExerciseMultiplier,
    GymExerciseMultiplier,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GymExerciseMultiplier,
    GymExerciseMultiplier,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GymExerciseMultiplier,
    GymExerciseMultiplier,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GymExerciseMultiplier,
    GymExerciseMultiplier,
    QAfterFilterCondition
  >
  multiplierEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'multiplier',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    GymExerciseMultiplier,
    GymExerciseMultiplier,
    QAfterFilterCondition
  >
  multiplierGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'multiplier',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    GymExerciseMultiplier,
    GymExerciseMultiplier,
    QAfterFilterCondition
  >
  multiplierLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'multiplier',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    GymExerciseMultiplier,
    GymExerciseMultiplier,
    QAfterFilterCondition
  >
  multiplierBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'multiplier',
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

extension GymExerciseMultiplierQueryObject
    on
        QueryBuilder<
          GymExerciseMultiplier,
          GymExerciseMultiplier,
          QFilterCondition
        > {}
