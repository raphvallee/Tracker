/// How the Exercises tab lays out the library. Each layout opens on the
/// same search field and leads to the same exercises.
enum ExercisesLayout {
  /// Recently trained exercises on top, then one row per muscle group with a
  /// ring for how much of it was trained lately, then one per movement.
  rows,

  /// One tile per group, each broken down by muscle with a bar per
  /// exercise, under a switch between muscle, movement, equipment and
  /// recent.
  tiles,

  /// Recently trained exercises on top, then one tile per group that opens
  /// its exercises right below its row, without leaving the page.
  openTiles,
}
