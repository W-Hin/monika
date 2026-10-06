# Training recommender — model card (lr-20261006-81ddfa)

Trained 2026-10-06T04:24:38+00:00 on 2400 rows, tested on 600 held-out rows.

## What it predicts
Which training area (technical, behavioural or leadership) an employee would benefit from most,
from nine signals MONIKA already records: `tenure_months`, `attendance_rate`, `punctuality_rate`, `risk_score`, `pe_technical`, `pe_behavioural`, `pe_leadership`, `trainings_completed`, `avg_training_score`.
Missing signals (new hires, no appraisal yet) are treated as "average".

## Model comparison (held-out test set)

| Model | Test accuracy | Macro F1 | 5-fold CV accuracy |
|---|---|---|---|
| Logistic regression (deployed) | 0.783 | 0.777 | 0.777 |
| Decision tree (depth 5) | 0.693 | 0.671 | 0.697 |
| Random forest (200 trees) | 0.755 | 0.744 | 0.754 |
| Previous rule: lowest PE category | 0.578 | 0.568 | — |

The deployed model is the logistic regression: it matches the tree models closely while being
small enough to run inside Postgres and explainable per prediction.

## Confusion matrix (deployed model, test set)

| actual \ predicted | technical | behavioural | leadership |
|---|---|---|---|
| technical | 185 | 18 | 15 |
| behavioural | 26 | 176 | 17 |
| leadership | 36 | 18 | 109 |

## Confidence threshold

The database only acts on a prediction when its confidence is at least **0.65**
(the lowest level at which cross-validated predictions were right at least 85% of the time).

| Confidence ≥ | Share of employees covered | Accuracy on those |
|---|---|---|
| 0.40 | 98.9% | 77.9% |
| 0.45 | 97.0% | 78.4% |
| 0.50 | 93.1% | 79.8% |
| 0.55 | 85.7% | 82.4% |
| 0.60 | 79.3% | 84.9% |
| 0.65 | 73.1% | 86.9% |
| 0.70 | 66.0% | 89.1% |
| 0.75 | 59.1% | 90.9% |
| 0.80 | 51.2% | 93.2% |
| 0.85 | 43.9% | 94.9% |
| 0.90 | 35.6% | 96.1% |

On the test set at that threshold: 74.7% of employees get an ML recommendation,
and 85.9% of those are correct.

## Coefficients (standardised features)

| Feature | technical | behavioural | leadership |
|---|---|---|---|
| tenure_months | -0.550 | -0.139 | +0.689 |
| attendance_rate | +0.287 | -0.539 | +0.252 |
| punctuality_rate | +0.217 | -0.475 | +0.259 |
| risk_score | +0.466 | -1.132 | +0.667 |
| pe_technical | -1.691 | +0.725 | +0.967 |
| pe_behavioural | +0.804 | -1.303 | +0.499 |
| pe_leadership | +0.431 | +0.423 | -0.853 |
| trainings_completed | -0.032 | +0.115 | -0.083 |
| avg_training_score | -0.432 | +0.290 | +0.141 |

A positive number means a higher value of that feature pushes the prediction towards that area.

## Limitations
- Trained on a simulated workforce (see generate_synthetic.py) because MONIKA has no real history yet.
  The labels follow a documented hypothesis, so the model learns that hypothesis, not ground truth.
- Re-train with real data (export_real_data.sql) once enough employees have completed trainings
  and been re-appraised, then re-upload; nothing in the app needs to change.
