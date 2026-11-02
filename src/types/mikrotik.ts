export type NavigationTab = 'vitals' | 'interfaces' | 'dhcp' | 'pppoe' | 'hotspot' | 'setup';

export interface RouterProfile {
  id: string;
  name: string;
  host: string;
  port: number;
  useHttps: boolean;
  username: string;
  password?: string;
  rememberPassword?: boolean;
  timeoutSeconds?: number;
}

export interface SystemResource {
  'uptime'?: string;
  'version'?: string;
  'build-time'?: string;
  'factory-software'?: string;
  'free-memory'?: number | string;
  'total-memory'?: number | string;
  'cpu'?: string;
  'cpu-count'?: number | string;
  'cpu-frequency'?: number | string;
  'cpu-load'?: number | string;
  'free-hdd-space'?: number | string;
  'total-hdd-space'?: number | string;
  'write-sect-since-reboot'?: number | string;
  'write-sect-total'?: number | string;
  'bad-blocks'?: number | string;
  'architecture-name'?: string;
  'board-name'?: string;
  'platform'?: string;
}

export interface NetworkInterface {
  '.id': string;
  name: string;
  type: string;
  running?: string | boolean;
  disabled?: string | boolean;
  comment?: string;
  'mac-address'?: string;
  'rx-byte'?: string | number;
  'tx-byte'?: string | number;
}

export interface DhcpLease {
  '.id': string;
  address: string;
  'mac-address': string;
  server?: string;
  'host-name'?: string;
  status?: string; // 'bound', 'waiting', 'offered'
  'expires-after'?: string;
  'last-seen'?: string;
  comment?: string;
  disabled?: string | boolean;
  dynamic?: string | boolean;
  'active-address'?: string;
  'active-mac-address'?: string;
  'active-server'?: string;
  'active-client-id'?: string;
}

export interface PppSecret {
  '.id': string;
  name: string;
  password?: string;
  service?: string; // 'pppoe', 'any'
  profile?: string;
  comment?: string; // e.g. "exp: 2026-11-19 | Bpk Budi"
  disabled?: string | boolean; // 'true' = isolir, 'false' = aktif
  'remote-address'?: string;
  'local-address'?: string;
  'caller-id'?: string;
  'last-logged-out'?: string;
}

export interface PppActive {
  '.id': string;
  name: string;
  service?: string;
  'caller-id'?: string; // MAC / ONT identifier
  address?: string; // IP address assigned
  uptime?: string;
  'session-id'?: string;
}

export interface PppProfile {
  '.id': string;
  name: string;
  'local-address'?: string;
  'remote-address'?: string;
  'rate-limit'?: string;
  'only-one'?: string | boolean;
  'dns-server'?: string;
  comment?: string;
}

export interface IpPool {
  '.id'?: string;
  name: string;
  ranges?: string;
  'next-pool'?: string;
}

export interface ConnectionTestResult {
  success: boolean;
  statusCode?: number;
  data?: SystemResource;
  error?: string;
  durationMs?: number;
}

export interface HotspotUser {
  '.id': string;
  name: string;
  password?: string;
  profile?: string;
  uptime?: string;
  'bytes-in'?: string | number;
  'bytes-out'?: string | number;
  comment?: string;
  disabled?: string | boolean;
  'limit-uptime'?: string;
  'limit-bytes-total'?: string | number;
  server?: string;
  'mac-address'?: string;
}

export interface HotspotActive {
  '.id': string;
  user: string;
  address: string;
  'mac-address': string;
  uptime?: string;
  'session-time-left'?: string;
  'bytes-in'?: string | number;
  'bytes-out'?: string | number;
  'login-by'?: string;
  server?: string;
}

export interface HotspotProfile {
  '.id': string;
  name: string;
  'rate-limit'?: string;
  'shared-users'?: string | number;
  'address-pool'?: string;
  'idle-timeout'?: string;
  'keepalive-timeout'?: string;
  'status-autorefresh'?: string;
  'session-timeout'?: string;
  comment?: string;
  validity?: string;
}
