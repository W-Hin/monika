"""Generates a synthetic employee dataset for training the recommender.

MONIKA has no real history yet (a handful of test accounts), so the model is
trained on a simulated workforce whose labels come from an explicit,
documented hypothesis of which training area each employee needs most. The
hypothesis encodes the same reasoning HR would apply by hand, but weighs
every signal together instead of looking at one threshold at a time:

  technical   needs grow with a low Technical PE score, weak past training
              scores, and being new (first year = onboarding skills)
  behavioural needs grow with a low Behavioural PE score, poor attendance,
              poor punctuality and a reduced risk score (offences)
  leadership  needs grow with a low Leadership PE score and with seniority,
              especially for staff who are already technically strong

Each employee's label is the area with the highest need after adding noise
(the "true" need is never perfectly observable). Every employee has latent
true values for all signals; the dataset then hides what the real system
would not know yet — no attendance rate for brand-new hires, no PE before
the first appraisal, no training score before a training is completed — so
the model has to cope with the same gaps it meets in production.

Usage:  python generate_synthetic.py [--rows 3000] [--seed 42]
Writes: data/synthetic_employees.csv
"""
import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from features import CLASSES, FEATURES


def generate(rows: int, seed: int) -> pd.DataFrame:
    rng = np.random.default_rng(seed)

    tenure = np.clip(rng.gamma(shape=1.6, scale=18, size=rows), 0, 180).astype(int)

    # A general "conscientiousness" factor links attendance, punctuality and
    # risk, and a general "ability" factor links the PE scores, so the
    # signals are correlated the way real staff records are.
    conscientious = rng.normal(0, 1, rows)
    ability = rng.normal(0, 1, rows)

    attendance = np.clip(95 + 3.5 * conscientious + rng.normal(0, 2.5, rows), 55, 100)
    punctuality = np.clip(88 + 7 * conscientious + rng.normal(0, 5, rows), 30, 100)
    offences = rng.poisson(np.exp(-0.2 - 0.9 * conscientious))
    risk = np.clip(100 - offences * rng.choice([8, 10, 12, 15, 20], size=rows), 0, 100)

    pe_tech = np.clip(72 + 9 * ability + rng.normal(0, 8, rows) + 0.05 * np.minimum(tenure, 60), 20, 100)
    pe_beh = np.clip(72 + 5 * ability + 5 * conscientious + rng.normal(0, 8, rows), 20, 100)
    pe_lead = np.clip(64 + 6 * ability + 0.18 * np.minimum(tenure, 72) + rng.normal(0, 9, rows), 20, 100)

    completed = rng.poisson(0.1 + tenure / 14)
    train_score = np.clip(76 + 7 * ability + rng.normal(0, 7, rows), 30, 100)

    # ── Ground-truth need per area (the documented hypothesis above) ──────
    need_tech = (
        1.0 * (75 - pe_tech)
        + 0.4 * (78 - train_score)
        + 9.0 * (tenure < 12)
    )
    need_beh = (
        0.9 * (75 - pe_beh)
        + 0.9 * (95 - attendance)
        + 0.35 * (88 - punctuality)
        + 0.45 * (100 - risk)
        - 4.0
    )
    need_lead = (
        0.9 * (70 - pe_lead)
        + 0.30 * (np.minimum(tenure, 72) - 24)
        + 0.25 * (pe_tech - 72)
    )
    needs = np.stack([need_tech, need_beh, need_lead], axis=1)
    needs += rng.normal(0, 5, needs.shape)
    label = np.array(CLASSES)[needs.argmax(axis=1)]

    # ── Hide what the live system wouldn't know yet ──────────────────────
    df = pd.DataFrame({
        'tenure_months': tenure,
        'attendance_rate': attendance.round(1),
        'punctuality_rate': punctuality.round(1),
        'risk_score': risk,
        'pe_technical': pe_tech.round(1),
        'pe_behavioural': pe_beh.round(1),
        'pe_leadership': pe_lead.round(1),
        'trainings_completed': completed,
        'avg_training_score': train_score.round(1),
    })
    new_hire = tenure < 1                      # < 10 expected workdays recorded
    df.loc[new_hire, ['attendance_rate', 'punctuality_rate']] = np.nan
    no_pe = (tenure < 6) | (rng.random(rows) < 0.12)   # first appraisal after probation; some missed
    df.loc[no_pe, ['pe_technical', 'pe_behavioural', 'pe_leadership']] = np.nan
    # Templates don't always carry a Leadership KPI (e.g. junior roles).
    df.loc[(~no_pe) & (rng.random(rows) < 0.25), 'pe_leadership'] = np.nan
    df.loc[completed == 0, 'avg_training_score'] = np.nan

    df['label'] = label
    return df[FEATURES + ['label']]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--rows', type=int, default=3000)
    ap.add_argument('--seed', type=int, default=42)
    args = ap.parse_args()

    df = generate(args.rows, args.seed)
    out = Path(__file__).parent / 'data' / 'synthetic_employees.csv'
    out.parent.mkdir(exist_ok=True)
    df.to_csv(out, index=False)
    print(f'Wrote {len(df)} rows to {out}')
    print(df['label'].value_counts().to_string())
    print('Missing values per column:')
    print(df.isna().sum().to_string())


if __name__ == '__main__':
    main()
