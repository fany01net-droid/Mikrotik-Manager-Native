import 'dart:math';

class FormatUtils {
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = min(units.length - 1, (log(bytes) / log(1024)).floor());
    final val = bytes / pow(1024, i);
    return '${val.toStringAsFixed(1)} ${units[i]}';
  }

  static String formatSpeed(double mbps) {
    if (mbps >= 1000) {
      return '${(mbps / 1000).toStringAsFixed(1)}G';
    }
    if (mbps < 0.1) {
      return '0M';
    }
    if (mbps < 1.0) {
      return '${(mbps * 1000).round()}K';
    }
    return '${mbps.toStringAsFixed(1)}M';
  }

  static String detectDeviceVendor(String mac, String hostname) {
    final cleanMac = mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    final lowerHost = hostname.toLowerCase();

    // Hostname check
    if (lowerHost.contains('zte') || lowerHost.contains('f609') || lowerHost.contains('f670')) {
      return 'ZTE ONT';
    }
    if (lowerHost.contains('huawei') || lowerHost.contains('hg8') || lowerHost.contains('echolife')) {
      return 'Huawei ONT';
    }
    if (lowerHost.contains('fiberhome') || lowerHost.contains('an5506')) {
      return 'Fiberhome ONT';
    }
    if (lowerHost.contains('tplink') || lowerHost.contains('tp-link') || lowerHost.contains('wr840')) {
      return 'TP-Link Router';
    }
    if (lowerHost.contains('totolink') || lowerHost.contains('n200')) {
      return 'TOTOLINK';
    }
    if (lowerHost.contains('tenda') || lowerHost.contains('f3')) {
      return 'Tenda Router';
    }
    if (lowerHost.contains('mercusys')) {
      return 'Mercusys';
    }
    if (lowerHost.contains('mikrotik') || lowerHost.contains('routerboard')) {
      return 'MikroTik';
    }

    // MAC OUI Prefix check (first 6 hex chars)
    if (cleanMac.length >= 6) {
      final prefix = cleanMac.substring(0, 6);
      if (['702E22', '0019C6', '8482F4', 'D076E7', '34E12D', '4883C7', 'C864C7', 'DC028E'].contains(prefix)) {
        return 'ZTE Corporation';
      }
      if (['00259E', '00464B', '00E0FC', '0819A6', '10C61F', '200BC7', '286ED4', '4846FB', '548998', 'F4C479'].contains(prefix)) {
        return 'Huawei Technologies';
      }
      if (['000FB5', '704C53', '801382', 'A80C63', 'C4B983', 'CC81DA', 'DCB542'].contains(prefix)) {
        return 'FiberHome Telecommunication';
      }
      if (['003192', '14CC20', '1C3BF3', '30B5C2', '50D4F7', '60E327', 'E848B8', 'EC086B'].contains(prefix)) {
        return 'TP-Link Technologies';
      }
      if (['000C42', '488F5A', '64D154', 'B869F4', 'CC2DE0', 'D4CA6D', 'E48D8C'].contains(prefix)) {
        return 'MikroTik RouterBoard';
      }
      if (['0418D6', '24A43C', '68D79A', '788A20', 'B4FBE4', 'DC9FDB'].contains(prefix)) {
        return 'Ubiquiti Networks';
      }
    }

    return 'Perangkat Jaringan';
  }
}
