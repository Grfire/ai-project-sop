---
name: python-web
description: >-
  Stack skill for FastAPI and Django web services with pytest-oriented
  verification. Only load when explicitly instructed by dev-agent. Do not
  auto-trigger.
disable-model-invocation: true
---

# Stack: Python Web (FastAPI / Django)

## Responsibilities

- FastAPI: routers, dependency injection, Pydantic models, OpenAPI stays accurate.
- Django: apps, views/serializers, settings split for test.
- Tests via `pytest` (and Django test runner if that is the repo standard).
- Typecheck with the repo's tool if configured (`mypy` / `pyright`).
- Health endpoint for Docker.

## Commands

Discover from `pyproject.toml` / `Makefile` / CI. Typical: `pytest`, `ruff check`, `uvicorn`/`gunicorn` entry in container.

## Docker

Pin dependencies; run migrations in entrypoint only if architecture requires; rebuild+restart after code changes before READY.
