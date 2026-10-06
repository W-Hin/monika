"""Single source of truth for the model's inputs and outputs.

The order of FEATURES is the order the exported coefficients use, and the
names must match the keys returned by public.ml_employee_features() in the
database (migration 0040) exactly — the SQL scorer looks each feature up by
name in that JSON object.
"""

FEATURES = [
    'tenure_months',        # whole months since hire_date
    'attendance_rate',      # % of expected workdays attended, last 90 days (null if < 10 expected days)
    'punctuality_rate',     # % of on-time clock-ins among on-time + late, last 90 days (null if < 5 clock-ins)
    'risk_score',           # current profiles.risk_score, 0-100 (100 = no offences)
    'pe_technical',         # weighted Technical KPI score in the latest submitted PE (null if none)
    'pe_behavioural',       # weighted Behavioural KPI score in the latest submitted PE (null if none)
    'pe_leadership',        # weighted Leadership KPI score in the latest submitted PE (null if none)
    'trainings_completed',  # completed training enrolments, all time
    'avg_training_score',   # mean quiz/performance score of completed trainings (null if none)
]

# Must match training_programs.category values.
CLASSES = ['technical', 'behavioural', 'leadership']
