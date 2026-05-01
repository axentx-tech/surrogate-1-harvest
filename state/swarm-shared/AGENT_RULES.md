
## 20260422_1130: **STOP outputting generic templates. START every task by reading the project's actual code, README, and existing data BEFORE writing a single recommendation.**

## [20260422_1251] Mythos-coding directives:
1. **Fix the skip marker bug immediately** — current logic always skips Postgres tests. Change to `startswith("postgresql")` + remove `__import__` trick. Add assertion to `test_scan_skips_services_with_insufficient_history`.
2. **Replace `sys.path` hack with `pyproject.toml` pythonpath config.** Also add `asyncio_mode = "auto"` to `[tool.pytest.ini_options]` since docstring claims it.
3. **Migrate `sessionmaker(class_=AsyncSession)` → `async_sessionmaker`.** SQLAlchemy 2.0 canonical.
4. **Fix fixture return type** to `AsyncGenerator[AsyncSession, None]` and rename `Session` → `session_factory`. Enable `mypy --strict` in CI to catch these.
5. **Introduce a backend-switching fixture** (SQLite vs Postgres via testcontainers) instead of skip-marker plumbing. Postgres-dependent tests should *ru

## [20260422_1252] Mythos-ops directives:
1. **Intake filter**: Orchestrator must tag artifacts by type (ops | dev | sec | bd | growth) and route to the matching reviewer. Current ops queue is 90% non-ops.
2. **Reliability claims require SLOs**: Any doc using "real-time", "always-on", "instant", "high-availability" must define SLI + target + window in the same doc, or the claim gets stripped.
3. **Security audit scope statement mandatory**: First section = threat model boundary (in-scope / out-of-scope / rationale). "N/A" verdicts must name the component that made it N/A.
4. **Audit dedup**: Mythos auditors read last audit of the same artifact; output `{new_findings, still_open, resolved_since_last}`. No more copy-paste findings across runs.
5. **Experiment template**: success metric + **guardrail metric(s)** + kill-switch are man

## [20260422_1254] Mythos-ai-engineering directives:
1. **Add RAG citations + refusal branch**: every BD/marketing/research agent must emit `[source: doc_id]` per claim and return `INSUFFICIENT_CONTEXT` below retrieval confidence threshold. Post-gen regex blocks template literals and banned marketing clichés.
2. **Route by task difficulty**: 7B for summarize/tag; 27B+ for grounded analysis and audits. Log `model × task × eval_score` for adaptive routing.
3. **Auditor memory**: persist findings as structured JSON with fingerprints; every run outputs `{new, still_open, resolved}`. No more duplicate findings across runs.
4. **Pipeline guardrails**: orchestrator validates schema, content-category, and non-empty on every agent output. Empty/mis-categorized = auto-escalate, not silent pass.
5. **Eval harness in CI**: promptfoo + ragas (faithfulnes

## [20260422_1257] Mythos-cloud directives:
1. **Replace SQLite test engine with Testcontainers Postgres.** Remove `_requires_postgres` skip guard entirely. All scan tests must run in default CI. Pin container to prod Postgres major version.
2. **Delete the `anomaly_detector` module singleton test.** Refactor access via FastAPI `Depends(get_anomaly_detector)` factory. Keeps DI seam for test overrides.
3. **Fix `sys.path` hack** → move to `pyproject.toml` `pythonpath` or editable install. Zero runtime code should touch `sys.path`.
4. **Add hypothesis property test** for severity monotonicity + one for `scan()` idempotence (re-running scan on same day produces zero new rows — directly exercises the "3-day dedup" claim).
5. **Either implement `persist_anomalies` dedup test or remove the docstring claim.** Lying docstrings are worse tha

## [20260422_1311] Mythos-ai-agent directives:
1. **Add content-type router at orchestrator intake.** Classifier outputs `{domain, confidence}`; route by domain; reject low-confidence to triage. Reject ops queue acceptance of non-ops artifacts.
2. **Persist auditor findings as fingerprinted JSON** and feed prior set into every subsequent audit. Enforce `{new, still_open, resolved, regressed}` output schema at validator.
3. **Implement two-tier model router**: 7B for summarize/dedup, qwen3.5:27b for grounded analysis/audits/citations. Log `{model_id, task_type}` per call.
4. **Enforce RAG grounding contract**: retrieval returns ≥3 chunks with doc-ids; prompt appends `[source: doc_id]` per claim; refusal branch on low retrieval score; post-gen regex reject template literals.
5. **Wrap every agent call with guardrails**: schema validator,

## 20260424_0444: STOP producing project-specific outputs without first listing and reading the target project's root files (README, manifest, src/) — treat empty-project assumptions as escalation triggers, not as findings.

## 20260424_0445: **Stop emitting reports before reading the target repo**: every scheduled agent must `ls` + read at least one project file (README, manifest, or ADR) and cite those paths in the output — no path citations = the run is invalid and must be re-queued.

## 20260427_1639: **Stop** generating positioning/research from priors alone — **start** every Costinel doc by grepping `~/Documents/Obsidian Vault/AI-Hub/knowledge/` for `costinel`, `sense-signal`, and competitor names, and cite at least 2 internal sources or 2 verifiable external URLs per claim; mark anything else 

## 20260427_1836: **STOP** producing research/growth docs without first reading `~/axentx/Costinel/README.md` + recent session files, and **STOP** inventing percentages, scores, and competitor names — cite a source (file path, URL, or benchmark) for every quantitative claim or mark it `UNKNOWN`.

## 20260427_2252: Before generating any business/growth artifact for a project, **grep the project root for README/spec/CLAUDE.md and quote ≥3 product-specific facts in the output** — refuse to emit the file if the codebase wasn't read.

## 20260427_2258: **Stop** generating positioning/growth/competitor docs without first grep'ing `~/axentx/Vanguard/` for actual product scope, README, and pricing — and **start** every such doc with a "Grounded in:" header listing the 3+ source files read, or refuse the task and ask the user for the missing context.
