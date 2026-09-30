# Indian Scam Call Detection — Full MLOps Platform

**OTP-Guard** is a full MLOps platform that detects OTP fraud, digital-arrest scams, KYC scams, banking scams, courier scams, investment scams and other Indian phone-call scams from **English, Hindi, Tamil, Hinglish, Tanglish and mixed-language** transcripts.

The project ships end-to-end:

- data ingestion → validation → deduplication → **template grouping** → leakage-safe 80/10/10 split
- baseline (TF-IDF + Logistic Regression) + optional multilingual BERT (`bert-base-multilingual-cased`)
- experiment tracking via **MLflow**, data versioning via **DVC**
- FastAPI inference API + React dashboard
- Prometheus metrics + drift monitor
- Docker Compose, GitHub Actions CI/CD, unit tests
- privacy masking of OTP / phone / account numbers before logging

## Architecture

```
Raw dataset → Ingest → Validate → Preprocess → Deduplicate → Template group
           → Leakage-safe split → EDA → Baseline + Transformer → Threshold opt.
           → Validation gate → MLflow registry → FastAPI + React dashboard
           → Monitoring / Feedback
```

## Quick start

### 1. Clone & install (Linux / macOS)

```bash
git clone <this-repo>
cd scam-call-mlops
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### 1. Quick start (Windows PowerShell)

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 2. Run the data + baseline pipeline

```bash
# Full pipeline (data + training + evaluation + validation gate)
python scripts/run_pipeline.py

# Or use the Makefile
make pipeline           # data-only
make train              # baseline (TF-IDF + LR, MLflow logged)
make evaluate

# Windows PowerShell equivalents
python scripts\run_pipeline.py
python -m src.cli data validate
python -m src.cli model train-baseline
python -m src.cli model evaluate
```

### 3. Serve the API

```bash
make api                # uvicorn backend.server:app :8001
# or
uvicorn backend.server:app --host 0.0.0.0 --port 8001 --reload
```

Test it:

```bash
curl http://localhost:8001/api/health
curl -X POST http://localhost:8001/api/predict \
     -H "Content-Type: application/json" \
     -d '{"text":"Sir your bank account will be blocked. Share the OTP."}'
```

### 4. Frontend

```bash
cd frontend && yarn install && yarn start   # http://localhost:3000
```

### 5. MLflow

```bash
make mlflow             # http://localhost:5000
```

### 6. Docker (all services)

```bash
docker compose up --build
# Backend    : http://localhost:8001
# Frontend   : http://localhost:3000
# MLflow     : http://localhost:5000
# Prometheus : http://localhost:9090

# Enable Grafana (pre-provisioned dashboard: OTP-Guard :: Scam Detector)
docker compose --profile viz up
# Grafana    : http://localhost:3001   (admin / admin, anonymous viewer enabled)
```

### 7. Multilingual BERT fine-tuning (optional, heavy)

```bash
# Install extra deps: torch / transformers / datasets / accelerate / mlflow / dvc
make install-train

# CPU-friendly defaults kick in automatically when no GPU is detected
# (batch 4, epochs 2, max_length 128).
python -m src.cli model train-transformer

# Everything ends up in:
#   models/transformer/          – model, tokenizer, threshold, metadata
#   models/production/           – copied over automatically IF gates pass
#   mlruns/                      – MLflow experiment + registered model
```

Trigger the full workflow from GitHub Actions:

```
Actions → training → Run workflow
```


## CLI

```bash
python -m src.cli data validate
python -m src.cli data preprocess
python -m src.cli data deduplicate
python -m src.cli data group
python -m src.cli data split
python -m src.cli data eda
python -m src.cli model train-baseline
python -m src.cli model train-transformer     # optional / heavy
python -m src.cli model evaluate
python -m src.cli model validate
python -m src.cli pipeline
python -m src.cli api
```

## DVC (data versioning)

```bash
pip install dvc
dvc init
dvc repro          # rebuild pipeline stages defined in dvc.yaml
dvc repro split    # rebuild only the split stage
```

## Repository structure

```
scam-call-mlops/
├── api/                (thin proxy – backend lives in /backend)
├── backend/            FastAPI app (server.py)
├── configs/            config.yaml (API + runtime knobs)
├── data/               raw / interim / processed / splits / feedback
├── examples/           legitimate + scam sample transcripts
├── frontend/           React + Vite dashboard
├── models/             baseline / transformer / production
├── monitoring/         prometheus.yml
├── reports/            data / evaluation / leakage / model & data cards
├── scripts/            run_pipeline.py, final_check.py
├── src/
│   ├── analysis/       eda.py
│   ├── data/           ingest, validate, preprocess, deduplicate, group, split
│   ├── evaluation/     evaluate, threshold_optimizer, error_analysis
│   ├── inference/      indicators, risk_engine, predictor
│   ├── models/         train_baseline, train_transformer
│   ├── monitoring/     drift, metrics (prometheus)
│   ├── privacy/        masking
│   └── validation/     check_source_label, leakage_check, model_validation
├── tests/              pytest unit tests
├── .github/workflows/  ci.yml + training.yml
├── docker-compose.yml
├── Dockerfile
├── dvc.yaml            reproducible pipeline
├── Makefile
├── params.yaml         DVC / training parameters
└── requirements.txt
```

## Testing

```bash
make test                       # pytest -q
python scripts/final_check.py   # PASS/MISSING checklist across all artefacts
```

## MLOps guarantees

- **Leakage-safe splits**: template groups never cross train / validation / test.
- **Threshold optimisation** on validation only – the test set is untouched.
- **Model collapse detection** aborts promotion if predicted scam ratio is < 1 % or > 99 %.
- **Validation gates** (`scam_recall ≥ 0.80`, `scam_f1 ≥ 0.70`, `PR-AUC ≥ 0.75`) enforced before registry promotion.
- **Privacy**: OTP / PIN / phone / account numbers are masked before any logging.

## Retraining

1. Collect verified feedback via `POST /api/feedback`.
2. Merge into `data/raw/` and version with DVC.
3. Trigger the `training.yml` workflow (GitHub Actions → `workflow_dispatch`) or run `make train`.
4. New model is promoted only if it passes the gate.

## Documents

- [Model card](reports/model_card.md)
- [Data card](reports/data_card.md)
- [Data quality](reports/data_quality_report.md)
- [Split report](reports/split_report.json)
- [Leakage report](reports/leakage/leakage_report.md)
- [Validation gates](reports/evaluation/validation_gates.json)

## License

MIT
