"""Trains the training-area recommender offline and exports it for Supabase.

The deployed model is a multinomial logistic regression behind mean
imputation and standardisation. It was chosen over the tree models it is
compared against below because (a) its accuracy is on par, (b) it is small
enough to be evaluated inside Postgres with plain arithmetic, so no model
server is needed, and (c) every prediction can be explained as a sum of
per-feature contributions, which the HR screen shows.

Usage:  python train.py [--data data/synthetic_employees.csv] [--data more.csv ...]
Writes: output/model.json        exported parameters + metrics + check vectors
        output/model_upload.sql  run in the Supabase SQL Editor to activate it
        output/model_card.md     human-readable evaluation report
"""
import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score
from sklearn.model_selection import cross_val_predict, cross_val_score, train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier

from features import CLASSES, FEATURES

HERE = Path(__file__).parent
OUT = HERE / 'output'
SEED = 42


def load(paths):
    frames = [pd.read_csv(p) for p in paths]
    df = pd.concat(frames, ignore_index=True)
    missing = [c for c in FEATURES + ['label'] if c not in df.columns]
    if missing:
        raise SystemExit(f'Dataset is missing columns: {missing}')
    df = df[df['label'].isin(CLASSES)]
    return df[FEATURES].astype(float), df['label'].to_numpy()


def baseline_lowest_pe(X: pd.DataFrame) -> np.ndarray:
    """The rule the app used before: recommend the PE category the employee
    scored lowest in; with no PE on record there is nothing to go on, so it
    falls back to technical."""
    pe = X[['pe_technical', 'pe_behavioural', 'pe_leadership']].to_numpy()
    out = np.full(len(X), 'technical', dtype=object)
    has_any = ~np.all(np.isnan(pe), axis=1)
    filled = np.where(np.isnan(pe), np.inf, pe)
    out[has_any] = np.array(CLASSES)[filled[has_any].argmin(axis=1)]
    return out


def make_lr():
    return make_pipeline(
        SimpleImputer(strategy='mean'),
        StandardScaler(),
        LogisticRegression(max_iter=2000, C=1.0),
    )


def pick_threshold(proba: np.ndarray, y: np.ndarray, classes: np.ndarray):
    """Lowest confidence at which predictions are right at least 85% of the
    time. Chosen on cross-validated training predictions, not the test set."""
    pred = classes[proba.argmax(axis=1)]
    conf = proba.max(axis=1)
    rows = []
    for t in np.arange(0.40, 0.91, 0.05):
        keep = conf >= t
        cov = keep.mean()
        acc = (pred[keep] == y[keep]).mean() if keep.any() else float('nan')
        rows.append((round(float(t), 2), float(cov), float(acc)))
    chosen = next((t for t, cov, acc in rows if acc >= 0.85 and cov >= 0.3), 0.6)
    return chosen, rows


def softmax_from_export(model: dict, X: pd.DataFrame) -> np.ndarray:
    """Re-implements exactly what the SQL scorer does, from the exported
    numbers only — missing value -> z = 0, else (x - mean) / scale."""
    means = np.array(model['means'])
    scales = np.array(model['scales'])
    coef = np.array(model['coef'])
    intercept = np.array(model['intercept'])
    raw = X[model['features']].to_numpy(dtype=float)
    z = np.where(np.isnan(raw), 0.0, (raw - means) / scales)
    logits = z @ coef.T + intercept
    logits -= logits.max(axis=1, keepdims=True)
    e = np.exp(logits)
    return e / e.sum(axis=1, keepdims=True)


def sql_num(v: float) -> str:
    return repr(float(v))


def sql_text(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def build_upload_sql(model: dict) -> str:
    feats = ', '.join(sql_text(f) for f in model['features'])
    classes = ', '.join(sql_text(c) for c in model['classes'])
    means = ', '.join(sql_num(v) for v in model['means'])
    scales = ', '.join(sql_num(v) for v in model['scales'])
    coef = ', '.join('[' + ', '.join(sql_num(v) for v in row) + ']' for row in model['coef'])
    intercept = ', '.join(sql_num(v) for v in model['intercept'])
    metrics = sql_text(json.dumps(model['metrics']))

    checks = []
    for i, cv in enumerate(model['check_vectors']):
        expected = ' and '.join(
            f"abs((r->'probabilities'->>{sql_text(c)})::float8 - {sql_num(p)}) < 1e-6"
            for c, p in cv['probabilities'].items()
        )
        checks.append(
            f"    r := public.ml_score_features(v_id, {sql_text(json.dumps(cv['features']))}::jsonb);\n"
            f"    if not ({expected}) then\n"
            f"        raise exception 'Model check {i + 1} failed: database scored %, expected {json.dumps(cv['probabilities'])}', r->'probabilities';\n"
            f"    end if;"
        )

    return f"""-- Uploads training recommender model {model['version']} and makes it the
-- active one. Generated by ml/train.py — do not edit by hand. Needs
-- migration 0040 applied first. Safe to re-run.
begin;

update public.training_ml_models set is_active = false where is_active;

insert into public.training_ml_models
    (version, trained_at, algorithm, features, means, scales, classes, coef, intercept, metrics, min_confidence, is_active)
values (
    {sql_text(model['version'])},
    {sql_text(model['trained_at'])},
    {sql_text(model['algorithm'])},
    array[{feats}]::text[],
    array[{means}]::float8[],
    array[{scales}]::float8[],
    array[{classes}]::text[],
    array[{coef}]::float8[],
    array[{intercept}]::float8[],
    {metrics}::jsonb,
    {model['min_confidence']},
    true
)
on conflict (version) do update set
    trained_at = excluded.trained_at, algorithm = excluded.algorithm,
    features = excluded.features, means = excluded.means, scales = excluded.scales,
    classes = excluded.classes, coef = excluded.coef, intercept = excluded.intercept,
    metrics = excluded.metrics, min_confidence = excluded.min_confidence, is_active = true;

-- Self-check: the database must reproduce the probabilities Python computed
-- for these sample employees, or the whole upload is rolled back.
do $$
declare
    v_id bigint;
    r jsonb;
begin
    select id into v_id from public.training_ml_models where version = {sql_text(model['version'])};
{chr(10).join(checks)}
    raise notice 'Model {model['version']} uploaded and verified.';
end;
$$;

commit;
"""


def build_card(model: dict, comparison, threshold_rows, cm, labels) -> str:
    m = model['metrics']
    lines = [
        f"# Training recommender — model card ({model['version']})",
        '',
        f"Trained {model['trained_at']} on {m['train_rows']} rows, tested on {m['test_rows']} held-out rows.",
        '',
        '## What it predicts',
        'Which training area (technical, behavioural or leadership) an employee would benefit from most,',
        'from nine signals MONIKA already records: ' + ', '.join(f'`{f}`' for f in model['features']) + '.',
        'Missing signals (new hires, no appraisal yet) are treated as "average".',
        '',
        '## Model comparison (held-out test set)',
        '',
        '| Model | Test accuracy | Macro F1 | 5-fold CV accuracy |',
        '|---|---|---|---|',
    ]
    for name, acc, f1, cv in comparison:
        cv_s = f'{cv:.3f}' if cv is not None else '—'
        lines.append(f'| {name} | {acc:.3f} | {f1:.3f} | {cv_s} |')
    lines += [
        '',
        'The deployed model is the logistic regression: it matches the tree models closely while being',
        'small enough to run inside Postgres and explainable per prediction.',
        '',
        '## Confusion matrix (deployed model, test set)',
        '',
        '| actual \\ predicted | ' + ' | '.join(labels) + ' |',
        '|---|' + '---|' * len(labels),
    ]
    for lab, row in zip(labels, cm):
        lines.append(f'| {lab} | ' + ' | '.join(str(v) for v in row) + ' |')
    lines += [
        '',
        '## Confidence threshold',
        '',
        f"The database only acts on a prediction when its confidence is at least **{model['min_confidence']}**",
        '(the lowest level at which cross-validated predictions were right at least 85% of the time).',
        '',
        '| Confidence ≥ | Share of employees covered | Accuracy on those |',
        '|---|---|---|',
    ]
    for t, cov, acc in threshold_rows:
        lines.append(f'| {t:.2f} | {cov:.1%} | {acc:.1%} |')
    lines += [
        '',
        f"On the test set at that threshold: {m['coverage_at_threshold']:.1%} of employees get an ML recommendation,",
        f"and {m['accuracy_at_threshold']:.1%} of those are correct.",
        '',
        '## Coefficients (standardised features)',
        '',
        '| Feature | ' + ' | '.join(model['classes']) + ' |',
        '|---|' + '---|' * len(model['classes']),
    ]
    coef = np.array(model['coef'])
    for j, f in enumerate(model['features']):
        lines.append(f'| {f} | ' + ' | '.join(f'{coef[k][j]:+.3f}' for k in range(len(model['classes']))) + ' |')
    lines += [
        '',
        'A positive number means a higher value of that feature pushes the prediction towards that area.',
        '',
        '## Limitations',
        '- Trained on a simulated workforce (see generate_synthetic.py) because MONIKA has no real history yet.',
        '  The labels follow a documented hypothesis, so the model learns that hypothesis, not ground truth.',
        '- Re-train with real data (export_real_data.sql) once enough employees have completed trainings',
        '  and been re-appraised, then re-upload; nothing in the app needs to change.',
        '',
    ]
    return '\n'.join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--data', action='append', default=None)
    args = ap.parse_args()
    paths = args.data or [str(HERE / 'data' / 'synthetic_employees.csv')]

    X, y = load(paths)
    X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.2, stratify=y, random_state=SEED)

    candidates = {
        'Logistic regression (deployed)': make_lr(),
        'Decision tree (depth 5)': make_pipeline(SimpleImputer(strategy='mean'),
                                                 DecisionTreeClassifier(max_depth=5, random_state=SEED)),
        'Random forest (200 trees)': make_pipeline(SimpleImputer(strategy='mean'),
                                                   RandomForestClassifier(n_estimators=200, min_samples_leaf=5,
                                                                          random_state=SEED)),
    }
    comparison = []
    for name, pipe in candidates.items():
        cv = cross_val_score(pipe, X_tr, y_tr, cv=5, scoring='accuracy').mean()
        pipe.fit(X_tr, y_tr)
        pred = pipe.predict(X_te)
        comparison.append((name, accuracy_score(y_te, pred), f1_score(y_te, pred, average='macro'), cv))
    base = baseline_lowest_pe(X_te)
    comparison.append(('Previous rule: lowest PE category', accuracy_score(y_te, base),
                       f1_score(y_te, base, average='macro'), None))

    lr = candidates['Logistic regression (deployed)']
    imputer, scaler, clf = lr.named_steps.values()
    classes = clf.classes_

    cv_proba = cross_val_predict(make_lr(), X_tr, y_tr, cv=5, method='predict_proba')
    min_conf, threshold_rows = pick_threshold(cv_proba, y_tr, classes)

    te_proba = lr.predict_proba(X_te)
    te_pred = classes[te_proba.argmax(axis=1)]
    keep = te_proba.max(axis=1) >= min_conf

    # Export in CLASSES order regardless of how sklearn sorted the labels.
    order = [list(classes).index(c) for c in CLASSES]
    coef = clf.coef_[order]
    intercept = clf.intercept_[order]

    digest = hashlib.sha1(np.concatenate([coef.ravel(), intercept]).round(12).tobytes()).hexdigest()[:6]
    now = datetime.now(timezone.utc)
    lr_row = comparison[0]
    model = {
        'version': f"lr-{now:%Y%m%d}-{digest}",
        'trained_at': now.isoformat(timespec='seconds'),
        'algorithm': 'multinomial logistic regression (mean imputation + standardisation)',
        'features': FEATURES,
        'means': scaler.mean_.tolist(),
        'scales': scaler.scale_.tolist(),
        'classes': CLASSES,
        'coef': coef.tolist(),
        'intercept': intercept.tolist(),
        'min_confidence': round(float(min_conf), 2),
        'metrics': {
            'train_rows': int(len(X_tr)),
            'test_rows': int(len(X_te)),
            'test_accuracy': round(lr_row[1], 4),
            'test_macro_f1': round(lr_row[2], 4),
            'cv_accuracy': round(lr_row[3], 4),
            'baseline_accuracy': round(comparison[-1][1], 4),
            'coverage_at_threshold': round(float(keep.mean()), 4),
            'accuracy_at_threshold': round(float((te_pred[keep] == y_te[keep]).mean()), 4),
            'data': [Path(p).name for p in paths],
        },
    }

    # Parity: the exported numbers alone must reproduce sklearn's output.
    exported = softmax_from_export(model, X_te)
    sk = te_proba[:, order]
    gap = float(np.abs(exported - sk).max())
    assert gap < 1e-9, f'Exported model disagrees with sklearn by {gap}'

    # A few test employees (including ones with missing signals) that the
    # upload script re-scores inside the database as a self-check.
    picks = [0, 1, 2]
    picks += list(np.where(X_te['pe_technical'].isna().to_numpy())[0][:1])
    picks += list(np.where(X_te['attendance_rate'].isna().to_numpy())[0][:1])
    model['check_vectors'] = [
        {
            'features': {f: (None if pd.isna(X_te.iloc[i][f]) else float(X_te.iloc[i][f])) for f in FEATURES},
            'probabilities': {c: float(exported[i][k]) for k, c in enumerate(CLASSES)},
        }
        for i in picks
    ]

    OUT.mkdir(exist_ok=True)
    (OUT / 'model.json').write_text(json.dumps(model, indent=2), encoding='utf-8')
    (OUT / 'model_upload.sql').write_text(build_upload_sql(model), encoding='utf-8')
    labels = list(CLASSES)
    cm = confusion_matrix(y_te, te_pred, labels=labels)
    (OUT / 'model_card.md').write_text(build_card(model, comparison, threshold_rows, cm, labels), encoding='utf-8')

    print(f"Model {model['version']}")
    for name, acc, f1, cv in comparison:
        cv_s = f'  cv={cv:.3f}' if cv is not None else ''
        print(f'  {name:36s} acc={acc:.3f}  macroF1={f1:.3f}{cv_s}')
    print(f"  min_confidence={model['min_confidence']}  coverage={model['metrics']['coverage_at_threshold']:.1%}"
          f"  accuracy_at_threshold={model['metrics']['accuracy_at_threshold']:.1%}")
    print(f'  parity with sklearn: max |diff| = {gap:.2e}')
    print(f'Wrote {OUT / "model.json"}, model_upload.sql, model_card.md')


if __name__ == '__main__':
    main()
