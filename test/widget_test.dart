// Unit test sederhana untuk aplikasi POS UMKM
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_umkm/main.dart';

void main() {
  testWidgets('App should load without errors', (WidgetTester tester) async {
    // Build aplikasi
    await tester.pumpWidget(const MyApp());
    
    // Verifikasi aplikasi berhasil di-load
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Login screen should be displayed', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verifikasi elemen login screen ada
    expect(find.text('POS UMKM'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}