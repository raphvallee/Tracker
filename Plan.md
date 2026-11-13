# Fitness Tracker Specification

## 1. Navigation & App Structure

* **Home**
  * **1.1 Feed**: Activity stream, recent accomplishments, and community/personal updates.
  * **1.2 History**: Overview of past logged workouts, dates, and historical performance.
  * **1.3 Workout**: Active workout session view and tracker.
    * **1.3.1 Split Edit**: Interface to customize and manage workout splits (e.g., Push/Pull/Legs).
      * **1.3.1.1 Split Day Edit**: Configure specific days within a split routine.
        * **1.3.1.1.1 Split Day Exercises Edit**: Add, remove, or reorder exercises for a specific workout day.
  * **1.4 Exercises**: Master exercise library and custom exercise creation.
    * **1.4.1 Category View**: Browse exercises categorized by target muscle group or movement patterns.
      * **1.4.1.1 Exercise View**: Detailed view for an individual exercise, including historical stats, graphs, and performance logs.
  * **1.5 Settings**: User profile, units (kg/lbs), gym configurations, and application settings.

---

## 2. Core Features & Functional Requirements

### 2.1 Warmup Weights
* **Logging**: Allow users to explicitly flag and log warm-up sets during a workout session.
* **Display**: Display warm-up sets clearly in workout history and exercise summary logs with distinct visual indicators.
* **Calculations**: Exclude warm-up sets from progression algorithms, 1RM estimates, peak volume calculations, and performance analytics.

### 2.2 Gym & Equipment Management
* **Per Gym Machine**: Support multi-gym environments (e.g., Home Gym, Commercial Gym A, Commercial Gym B).
* **Location Selection**: When starting a new workout, prompt the user to select their current gym location if more than one gym profile exists.

### 2.3 Machine Weight Equivalence & Multipliers
* **Cross-Machine Alignment**: When identical movements are performed across different machines or equipment brands, aggregate all lifted weights onto a single unified chart.
* **Trend & Multiplier Calculation**:
  * Set the primary home gym machine as the baseline standard (Multiplier = 1.0).
  * Estimate trendlines across machine performances to auto-calculate weight equivalence multipliers for secondary gym machines.
  * Allow users to manually override and adjust equipment weight multipliers.

### 2.4 Normalized Progression Analytics
* **Progression Normalization**: Normalize performance metrics across all machines and equipment variants to standard effort scales.
* **General Progression Graphing**: Plot general overall strength progression, volume trends, and performance trajectory over time.

### 2.5 Calendar View
* **Workout Calendar**: Interactive calendar view displaying historical workout days, frequency, consistency metrics, and quick links to past session logs.
