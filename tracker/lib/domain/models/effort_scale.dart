/// How a set's effort is rated, both from 0 to 10. Sets store RPE either
/// way: reps in reserve is 10 minus RPE, so switching scales keeps every
/// rating.
enum EffortScale {
  /// Rate of perceived exertion: 10 is a set taken to failure.
  rpe,

  /// Reps in reserve: how many more reps the set had in it.
  rir;

  String get label => this == EffortScale.rpe ? 'RPE' : 'RIR';

  String get title => this == EffortScale.rpe
      ? 'Rate of perceived exertion'
      : 'Reps in reserve';

  /// A stored RPE in this scale.
  double fromRpe(double rpe) => this == EffortScale.rpe ? rpe : 10 - rpe;

  /// A value in this scale as the RPE sets store.
  double toRpe(double value) => this == EffortScale.rpe ? value : 10 - value;
}
