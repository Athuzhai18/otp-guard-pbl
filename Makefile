# -----------------------------------------------------------------------------
# Scam-Call MLOps :: Makefile
# Cross-platform helpers. Windows PowerShell equivalents in README.md.
# -----------------------------------------------------------------------------
PYTHON ?= python
PIP ?= pip
API_HOST ?= 0.0.0.0
API_PORT ?= 8001

.PHONY: help install install-dev install-train validate preprocess dedup group split \
        eda train train-baseline train-transformer evaluate api frontend test lint \
        format pipeline final-check docker-build docker-up docker-down mlflow prom \
        clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?##' Makefile | sort | awk 'BEGIN{FS=":.*?##"}{printf "  \033[36m%-20s\033[0m %s\n",$$1,$$2}'

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
install: ## Install base dependencies
	$(PIP) install -r requirements.txt

install-dev: install ## Install dev / test dependencies
	$(PIP) install pytest pytest-cov ruff black isort

install-train: ## Install optional heavy training deps (transformers/torch/mlflow/dvc)
	$(PIP) install mlflow==2.14.3 dvc==3.55.2 || true
	$(PIP) install torch --index-url https://download.pytorch.org/whl/cpu || true
	$(PIP) install transformers==4.44.2 datasets==2.21.0 accelerate==0.34.2 || true

# ---------------------------------------------------------------------------
# Data pipeline
# ---------------------------------------------------------------------------
validate: ## Run data quality validation
	$(PYTHON) -m src.cli data validate

preprocess: ## Normalise / mask / clean text
	$(PYTHON) -m src.cli data preprocess

dedup: ## Exact + near-duplicate detection
	$(PYTHON) -m src.cli data deduplicate

group: ## Build template groups from near-duplicate graph
	$(PYTHON) -m src.cli data group

split: ## Leakage-safe 80/10/10 split (group-aware)
	$(PYTHON) -m src.cli data split

eda: ## Generate exploratory data analysis report
	$(PYTHON) -m src.cli data eda

pipeline: ## Run full data pipeline (no training)
	$(PYTHON) scripts/run_pipeline.py --skip-training

# ---------------------------------------------------------------------------
# Training / evaluation
# ---------------------------------------------------------------------------
train-baseline: ## Train TF-IDF + Logistic Regression baseline (logs to MLflow)
	$(PYTHON) -m src.cli model train-baseline

train-transformer: ## Optional: fine-tune multilingual BERT (needs GPU ideally)
	$(PYTHON) -m src.cli model train-transformer

train: train-baseline ## Alias for baseline training
evaluate: ## Evaluate models on the held-out test set
	$(PYTHON) -m src.cli model evaluate

# ---------------------------------------------------------------------------
# Services
# ---------------------------------------------------------------------------
api: ## Run FastAPI locally (dev)
	uvicorn backend.server:app --host $(API_HOST) --port $(API_PORT) --reload

frontend: ## Run React dev server
	cd frontend && yarn start

mlflow: ## Start local MLflow tracking UI on :5000
	mlflow server --host 0.0.0.0 --port 5000 \
		--backend-store-uri ./mlruns --default-artifact-root ./mlartifacts

prom: ## Run Prometheus locally (requires prometheus binary)
	prometheus --config.file=monitoring/prometheus.yml

# ---------------------------------------------------------------------------
# Quality
# ---------------------------------------------------------------------------
test: ## Run unit tests
	$(PYTHON) -m pytest -q

lint: ## Static checks
	ruff check src backend tests scripts || true

format: ## Auto-format source
	ruff check --fix src backend tests scripts || true
	black src backend tests scripts || true

final-check: ## End-to-end verification of the repo
	$(PYTHON) scripts/final_check.py

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------
docker-build: ## Build all images
	docker compose build

docker-up: ## Start the full stack (backend, frontend, mlflow, prometheus)
	docker compose up --build

docker-down: ## Stop the stack
	docker compose down

clean: ## Remove caches / build artefacts
	rm -rf .pytest_cache .ruff_cache __pycache__ */__pycache__ */*/__pycache__ \
	       frontend/build reports/figures/*.png 2>/dev/null || true
