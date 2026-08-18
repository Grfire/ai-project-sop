---
name: java-spring
description: >-
  Stack skill for Java Spring Boot structure, TDD, and verification commands.
  Only load when explicitly instructed by dev-agent. Do not auto-trigger.
disable-model-invocation: true
---

# Stack: Java Spring

Influenced by affaan-m everything-claude-code Spring Boot pattern/TDD/verification skills.

## Responsibilities

- Follow existing package layering (controller/service/repository or hexagonal if present).
- Prefer constructor injection; avoid field injection in new code.
- Configuration via `application*.yml` / profiles for test.
- Tests: unit for services; `@SpringBootTest` / `@WebMvcTest` / Testcontainers as repo already does.
- Actuator or custom `/health` for compose healthcheck.

## Commands

Prefer wrappers: `./mvnw test`, `./gradlew test`, `./mvnw -DskipTests package`.

## Docker

Multi-stage build (JDK build → JRE run). Rebuild image after code changes before READY.
