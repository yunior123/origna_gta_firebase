// Test driver for Flutter integration tests
// Used with: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d chrome

import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
	const env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
	const isTest = String.fromEnvironment('IS_TEST', defaultValue: 'false') == 'true';

	if (env == 'dev' && isTest) {
		await _seedDevAdminData();
	}

	await integrationDriver(
		responseDataCallback: (data) async {
			stdout.writeln(
				'[integration] reportData received: ${data == null ? 'null' : data.keys.toList()}',
			);
			final failed = data?['failedCases'];
			if (failed is List && failed.isNotEmpty) {
				stdout.writeln('[integration] Failed cases (${failed.length}):');
				for (final item in failed) {
					stdout.writeln('  - $item');
				}
			}
		},
	);
}

Future<void> _seedDevAdminData() async {
	const adminEmail = String.fromEnvironment('TEST_ADMIN_EMAIL', defaultValue: '');
	if (adminEmail.trim().isEmpty) {
		stderr.writeln('[seed] TEST_ADMIN_EMAIL not set; skipping seed.');
		return;
	}

	final scriptPath = '../functions/scripts/seed_dev_admin_data.py';

	final venvPython = File('../functions/venv/bin/python');
	final venvPython3 = File('../functions/venv/bin/python3');
	final pythonExe = venvPython.existsSync()
			? venvPython.path
			: (venvPython3.existsSync() ? venvPython3.path : 'python3');

	final result = await Process.run(
		pythonExe,
		<String>[scriptPath, '--admin-email', adminEmail],
		runInShell: true,
	);

	if (result.stdout is String && (result.stdout as String).trim().isNotEmpty) {
		// Keep logs minimal but visible when debugging.
		stdout.writeln((result.stdout as String).trim());
	}
	if (result.stderr is String && (result.stderr as String).trim().isNotEmpty) {
		stderr.writeln((result.stderr as String).trim());
	}

	if (result.exitCode != 0) {
		stderr.writeln('[seed] FAILED exitCode=${result.exitCode}');
		// Do not fail the whole run; allow tests to proceed (they may still pass).
	} else {
		stdout.writeln('[seed] OK (admin favorites + order ensured)');
	}
}
