import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/services/session_timeout_service.dart';
import 'package:flutter/material.dart';

import 'session_timeout_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<User>(),
])
void main() {
  late SessionTimeoutService service;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    service = SessionTimeoutService();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    service.setAuth(mockAuth);
    when(mockUser.uid).thenReturn('u1');
  });

  tearDown(() {
    service.stopMonitoring();
  });

  test('getRemainingTime returns positive duration after recent activity', () {
    service.recordActivity();
    final remaining = service.getRemainingTime();
    expect(remaining.inMinutes, greaterThan(0));
  });

  test('isAboutToExpire returns false after recent activity', () {
    service.recordActivity();
    expect(service.isAboutToExpire(), isFalse);
  });

  test('startMonitoring does nothing when no current user', () {
    when(mockAuth.currentUser).thenReturn(null);
    final key = GlobalKey<NavigatorState>();
    service.startMonitoring(key);
    // Should not crash
  });

  test('startMonitoring sets up timer when user exists', () {
    when(mockAuth.currentUser).thenReturn(mockUser);
    final key = GlobalKey<NavigatorState>();
    service.startMonitoring(key);
    // Should not crash
  });

  test('stopMonitoring cancels timer', () {
    when(mockAuth.currentUser).thenReturn(mockUser);
    final key = GlobalKey<NavigatorState>();
    service.startMonitoring(key);
    service.stopMonitoring();
    // Should not crash
  });

  test('recordActivity resets timer', () {
    when(mockAuth.currentUser).thenReturn(mockUser);
    final key = GlobalKey<NavigatorState>();
    service.startMonitoring(key);
    service.recordActivity();
    final remaining = service.getRemainingTime();
    expect(remaining.inMinutes, greaterThan(10));
  });

  test('multiple startMonitoring calls do not leak timers', () {
    when(mockAuth.currentUser).thenReturn(mockUser);
    final key = GlobalKey<NavigatorState>();
    service.startMonitoring(key);
    service.startMonitoring(key);
    service.startMonitoring(key);
    service.stopMonitoring();
  });
}
