import { defineConfig, devices } from "@playwright/test";

// Default target: the production deployment on Fly.io.
// Override for runs against a local server: E2E_BASE_URL=http://localhost:4000 pnpm test
const baseURL = process.env.E2E_BASE_URL ?? "https://biometric.fly.dev/";

export default defineConfig({
  testDir: "./tests",
  timeout: 30_000,
  retries: 1,
  fullyParallel: true,
  reporter: [["list"]],
  use: {
    baseURL,
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"], channel: "chrome" },
    },
  ],
});
