import { expect, test } from "@playwright/test";

test.describe("Once — public flows", () => {
  // Public landing (anonymous visitor sees the marketing hero + auth CTAs)
  test("landing shows hero copy and auth CTAs", async ({ page }) => {
    await page.goto("/");

    await expect(page.getByText("Grow Smarter. Work Faster.")).toBeVisible();
    await expect(page.getByText("Clock. Track. Manage.").first()).toBeVisible();
    await expect(
      page.getByText(
        /Live attendance data straight from your biometric devices/,
      ),
    ).toBeVisible();

    const signIn = page.getByRole("link", { name: "Sign in" }).first();
    await expect(signIn).toBeVisible();
    await expect(signIn).toHaveAttribute("href", /sign-in/);

    const register = page.getByRole("link", { name: "Create account" });
    await expect(register).toBeVisible();
    await expect(register).toHaveAttribute("href", /register/);
  });

  test("sign-in form renders with email and password fields", async ({
    page,
  }) => {
    await page.goto("/sign-in");

    await expect(
      page.getByText("Email", { exact: true }).first(),
    ).toBeVisible();
    await expect(page.locator('input[type="email"]').first()).toBeVisible();
    await expect(page.locator('input[type="password"]').first()).toBeVisible();

    const submit = page.locator('button:not([type="hidden"])').first();
    await expect(submit).toBeVisible();

    const forgot = page.getByRole("link", { name: /Forgot your password/ });
    await expect(forgot).toBeVisible();
    await expect(forgot.first()).toHaveAttribute("href", /reset/);
  });

  test("register form renders", async ({ page }) => {
    // The auth page DOM contains several AshAuthentication strategy forms;
    // match against the visible one.
    await page.goto("/register");

    await expect(
      page.locator('input[type="email"]:visible').first(),
    ).toBeVisible();
    await expect(
      page.locator('input[type="password"]:visible').first(),
    ).toBeVisible();
  });

  test("password reset form renders", async ({ page }) => {
    await page.goto("/reset");

    await expect(
      page.getByText(/Request reset password link|reset/i).first(),
    ).toBeVisible();
    await expect(
      page.locator('input[type="email"]:visible').first(),
    ).toBeVisible();
  });

  test("app pages report no HTTP 5xx", async ({ page }) => {
    const badRoutes = new Set<string>();
    page.on("response", (response) => {
      if (response.status() >= 500)
        badRoutes.add(`${response.status()} ${response.url()}`);
    });

    for (const route of ["/", "/sign-in", "/register"]) {
      await page.goto(route);
      await page.waitForLoadState("networkidle");
    }

    expect([...badRoutes]).toEqual([]);
  });
});
