export type E2EHealth = "healthy" | "degraded";

export function clampPercent(value: number, min = 0, max = 100): number {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

export function canonicalRoute(path: string): string {
  const normalized = path.trim().toLowerCase();
  if (!normalized) {
    return "/";
  }
  if (normalized.startsWith("/")) {
    return normalized;
  }
  return `/${normalized}`;
}

export function shouldExecuteFlow(input: {
  authenticated: boolean;
  health: E2EHealth;
  strictMode: boolean;
}): boolean {
  if (!input.authenticated) {
    return false;
  }
  if (input.strictMode) {
    return input.health === "healthy";
  }
  return true;
}
