import { expect, test } from "@playwright/test";
import { canonicalRoute, clampPercent, shouldExecuteFlow } from "./coverage_gate";

test.describe("Playwright Coverage Gate", () => {
  test("clampPercent covers clamp branches", () => {
    expect(clampPercent(-5, 0, 100)).toBe(0);
    expect(clampPercent(150, 0, 100)).toBe(100);
    expect(clampPercent(60, 0, 100)).toBe(60);
  });

  test("canonicalRoute covers empty and normalized branches", () => {
    expect(canonicalRoute("   ")).toBe("/");
    expect(canonicalRoute(" /Profile ")).toBe("/profile");
    expect(canonicalRoute("Orders")).toBe("/orders");
  });

  test("shouldExecuteFlow covers auth and strict branches", () => {
    expect(
      shouldExecuteFlow({
        authenticated: false,
        health: "healthy",
        strictMode: false,
      }),
    ).toBeFalsy();

    expect(
      shouldExecuteFlow({
        authenticated: true,
        health: "degraded",
        strictMode: true,
      }),
    ).toBeFalsy();
    expect(
      shouldExecuteFlow({
        authenticated: true,
        health: "healthy",
        strictMode: true,
      }),
    ).toBeTruthy();

    expect(
      shouldExecuteFlow({
        authenticated: true,
        health: "degraded",
        strictMode: false,
      }),
    ).toBeTruthy();
  });
});
