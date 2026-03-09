// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/screens/notifications_screen.dart';

import '../_preview_theme.dart';

Widget _notificationsLoading() => previewScope(
  child: NotificationsScreenLayout(
    notificationsAsync: const AsyncValue.loading(),
    uid: 'preview-uid',
    onRefresh: () async {},
    onBack: () {},
    onMarkAllRead: () async {},
    onMarkRead: (n) async {},
  ),
);

Widget _notificationsEmpty() => previewScope(
  child: NotificationsScreenLayout(
    notificationsAsync: const AsyncValue.data([]),
    uid: 'preview-uid',
    onRefresh: () async {},
    onBack: () {},
    onMarkAllRead: () async {},
    onMarkRead: (n) async {},
  ),
);

// ── Loading Dark ─────────────────────────────────────────────────────────────
@Preview(name: 'Notifications Center Dark — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewNotificationsScreenMobile() => previewMobile(child: _notificationsLoading());

@Preview(name: 'Notifications Center Dark — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewNotificationsScreenTablet() => previewTablet(child: _notificationsLoading());

@Preview(name: 'Notifications Center Dark — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewNotificationsScreenDesktop() => previewDesktop(child: _notificationsLoading());

@Preview(name: 'Notifications Center Dark — Web', group: 'Screens', size: Size(1440, 900))
Widget previewNotificationsScreenWeb() => previewWeb(child: _notificationsLoading());

// ── Empty State Dark ─────────────────────────────────────────────────────────
@Preview(name: 'Notifications Empty Dark — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewNotificationsScreenEmptyMobile() => previewMobile(child: _notificationsEmpty());

@Preview(name: 'Notifications Empty Dark — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewNotificationsScreenEmptyTablet() => previewTablet(child: _notificationsEmpty());

@Preview(name: 'Notifications Empty Dark — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewNotificationsScreenEmptyDesktop() => previewDesktop(child: _notificationsEmpty());

@Preview(name: 'Notifications Empty Dark — Web', group: 'Screens', size: Size(1440, 900))
Widget previewNotificationsScreenEmptyWeb() => previewWeb(child: _notificationsEmpty());

// ── Light mode ───────────────────────────────────────────────────────────────
@Preview(name: 'Notifications Center Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewNotificationsLightMobile() => previewMobile(theme: previewLightTheme, child: _notificationsLoading());

@Preview(name: 'Notifications Center Light — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewNotificationsLightTablet() => previewTablet(theme: previewLightTheme, child: _notificationsLoading());

@Preview(name: 'Notifications Center Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewNotificationsLightDesktop() => previewDesktop(theme: previewLightTheme, child: _notificationsLoading());

@Preview(name: 'Notifications Center Light — Web', group: 'Screens', size: Size(1440, 900))
Widget previewNotificationsLightWeb() => previewWeb(theme: previewLightTheme, child: _notificationsLoading());

@Preview(name: 'Notifications Empty Light — Mobile', group: 'Screens', size: Size(390, 844))
Widget previewNotificationsEmptyLightMobile() => previewMobile(theme: previewLightTheme, child: _notificationsEmpty());

@Preview(name: 'Notifications Empty Light — Tablet', group: 'Screens', size: Size(768, 1024))
Widget previewNotificationsEmptyLightTablet() => previewTablet(theme: previewLightTheme, child: _notificationsEmpty());

@Preview(name: 'Notifications Empty Light — Desktop', group: 'Screens', size: Size(1280, 800))
Widget previewNotificationsEmptyLightDesktop() => previewDesktop(theme: previewLightTheme, child: _notificationsEmpty());

@Preview(name: 'Notifications Empty Light — Web', group: 'Screens', size: Size(1440, 900))
Widget previewNotificationsEmptyLightWeb() => previewWeb(theme: previewLightTheme, child: _notificationsEmpty());
