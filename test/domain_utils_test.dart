import 'package:flutter_test/flutter_test.dart';
import 'package:fnet/utils/pppoe_utils.dart';
import 'package:fnet/utils/hotspot_utils.dart';
import 'package:fnet/models/mikrotik_models.dart';

void main() {
  group('PppoeUtils Unit Tests', () {
    test('parses ISO date from comment', () {
      final parsed = PppoeUtils.parseExpiryFromComment('exp: 2026-11-19 | Bpk Budi');
      expect(parsed.status, isNot(ExpiryStatus.noExpiry));
      expect(parsed.customerName, equals('Bpk Budi'));
      expect(parsed.expiryDate?.year, equals(2026));
      expect(parsed.expiryDate?.month, equals(11));
      expect(parsed.expiryDate?.day, equals(19));
    });

    test('extends expiry date by 30 days', () {
      final extended = PppoeUtils.extendExpiryDate('exp: 2026-11-19 | Ibu Siti', 30);
      expect(extended, contains('2026-12-19'));
      expect(extended, contains('Ibu Siti'));
    });

    test('builds expiry comment with full timestamp', () {
      final comment = PppoeUtils.buildExpiryComment('2026-12-31', 'Pak Joko');
      expect(comment, equals('2026-12-31 23:59:59 | Pak Joko'));
    });
  });

  group('HotspotUtils Unit Tests', () {
    test('parses hotspot duration strings', () {
      expect(HotspotUtils.parseHotspotDuration('30d'), equals(30 * 24 * 3600 * 1000));
      expect(HotspotUtils.parseHotspotDuration('3Jam'), equals(3 * 3600 * 1000));
      expect(HotspotUtils.parseHotspotDuration('01:30:00'), equals(90 * 60 * 1000));
    });

    test('generates batch vouchers with correct prefix and count', () {
      final batch = HotspotUtils.generateBatchVouchers(
        count: 5,
        prefix: 'vip',
        codeLength: 4,
        profile: 'paket-vip',
      );
      expect(batch.length, equals(5));
      for (final v in batch) {
        expect(v['name']?.startsWith('vip'), isTrue);
        expect(v['profile'], equals('paket-vip'));
      }
    });

    test('calculates hotspot user expiry for unused voucher', () {
      final user = HotspotUser(id: '1', name: 'user1', profile: 'default');
      final exp = HotspotUtils.calculateHotspotUserExpiry(user, []);
      expect(exp.status, equals(HotspotStatus.unused));
      expect(exp.badgeText, equals('Belum Dipakai'));
    });
  });
}
