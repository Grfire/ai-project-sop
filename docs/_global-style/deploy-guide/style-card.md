# Style card — `deploy-guide`

## Voice
- Language: Chinese by default; preserve exact command and configuration names
- Person / tone: imperative, operations-focused, evidence-based
- Formality: technical runbook

## Structure
- Title pattern: `<系统名> 部署指南`
- Heading levels used: H1–H3
- Numbering: ordered procedures with explicit verification after each phase
- Opening meta block: version, environment, owner, source handoff revision

## Patterns
- Tables when: environment variables, ports, dependencies, rollback criteria
- Lists when: prerequisites and post-deploy checks
- Callouts / 注意: secrets, destructive actions, downtime

## Required sections
1. Preconditions and dependencies
2. Configuration
3. Start, verify, stop, and restart
4. Rollback and troubleshooting

## Forbidden
- Real secrets or fabricated commands
- Claiming production readiness from smoke evidence alone

## Fingerprint (excerpt)
```text
部署前，确认依赖服务健康且配置已通过审查。
1. 按代码交接文件执行构建命令。
2. 启动服务并等待健康检查通过。
3. 访问 health_url，保存时间与结果。
验证失败时停止推进，并按回滚步骤恢复。
```
