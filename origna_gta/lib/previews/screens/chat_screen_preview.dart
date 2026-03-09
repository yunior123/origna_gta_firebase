// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/chat_screen.dart';

import '../_preview_theme.dart';

// Default — chat view (will show loading state while Firebase stub resolves)
Widget _chatContent() => previewScopeLoggedIn(
  child: ChatScreen(productId: 'preview-id', productTitle: 'Premium Headphones'),
);

// French locale variant
Widget _chatContentFr() => previewScopeLoggedIn(
  child: ChatScreen(productId: 'preview-fr', productTitle: 'Casque Audio Premium'),
);

@Preview(name: 'Direct Messaging — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewChatScreenMobile() => previewMobile(child: _chatContent());

@Preview(name: 'Direct Messaging — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewChatScreenTablet() => previewTablet(child: _chatContent());

@Preview(name: 'Direct Messaging — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewChatScreenDesktop() => previewDesktop(child: _chatContent());

@Preview(name: 'Direct Messaging — Web', group: 'Screens', size: Size(1440, 900))
Widget previewChatScreenWeb() => previewWeb(child: _chatContent());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Direct Messaging Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewChatScreenLightMobile() => previewMobile(theme: previewLightTheme, child: _chatContent());

@Preview(name: 'Direct Messaging Light — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewChatScreenLightTablet() => previewTablet(theme: previewLightTheme, child: _chatContent());

@Preview(name: 'Direct Messaging Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewChatScreenLightDesktop() => previewDesktop(theme: previewLightTheme, child: _chatContent());

@Preview(name: 'Direct Messaging Light — Web', group: 'Screens', size: Size(1440, 900))
Widget previewChatScreenLightWeb() => previewWeb(theme: previewLightTheme, child: _chatContent());

// ── French Locale ─────────────────────────────────────────────────────────────
@Preview(name: 'Direct Messaging French — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewChatScreenFrMobile() => previewMobile(locale: const Locale('fr'), child: _chatContentFr());

@Preview(name: 'Direct Messaging French — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewChatScreenFrDesktop() => previewDesktop(locale: const Locale('fr'), child: _chatContentFr());
