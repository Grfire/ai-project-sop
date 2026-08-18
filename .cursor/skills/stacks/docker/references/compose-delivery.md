# Compose Delivery Patterns

Distilled for test-environment delivery (not production hardening).

## Minimal layout

```
Dockerfile
docker-compose.yml   # or compose.yaml
```

## Required practices

- Multi-stage build when app needs compile step (Node/Java) to keep runtime image lean.
- `HEALTHCHECK` or compose `healthcheck` on the public service.
- Explicit ports for the test entry only.
- One primary public URL; dependencies on internal network.
- `.dockerignore` excludes `node_modules`, `.git`, build caches, secrets.
- Env via compose `environment` / `.env.example` — never commit real secrets.

## Commands (adapt to repo)

```bash
docker compose -f docker-compose.yml build
docker compose -f docker-compose.yml up -d
docker compose -f docker-compose.yml ps
docker compose -f docker-compose.yml logs --tail=100
curl -sfS "$ACCESS_URL"   # or health_url
docker compose -f docker-compose.yml down
```

## After every runtime change

`build` → `up -d` (recreate) → health → smoke. Record container/image IDs on Run Card.
