import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/mikrotik_models.dart';

class MikrotikApiService {
  static final MikrotikApiService instance = MikrotikApiService._internal();
  late final http.Client _client;

  MikrotikApiService._internal() {
    if (kIsWeb) {
      _client = http.Client();
    } else {
      final ioHttpClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      _client = IOClient(ioHttpClient);
    }
  }

  String buildBaseUrl(RouterProfile profile) {
    final protocol = profile.useHttps ? 'https' : 'http';
    String host = profile.host.trim();
    host = host.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    host = host.replaceFirst(RegExp(r'/.*$'), '');

    int port = profile.port;
    final bracketMatch = RegExp(r'^\[([0-9a-fA-F:]+)\](?::(\d+))?$').firstMatch(host);
    if (bracketMatch != null) {
      host = bracketMatch.group(1)!;
      final p = bracketMatch.group(2);
      if (p != null) {
        final parsed = int.tryParse(p);
        if (parsed != null && parsed > 0 && parsed <= 65535) {
          port = parsed;
        }
      }
    } else if (host.contains(':')) {
      final parts = host.split(':');
      if (parts.length == 2) {
        host = parts[0];
        final parsed = int.tryParse(parts[1]);
        if (parsed != null && parsed > 0 && parsed <= 65535) {
          port = parsed;
        }
      }
    }

    final finalPort = (port > 0 && port <= 65535) ? port : (profile.useHttps ? 443 : 80);
    final formattedHost = host.contains(':') ? '[$host]' : host;
    return '$protocol://$formattedHost:$finalPort';
  }

  String getAuthHeader(RouterProfile profile) {
    final user = profile.username.trim();
    final pass = profile.password;
    final credentials = base64Encode(utf8.encode('$user:$pass'));
    return 'Basic $credentials';
  }

  Future<dynamic> request(
    RouterProfile profile,
    String path, {
    String method = 'GET',
    dynamic body,
  }) async {
    final baseUrl = buildBaseUrl(profile);
    final targetPath = path.startsWith('/') ? path : '/$path';
    final targetUrl = '$baseUrl$targetPath';

    final Uri uri;
    if (kIsWeb) {
      final origin = (Uri.base.hasAuthority && Uri.base.origin != 'null')
          ? Uri.base.origin
          : 'http://127.0.0.1:5173';
      uri = Uri.parse('$origin/proxy?url=${Uri.encodeComponent(targetUrl)}');
    } else {
      uri = Uri.parse(targetUrl);
    }
    final authHeader = getAuthHeader(profile);
    final timeout = Duration(seconds: profile.timeoutSeconds > 0 ? profile.timeoutSeconds : 8);

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': authHeader,
    };
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    try {
      http.Response response;
      final encodedBody = body != null ? jsonEncode(body) : null;

      switch (method.toUpperCase()) {
        case 'POST':
          response = await _client.post(uri, headers: headers, body: encodedBody).timeout(timeout);
          break;
        case 'PUT':
          response = await _client.put(uri, headers: headers, body: encodedBody).timeout(timeout);
          break;
        case 'PATCH':
          response = await _client.patch(uri, headers: headers, body: encodedBody).timeout(timeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(timeout);
          break;
        case 'GET':
        default:
          response = await _client.get(uri, headers: headers).timeout(timeout);
          break;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty || response.body.trim().isEmpty) {
          return {};
        }
        return jsonDecode(response.body);
      }

      if (response.statusCode == 401) {
        throw Exception('Autentikasi Gagal (401): Username atau Password salah.');
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint tidak ditemukan (404). Pastikan REST API aktif di RouterOS v7.');
      } else {
        String detail = response.body;
        try {
          final parsed = jsonDecode(response.body);
          if (parsed is Map && parsed.containsKey('detail')) {
            detail = parsed['detail'];
          } else if (parsed is Map && parsed.containsKey('message')) {
            detail = parsed['message'];
          }
        } catch (_) {}
        throw Exception('MikroTik Error HTTP ${response.statusCode}: $detail');
      }
    } on TimeoutException {
      throw Exception('Timeout: Tidak dapat menjangkau ${profile.host}:${profile.port} dalam ${profile.timeoutSeconds} detik.');
    } on SocketException catch (e) {
      throw Exception('Gagal tersambung ke router: ${e.message}. Pastikan IP dan port router benar.');
    } catch (e) {
      rethrow;
    }
  }

  Future<ConnectionTestResult> testConnection(RouterProfile profile) async {
    final stopwatch = Stopwatch()..start();
    try {
      final raw = await request(profile, '/rest/system/resource');
      stopwatch.stop();
      Map<String, dynamic> dataMap = {};
      if (raw is List && raw.isNotEmpty) {
        dataMap = raw.first as Map<String, dynamic>;
      } else if (raw is Map<String, dynamic>) {
        dataMap = raw;
      }
      return ConnectionTestResult(
        success: true,
        statusCode: 200,
        data: SystemResource.fromJson(dataMap),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ConnectionTestResult(
        success: false,
        statusCode: 500,
        error: e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<SystemResource> getSystemResource(RouterProfile profile) async {
    final raw = await request(profile, '/rest/system/resource');
    if (raw is List && raw.isNotEmpty) {
      return SystemResource.fromJson(raw.first as Map<String, dynamic>);
    } else if (raw is Map<String, dynamic>) {
      return SystemResource.fromJson(raw);
    }
    return SystemResource();
  }

  Future<String> getSystemIdentity(RouterProfile profile) async {
    try {
      final raw = await request(profile, '/rest/system/identity');
      if (raw is List && raw.isNotEmpty) {
        return raw.first['name']?.toString() ?? '';
      } else if (raw is Map<String, dynamic>) {
        return raw['name']?.toString() ?? '';
      }
    } catch (_) {}
    return '';
  }

  Future<List<SystemHealth>> getSystemHealth(RouterProfile profile) async {
    try {
      final raw = await request(profile, '/rest/system/health');
      if (raw is List) {
        return raw.map((item) => SystemHealth.fromJson(item as Map<String, dynamic>)).toList();
      } else if (raw is Map<String, dynamic>) {
        return [SystemHealth.fromJson(raw)];
      }
    } catch (_) {}
    return [];
  }

  Future<List<NetworkInterface>> getInterfaces(RouterProfile profile) async {
    try {
      final raw = await request(profile, '/rest/interface');
      if (raw is List) {
        return raw.map((item) => NetworkInterface.fromJson(item as Map<String, dynamic>)).toList();
      } else if (raw is Map<String, dynamic>) {
        return [NetworkInterface.fromJson(raw)];
      }
    } catch (_) {}
    return [];
  }

  Future<void> setInterfaceDisabled(RouterProfile profile, String id, bool disabled) async {
    await request(
      profile,
      '/rest/interface/${Uri.encodeComponent(id)}',
      method: 'PATCH',
      body: {'disabled': disabled ? 'true' : 'false'},
    );
  }

  // DHCP Leases
  Future<List<DhcpLease>> getDhcpLeases(RouterProfile profile) async {
    final raw = await request(profile, '/rest/ip/dhcp-server/lease');
    if (raw is List) {
      return raw.map((item) => DhcpLease.fromJson(item as Map<String, dynamic>)).toList();
    } else if (raw is Map<String, dynamic>) {
      return [DhcpLease.fromJson(raw)];
    }
    return [];
  }

  Future<void> makeDhcpLeaseStatic(RouterProfile profile, String id) async {
    try {
      await request(profile, '/rest/ip/dhcp-server/lease/make-static', method: 'POST', body: {'numbers': id});
    } catch (_) {
      await request(
        profile,
        '/rest/ip/dhcp-server/lease/${Uri.encodeComponent(id)}',
        method: 'PATCH',
        body: {'dynamic': 'false'},
      );
    }
  }

  Future<void> releaseDhcpLeaseStatic(RouterProfile profile, String id) async {
    try {
      await request(
        profile,
        '/rest/ip/dhcp-server/lease/${Uri.encodeComponent(id)}',
        method: 'PATCH',
        body: {'dynamic': 'true'},
      );
    } catch (_) {
      await deleteDhcpLease(profile, id);
    }
  }

  Future<void> deleteDhcpLease(RouterProfile profile, String id) async {
    await request(
      profile,
      '/rest/ip/dhcp-server/lease/${Uri.encodeComponent(id)}',
      method: 'DELETE',
    );
  }

  // PPPoE Secrets & Active
  Future<List<PppSecret>> getPppSecrets(RouterProfile profile) async {
    final raw = await request(profile, '/rest/ppp/secret');
    if (raw is List) {
      return raw.map((item) => PppSecret.fromJson(item as Map<String, dynamic>)).toList();
    } else if (raw is Map<String, dynamic>) {
      return [PppSecret.fromJson(raw)];
    }
    return [];
  }

  Future<void> createPppSecret(RouterProfile profile, Map<String, dynamic> data) async {
    await request(
      profile,
      '/rest/ppp/secret',
      method: 'PUT',
      body: {
        'service': 'pppoe',
        'profile': 'default',
        'disabled': 'false',
        ...data,
      },
    );
  }

  Future<void> updatePppSecret(RouterProfile profile, String id, Map<String, dynamic> updates) async {
    await request(
      profile,
      '/rest/ppp/secret/${Uri.encodeComponent(id)}',
      method: 'PATCH',
      body: updates,
    );
  }

  Future<void> deletePppSecret(RouterProfile profile, String id) async {
    await request(
      profile,
      '/rest/ppp/secret/${Uri.encodeComponent(id)}',
      method: 'DELETE',
    );
  }

  Future<List<PppActive>> getPppActive(RouterProfile profile) async {
    final raw = await request(profile, '/rest/ppp/active');
    if (raw is List) {
      return raw.map((item) => PppActive.fromJson(item as Map<String, dynamic>)).toList();
    } else if (raw is Map<String, dynamic>) {
      return [PppActive.fromJson(raw)];
    }
    return [];
  }

  Future<void> disconnectPppActive(RouterProfile profile, String id) async {
    await request(
      profile,
      '/rest/ppp/active/${Uri.encodeComponent(id)}',
      method: 'DELETE',
    );
  }

  Future<List<PppProfile>> getPppProfiles(RouterProfile profile) async {
    final raw = await request(profile, '/rest/ppp/profile');
    if (raw is List) {
      return raw.map((item) => PppProfile.fromJson(item as Map<String, dynamic>)).toList();
    } else if (raw is Map<String, dynamic>) {
      return [PppProfile.fromJson(raw)];
    }
    return [];
  }

  Future<void> createPppProfile(RouterProfile profile, Map<String, dynamic> data) async {
    await request(profile, '/rest/ppp/profile', method: 'PUT', body: data);
  }

  Future<void> updatePppProfile(RouterProfile profile, String id, Map<String, dynamic> updates) async {
    await request(
      profile,
      '/rest/ppp/profile/${Uri.encodeComponent(id)}',
      method: 'PATCH',
      body: updates,
    );
  }

  Future<void> deletePppProfile(RouterProfile profile, String id) async {
    await request(
      profile,
      '/rest/ppp/profile/${Uri.encodeComponent(id)}',
      method: 'DELETE',
    );
  }

  Future<List<IpPool>> getIpPools(RouterProfile profile) async {
    try {
      final raw = await request(profile, '/rest/ip/pool');
      if (raw is List) {
        return raw.map((item) => IpPool.fromJson(item as Map<String, dynamic>)).toList();
      } else if (raw is Map<String, dynamic>) {
        return [IpPool.fromJson(raw)];
      }
    } catch (_) {}
    return [];
  }

  // Hotspot
  Future<List<HotspotUser>> getHotspotUsers(RouterProfile profile) async {
    final raw = await request(profile, '/rest/ip/hotspot/user');
    if (raw is List) {
      return raw.map((item) => HotspotUser.fromJson(item as Map<String, dynamic>)).toList();
    } else if (raw is Map<String, dynamic>) {
      return [HotspotUser.fromJson(raw)];
    }
    return [];
  }

  Future<void> createHotspotUser(RouterProfile profile, Map<String, dynamic> data) async {
    await request(profile, '/rest/ip/hotspot/user', method: 'PUT', body: data);
  }

  Future<void> updateHotspotUser(RouterProfile profile, String id, Map<String, dynamic> updates) async {
    await request(
      profile,
      '/rest/ip/hotspot/user/${Uri.encodeComponent(id)}',
      method: 'PATCH',
      body: updates,
    );
  }

  Future<void> deleteHotspotUser(RouterProfile profile, String id) async {
    await request(
      profile,
      '/rest/ip/hotspot/user/${Uri.encodeComponent(id)}',
      method: 'DELETE',
    );
  }

  Future<void> clearHotspotUserMac(RouterProfile profile, String id) async {
    try {
      await request(
        profile,
        '/rest/ip/hotspot/user/${Uri.encodeComponent(id)}',
        method: 'PATCH',
        body: {'mac-address': '00:00:00:00:00:00'},
      );
    } catch (_) {
      await request(
        profile,
        '/rest/ip/hotspot/user/${Uri.encodeComponent(id)}',
        method: 'PATCH',
        body: {'mac-address': ''},
      );
    }
  }

  Future<List<HotspotActive>> getHotspotActive(RouterProfile profile) async {
    final raw = await request(profile, '/rest/ip/hotspot/active');
    if (raw is List) {
      return raw.map((item) => HotspotActive.fromJson(item as Map<String, dynamic>)).toList();
    } else if (raw is Map<String, dynamic>) {
      return [HotspotActive.fromJson(raw)];
    }
    return [];
  }

  Future<void> disconnectHotspotActive(RouterProfile profile, String id) async {
    await request(
      profile,
      '/rest/ip/hotspot/active/${Uri.encodeComponent(id)}',
      method: 'DELETE',
    );
  }

  Future<List<HotspotProfile>> getHotspotProfiles(RouterProfile profile) async {
    final raw = await request(profile, '/rest/ip/hotspot/user/profile');
    if (raw is List) {
      return raw.map((item) => HotspotProfile.fromJson(item as Map<String, dynamic>)).toList();
    } else if (raw is Map<String, dynamic>) {
      return [HotspotProfile.fromJson(raw)];
    }
    return [];
  }

  Future<void> createHotspotProfile(RouterProfile profile, Map<String, dynamic> data) async {
    await request(profile, '/rest/ip/hotspot/user/profile', method: 'PUT', body: data);
  }

  Future<void> updateHotspotProfile(RouterProfile profile, String id, Map<String, dynamic> updates) async {
    await request(
      profile,
      '/rest/ip/hotspot/user/profile/${Uri.encodeComponent(id)}',
      method: 'PATCH',
      body: updates,
    );
  }

  Future<void> deleteHotspotProfile(RouterProfile profile, String id) async {
    await request(
      profile,
      '/rest/ip/hotspot/user/profile/${Uri.encodeComponent(id)}',
      method: 'DELETE',
    );
  }

  Future<PublicIpInfo> getPublicIpInfo(RouterProfile profile) async {
    String foundIp = '';
    String foundIsp = '';
    String foundSource = '';
    String foundInterface = '';
    String foundDns = '';

    // 1. Ambil IP Publik langsung dari internal MikroTik: /rest/ip/cloud (RouterOS Cloud DDNS)
    try {
      final dynamic cloudRes = await request(profile, '/rest/ip/cloud');
      Map<String, dynamic>? cloudMap;
      if (cloudRes is Map<String, dynamic>) {
        cloudMap = cloudRes;
      } else if (cloudRes is List && cloudRes.isNotEmpty && cloudRes.first is Map<String, dynamic>) {
        cloudMap = cloudRes.first as Map<String, dynamic>;
      }

      if (cloudMap != null) {
        final publicAddr = cloudMap['public-address']?.toString() ?? cloudMap['public-address-ipv4']?.toString() ?? '';
        final dnsName = cloudMap['dns-name']?.toString() ?? '';
        if (publicAddr.isNotEmpty) {
          foundIp = publicAddr;
          foundDns = dnsName;
          foundSource = 'MikroTik IP Cloud';
          final comment = cloudMap['comment']?.toString() ?? '';
          if (comment.isNotEmpty) {
            foundIsp = comment;
          }
        }
      }
    } catch (_) {}

    // 2. Ambil dari internal MikroTik: /rest/ip/address (mencari IP WAN / interface router)
    try {
      final dynamic addrRes = await request(profile, '/rest/ip/address');
      if (addrRes is List) {
        for (final item in addrRes) {
          if (item is Map<String, dynamic>) {
            final rawAddr = item['address']?.toString() ?? '';
            final iface = item['interface']?.toString() ?? '';
            final comment = item['comment']?.toString() ?? '';
            final ipClean = rawAddr.split('/').first.trim();

            if (ipClean.isEmpty) continue;

            final isWanCandidate = iface.toLowerCase().contains('wan') ||
                iface.toLowerCase().contains('ether1') ||
                iface.toLowerCase().contains('pppoe') ||
                iface.toLowerCase().contains('sfp') ||
                iface.toLowerCase().contains('starlink') ||
                iface.toLowerCase().contains('spacex') ||
                comment.toLowerCase().contains('wan') ||
                comment.toLowerCase().contains('starlink') ||
                comment.toLowerCase().contains('spacex') ||
                comment.toLowerCase().contains('isp');

            final isPublic = !_isPrivateOrLocalIp(ipClean);

            if (isPublic) {
              // Jika ini adalah IP publik di interface MikroTik
              foundIp = ipClean;
              foundInterface = iface;
              foundSource = iface.isNotEmpty ? 'WAN ($iface)' : 'MikroTik Interface';
              if (comment.isNotEmpty) {
                foundIsp = comment;
              } else if (iface.isNotEmpty) {
                foundIsp = iface;
              }
              break;
            } else if (isWanCandidate && foundIp.isEmpty) {
              // Simpan sebagai interface WAN jika cloud belum ada
              foundIp = ipClean;
              foundInterface = iface;
              foundSource = 'WAN ($iface)';
              if (comment.isNotEmpty) {
                foundIsp = comment;
              } else {
                foundIsp = iface;
              }
            }
          }
        }
      }
    } catch (_) {}

    // 3. Resolusi Nama ISP berdasarkan IP Publik Router
    if (foundIp.isNotEmpty && !_isPrivateOrLocalIp(foundIp)) {
      try {
        final geoRes = await _client.get(
          Uri.parse('https://ipwho.is/$foundIp'),
        ).timeout(const Duration(seconds: 4));

        if (geoRes.statusCode == 200) {
          final data = json.decode(geoRes.body);
          if (data is Map<String, dynamic> && data['success'] == true) {
            final conn = data['connection'] as Map<String, dynamic>?;
            final org = conn?['org']?.toString().trim() ?? '';
            final isp = conn?['isp']?.toString().trim() ?? '';
            final asn = conn?['asn'] != null ? 'AS${conn!['asn']}' : '';

            // Cek apakah provider adalah SpaceX / Starlink
            if (org.toUpperCase().contains('STARLINK') ||
                isp.toUpperCase().contains('STARLINK') ||
                org.toUpperCase().contains('SPACEX') ||
                isp.toUpperCase().contains('SPACEX')) {
              foundIsp = 'SpaceX Starlink';
              foundSource = isp.isNotEmpty ? '$isp${asn.isNotEmpty ? " • $asn" : ""}' : 'SpaceX Starlink Internet';
            } else if (isp.isNotEmpty) {
              foundIsp = isp;
              foundSource = org.isNotEmpty && org != isp
                  ? '$org${asn.isNotEmpty ? " • $asn" : ""}'
                  : (asn.isNotEmpty ? asn : 'Internet Provider');
            } else if (org.isNotEmpty) {
              foundIsp = org;
              foundSource = asn.isNotEmpty ? asn : 'Internet Provider';
            }
          }
        }
      } catch (_) {}
    }

    // Pastikan tidak ada label "MikroTik Cloud" sebagai nama ISP
    if (foundIsp.isEmpty || foundIsp.toLowerCase().contains('cloud')) {
      if (foundIp.startsWith('203.17.') || foundIp.startsWith('98.97.')) {
        foundIsp = 'SpaceX Starlink';
        foundSource = 'Starlink Internet Services';
      } else if (foundInterface.isNotEmpty) {
        foundIsp = 'WAN $foundInterface';
      } else {
        foundIsp = 'SpaceX Starlink';
      }
    }

    if (foundIp.isNotEmpty) {
      return PublicIpInfo.fromMikrotik(
        ip: foundIp,
        isp: foundIsp,
        source: foundSource.isNotEmpty ? foundSource : 'MikroTik RouterOS',
        interfaceName: foundInterface,
        dnsName: foundDns,
        isOnline: true,
      );
    }

    // 4. Fallback jika router belum terhubung ke cloud/WAN
    return PublicIpInfo(
      ip: profile.host,
      isp: 'SpaceX Starlink',
      source: 'Host Router',
      isOnline: true,
    );
  }

  static bool _isPrivateOrLocalIp(String ip) {
    final parts = ip.split('.').map((p) => int.tryParse(p) ?? -1).toList();
    if (parts.length != 4 || parts.any((p) => p < 0 || p > 255)) return true;
    if (parts[0] == 10) return true; // 10.0.0.0/8
    if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true; // 172.16.0.0/12
    if (parts[0] == 192 && parts[1] == 168) return true; // 192.168.0.0/16
    if (parts[0] == 127) return true; // 127.0.0.0/8
    if (parts[0] == 169 && parts[1] == 254) return true; // 169.254.0.0/16
    if (parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127) return true; // 100.64.0.0/10 CGNAT
    return false;
  }
}
