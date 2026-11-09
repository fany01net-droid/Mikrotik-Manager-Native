import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fnet/main.dart';
import 'package:fnet/models/mikrotik_models.dart';
import 'package:fnet/screens/dhcp_screen.dart';
import 'package:fnet/widgets/loading_indicator_m3e.dart';
import 'package:fnet/widgets/user_card_m3.dart';

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
    expect(find.text('Memuat data Dashboard...'), findsOneWidget);

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

    // Tap Tes Koneksi - verify inline error (no SnackBar)
    await tester.tap(find.text('Tes Koneksi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Koneksi gagal'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    // Close bottom sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Profil Router'), findsNothing);
  });

  testWidgets('PPPoE, Hotspot, and DHCP screens hide top buttons/TabBar when loading and when loading fails', (WidgetTester tester) async {
    await tester.pumpWidget(const MikrotikManagerApp(
      initialLoggedIn: true,
      initialTheme: 'dark',
    ));

    // Tap PPPoE tab - verify while loading
    await tester.tap(find.text('PPPoE').last);
    await tester.pump(); // frame 1: loading
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(LoadingIndicatorM3E), findsWidgets);
    expect(find.text('Memuat data PPPoE...'), findsOneWidget);

    // Wait until network timeout/fail
    await tester.pumpAndSettle();
    expect(find.text('Gagal Menghubungi Router'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byTooltip('Tambah Pelanggan'), findsNothing);

    // Tap Hotspot tab - verify while loading
    await tester.tap(find.text('Hotspot').last);
    await tester.pump(); // frame 1: loading
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(LoadingIndicatorM3E), findsWidgets);
    expect(find.text('Memuat data Hotspot...'), findsOneWidget);

    // Wait until network timeout/fail
    await tester.pumpAndSettle();
    expect(find.text('Gagal Menghubungi Router'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byTooltip('Tambah Voucher'), findsNothing);

    // Tap DHCP tab - verify while loading
    await tester.tap(find.text('DHCP').last);
    await tester.pump(); // frame 1: loading
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(LoadingIndicatorM3E), findsWidgets);
    expect(find.text('Memuat data DHCP Server...'), findsOneWidget);

    // Wait until network timeout/fail
    await tester.pumpAndSettle();
    expect(find.text('Gagal Menghubungi Router'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('AppBar has search button on PPPoE, Hotspot, and DHCP, replacing theme toggle', (WidgetTester tester) async {
    await tester.pumpWidget(const MikrotikManagerApp(
      initialLoggedIn: true,
      initialTheme: 'dark',
    ));

    // On Dashboard, theme icon is not in AppBar
    expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
    expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
    expect(find.byTooltip('Cari'), findsNothing);

    // Switch to PPPoE tab
    await tester.tap(find.text('PPPoE').last);
    await tester.pumpAndSettle();

    // Verify search icon exists in AppBar and theme icon does not
    expect(find.byTooltip('Cari'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);

    // Tap search in AppBar
    await tester.tap(find.byTooltip('Cari'));
    await tester.pumpAndSettle();

    // Verify search input field is visible
    expect(find.byTooltip('Tutup Pencarian'), findsOneWidget);

    // Close search
    await tester.tap(find.byTooltip('Tutup Pencarian'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cari'), findsOneWidget);
  });

  testWidgets('DHCP screen displays consistent error empty state when loading fails', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: DhcpScreen(
        profile: RouterProfile(id: 'err-test', name: 'Offline Router', host: '127.0.0.1', port: 19999, username: 'admin'),
        onConvertToPppoe: ({required name, required ip, required comment}) {},
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('Gagal Menghubungi Router'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });

  testWidgets('UserCardM3 supports selection mode and long press', (WidgetTester tester) async {
    bool longPressed = false;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: UserCardM3(
          username: 'test_user',
          profile: 'default',
          sisaHari: 'Aktif',
          isSelected: true,
          isSelectionMode: true,
          onLongPress: () => longPressed = true,
        ),
      ),
    ));

    expect(find.text('test_user'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.longPress(find.text('test_user'));
    expect(longPressed, isTrue);
  });
}
