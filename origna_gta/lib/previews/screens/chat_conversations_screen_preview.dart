// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/screens/chat_conversations_screen.dart';

import '../_preview_theme.dart';

@Preview(name: 'Chat Conversations — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewChatConversationsScreenMobile() => previewMobile(child: previewScopeLoggedIn(child: ChatConversationsScreen()));

@Preview(name: 'Chat Conversations — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewChatConversationsScreenTablet() => previewTablet(child: previewScopeLoggedIn(child: ChatConversationsScreen()));

@Preview(name: 'Chat Conversations — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewChatConversationsScreenDesktop() => previewDesktop(child: previewScopeLoggedIn(child: ChatConversationsScreen()));

@Preview(name: 'Chat Conversations — Web', group: 'Screens', size: Size(1440, 900))
Widget previewChatConversationsScreenWeb() => previewWeb(child: previewScopeLoggedIn(child: ChatConversationsScreen()));

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Chat Conversations Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewChatConversationsLightMobile() => previewMobile(theme: previewLightTheme, child: previewScopeLoggedIn(child: ChatConversationsScreen()));

@Preview(name: 'Chat Conversations Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewChatConversationsLightDesktop() => previewDesktop(theme: previewLightTheme, child: previewScopeLoggedIn(child: ChatConversationsScreen()));

@Preview(name: 'Chat Conversations Light — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewChatConversationsLightTablet() => previewTablet(theme: previewLightTheme, child: previewScopeLoggedIn(child: ChatConversationsScreen()));

@Preview(name: 'Chat Conversations Light — Web', group: 'Screens', size: Size(1440, 900))
Widget previewChatConversationsLightWeb() => previewWeb(theme: previewLightTheme, child: previewScopeLoggedIn(child: ChatConversationsScreen()));
