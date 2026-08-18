#!/usr/bin/env node

import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const hookDir = dirname(fileURLToPath(import.meta.url));
const root = resolve(hookDir, "..", "..");
const localCandidates =
  process.platform === "win32"
    ? [join(root, ".venv", "Scripts", "python.exe")]
    : [join(root, ".venv", "bin", "python")];
const candidates = [
  ...localCandidates.filter(existsSync).map((command) => ({ command, prefix: [] })),
  { command: "python3", prefix: [] },
  { command: "python", prefix: [] },
  { command: "py", prefix: [] },
];

function emit(additional_context) {
  process.stdout.write(JSON.stringify({ additional_context }));
}

const failures = [];
for (const candidate of candidates) {
  const result = spawnSync(
    candidate.command,
    [...candidate.prefix, "-m", "sop", "--root", root, "session", "context"],
    { cwd: root, encoding: "utf8", windowsHide: true, timeout: 15000 },
  );
  if (result.status === 0) {
    try {
      const context = JSON.parse(result.stdout);
      emit(
        [
          `SOP portable bundle: ${context.bundle_root}.`,
          `Active slug: ${context.active_slug ?? "unset"}.`,
          context.project
            ? `Project: ${JSON.stringify(context.project)}.`
            : context.project_root
              ? `Project root: ${context.project_root}; lifecycle=${context.lifecycle}; stage=${context.current_stage}; mode=${context.mode ?? "none"}.`
              : "No active project.",
          "Read .cursor/skills/sop-orchestrator/SKILL.md and route exactly one primary stage.",
          "Human gates require explicit conversational confirmation; machine state is evidence only.",
        ].join("\n"),
      );
      process.exit(0);
    } catch (error) {
      failures.push(`${candidate.command}: invalid JSON (${error.message})`);
    }
  } else {
    const detail = (result.error?.message || result.stderr || `exit ${result.status}`)
      .trim()
      .replace(/\s+/g, " ");
    failures.push(`${candidate.command}: ${detail}`);
  }
}

emit(
  [
    "SOP portable bundle startup degraded.",
    `Warning: unable to run Python session context (${failures.join("; ")}).`,
    "Read .cursor/skills/sop-orchestrator/SKILL.md and do not infer project state or approvals.",
  ].join("\n"),
);
