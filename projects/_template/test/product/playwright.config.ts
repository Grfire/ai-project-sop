# Playwright product tests
# ACCESS_URL is injected by run-full-regression.ps1

import { defineConfig } from "@playwright/test";

const baseURL = process.env.ACCESS_URL || "http://127.0.0.1:18088";

export default defineConfig({
  testDir: "./tests",
  timeout: 60_000,
  use: {
    baseURL,
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
});
