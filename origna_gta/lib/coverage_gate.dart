enum CoverageMode { safe, fast }

int boundedAdd(int left, int right, {int min = 0, int max = 100}) {
  final total = left + right;
  if (total < min) {
    return min;
  }
  if (total > max) {
    return max;
  }
  return total;
}

String normalizeLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return "unknown";
  }
  return normalized;
}

bool shouldProceed({
  required bool hasSession,
  required bool e2eHealthy,
  required CoverageMode mode,
}) {
  if (!hasSession) {
    return false;
  }
  if (mode == CoverageMode.safe) {
    return e2eHealthy;
  }
  return true;
}
