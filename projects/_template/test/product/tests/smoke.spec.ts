import { test, expect } from "@playwright/test";

test("health or entry is reachable", async ({ page }) => {
  const res = await page.goto("/");
  expect(res, "entry should respond").not.toBeNull();
  expect(res!.ok(), `status ${res!.status()}`).toBeTruthy();
});
