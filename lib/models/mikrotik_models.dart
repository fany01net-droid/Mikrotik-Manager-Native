class RouterProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final bool useHttps;
  final String username;
  final String password;
  final bool rememberPassword;
  final int timeoutSeconds;

  RouterProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 80,
    this.useHttps = false,
    required this.username,
    this.password = '',
    this.rememberPassword = true,
    this.timeoutSeconds = 8,
  });

  factory RouterProfile.fromJson(Map<String, dynamic> json) {
    return RouterProfile(
      id: json['id']?.toString() ?? 'profile-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'MikroTik Utama',
      host: json['host']?.toString() ?? '192.168.88.1',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 80,
      useHttps: json['useHttps'] == true,
      username: json['username']?.toString() ?? 'admin',
      password: json['password']?.toString() ?? '',
      rememberPassword: json['rememberPassword'] != false,
      timeoutSeconds: int.tryParse(json['timeoutSeconds']?.toString() ?? '') ?? 8,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'useHttps': useHttps,
      'username': username,
      'password': password,
      'rememberPassword': rememberPassword,
      'timeoutSeconds': timeoutSeconds,
    };
  }

  RouterProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    bool? useHttps,
    String? username,
    String? password,
    bool? rememberPassword,
    int? timeoutSeconds,
  }) {
    return RouterProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      useHttps: useHttps ?? this.useHttps,
      username: username ?? this.username,
      password: password ?? this.password,
      rememberPassword: rememberPassword ?? this.rememberPassword,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }
}

class SystemResource {
  final String uptime;
  final String version;
  final String buildTime;
  final int freeMemory;
  final int totalMemory;
  final String cpu;
  final int cpuCount;
  final int cpuFrequency;
  final int cpuLoad;
  final int freeHddSpace;
  final int totalHddSpace;
  final String architectureName;
  final String boardName;
  final String platform;
  final int badBlocks;

  SystemResource({
    this.uptime = '0s',
    this.version = '',
    this.buildTime = '',
    this.freeMemory = 0,
    this.totalMemory = 0,
    this.cpu = '',
    this.cpuCount = 1,
    this.cpuFrequency = 0,
    this.cpuLoad = 0,
    this.freeHddSpace = 0,
    this.totalHddSpace = 0,
    this.architectureName = '',
    this.boardName = '',
    this.platform = '',
    this.badBlocks = 0,
  });

  factory SystemResource.fromJson(Map<String, dynamic> json) {
    int parseNum(dynamic val, [int fallback = 0]) {
      if (val == null) return fallback;
      if (val is num) return val.round();
      final str = val.toString().replaceAll('%', '').trim();
      return num.tryParse(str)?.round() ?? fallback;
    }

    return SystemResource(
      uptime: json['uptime']?.toString() ?? '0s',
      version: json['version']?.toString() ?? '',
      buildTime: json['build-time']?.toString() ?? '',
      freeMemory: parseNum(json['free-memory']),
      totalMemory: parseNum(json['total-memory']),
      cpu: json['cpu']?.toString() ?? '',
      cpuCount: parseNum(json['cpu-count'], 1),
      cpuFrequency: parseNum(json['cpu-frequency']),
      cpuLoad: parseNum(json['cpu-load']),
      freeHddSpace: parseNum(json['free-hdd-space']),
      totalHddSpace: parseNum(json['total-hdd-space']),
      architectureName: json['architecture-name']?.toString() ?? '',
      boardName: json['board-name']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      badBlocks: parseNum(json['bad-blocks']),
    );
  }

  int get memoryLoadPercent {
    if (totalMemory <= 0) return 0;
    final used = totalMemory - freeMemory;
    return ((used / totalMemory) * 100).clamp(0, 100).round();
  }

  int get hddLoadPercent {
    if (totalHddSpace <= 0) return 0;
    final used = totalHddSpace - freeHddSpace;
    return ((used / totalHddSpace) * 100).clamp(0, 100).round();
  }
}

class SystemHealth {
  final String name;
  final String value;
  final String type;

  SystemHealth({
    required this.name,
    required this.value,
    this.type = '',
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    return SystemHealth(
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }
}

class NetworkInterface {
  final String id;
  final String name;
  final String type;
  final bool running;
  final bool disabled;
  final String comment;
  final String macAddress;
  final int rxByte;
  final int txByte;

  NetworkInterface({
    required this.id,
    required this.name,
    this.type = '',
    this.running = false,
    this.disabled = false,
    this.comment = '',
    this.macAddress = '',
    this.rxByte = 0,
    this.txByte = 0,
  });

  factory NetworkInterface.fromJson(Map<String, dynamic> json) {
    return NetworkInterface(
      id: json['.id']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      running: json['running'] == true || json['running'] == 'true',
      disabled: json['disabled'] == true || json['disabled'] == 'true',
      comment: json['comment']?.toString() ?? '',
      macAddress: json['mac-address']?.toString() ?? '',
      rxByte: int.tryParse(json['rx-byte']?.toString() ?? '') ?? 0,
      txByte: int.tryParse(json['tx-byte']?.toString() ?? '') ?? 0,
    );
  }
}

class DhcpLease {
  final String id;
  final String address;
  final String macAddress;
  final String server;
  final String hostName;
  final String status;
  final String expiresAfter;
  final String lastSeen;
  final String comment;
  final bool disabled;
  final bool isDynamic;

  DhcpLease({
    required this.id,
    required this.address,
    required this.macAddress,
    this.server = '',
    this.hostName = '',
    this.status = 'bound',
    this.expiresAfter = '',
    this.lastSeen = '',
    this.comment = '',
    this.disabled = false,
    this.isDynamic = true,
  });

  factory DhcpLease.fromJson(Map<String, dynamic> json) {
    return DhcpLease(
      id: json['.id']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      macAddress: json['mac-address']?.toString() ?? '',
      server: json['server']?.toString() ?? '',
      hostName: json['host-name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'bound',
      expiresAfter: json['expires-after']?.toString() ?? '',
      lastSeen: json['last-seen']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      disabled: json['disabled'] == true || json['disabled'] == 'true',
      isDynamic: json['dynamic'] == true || json['dynamic'] == 'true',
    );
  }
}

class PppSecret {
  final String id;
  final String name;
  final String password;
  final String service;
  final String profile;
  final String comment;
  final bool disabled;
  final String remoteAddress;
  final String localAddress;
  final String callerId;
  final String lastLoggedOut;

  PppSecret({
    required this.id,
    required this.name,
    this.password = '',
    this.service = 'pppoe',
    this.profile = 'default',
    this.comment = '',
    this.disabled = false,
    this.remoteAddress = '',
    this.localAddress = '',
    this.callerId = '',
    this.lastLoggedOut = '',
  });

  factory PppSecret.fromJson(Map<String, dynamic> json) {
    return PppSecret(
      id: json['.id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      service: json['service']?.toString() ?? 'pppoe',
      profile: json['profile']?.toString() ?? 'default',
      comment: json['comment']?.toString() ?? '',
      disabled: json['disabled'] == true || json['disabled'] == 'true',
      remoteAddress: json['remote-address']?.toString() ?? '',
      localAddress: json['local-address']?.toString() ?? '',
      callerId: json['caller-id']?.toString() ?? '',
      lastLoggedOut: json['last-logged-out']?.toString() ?? '',
    );
  }
}

class PppActive {
  final String id;
  final String name;
  final String service;
  final String callerId;
  final String address;
  final String uptime;
  final String sessionId;

  PppActive({
    required this.id,
    required this.name,
    this.service = 'pppoe',
    this.callerId = '',
    this.address = '',
    this.uptime = '',
    this.sessionId = '',
  });

  factory PppActive.fromJson(Map<String, dynamic> json) {
    return PppActive(
      id: json['.id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      service: json['service']?.toString() ?? 'pppoe',
      callerId: json['caller-id']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      uptime: json['uptime']?.toString() ?? '',
      sessionId: json['session-id']?.toString() ?? '',
    );
  }
}

class PppProfile {
  final String id;
  final String name;
  final String localAddress;
  final String remoteAddress;
  final String rateLimit;
  final String onlyOne;
  final String dnsServer;
  final String comment;

  PppProfile({
    required this.id,
    required this.name,
    this.localAddress = '',
    this.remoteAddress = '',
    this.rateLimit = '',
    this.onlyOne = 'default',
    this.dnsServer = '',
    this.comment = '',
  });

  factory PppProfile.fromJson(Map<String, dynamic> json) {
    return PppProfile(
      id: json['.id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      localAddress: json['local-address']?.toString() ?? '',
      remoteAddress: json['remote-address']?.toString() ?? '',
      rateLimit: json['rate-limit']?.toString() ?? '',
      onlyOne: json['only-one']?.toString() ?? 'default',
      dnsServer: json['dns-server']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
    );
  }
}

class IpPool {
  final String id;
  final String name;
  final String ranges;
  final String nextPool;

  IpPool({
    required this.id,
    required this.name,
    this.ranges = '',
    this.nextPool = '',
  });

  factory IpPool.fromJson(Map<String, dynamic> json) {
    return IpPool(
      id: json['.id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      ranges: json['ranges']?.toString() ?? '',
      nextPool: json['next-pool']?.toString() ?? '',
    );
  }
}

class HotspotUser {
  final String id;
  final String name;
  final String password;
  final String profile;
  final String uptime;
  final int bytesIn;
  final int bytesOut;
  final String comment;
  final bool disabled;
  final String limitUptime;
  final int limitBytesTotal;
  final String server;
  final String macAddress;

  HotspotUser({
    required this.id,
    required this.name,
    this.password = '',
    this.profile = 'default',
    this.uptime = '',
    this.bytesIn = 0,
    this.bytesOut = 0,
    this.comment = '',
    this.disabled = false,
    this.limitUptime = '',
    this.limitBytesTotal = 0,
    this.server = '',
    this.macAddress = '',
  });

  factory HotspotUser.fromJson(Map<String, dynamic> json) {
    return HotspotUser(
      id: json['.id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      profile: json['profile']?.toString() ?? 'default',
      uptime: json['uptime']?.toString() ?? '',
      bytesIn: int.tryParse(json['bytes-in']?.toString() ?? '') ?? 0,
      bytesOut: int.tryParse(json['bytes-out']?.toString() ?? '') ?? 0,
      comment: json['comment']?.toString() ?? '',
      disabled: json['disabled'] == true || json['disabled'] == 'true',
      limitUptime: json['limit-uptime']?.toString() ?? '',
      limitBytesTotal: int.tryParse(json['limit-bytes-total']?.toString() ?? '') ?? 0,
      server: json['server']?.toString() ?? '',
      macAddress: json['mac-address']?.toString() ?? '',
    );
  }
}

class HotspotActive {
  final String id;
  final String user;
  final String address;
  final String macAddress;
  final String uptime;
  final String sessionTimeLeft;
  final int bytesIn;
  final int bytesOut;
  final String loginBy;
  final String server;

  HotspotActive({
    required this.id,
    required this.user,
    required this.address,
    required this.macAddress,
    this.uptime = '',
    this.sessionTimeLeft = '',
    this.bytesIn = 0,
    this.bytesOut = 0,
    this.loginBy = '',
    this.server = '',
  });

  factory HotspotActive.fromJson(Map<String, dynamic> json) {
    return HotspotActive(
      id: json['.id']?.toString() ?? '',
      user: json['user']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      macAddress: json['mac-address']?.toString() ?? '',
      uptime: json['uptime']?.toString() ?? '',
      sessionTimeLeft: json['session-time-left']?.toString() ?? '',
      bytesIn: int.tryParse(json['bytes-in']?.toString() ?? '') ?? 0,
      bytesOut: int.tryParse(json['bytes-out']?.toString() ?? '') ?? 0,
      loginBy: json['login-by']?.toString() ?? '',
      server: json['server']?.toString() ?? '',
    );
  }
}

class HotspotProfile {
  final String id;
  final String name;
  final String rateLimit;
  final String sharedUsers;
  final String addressPool;
  final String idleTimeout;
  final String keepaliveTimeout;
  final String statusAutorefresh;
  final String sessionTimeout;
  final String comment;

  HotspotProfile({
    required this.id,
    required this.name,
    this.rateLimit = '',
    this.sharedUsers = '1',
    this.addressPool = '',
    this.idleTimeout = '',
    this.keepaliveTimeout = '',
    this.statusAutorefresh = '1m',
    this.sessionTimeout = '',
    this.comment = '',
  });

  factory HotspotProfile.fromJson(Map<String, dynamic> json) {
    return HotspotProfile(
      id: json['.id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      rateLimit: json['rate-limit']?.toString() ?? '',
      sharedUsers: json['shared-users']?.toString() ?? '1',
      addressPool: json['address-pool']?.toString() ?? '',
      idleTimeout: json['idle-timeout']?.toString() ?? '',
      keepaliveTimeout: json['keepalive-timeout']?.toString() ?? '',
      statusAutorefresh: json['status-autorefresh']?.toString() ?? '1m',
      sessionTimeout: json['session-timeout']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
    );
  }
}

class ConnectionTestResult {
  final bool success;
  final int statusCode;
  final SystemResource? data;
  final String? error;
  final int durationMs;

  ConnectionTestResult({
    required this.success,
    this.statusCode = 200,
    this.data,
    this.error,
    required this.durationMs,
  });
}

class MasterAuth {
  final String username;
  final String password;

  const MasterAuth({
    required this.username,
    required this.password,
  });

  factory MasterAuth.fromJson(Map<String, dynamic> json) {
    return MasterAuth(
      username: json['username']?.toString() ?? 'superadmin',
      password: json['password']?.toString() ?? 'ihwan',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}
