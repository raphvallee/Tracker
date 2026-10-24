# Refining the app

## General

- [ ] When a field is selected, the keyboard should not hide that field, the page should automatically scroll to allow viewing that field
- [ ] Everywhere a gym selector appears i want the option to "Add Gym"

## Settings

- [ ] Units has a different paddings then the other ones.
- [ ] Defaut rep mode select box should fit the entire words contained in it.
- [ ] Default reps and default rep range should not have their own container, they should fit the style of the settings page.
	
## Editor

- [ ] Field validation should only be done when saving (we have a "cannot be empty" when entering the page for first time)
- [ ] Removing a split day should prompt confirmation
- [ ] In the splitday editor, add a couple pixel of gap between sets when there are multiple
- [ ] In the splitday editor, when switching back and forth between fixed and rep range, we should remember the max reps range so we can put it back if the user had accidentally switched the mode. (Exemple: if it default to 8-12, then user customizes it to 5-9, then he switches to fixed, the fix reps will be 5, then he switches back to rep-range, it becomes 5-9 again) dont store that value in the persistent db across restart, we just want it while hes editing that set
- [ ] Split Days should be re-orderable just like splitdays exercices
- [ ] When clicking on a split day before starting the workout, the descriptions for the sets is really confusing.
- [ ] When clicking on a split day before starting the workout, we should add a gap between exercices.
- [ ] When clicking on a split day before starting the workout, the title of the page should be Splitname + splitdayname, replace the other redundant title that is above the exercice list with the splitday description
	
## Workout

- [ ] When a workout has multiple sets planned, there should be multiple inputs to enter the weight and reps. The rep-range/fixed-reps should be a hint in the input 
- [ ] The sets added are in a black container that does not fit the theme at all, find another way to present them

## Feed - Analytics

- [ ] When editing a graph, dont autofocus a input, i dont want the keyboard to popup at first.
- [ ] When editing a graph, the Exercice selector should be rewritten to be easier to understand. It should be clear that it is an input, with a dropdown indicator. In the dropdown, we can search, select all or select a specific exercice.
	
## History

- [ ] When editing a session, the gym and started datetime are in a black container that does not fit the theme at all, find another way to present them
- [ ] Editing a session's start time should modify the session duration. (We assume the user forgot to start the session but remembered to finish it when he was done working out)
- [ ] When editing a session, replace the "no gym" option with "Other gym"
