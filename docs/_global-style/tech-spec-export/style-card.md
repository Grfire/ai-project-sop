# Style card — `tech-spec-export`

## Voice
- Language: Chinese by default; retain canonical API and domain names
- Person / tone: declarative and precise
- Formality: engineering specification

## Structure
- Title pattern: `<系统名> 技术规格（导出版）`
- Heading levels used: H1–H4
- Numbering: mirror architecture-pack section and decision identifiers
- Opening meta block: architecture revision, PRD revision, export time

## Patterns
- Tables when: interfaces, data fields, NFRs, decision traceability
- Lists when: invariants, failure modes, constraints
- Callouts / 注意: assumptions and unresolved risks

## Required sections
1. Scope and source precedence
2. Architecture and module boundaries
3. Interfaces and data
4. NFRs, deployment constraints, and decisions

## Forbidden
- New design decisions introduced during export
- Copying stale or contradicted architecture facts

## Fingerprint (excerpt)
```text
本文件是已确认架构包的导出，不创建新的技术决策。
产品规则以 PRD 为准，技术规则以 design pack 为准。
接口、数据与模块边界保留其原始标识。
发现冲突时标记来源并返回 ARCH 处理。
```
