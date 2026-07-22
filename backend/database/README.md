# MONIKA database

## Setup

1. Open phpMyAdmin (`http://localhost/phpmyadmin/`)
2. Create a database named `monika` (matches `backend/config.php`'s `db_name`)
3. Select it, go to **Import**, choose `schema.sql`, click Go

Or via CLI:

```
mysql -u root -e "CREATE DATABASE monika"
mysql -u root monika < schema.sql
```

## Design notes

- **IDs**: internal primary keys are auto-increment `INT`. The human-readable codes already used throughout the Flutter app (`EMP-1042`, `LV-2201`, ...) are kept as a separate unique `VARCHAR` column (`employee_code`, `reference_code`) rather than becoming the primary key — simpler joins, same display values.
- **`departments` is normalized** into its own table (referenced by `users`, `kpi_templates`, `training_programs`) since it recurs across multiple entities. Where the Dart model uses `department: null` / `'All Departments'` as a sentinel, the schema uses a nullable FK instead.
- **`employment_duration` (a formatted string like "2 yrs 3 mos" in the Dart model) is not stored.** The schema stores `hire_date` instead; duration is a display-time calculation.
- **`attendanceRate` (on `TeamMemberSummary`) is not stored anywhere.** It's a derived aggregate — compute it from `attendance_records` in the Analytics endpoints so it can't drift out of sync.
- **Training programs vs. enrollments are split.** The Dart `TrainingProgram` model conflates a program's definition (title, category, description) with one employee's progress on it (progress, isCompleted, performanceScore) — that's fine for dummy data, but a real schema needs `training_programs` (shared) and `training_enrollments` (per-user) as separate tables, or every employee enrolling in the same program would duplicate the program's own fields.
- **`policy_settings` is a single-row table** (not key-value) — it's a small, fixed set of fields the UI already treats as one settings form, so named/typed columns are simpler to work with in PHP than unpacking a key-value table.
- **PE scores are snapshotted.** `performance_evaluation_scores` stores the KPI weightage *as it was when the evaluation was scored*, not a live reference to `kpi_template_items` — so editing a template later doesn't silently rewrite past years' evaluations.
- **`risk_score` is a running numeric value** (starts at 100 per the FYP scope doc), with `risk_level` kept as a cached band column for fast sorting/filtering on list screens — recomputed by the application whenever `risk_score` changes, not derived on every read.
