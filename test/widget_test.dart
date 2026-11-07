import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fnet/main.dart';

void main() {
  testWidgets('MikrotikManagerApp loads login screen when not logged in', (WidgetTester tester) async {
    await tester.pumpWidget(const MikrotikManagerApp(
      initialLoggedIn: false,
      initialTheme: 'dark',
    ));

    expect(find.text('Mikrotik Manager'), findsWidgets);
    expect(find.text('Anda harus masuk untuk mengakses aplikasi.'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('MikrotikManagerApp loads main navigation and home content when logged in', (WidgetTester tester) async {
    await tester.pumpWidget(const MikrotikManagerApp(
      initialLoggedIn: true,
      initialTheme: 'dark',
    ));

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('PPPoE'), findsWidgets);
    expect(find.text('Hotspot'), findsWidgets);
    expect(find.text('DHCP'), findsWidgets);
    expect(find.text('Pengaturan'), findsWidgets);

    // Switch to Pengaturan tab
    await tester.tap(find.text('Pengaturan').last);
    await tester.pumpAndSettle();

    // Verify settings has no 'M. Ihwan', no 'Online' badge, and no 'Tambah Router' / 'Daftar Router' card
    expect(find.text('M. Ihwan'), findsNothing);
    expect(find.text('Online'), findsNothing);
    expect(find.text('Tambah Router'), findsNothing);
    expect(find.text('Daftar Router MikroTik'), findsNothing);

    // Verify active settings items
    expect(find.text('Auto Reconnect'), findsOneWidget);
    expect(find.text('Mode Gelap'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Keluar dari Akun Router'), 100);
    expect(find.text('Keluar dari Akun Router'), findsOneWidget);
  });

  testWidgets('Pengaturan can open Tambah Router modal with Material 3 bottom sheet', (WidgetTester tester) async {
    await tester.pumpWidget(const MikrotikManagerApp(
      initialLoggedIn: true,
      initialTheme: 'dark',
    ));

    await tester.tap(find.text('Pengaturan').last);
    await tester.pumpAndSettle();

    // Verify Tambah button exists
    expect(find.text('Tambah'), findsOneWidget);

    // Tap Tambah button to open bottom sheet
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    // Verify bottom sheet content
    expect(find.text('Tambah Profil Router'), findsOneWidget);
    expect(find.text('Nama Router'), findsOneWidget);
    expect(find.text('Host / IP Router'), findsOneWidget);
    expect(find.text('Username RouterOS'), findsOneWidget);
    expect(find.text('Tes Koneksi'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);

    // Close bottom sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Profil Router'), findsNothing);
  });

  testWidgets('PPPoE, Hotspot, and DHCP tabs load with Material 3 navigation and action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MikrotikManagerApp(
      initialLoggedIn: true,
      initialTheme: 'dark',
    ));

    // Tap PPPoE tab
    await tester.tap(find.text('PPPoE').last);
    await tester.pumpAndSettle();

    expect(find.text('Tambah Pelanggan'), findsOneWidget);

    // Tap Hotspot tab
    await tester.tap(find.text('Hotspot').last);
    await tester.pumpAndSettle();

    expect(find.text('Batch'), findsOneWidget);

    // Tap DHCP tab
    await tester.tap(find.text('DHCP').last);
    await tester.pumpAndSettle();

    expect(find.byType(SearchBar), findsOneWidget);
  });
}
