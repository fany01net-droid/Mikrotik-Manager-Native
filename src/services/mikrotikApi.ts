import { Capacitor, CapacitorHttp } from '@capacitor/core';
import {
  RouterProfile,
  SystemResource,
  NetworkInterface,
  DhcpLease,
  PppSecret,
  PppActive,
  PppProfile,
  HotspotUser,
  HotspotActive,
  HotspotProfile,
  IpPool,
  ConnectionTestResult,
} from '../types/mikrotik';

export const mikrotikApiService = {
  buildBaseUrl(profile: RouterProfile): string {
    const protocol = profile.useHttps ? 'https' : 'http';
    let host = (profile.host || '').trim();
    // Strip http:// or https:// prefix if user entered or pasted full URL
    host = host.replace(/^https?:\/\//i, '');
    // Strip any trailing path or slash (e.g., 192.168.88.1/rest)
    host = host.replace(/\/.*$/, '');

    let port = typeof profile.port === 'number' ? profile.port : parseInt(String(profile.port), 10);

    // Check for bracketed IPv6 with optional port: [2001:db8::1] or [2001:db8::1]:8443
    const bracketMatch = host.match(/^\[([0-9a-fA-F:]+)\](?::(\d+))?$/);
    if (bracketMatch) {
      host = bracketMatch[1];
      if (bracketMatch[2]) {
        const parsedPort = parseInt(bracketMatch[2], 10);
        if (!isNaN(parsedPort) && parsedPort > 0 && parsedPort <= 65535) {
          port = parsedPort;
        }
      }
    } else if (host.includes(':')) {
      const parts = host.split(':');
      if (parts.length === 2) {
        host = parts[0];
        const parsedPort = parseInt(parts[1], 10);
        if (!isNaN(parsedPort) && parsedPort > 0 && parsedPort <= 65535) {
          port = parsedPort;
        }
      }
    }

    const finalPort = !isNaN(port) && port > 0 && port <= 65535 ? port : (profile.useHttps ? 443 : 80);
    const formattedHost = host.includes(':') ? `[${host}]` : host;
    return `${protocol}://${formattedHost}:${finalPort}`;
  },

  getAuthHeader(profile: RouterProfile): string {
    const user = (profile.username || '').trim();
    const pass = profile.password || '';
    const utf8Bytes = new TextEncoder().encode(`${user}:${pass}`);
    let binary = '';
    for (let i = 0; i < utf8Bytes.length; i++) {
      binary += String.fromCharCode(utf8Bytes[i]);
    }
    const credentials = btoa(binary);
    return `Basic ${credentials}`;
  },

  async request<T>(
    profile: RouterProfile,
    path: string,
    method: string = 'GET',
    body?: any
  ): Promise<T> {
    const baseUrl = this.buildBaseUrl(profile);
    const targetUrl = `${baseUrl}${path.startsWith('/') ? path : '/' + path}`;
    const authHeader = this.getAuthHeader(profile);
    const timeoutSeconds = profile.timeoutSeconds || 8;

    // 1. Native Capacitor Android HTTP:
    if (Capacitor.isNativePlatform()) {
      try {
        const response = await CapacitorHttp.request({
          url: targetUrl,
          method: method,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': authHeader,
          },
          data: body,
          connectTimeout: timeoutSeconds * 1000,
          readTimeout: timeoutSeconds * 1000,
        });

        if (response.status >= 200 && response.status < 300) {
          return response.data as T;
        }

        if (response.status === 401) {
          throw new Error('Autentikasi Gagal (401): Username atau Password salah.');
        } else if (response.status === 404) {
          throw new Error(`Endpoint tidak ditemukan (404). Pastikan REST API aktif di RouterOS v7.`);
        } else {
          const detail = typeof response.data === 'object' ? JSON.stringify(response.data) : String(response.data || '');
          throw new Error(`MikroTik error HTTP ${response.status}: ${detail}`);
        }
      } catch (err: any) {
        throw new Error(err.message || 'Gagal menghubungi MikroTik via Native HTTP.');
      }
    }

    // 2. Web Browser via Vite Dev/Preview Proxy (/api-proxy):
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutSeconds * 1000);

      const headers: Record<string, string> = {
        'x-target-url': targetUrl,
        'x-auth-header': authHeader,
      };
      if (body) {
        headers['Content-Type'] = 'application/json';
      }

      const res = await fetch('/api-proxy', {
        method: method,
        headers,
        body: body ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });

      clearTimeout(timer);

      if (res.status === 401) {
        throw new Error('Autentikasi Gagal (401): Username atau Password salah.');
      } else if (res.status === 404) {
        throw new Error('Endpoint tidak ditemukan (404). Pastikan REST API aktif di RouterOS v7.');
      }

      if (!res.ok) {
        const errJson = await res.json().catch(() => ({}));
        const errMsg = errJson.detail || errJson.message || errJson.error || `HTTP error ${res.status}`;
        throw new Error(errMsg);
      }

      // Check if response has body content (e.g. DELETE might return 204 No Content)
      const text = await res.text();
      if (!text || text.trim() === '') {
        return {} as T;
      }
      return JSON.parse(text) as T;
    } catch (err: any) {
      if (err.name === 'AbortError') {
        throw new Error(`Timeout: Tidak dapat menjangkau ${profile.host}:${profile.port} dalam ${timeoutSeconds} detik.`);
      }
      throw new Error(err.message || 'Gagal tersambung ke router.');
    }
  },

  async testConnection(profile: RouterProfile): Promise<ConnectionTestResult> {
    const startTime = performance.now();
    try {
      const raw = await this.request<SystemResource | SystemResource[]>(profile, '/rest/system/resource');
      const data = Array.isArray(raw) ? (raw[0] || {}) : (raw || {});
      const durationMs = Math.round(performance.now() - startTime);
      return {
        success: true,
        statusCode: 200,
        data,
        durationMs,
      };
    } catch (err: any) {
      const durationMs = Math.round(performance.now() - startTime);
      return {
        success: false,
        error: err.message || 'Koneksi gagal',
        durationMs,
      };
    }
  },

  async getSystemResource(profile: RouterProfile): Promise<SystemResource> {
    const raw = await this.request<SystemResource | SystemResource[]>(profile, '/rest/system/resource');
    return Array.isArray(raw) ? (raw[0] || {}) : (raw || {});
  },

  async getSystemIdentity(profile: RouterProfile): Promise<{ name?: string }> {
    try {
      const raw = await this.request<{ name?: string } | { name?: string }[]>(profile, '/rest/system/identity');
      return Array.isArray(raw) ? (raw[0] || {}) : (raw || {});
    } catch {
      return {};
    }
  },

  async getSystemClock(profile: RouterProfile): Promise<{ time?: string; date?: string; 'time-zone-name'?: string }> {
    try {
      const raw = await this.request<any>(profile, '/rest/system/clock');
      return Array.isArray(raw) ? (raw[0] || {}) : (raw || {});
    } catch {
      return {};
    }
  },

  async getSystemHealth(profile: RouterProfile): Promise<Array<{ name: string; value: string | number; type?: string }>> {
    try {
      const raw = await this.request<any>(profile, '/rest/system/health');
      return Array.isArray(raw) ? raw : (raw ? [raw] : []);
    } catch {
      return [];
    }
  },

  // --- Hotspot Users, Active & Profiles (Manajemen Voucher & Sesi Hotspot) ---
  async getHotspotActive(profile: RouterProfile): Promise<HotspotActive[]> {
    try {
      const raw = await this.request<HotspotActive[] | HotspotActive>(profile, '/rest/ip/hotspot/active');
      return Array.isArray(raw) ? raw : (raw ? [raw] : []);
    } catch {
      return [];
    }
  },

  async getHotspotUsers(profile: RouterProfile): Promise<HotspotUser[]> {
    try {
      const raw = await this.request<HotspotUser[] | HotspotUser>(profile, '/rest/ip/hotspot/user');
      return Array.isArray(raw) ? raw : (raw ? [raw] : []);
    } catch {
      return [];
    }
  },

  async getHotspotProfiles(profile: RouterProfile): Promise<HotspotProfile[]> {
    try {
      const raw = await this.request<HotspotProfile[] | HotspotProfile>(profile, '/rest/ip/hotspot/user/profile');
      return Array.isArray(raw) ? raw : (raw ? [raw] : []);
    } catch {
      return [];
    }
  },

  async createHotspotProfile(profile: RouterProfile, data: Partial<HotspotProfile>): Promise<any> {
    return await this.request(profile, '/rest/ip/hotspot/user/profile', 'PUT', data);
  },

  async updateHotspotProfile(profile: RouterProfile, id: string, updates: Partial<HotspotProfile>): Promise<any> {
    return await this.request(profile, `/rest/ip/hotspot/user/profile/${encodeURIComponent(id)}`, 'PATCH', updates);
  },

  async deleteHotspotProfile(profile: RouterProfile, id: string): Promise<any> {
    return await this.request(profile, `/rest/ip/hotspot/user/profile/${encodeURIComponent(id)}`, 'DELETE');
  },

  async createHotspotUser(profile: RouterProfile, user: Partial<HotspotUser>): Promise<any> {
    return await this.request(profile, '/rest/ip/hotspot/user', 'PUT', user);
  },

  async updateHotspotUser(profile: RouterProfile, id: string, updates: Partial<HotspotUser>): Promise<any> {
    return await this.request(profile, `/rest/ip/hotspot/user/${encodeURIComponent(id)}`, 'PATCH', updates);
  },

  async deleteHotspotUser(profile: RouterProfile, id: string): Promise<any> {
    return await this.request(profile, `/rest/ip/hotspot/user/${encodeURIComponent(id)}`, 'DELETE');
  },

  async clearHotspotUserMac(profile: RouterProfile, id: string): Promise<any> {
    try {
      return await this.request(profile, `/rest/ip/hotspot/user/${encodeURIComponent(id)}`, 'PATCH', {
        'mac-address': '00:00:00:00:00:00',
      });
    } catch {
      return await this.request(profile, `/rest/ip/hotspot/user/${encodeURIComponent(id)}`, 'PATCH', {
        'mac-address': '',
      });
    }
  },

  async clearHotspotUserMacByName(profile: RouterProfile, username: string): Promise<any> {
    const users = await this.getHotspotUsers(profile);
    const found = users.find((u) => u.name.toLowerCase() === username.toLowerCase());
    if (found && found['.id']) {
      return await this.clearHotspotUserMac(profile, found['.id']);
    }
    return null;
  },

  async disconnectHotspotActive(profile: RouterProfile, id: string): Promise<any> {
    return await this.request(profile, `/rest/ip/hotspot/active/${encodeURIComponent(id)}`, 'DELETE');
  },

  async getInterfaces(profile: RouterProfile): Promise<NetworkInterface[]> {
    const raw = await this.request<NetworkInterface[] | NetworkInterface>(profile, '/rest/interface');
    return Array.isArray(raw) ? raw : (raw ? [raw] : []);
  },

  // --- DHCP Server Leases (untuk deteksi modem ONT baru & monitoring IP client) ---
  async getDhcpLeases(profile: RouterProfile): Promise<DhcpLease[]> {
    const raw = await this.request<DhcpLease[] | DhcpLease>(profile, '/rest/ip/dhcp-server/lease');
    return Array.isArray(raw) ? raw : (raw ? [raw] : []);
  },

  async makeDhcpLeaseStatic(profile: RouterProfile, id: string): Promise<any> {
    try {
      return await this.request(profile, '/rest/ip/dhcp-server/lease/make-static', 'POST', { numbers: id });
    } catch {
      return await this.request(profile, `/rest/ip/dhcp-server/lease/${encodeURIComponent(id)}`, 'PATCH', { dynamic: 'false' });
    }
  },

  async releaseDhcpLeaseStatic(profile: RouterProfile, id: string): Promise<any> {
    try {
      return await this.request(profile, `/rest/ip/dhcp-server/lease/${encodeURIComponent(id)}`, 'PATCH', { dynamic: 'true' });
    } catch {
      // Pada RouterOS v7, melepas reservasi static dilakukan dengan menghapus entri static-nya sehingga kembali dynamic
      return await this.deleteDhcpLease(profile, id);
    }
  },

  async deleteDhcpLease(profile: RouterProfile, id: string): Promise<any> {
    return await this.request(profile, `/rest/ip/dhcp-server/lease/${encodeURIComponent(id)}`, 'DELETE');
  },

  // --- PPPoE Secrets & Active Sessions (Billing & Manajemen RT/RW Net) ---
  async getPppSecrets(profile: RouterProfile): Promise<PppSecret[]> {
    const raw = await this.request<PppSecret[] | PppSecret>(profile, '/rest/ppp/secret');
    return Array.isArray(raw) ? raw : (raw ? [raw] : []);
  },

  async getPppActive(profile: RouterProfile): Promise<PppActive[]> {
    const raw = await this.request<PppActive[] | PppActive>(profile, '/rest/ppp/active');
    return Array.isArray(raw) ? raw : (raw ? [raw] : []);
  },

  async getPppProfiles(profile: RouterProfile): Promise<PppProfile[]> {
    const raw = await this.request<PppProfile[] | PppProfile>(profile, '/rest/ppp/profile');
    return Array.isArray(raw) ? raw : (raw ? [raw] : []);
  },

  async getIpPools(profile: RouterProfile): Promise<IpPool[]> {
    const raw = await this.request<IpPool[] | IpPool>(profile, '/rest/ip/pool');
    return Array.isArray(raw) ? raw : (raw ? [raw] : []);
  },

  async createPppProfile(profile: RouterProfile, profileData: {
    name: string;
    'local-address'?: string;
    'remote-address'?: string;
    'rate-limit'?: string;
    'only-one'?: string;
    'dns-server'?: string;
    comment?: string;
  }): Promise<any> {
    const payload: Record<string, any> = {
      name: profileData.name.trim(),
    };
    if (profileData['local-address']?.trim()) payload['local-address'] = profileData['local-address'].trim();
    if (profileData['remote-address']?.trim()) payload['remote-address'] = profileData['remote-address'].trim();
    if (profileData['rate-limit']?.trim()) payload['rate-limit'] = profileData['rate-limit'].trim();
    if (profileData['only-one']?.trim()) payload['only-one'] = profileData['only-one'].trim();
    if (profileData['dns-server']?.trim()) payload['dns-server'] = profileData['dns-server'].trim();
    if (profileData.comment?.trim()) payload.comment = profileData.comment.trim();

    return await this.request(profile, '/rest/ppp/profile', 'PUT', payload);
  },

  async updatePppProfile(profile: RouterProfile, id: string, updates: {
    name?: string;
    'local-address'?: string;
    'remote-address'?: string;
    'rate-limit'?: string;
    'only-one'?: string;
    'dns-server'?: string;
    comment?: string;
  }): Promise<any> {
    const payload: Record<string, any> = {};
    if (updates.name !== undefined) payload.name = updates.name.trim();
    if (updates['local-address'] !== undefined) payload['local-address'] = updates['local-address'].trim();
    if (updates['remote-address'] !== undefined) payload['remote-address'] = updates['remote-address'].trim();
    if (updates['rate-limit'] !== undefined) payload['rate-limit'] = updates['rate-limit'].trim();
    if (updates['only-one'] !== undefined) payload['only-one'] = updates['only-one'].trim();
    if (updates['dns-server'] !== undefined) payload['dns-server'] = updates['dns-server'].trim();
    if (updates.comment !== undefined) payload.comment = updates.comment.trim();

    return await this.request(profile, `/rest/ppp/profile/${encodeURIComponent(id)}`, 'PATCH', payload);
  },

  async deletePppProfile(profile: RouterProfile, id: string): Promise<any> {
    return await this.request(profile, `/rest/ppp/profile/${encodeURIComponent(id)}`, 'DELETE');
  },

  async createPppSecret(profile: RouterProfile, secretData: {
    name: string;
    password?: string;
    profile?: string;
    service?: string;
    comment?: string;
    disabled?: string | boolean;
    'caller-id'?: string;
    'remote-address'?: string;
  }): Promise<any> {
    // MikroTik RouterOS REST API uses PUT for creating/adding new resources (maps to CLI 'add')
    return await this.request(profile, '/rest/ppp/secret', 'PUT', {
      service: 'pppoe',
      profile: 'default',
      disabled: 'false',
      ...secretData,
    });
  },

  async updatePppSecret(profile: RouterProfile, id: string, updates: Partial<PppSecret>): Promise<any> {
    return await this.request(profile, `/rest/ppp/secret/${encodeURIComponent(id)}`, 'PATCH', updates);
  },

  async deletePppSecret(profile: RouterProfile, id: string): Promise<any> {
    return await this.request(profile, `/rest/ppp/secret/${encodeURIComponent(id)}`, 'DELETE');
  },

  async disconnectPppActive(profile: RouterProfile, id: string): Promise<any> {
    return await this.request(profile, `/rest/ppp/active/${encodeURIComponent(id)}`, 'DELETE');
  },
};
