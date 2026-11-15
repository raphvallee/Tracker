# Motion principles

How things move in the Tracker app. Motion here exists to show what changed
because of something the user did, never to decorate. The reference
implementation is the set row on the exercise page
(`tracker/lib/ui/workout/widgets/exercise_page.dart`: `_RowMotion`,
`_setRow`, `_valueCell`, `_followOpening`). The shared pieces live in
`tracker/lib/ui/core/ui/`: `motion.dart` (the M11 timings and the M12
switch), `row_motion.dart` (`RowMotion`, `followOpening`),
`animated_reveal.dart`, `animated_swap.dart` and `sliding_column.dart`.

Each principle names what goes wrong without it, so an audit can point at
the symptom.

## M1. One action, one motion

Everything that changes because of one action moves together, on one clock.
Nothing pops in or out while its neighbours glide: a label, an icon, a
tint, a border, the space under a list.

Without it: a row glides while its outline jumps, a button's label snaps
while the panel above it slides, a clock appears at full size in one frame.

## M2. Morph, don't swap

When an element changes state (folded to open, waiting to logged, compact
to expanded), interpolate one widget tree between its two looks: shared
parts move to their new place, parts only one look has fold or grow in.
Do not swap two different subtrees under an `AnimatedSize` or an
`AnimatedSwitcher`, which cuts the old look away in one frame and clips the
new one in as a curtain. Text fields and other stateful children keep their
`GlobalKey`s and their focus throughout.

Without it: the outline or the labels teleport, a field flickers or loses
its caret, the content is revealed top-down instead of growing.

## M3. Conserve space

When one thing gives up room while another takes it (one row folds as the
next opens, one tab's content shrinks as another grows), both run the same
duration and mirrored curves (`easeOutCubic` one way, `easeInCubic` on the
reverse of the same controller), so what one loses the other gains at every
frame and everything below them stays still. Do not delay one size change to
"stagger" it; stagger with opacity instead (M5).

Without it: rows under the change bob up and back down.

## M4. Never show empty room

A space never opens or closes empty. What fills it fades in with the room
(or slightly after it starts) and stays visible while the room closes;
`AnimatedReveal` keeps its last child while it leaves. Nothing collapses as
a hollow box under content that already changed.

Without it: a box grows with nothing in it for a few frames, or shrinks with
its content already gone.

## M5. Sequence with opacity, not with position

To read as "this closes, then that opens", fade the leaving parts out early
(the first ~30 % of the motion) and the arriving parts in late (the last
~60 %), while sizes and positions move together. Arriving labels may rise
the last few pixels into place.

Without it: either everything cross-dissolves at once into mush, or sizes
are staggered and break M3.

## M6. Leaving parts are gone for input

A part on its way out takes no taps and has no semantics
(`IgnorePointer` + `ExcludeSemantics`); a part on its way in takes taps as
soon as it is the target. Finders in tests still see an arriving part from
its first frame.

Without it: a tap lands on a fading button, a screen reader reads two
labels.

## M7. Don't animate what is being typed

Text that follows the user's input (a Log label that repeats the typed
weight, a running total) updates in place. It crossfades only when the step
it names changes and its words change with it (`AccentButton.labelKey`).
Identical text never crossfades with itself.

Without it: every keystroke shimmers, or the same label smears while it
crossfades with a copy of itself.

## M8. Keep the context, don't make the user redo the trigger

A flow that continues stays where it is: the keypad stays up when the next
set is due, a sheet stays open when its next step is in it. Avoid a motion
that undoes itself (a panel sliding down only to be called back up by the
next tap).

Without it: two motions and an extra tap for one intent.

## M9. Scroll with the motion, not after it

When something grows under an edge (the dock, the keypad, the keyboard, a
sheet's bottom), the page scrolls in the same frames as the growth, closing
the hidden part in step with it, and ends with the whole thing in view.

Without it: an item opens under the dock, then the page jumps or scrolls in
a second, separate motion.

## M10. Room follows what needs it

Padding or space reserved for an overlay (the keypad, a bar) opens at once,
so reveals can measure against it, and closes in step with the overlay
leaving, so a page scrolled to its end settles instead of jumping.

Without it: the list snaps down when the keypad goes, or a reveal scrolls
short because the room was not there yet.

## M11. Shared timing and curves

| Kind | Duration | Curve |
|---|---|---|
| Press feedback, label crossfade | 100 to 150 ms | `easeOutCubic` in, `easeInCubic` out |
| A state change in place (open, fold, tint, tick) | 220 ms | `easeOutCubic`, reverse `easeInCubic` |
| A panel sliding in and out (keypad, sheet, bar) | 240 ms in, 170 ms out | `easeOutCubic` in, `easeInCubic` out |
| Room opening and closing (`AnimatedReveal`) | 320 ms in, 240 ms out | `easeOutCubic` |

Two things that answer the same action share one row of this table.
`linear`, `bounce` and `elastic` curves are not used for UI state.

## M12. Reduced motion

Every animation checks `MediaQuery.disableAnimationsOf(context)` and jumps
to its end state when it is set: `Duration.zero` for implicit widgets,
`controller.value = target` for controllers. Scrolls jump instead of
animating.

## M13. Cheap frames

Animate with transitions (`FadeTransition`, `SizeTransition`,
`SlideTransition`) or with values read in a builder low in the tree. Never
rebuild the whole app or a whole page per frame (see `KeyboardReveal`),
never derive a theme from an animating value, and avoid an `Opacity` on a
large subtree that animates for long.
