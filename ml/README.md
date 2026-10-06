# ML training recommender (FR9.2)

Predicts which training area — **technical**, **behavioural** or **leadership** — an
employee would benefit from most. The model is **trained offline** on a laptop and
uploaded to Supabase as plain numbers; the database scores employees itself, so
there is no model server to host or pay for.

```
ml/generate_synthetic.py ──> data/synthetic_employees.csv
                                   │
ml/train.py ───────────────────────┴──> output/model.json        (parameters + metrics)
                                        output/model_upload.sql  (run in Supabase)
                                        output/model_card.md     (evaluation report)
```

## Steps

1. Install once: `pip install -r requirements.txt`
2. `python generate_synthetic.py` — simulated workforce of 3,000 employees (seeded, reproducible).
3. `python train.py` — trains and compares three models against the old rule, picks the
   confidence threshold, and checks the exported numbers reproduce scikit-learn exactly.
4. In the Supabase SQL Editor: apply `supabase/migrations/0040_ml_training_recommender.sql`
   (once), then run `output/model_upload.sql`. The upload re-scores sample employees inside
   the database and rolls itself back if the results differ from Python's.

That's it — the next daily sweep (03:00) or an employee opening Training picks it up. To
replace the model, re-run steps 2–4; the newest upload becomes the active one.

## Inputs

Defined once in `features.py` and computed live by `public.ml_employee_features()`:

| Feature | Meaning |
|---|---|
| `tenure_months` | months since hire date |
| `attendance_rate` | % of expected workdays attended, last 90 days |
| `punctuality_rate` | % of clock-ins on time, last 90 days |
| `risk_score` | current risk score (100 = no offences) |
| `pe_technical` / `pe_behavioural` / `pe_leadership` | weighted KPI score per area in the latest submitted PE |
| `trainings_completed` | completed trainings so far |
| `avg_training_score` | average score of completed trainings |

Anything not known yet (new hire, no appraisal) is treated as average.

## How the app uses it

- **Daily sweep** — after the attendance/risk rules, if the model's confidence is at least
  its threshold and the employee has no unfinished ML recommendation, they are enrolled in one
  programme from the predicted area (a recommendation-only one first). The employee sees the
  reason on the programme card.
- **HR → Employee Details → Training Insight** — the predicted area, confidence, the share for
  each area, and the top reasons in plain language.
- Every recommendation records where it came from (`training_enrollments.recommended_by`:
  `rule`, `pe` or `ml`).

## Why logistic regression

It scored on par with or better than a decision tree and a random forest (see
`output/model_card.md`), it is small enough to evaluate in SQL with ordinary arithmetic, and
each prediction splits cleanly into per-feature contributions, which is what the "why" list
shows.

## Training on real data later

`export_real_data.sql` produces the same columns from the live database, labelled by the
recommended programmes employees went on to pass. Download it as CSV into `data/` and pass
both files to `train.py` (`--data ... --data ...`).
