// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';

/// Seller Integration Guide — shows the public API endpoints, seller's product IDs,
/// and ready-to-use code snippets for activating licenses from their software.
class SellerIntegrationScreen extends ConsumerWidget {
  const SellerIntegrationScreen({super.key});

  String get _activateEndpoint => '${EnvConfig().baseUrl}/activate_license';
  String get _verifyEndpoint => '${EnvConfig().baseUrl}/verify_license';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBarFactory.simple(title: 'seller_integration.title'.tr()),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _IntroCard(),
                  const SizedBox(height: 20),
                  _HowItWorksCard(),
                  const SizedBox(height: 20),
                  _EndpointsCard(activateEndpoint: _activateEndpoint, verifyEndpoint: _verifyEndpoint),
                  const SizedBox(height: 20),
                  _SwiftSnippetCard(activateEndpoint: _activateEndpoint),
                  const SizedBox(height: 20),
                  _PythonSnippetCard(activateEndpoint: _activateEndpoint),
                  const SizedBox(height: 20),
                  _BookIntegrationCard(),
                  const SizedBox(height: 20),
                  _ErrorCodesCard(),
                  const SizedBox(height: 20),
                  _SecurityCard(),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 14, height: 1.6, color: DesignTokens.textSecondary));
  }
}

// ── Book integration ─────────────────────────────────────────────────────────

class _BookIntegrationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.menu_book_outlined,
      title: 'seller_integration.book_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BodyText('seller_integration.book_p1'.tr()),
          const SizedBox(height: 8),
          _BodyText('seller_integration.book_p2'.tr()),
          const SizedBox(height: 12),
          _StepRow(number: '✓', text: 'seller_integration.book_step1'.tr()),
          _StepRow(number: '✓', text: 'seller_integration.book_step2'.tr()),
          _StepRow(number: '✓', text: 'seller_integration.book_step3'.tr()),
          _StepRow(number: '✓', text: 'seller_integration.book_step4'.tr()),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock(this.code);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 44, 12),
          decoration: BoxDecoration(color: isDark ? DesignTokens.darkSurface : const Color(0xFFF4F4F8), borderRadius: BorderRadius.circular(8)),
          child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6)),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: Tooltip(
            message: 'common.copy'.tr(),
            child: IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'common.copy'.tr(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('common.copied'.tr()), duration: const Duration(seconds: 2)));
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EndpointRow extends StatelessWidget {
  final String method;
  final String url;
  final String label;
  const _EndpointRow({required this.method, required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DesignTokens.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: DesignTokens.primary, borderRadius: BorderRadius.circular(4)),
            child: Text(
              method,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: DesignTokens.primary),
            ),
          ),
          Tooltip(
            message: 'common.copy'.tr(),
            child: IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'common.copy'.tr(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('common.copied'.tr()), duration: const Duration(seconds: 2)));
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Endpoints ────────────────────────────────────────────────────────────────

class _EndpointsCard extends StatelessWidget {
  final String activateEndpoint;
  final String verifyEndpoint;

  const _EndpointsCard({required this.activateEndpoint, required this.verifyEndpoint});

  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.cloud_outlined,
      title: 'seller_integration.endpoints_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EndpointRow(method: 'POST', url: activateEndpoint, label: 'seller_integration.endpoints_activate_label'.tr()),
          const SizedBox(height: 8),
          _EndpointRow(method: 'POST', url: verifyEndpoint, label: 'seller_integration.endpoints_verify_label'.tr()),
          const SizedBox(height: 12),
          _SubHeading('seller_integration.endpoints_req_title'.tr()),
          const _CodeBlock('''
{
  "licenseKey": "XXXX-XXXX-XXXX-XXXX",
  "deviceId":   "<unique device identifier>",
  "platform":   "macos" | "windows" | "linux"
}'''),
          const SizedBox(height: 12),
          _SubHeading('seller_integration.endpoints_res_title'.tr()),
          const _CodeBlock('''
{
  "activated": true,
  "productName": "FXCleaner",
  "licenseKey": "XXXX-XXXX-XXXX-XXXX",
  "activatedAt": "2025-03-01T12:00:00Z"
}'''),
        ],
      ),
    );
  }
}

// ── Error codes ──────────────────────────────────────────────────────────────

class _ErrorCodesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.error_outline,
      title: 'seller_integration.error_title'.tr(),
      child: Column(
        children: [
          _ErrorRow('not_found', 404, 'seller_integration.error_404'.tr()),
          _ErrorRow('revoked', 403, 'seller_integration.error_revoked'.tr()),
          _ErrorRow('device_limit_exceeded', 403, 'seller_integration.error_limit'.tr()),
          _ErrorRow('platform_not_supported', 403, 'seller_integration.error_platform'.tr()),
          _ErrorRow('invalid_key_format', 400, 'seller_integration.error_format'.tr()),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String code;
  final int status;
  final String description;
  const _ErrorRow(this.code, this.status, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(color: DesignTokens.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: Center(
              child: Text(
                '$status',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DesignTokens.error),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(description, style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────────

class _GuideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _GuideCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.surface.withValues(alpha: 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        border: Border.all(color: DesignTokens.outline.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: DesignTokens.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── How it works detail ──────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.lock_open_outlined,
      title: 'seller_integration.how_it_works_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubHeading('seller_integration.how_it_works_act_title'.tr()),
          _BodyText('seller_integration.how_it_works_act_desc'.tr()),
          const SizedBox(height: 12),
          _SubHeading('seller_integration.how_it_works_ver_title'.tr()),
          _BodyText('seller_integration.how_it_works_ver_desc'.tr()),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DesignTokens.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.secondary.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: DesignTokens.secondary, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── Intro ────────────────────────────────────────────────────────────────────

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.integration_instructions_outlined,
      title: 'seller_integration.intro_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BodyText('seller_integration.intro_p1'.tr()),
          const SizedBox(height: 8),
          _BodyText('seller_integration.intro_p2'.tr()),
          const SizedBox(height: 12),
          _StepRow(number: '1', text: 'seller_integration.intro_step1'.tr()),
          _StepRow(number: '2', text: 'seller_integration.intro_step2'.tr()),
          _StepRow(number: '3', text: 'seller_integration.intro_step3'.tr()),
          _StepRow(number: '4', text: 'seller_integration.intro_step4'.tr()),
        ],
      ),
    );
  }
}

// ── Python snippet ───────────────────────────────────────────────────────────

class _PythonSnippetCard extends StatelessWidget {
  final String activateEndpoint;
  const _PythonSnippetCard({required this.activateEndpoint});

  String get _code =>
      '''
import requests, subprocess, platform

def device_id() -> str:
    """Returns a stable hardware identifier."""
    if platform.system() == "Darwin":
        out = subprocess.check_output(
            ["ioreg", "-rd1", "-c", "IOPlatformExpertDevice"],
            text=True
        )
        for line in out.splitlines():
            if "IOPlatformUUID" in line:
                return line.split('"')[-2]
    elif platform.system() == "Windows":
        import winreg
        key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
            r"SOFTWARE\\Microsoft\\Cryptography")
        return winreg.QueryValueEx(key, "MachineGuid")[0]
    import uuid
    return str(uuid.getnode())

def activate_license(key: str, plat: str = "windows") -> dict:
    resp = requests.post(
        "$activateEndpoint",
        json={"licenseKey": key, "deviceId": device_id(), "platform": plat},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()  # {"activated": True, "productName": "..."}''';

  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.code,
      title: 'seller_integration.python_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BodyText('seller_integration.python_desc'.tr()),
          const SizedBox(height: 10),
          _CodeBlock(_code),
          const SizedBox(height: 8),
          _InfoChip('seller_integration.python_chip'.tr()),
        ],
      ),
    );
  }
}

// ── Security ─────────────────────────────────────────────────────────────────

class _SecurityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.shield_outlined,
      title: 'seller_integration.security_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepRow(number: '1', text: 'seller_integration.security_step1'.tr()),
          _StepRow(number: '2', text: 'seller_integration.security_step2'.tr()),
          _StepRow(number: '3', text: 'seller_integration.security_step3'.tr()),
          _StepRow(number: '4', text: 'seller_integration.security_step4'.tr()),
          _StepRow(number: '5', text: 'seller_integration.security_step5'.tr()),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(
              child: Text(
                number,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DesignTokens.primary),
              ),
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5))),
        ],
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  final String text;
  const _SubHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Swift snippet ────────────────────────────────────────────────────────────

class _SwiftSnippetCard extends StatelessWidget {
  final String activateEndpoint;
  const _SwiftSnippetCard({required this.activateEndpoint});

  String get _code =>
      '''
import Foundation
import IOKit

/// Returns the hardware UUID of this Mac — stable across reboots.
func deviceID() -> String {
    let service = IOServiceGetMatchingService(
        kIOMainPortDefault,
        IOServiceMatching("IOPlatformExpertDevice")
    )
    defer { IOObjectRelease(service) }
    return IORegistryEntryCreateCFProperty(
        service,
        "IOPlatformUUID" as CFString,
        kCFAllocatorDefault, 0
    )?.takeRetainedValue() as? String ?? UUID().uuidString
}

/// Activate a license key against the Origna backend.
func activateLicense(key: String, platform: String = "macos") async throws -> Bool {
    let url = URL(string:
        "$activateEndpoint")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONSerialization.data(withJSONObject: [
        "licenseKey": key,
        "deviceId":   deviceID(),
        "platform":   platform,
    ])
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
        let body = try? JSONDecoder().decode([String: String].self, from: data)
        throw LicenseError(body?["error"] ?? "unknown_error")
    }
    return true
}''';

  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.apple,
      title: 'seller_integration.swift_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BodyText('seller_integration.swift_desc'.tr()),
          const SizedBox(height: 10),
          _CodeBlock(_code),
          const SizedBox(height: 8),
          _InfoChip('seller_integration.swift_chip'.tr()),
        ],
      ),
    );
  }
}
