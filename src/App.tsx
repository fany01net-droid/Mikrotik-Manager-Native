import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  figmaSpring,
  pageVariants,
  modalBackdropVariants,
  modalSheetVariants,
  toastBannerVariants,
} from './lib/motion';
import { App as CapApp } from '@capacitor/app';
import {
  Lock,
  User,
  Eye,
  EyeOff,
  CheckCircle2,
  AlertCircle,
  ArrowRight,
  LogOut,
  Shield,
  Home,
  Settings,
  Server,
  Plus,
  Trash2,
  X,
  Pencil,
  Check,
  Zap,
  Cpu,
  HardDrive,
  Activity,
  ChevronDown,
  ArrowDown,
  ArrowUp,
  Thermometer,
  Users,
  Wifi,
  Search,
  Ban,
  Unlock,
  CalendarPlus,
  ListFilter,
  ChevronRight,
  RefreshCw,
  Network,
  Copy,
  Ticket,
  Clock,
  KeyRound,
  Save,
} from 'lucide-react';
import { parseExpiryFromComment, extendExpiryDate, buildExpiryComment } from './lib/pppoeUtils';
import { calculateHotspotUserExpiry } from './lib/hotspotUtils';
import { mikrotikApiService } from './services/mikrotikApi';
import { RouterProfile, NetworkInterface, IpPool, DhcpLease, HotspotUser, HotspotActive, HotspotProfile } from './types/mikrotik';

interface DemoSecret {
  id: string;
  name: string;
  service: string;
  profile: string;
  comment: string;
  disabled: boolean;
  remoteAddress: string;
}

interface DemoProfile {
  id: string;
  name: string;
  rateLimit: string;
  localAddress: string;
  remotePool: string;
  onlyOne?: string;
  dnsServer?: string;
  comment?: string;
  userCount: number;
}

interface DemoActive {
  id: string;
  name: string;
  service: string;
  callerId: string;
  address: string;
  uptime: string;
}

interface AuthSession {
  username: string;
  loggedInAt: string;
}

interface MasterAuth {
  username: string;
  password: string;
}

const DEFAULT_MASTER_AUTH: MasterAuth = {
  username: 'ihwan',
  password: '1',
};

const getStoredMasterAuth = (): MasterAuth => {
  try {
    const raw = localStorage.getItem('fnet_master_auth');
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed.username === 'string' && typeof parsed.password === 'string') {
        return {
          username: parsed.username.trim() || 'ihwan',
          password: parsed.password || '1',
        };
      }
    }
  } catch {
    // fallback
  }
  return DEFAULT_MASTER_AUTH;
};

interface MikrotikDevice {
  id: string;
  ip: string;
  port: string;
  user: string;
  pass: string;
}

interface ToastData {
  id: string;
  type: 'success' | 'error' | 'info';
  message: string;
}

interface SmoothGaugeProps {
  id: string;
  percent: number;
  secondaryText: string;
  gradientStops?: Array<{ offset: string; color: string }>;
}

function SmoothGauge({ id, percent, secondaryText, gradientStops }: SmoothGaugeProps) {
  const clamped = Math.min(100, Math.max(0, percent));
  const dashOffset = 188.5 * (1 - clamped / 100);

  const defaultStops = [
    { offset: '0%', color: '#34d399' },
    { offset: '100%', color: '#059669' },
  ];

  const stops = gradientStops && gradientStops.length > 0 ? gradientStops : defaultStops;

  return (
    <div className="relative flex flex-col items-center justify-center my-1.5 sm:my-3">
      <svg
        className="w-full max-w-[100px] sm:max-w-[155px] h-auto aspect-[120/85] overflow-visible"
        viewBox="0 0 120 85"
      >
        <defs>
          <linearGradient id={id} x1="0%" y1="70%" x2="100%" y2="70%">
            {stops.map((stop, idx) => (
              <stop key={idx} offset={stop.offset} stopColor={stop.color} />
            ))}
          </linearGradient>
        </defs>

        {/* Background Track */}
        <path
          d="M 21.03 72.5 A 45 45 0 1 1 98.97 72.5"
          fill="none"
          stroke="currentColor"
          className="text-black/[0.06]"
          strokeWidth="10"
          strokeLinecap="round"
        />

        {/* Active Smooth Arc */}
        <path
          d="M 21.03 72.5 A 45 45 0 1 1 98.97 72.5"
          fill="none"
          stroke={`url(#${id})`}
          strokeWidth="10"
          strokeLinecap="round"
          strokeDasharray="188.5"
          strokeDashoffset={dashOffset}
          className="transition-all duration-700 ease-out"
        />
      </svg>

      {/* Center Typography inside Arc */}
      <div className="absolute inset-0 flex flex-col items-center justify-center pt-2 sm:pt-3 text-center pointer-events-none">
        <span className="font-mono text-lg sm:text-2xl font-bold tracking-tight text-apple-text">
          {clamped}%
        </span>
        <span className="text-[10px] sm:text-[11px] font-mono text-apple-subtext font-medium truncate max-w-full px-1 -mt-0.5">
          {secondaryText}
        </span>
      </div>
    </div>
  );
}

function getHealthStops(percent: number) {
  if (percent >= 80) {
    return [
      { offset: '0%', color: '#fb7185' },
      { offset: '100%', color: '#dc2626' },
    ]; // Merah Kritis (Coral Rose -> Crimson)
  }
  if (percent >= 50) {
    return [
      { offset: '0%', color: '#fde047' },
      { offset: '100%', color: '#ea580c' },
    ]; // Kuning / Amber Sedang (Golden Yellow -> Warm Orange)
  }
  return [
    { offset: '0%', color: '#34d399' },
    { offset: '100%', color: '#059669' },
  ]; // Hijau Normal (Mint Emerald -> Deep Forest Green)
}

function getTemperatureHealth(temp: number | null) {
  if (temp === null || isNaN(temp)) {
    return {
      status: 'N/A',
      colorText: 'text-apple-subtext',
      badgeBg: 'bg-black/[0.04] text-apple-subtext',
      cardBorder: 'border-black/[0.06]',
    };
  }
  if (temp >= 70) {
    return {
      status: 'Overheat',
      colorText: 'text-rose-600',
      badgeBg: 'bg-rose-500/10 text-rose-600 animate-pulse',
      cardBorder: 'border-rose-500/30',
    };
  }
  if (temp >= 55) {
    return {
      status: 'Hangat',
      colorText: 'text-amber-600',
      badgeBg: 'bg-amber-500/10 text-amber-600',
      cardBorder: 'border-amber-500/20',
    };
  }
  return {
    status: 'Normal',
    colorText: 'text-emerald-600',
    badgeBg: 'bg-emerald-500/10 text-emerald-600',
    cardBorder: 'border-black/[0.06]',
  };
}

function getVoltageHealth(volt: number | null) {
  if (volt === null || isNaN(volt)) {
    return {
      status: 'N/A',
      colorText: 'text-apple-subtext',
      badgeBg: 'bg-black/[0.04] text-apple-subtext',
      cardBorder: 'border-black/[0.06]',
    };
  }
  if (volt < 20.0) {
    return {
      status: 'Undervolt!',
      colorText: 'text-rose-600',
      badgeBg: 'bg-rose-500/10 text-rose-600 animate-pulse',
      cardBorder: 'border-rose-500/30',
    };
  }
  if (volt > 27.5) {
    return {
      status: 'Overvolt!',
      colorText: 'text-rose-600',
      badgeBg: 'bg-rose-500/10 text-rose-600 animate-pulse',
      cardBorder: 'border-rose-500/30',
    };
  }
  if (volt < 21.5 || volt > 26.5) {
    return {
      status: 'Fluktuasi',
      colorText: 'text-amber-600',
      badgeBg: 'bg-amber-500/10 text-amber-600',
      cardBorder: 'border-amber-500/20',
    };
  }
  return {
    status: 'Stabil',
    colorText: 'text-emerald-600',
    badgeBg: 'bg-emerald-500/10 text-emerald-600',
    cardBorder: 'border-black/[0.06]',
  };
}

function getSmoothSvgPath(coords: [number, number][], tension = 0.26): string {
  if (coords.length === 0) return '';
  if (coords.length === 1) return `M ${coords[0][0].toFixed(1)} ${coords[0][1].toFixed(1)}`;
  if (coords.length === 2) {
    return `M ${coords[0][0].toFixed(1)} ${coords[0][1].toFixed(1)} L ${coords[1][0].toFixed(1)} ${coords[1][1].toFixed(1)}`;
  }

  const n = coords.length;
  let d = `M ${coords[0][0].toFixed(1)} ${coords[0][1].toFixed(1)}`;

  for (let i = 0; i < n - 1; i++) {
    const p0 = coords[i === 0 ? 0 : i - 1];
    const p1 = coords[i];
    const p2 = coords[i + 1];
    const p3 = coords[i + 2 >= n ? n - 1 : i + 2];

    // Catmull-Rom Spline: Menghitung tangent kurva mulus tanpa lekukan kaku atau sudut patah
    const cp1x = p1[0] + (p2[0] - p0[0]) * tension;
    const cp1y = p1[1] + (p2[1] - p0[1]) * tension;
    const cp2x = p2[0] - (p3[0] - p1[0]) * tension;
    const cp2y = p2[1] - (p3[1] - p1[1]) * tension;

    d += ` C ${cp1x.toFixed(1)} ${cp1y.toFixed(1)}, ${cp2x.toFixed(1)} ${cp2y.toFixed(1)}, ${p2[0].toFixed(1)} ${p2[1].toFixed(1)}`;
  }

  return d;
}

function generateInitialTraffic(count = 28) {
  return Array.from({ length: count }, () => ({ rx: 0, tx: 0 }));
}

function formatSpeedShort(mbps: number): string {
  if (mbps >= 1000) {
    return `${(mbps / 1000).toFixed(1)}G`;
  }
  if (mbps < 0.1) {
    return '0M';
  }
  if (mbps < 1) {
    return `${Math.round(mbps * 1000)}K`;
  }
  return `${mbps.toFixed(1)}M`;
}

function formatBytes(bytes: number | string | undefined): string {
  if (bytes === undefined || bytes === null || bytes === '') return '0 B';
  const b = typeof bytes === 'string' ? parseInt(bytes, 10) : bytes;
  if (isNaN(b) || b <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.min(units.length - 1, Math.floor(Math.log(b) / Math.log(1024)));
  return `${(b / Math.pow(1024, i)).toFixed(1)} ${units[i]}`;
}

interface LiveTrafficCardProps {
  liveInterfaces?: NetworkInterface[];
  isLive?: boolean;
}

function LiveTrafficCard({ liveInterfaces, isLive = false }: LiveTrafficCardProps) {
  const options = useMemo(() => {
    if (liveInterfaces && liveInterfaces.length > 0) {
      return liveInterfaces.map((iface) => ({
        id: iface.name,
        label: `${iface.name}${iface.comment ? ` (${iface.comment})` : ''}`,
      }));
    }
    return [{ id: 'ether1', label: 'ether1' }];
  }, [liveInterfaces]);

  const [selectedIfId, setSelectedIfId] = useState('ether1');

  // If live interfaces are available and selectedIfId is not in options, select the first live interface
  useEffect(() => {
    if (options.length > 0 && !options.some((o) => o.id === selectedIfId)) {
      setSelectedIfId(options[0].id);
    }
  }, [options, selectedIfId]);

  const [trafficData, setTrafficData] = useState(() => generateInitialTraffic());

  const prevTrafficRef = useRef<{ [ifaceName: string]: { rxBytes: number; txBytes: number; timestamp: number } }>({});

  // Reset data saat interface berubah jika offline
  useEffect(() => {
    if (!isLive) {
      setTrafficData(generateInitialTraffic());
    }
  }, [selectedIfId, isLive]);

  // Delta calculation saat data live interface masuk dari polling MikroTik
  useEffect(() => {
    if (!isLive || !liveInterfaces || liveInterfaces.length === 0) return;
    const currentIface = liveInterfaces.find((i) => i.name === selectedIfId) || liveInterfaces[0];
    if (!currentIface) return;

    const rxBytes = Number(currentIface['rx-byte'] || 0);
    const txBytes = Number(currentIface['tx-byte'] || 0);
    const now = Date.now();

    const prev = prevTrafficRef.current[currentIface.name];
    if (prev && prev.timestamp > 0) {
      const elapsedSec = (now - prev.timestamp) / 1000;
      if (elapsedSec > 0.4) {
        const rxDelta = Math.max(0, rxBytes - prev.rxBytes);
        const txDelta = Math.max(0, txBytes - prev.txBytes);
        const rateRx = +((rxDelta * 8) / (elapsedSec * 1000 * 1000)).toFixed(2);
        const rateTx = +((txDelta * 8) / (elapsedSec * 1000 * 1000)).toFixed(2);

        // Deteksi perspektif WAN vs LAN/VLAN:
        // Pada WAN/ISP (eth2, eth3, atau port bertanda WAN/ISP):
        //   - Download internet = Rx router (data masuk dari ISP)
        //   - Upload internet = Tx router (data keluar ke ISP)
        // Pada LAN/VLAN/Pelanggan (VLAN, bridge, port lokal):
        //   - Download pelanggan = Tx router (data dikirim router ke perangkat/VLAN)
        //   - Upload pelanggan = Rx router (data diterima router dari perangkat/VLAN)
        const nameLower = (currentIface.name || '').toLowerCase();
        const commentLower = (currentIface.comment || '').toLowerCase();
        const typeLower = (currentIface.type || '').toLowerCase();

        const isClientVlan =
          typeLower === 'vlan' ||
          typeLower === 'bridge' ||
          /(vlan|bridge|lan|hotspot|wlan|client|pelanggan)/.test(`${nameLower} ${commentLower}`) ||
          (!/(wan|isp|uplink|internet|modem|gateway)/.test(`${nameLower} ${commentLower}`) &&
            !/^(ether2|ether3|eth2|eth3)/.test(nameLower));

        const downloadRate = isClientVlan ? rateTx : rateRx;
        const uploadRate = isClientVlan ? rateRx : rateTx;

        setTrafficData((prevData) => [...prevData.slice(1), { rx: downloadRate, tx: uploadRate }]);
      }
    }
    prevTrafficRef.current[currentIface.name] = { rxBytes, txBytes, timestamp: now };
  }, [liveInterfaces, selectedIfId, isLive]);

  const latest = trafficData[trafficData.length - 1] || { rx: 0, tx: 0 };
  const peakVal = Math.max(10, ...trafficData.map((d) => Math.max(d.rx, d.tx)));
  const scaleCeil = Math.ceil((peakVal * 1.15) / 20) * 20;

  const width = 400;
  const height = 110;
  const bottomY = 105;
  const topY = 10;
  const plotH = bottomY - topY;

  const rxCoords: [number, number][] = trafficData.map((d, i) => [
    (i / (trafficData.length - 1)) * width,
    bottomY - (d.rx / scaleCeil) * plotH,
  ]);
  const txCoords: [number, number][] = trafficData.map((d, i) => [
    (i / (trafficData.length - 1)) * width,
    bottomY - (d.tx / scaleCeil) * plotH,
  ]);

  const rxLine = getSmoothSvgPath(rxCoords);
  const rxArea = `${rxLine} L ${width} ${bottomY} L 0 ${bottomY} Z`;

  const txLine = getSmoothSvgPath(txCoords);
  const txArea = `${txLine} L ${width} ${bottomY} L 0 ${bottomY} Z`;

  const lastRxCoord = rxCoords[rxCoords.length - 1] || [width, bottomY];
  const lastTxCoord = txCoords[txCoords.length - 1] || [width, bottomY];

  return (
    <section className="bg-apple-card rounded-[26px] sm:rounded-3xl border border-black/[0.06] shadow-apple overflow-hidden p-3.5 sm:p-5">
      {/* Top Row: Pill Down & Up di KIRI (dengan icon), Select Interface di KANAN */}
      <div className="flex items-center justify-between gap-2 mb-3">
        {/* Angka Langsung di KIRI dengan icon up & down */}
        <div className="flex items-center gap-1.5 sm:gap-2 shrink-0 font-mono text-xs font-bold">
          <span
            title={`Download (Rx): ${latest.rx} Mbps`}
            className="w-[72px] sm:w-[78px] h-7 sm:h-8 flex items-center justify-center gap-1 text-center text-emerald-700 bg-emerald-500/[0.08] border border-emerald-500/15 rounded-lg sm:rounded-xl tracking-tight"
          >
            <ArrowDown className="w-3 h-3 text-emerald-600 stroke-[2.5] shrink-0" />
            <span>{formatSpeedShort(latest.rx)}</span>
          </span>
          <span
            title={`Upload (Tx): ${latest.tx} Mbps`}
            className="w-[72px] sm:w-[78px] h-7 sm:h-8 flex items-center justify-center gap-1 text-center text-apple-blue bg-apple-blue/[0.08] border border-apple-blue/15 rounded-lg sm:rounded-xl tracking-tight"
          >
            <ArrowUp className="w-3 h-3 text-apple-blue stroke-[2.5] shrink-0" />
            <span>{formatSpeedShort(latest.tx)}</span>
          </span>
        </div>

        {/* Select Interface Dropdown di KANAN (ukuran compact serasi dengan pill) */}
        <div className="relative inline-flex items-center">
          <select
            value={selectedIfId}
            onChange={(e) => setSelectedIfId(e.target.value)}
            aria-label="Pilih Interface MikroTik"
            className="appearance-none bg-black/[0.04] hover:bg-black/[0.07] border border-black/[0.08] text-apple-text font-mono text-xs font-semibold h-7 sm:h-8 pl-2.5 pr-6 rounded-lg sm:rounded-xl cursor-pointer focus:outline-none focus:ring-2 focus:ring-apple-blue/30 transition-all max-w-[160px] truncate"
          >
            {options.map((opt) => (
              <option key={opt.id} value={opt.id}>
                {opt.label}
              </option>
            ))}
          </select>
          <ChevronDown className="h-3.5 w-3.5 text-apple-subtext absolute right-2 pointer-events-none" />
        </div>
      </div>

      {/* SVG Real-time Wave Graph Langsung di Bawahnya */}
      <div className="relative w-full rounded-2xl bg-[#fbfbfd] border border-black/[0.04] p-2 sm:p-3 overflow-hidden">
        {/* Scale labels */}
        <div className="absolute left-2.5 top-2 text-[10px] font-mono text-apple-subtext font-semibold pointer-events-none">
          {formatSpeedShort(scaleCeil)}
        </div>
        <div className="absolute left-2.5 bottom-2 text-[10px] font-mono text-apple-subtext font-semibold pointer-events-none">
          0M
        </div>

        <svg
          className="w-full h-auto aspect-[400/110] overflow-visible"
          viewBox={`0 0 ${width} ${height}`}
          preserveAspectRatio="none"
        >
          <defs>
            <linearGradient id="liveTrafficRxGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#10b981" stopOpacity="0.32" />
              <stop offset="100%" stopColor="#10b981" stopOpacity="0.01" />
            </linearGradient>
            <linearGradient id="liveTrafficTxGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#0071e3" stopOpacity="0.25" />
              <stop offset="100%" stopColor="#0071e3" stopOpacity="0.01" />
            </linearGradient>
          </defs>

          {/* Grid guide lines */}
          <line
            x1="0"
            y1={topY}
            x2={width}
            y2={topY}
            stroke="currentColor"
            className="text-black/[0.05]"
            strokeDasharray="4 4"
          />
          <line
            x1="0"
            y1={(topY + bottomY) / 2}
            x2={width}
            y2={(topY + bottomY) / 2}
            stroke="currentColor"
            className="text-black/[0.05]"
            strokeDasharray="4 4"
          />
          <line
            x1="0"
            y1={bottomY}
            x2={width}
            y2={bottomY}
            stroke="currentColor"
            className="text-black/[0.08]"
          />

          {/* Tx Wave (Upload - Blue) */}
          <path d={txArea} fill="url(#liveTrafficTxGrad)" />
          <path
            d={txLine}
            fill="none"
            stroke="#0071e3"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          />

          {/* Rx Wave (Download - Green) */}
          <path d={rxArea} fill="url(#liveTrafficRxGrad)" />
          <path
            d={rxLine}
            fill="none"
            stroke="#10b981"
            strokeWidth="2.2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />

          {/* Real-time Tip Pulse Indicators */}
          <circle
            cx={lastTxCoord[0]}
            cy={lastTxCoord[1]}
            r="3"
            fill="#0071e3"
            className="transition-all duration-300"
          />
          <circle
            cx={lastRxCoord[0]}
            cy={lastRxCoord[1]}
            r="3.5"
            fill="#10b981"
            className="transition-all duration-300"
          />
        </svg>
      </div>
    </section>
  );
}

const initialDemoHotspotUsers: HotspotUser[] = [
  {
    '.id': '*H1',
    name: 'tasyauser',
    profile: 'Voucher-8M',
    uptime: '4h 12m 30s',
    'bytes-in': '105423891',
    'bytes-out': '847291823',
    'limit-uptime': '7d',
    'limit-bytes-total': '0',
    disabled: false,
    comment: '2026-11-07 11:23:28',
  },
  {
    '.id': '*H2',
    name: 'vip-01',
    profile: 'Voucher-10M',
    uptime: '2d 4h 15m',
    'bytes-in': '205423891',
    'bytes-out': '1847291823',
    'limit-uptime': '30d',
    'limit-bytes-total': '0',
    disabled: false,
    comment: '2026-11-20 10:00:00',
  },
  {
    '.id': '*H3',
    name: 'vc-3jam-882',
    profile: 'Voucher-3Jam',
    uptime: '1h 12m 44s',
    'bytes-in': '25423891',
    'bytes-out': '147291823',
    'limit-uptime': '3h',
    'limit-bytes-total': '0',
    disabled: false,
    comment: '2026-11-02 12:22:25',
  },
  {
    '.id': '*H4',
    name: 'vc-fresh-104',
    profile: 'Voucher-3M',
    uptime: '0s',
    'bytes-in': '0',
    'bytes-out': '0',
    'limit-uptime': '1d',
    'limit-bytes-total': '0',
    disabled: false,
    comment: '',
  },
  {
    '.id': '*H5',
    name: 'tamu-lobby',
    profile: 'Voucher-3M',
    uptime: '2h 15m 10s',
    'bytes-in': '5423891',
    'bytes-out': '27291823',
    'limit-uptime': '2h',
    'limit-bytes-total': '0',
    disabled: true,
    comment: '2026-11-01 10:00:00',
  },
];

const initialDemoHotspotActive: HotspotActive[] = [
  {
    '.id': '*HA1',
    user: 'tasyauser',
    address: '10.10.10.250',
    'mac-address': '6C:29:95:4A:21:88',
    uptime: '4h 12m 30s',
    'session-time-left': '4d 20h 59m',
    'bytes-in': '105423891',
    'bytes-out': '847291823',
    server: 'hotspot1',
  },
  {
    '.id': '*HA2',
    user: 'vip-01',
    address: '10.5.50.22',
    'mac-address': 'A4:C3:F0:11:92:40',
    uptime: '2d 4h 15m',
    'session-time-left': '17d 19h 45m',
    'bytes-in': '205423891',
    'bytes-out': '1847291823',
    server: 'hotspot1',
  },
];

const initialDemoHotspotProfiles: HotspotProfile[] = [
  {
    '.id': '*HP2',
    name: 'Voucher-3M',
    'rate-limit': '3M/3M',
    'shared-users': '1',
    'status-autorefresh': '1m',
    validity: '1d',
    comment: 'validity: 1d',
  },
  {
    '.id': '*HP3',
    name: 'Voucher-8M',
    'rate-limit': '8M/8M',
    'shared-users': '1',
    'status-autorefresh': '1m',
    validity: '7d',
    comment: 'validity: 7d',
  },
  {
    '.id': '*HP4',
    name: 'Voucher-3Jam',
    'rate-limit': '5M/5M',
    'shared-users': '1',
    'status-autorefresh': '1m',
    validity: '3h',
    comment: 'validity: 3h',
  },
  {
    '.id': '*HP5',
    name: 'Voucher-10M',
    'rate-limit': '10M/10M',
    'shared-users': '2',
    'status-autorefresh': '1m',
    validity: '30d',
    comment: 'validity: 30d',
  },
  {
    '.id': '*HP6',
    name: 'VIP-Unlimited',
    'rate-limit': '15M/15M',
    'shared-users': '3',
    'status-autorefresh': '1m',
    validity: '30d',
    comment: 'validity: 30d',
  },
];

const isHiddenDefaultProfile = (name: string) => {
  const lower = (name || '').toLowerCase().trim();
  return lower === 'default' || lower === 'default-encryption';
};

const isHiddenDefaultUser = (name: string) => {
  const lower = (name || '').toLowerCase().trim();
  return lower === 'default' || lower === 'default-trial';
};

export default function App() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [session, setSession] = useState<AuthSession | null>(null);
  const [masterUsername, setMasterUsername] = useState('ihwan');
  const [masterPassword, setMasterPassword] = useState('1');
  const [showMasterPassword, setShowMasterPassword] = useState(false);
  const [activeTab, setActiveTab] = useState<'beranda' | 'pppoe' | 'hotspot' | 'dhcp' | 'pengaturan'>('beranda');
  const [isKeyboardOpen, setIsKeyboardOpen] = useState(false);

  // Hotspot State [ User | Active | Profile ]
  const [hotspotSubTab, setHotspotSubTab] = useState<'user' | 'active' | 'profile'>('user');
  const [hotspotUsers, setHotspotUsers] = useState<HotspotUser[]>(initialDemoHotspotUsers);
  const [hotspotActive, setHotspotActive] = useState<HotspotActive[]>(initialDemoHotspotActive);
  const [hotspotProfiles, setHotspotProfiles] = useState<HotspotProfile[]>(initialDemoHotspotProfiles);
  const [isHotspotRefreshing, setIsHotspotRefreshing] = useState(false);
  const isFetchingHotspotRef = useRef(false);

  const [hotspotUserSearch, setHotspotUserSearch] = useState('');
  const [hotspotUserFilter, setHotspotUserFilter] = useState<'all' | 'used' | 'unused' | 'expiring-soon' | 'expired' | 'disabled'>('all');
  const [hotspotUserFilterOpen, setHotspotUserFilterOpen] = useState(false);
  const [hotspotActiveSearch, setHotspotActiveSearch] = useState('');
  const [hotspotProfileSearch, setHotspotProfileSearch] = useState('');

  // Hotspot Add User Modal
  const [isAddHotspotUserModalOpen, setIsAddHotspotUserModalOpen] = useState(false);
  const [newHotspotUserName, setNewHotspotUserName] = useState('');
  const [newHotspotUserPass, setNewHotspotUserPass] = useState('');
  const [showNewHotspotPass, setShowNewHotspotPass] = useState(false);
  const [newHotspotUserProfile, setNewHotspotUserProfile] = useState('Voucher-3M');
  const [newHotspotUserLimitUptime, setNewHotspotUserLimitUptime] = useState('');
  const [newHotspotUserComment, setNewHotspotUserComment] = useState('');

  // Hotspot Detail / Edit User Modal
  const [selectedHotspotUser, setSelectedHotspotUser] = useState<HotspotUser | null>(null);
  const [editHotspotUserPass, setEditHotspotUserPass] = useState('');
  const [showEditHotspotPass, setShowEditHotspotPass] = useState(false);
  const [editHotspotUserProfile, setEditHotspotUserProfile] = useState('Voucher-3M');
  const [editHotspotUserLimitUptime, setEditHotspotUserLimitUptime] = useState('');
  const [editHotspotUserComment, setEditHotspotUserComment] = useState('');
  const [hotspotDeleteHoldId, setHotspotDeleteHoldId] = useState<string | null>(null);
  const [hotspotDeleteHoldProgress, setHotspotDeleteHoldProgress] = useState<number>(0);
  const hotspotDeleteTimerRef = useRef<NodeJS.Timeout | null>(null);
  const hotspotDeleteIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // Hotspot Profile Add/Edit Modal State
  const [isHotspotProfileModalOpen, setIsHotspotProfileModalOpen] = useState(false);
  const [editingHotspotProfileId, setEditingHotspotProfileId] = useState<string | null>(null);
  const [hotspotProfileFormName, setHotspotProfileFormName] = useState('');
  const [hotspotProfileFormRateLimit, setHotspotProfileFormRateLimit] = useState('');
  const [hotspotProfileFormSharedUsers, setHotspotProfileFormSharedUsers] = useState('1');
  const [hotspotProfileFormAddressPool, setHotspotProfileFormAddressPool] = useState('');
  const [isHotspotManualPool, setIsHotspotManualPool] = useState(false);
  const [hotspotProfileFormAutorefresh, setHotspotProfileFormAutorefresh] = useState('1m');
  const [hotspotProfileFormValidity, setHotspotProfileFormValidity] = useState('');
  const [isSavingHotspotProfile, setIsSavingHotspotProfile] = useState(false);
  const [hotspotProfileDeleteHoldProgress, setHotspotProfileDeleteHoldProgress] = useState<number>(0);
  const hotspotProfileDeleteTimerRef = useRef<NodeJS.Timeout | null>(null);
  const hotspotProfileDeleteIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // DHCP Leases State
  const [dhcpLeases, setDhcpLeases] = useState<DhcpLease[]>([]);
  const [dhcpSearch, setDhcpSearch] = useState('');
  const [dhcpFilter, setDhcpFilter] = useState<'all' | 'bound' | 'dynamic' | 'static' | 'waiting'>('all');
  const [dhcpServerFilter, setDhcpServerFilter] = useState<string>('all');
  const [dhcpFilterMenuOpen, setDhcpFilterMenuOpen] = useState(false);
  const [isDhcpRefreshing, setIsDhcpRefreshing] = useState(false);
  const [selectedLease, setSelectedLease] = useState<DhcpLease | null>(null);
  const [dhcpDeleteHoldId, setDhcpDeleteHoldId] = useState<string | null>(null);
  const [dhcpDeleteHoldProgress, setDhcpDeleteHoldProgress] = useState<number>(0);
  const dhcpDeleteTimerRef = useRef<NodeJS.Timeout | null>(null);
  const dhcpDeleteIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const isFetchingDhcpRef = useRef(false);

  // PPPoE Sub-tab State [ User | Profile | Active ]
  const [pppSubTab, setPppSubTab] = useState<'user' | 'profile' | 'active'>('user');
  const [isPppRefreshing, setIsPppRefreshing] = useState(false);
  const [pppSearch, setPppSearch] = useState('');
  const [pppFilter, setPppFilter] = useState<'all' | 'active' | 'isolir'>('all');
  const [profileSearch, setProfileSearch] = useState('');
  const [profileFilter, setProfileFilter] = useState<'all' | 'used' | 'unused'>('all');
  const [activeSearch, setActiveSearch] = useState('');
  const [activeFilter, setActiveFilter] = useState<string>('all');
  const [selectedSecretId, setSelectedSecretId] = useState<string | null>(null);
  const [filterMenuOpen, setFilterMenuOpen] = useState(false);
  const [editingExpiryDate, setEditingExpiryDate] = useState<string | null>(null);
  const [editingProfile, setEditingProfile] = useState<string | null>(null);
  const [isAddUserModalOpen, setIsAddUserModalOpen] = useState(false);
  const [newUserName, setNewUserName] = useState('');
  const [newUserPass, setNewUserPass] = useState('');
  const [showNewUserPass, setShowNewUserPass] = useState(false);
  const [newUserProfile, setNewUserProfile] = useState('');
  const [newUserComment, setNewUserComment] = useState('');
  const [newUserExpiry, setNewUserExpiry] = useState('');
  const [deleteHoldProgress, setDeleteHoldProgress] = useState<number>(0);
  const deleteTimerRef = useRef<NodeJS.Timeout | null>(null);
  const deleteIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // PPPoE Profile Add/Edit Modal State
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [editingProfileId, setEditingProfileId] = useState<string | null>(null);
  const [profileFormName, setProfileFormName] = useState('');
  const [profileFormRateLimit, setProfileFormRateLimit] = useState('');
  const [profileFormLocalAddress, setProfileFormLocalAddress] = useState('');
  const [profileFormRemotePool, setProfileFormRemotePool] = useState('');
  const [isManualPool, setIsManualPool] = useState(false);
  const [profileFormOnlyOne, setProfileFormOnlyOne] = useState('default');
  const [profileFormDnsServer, setProfileFormDnsServer] = useState('');
  const [profileFormComment, setProfileFormComment] = useState('');
  const [isSavingProfile, setIsSavingProfile] = useState(false);
  const [profileDeleteHoldProgress, setProfileDeleteHoldProgress] = useState<number>(0);
  const profileDeleteTimerRef = useRef<NodeJS.Timeout | null>(null);
  const profileDeleteIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // MikroTik IP Pools
  const [ipPools, setIpPools] = useState<IpPool[]>([]);

  // Pengaturan MikroTik State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [selectedMikrotikId, setSelectedMikrotikId] = useState<string | null>(null);
  const [mikrotikIp, setMikrotikIp] = useState('');
  const [mikrotikPort, setMikrotikPort] = useState('80');
  const [mikrotikUser, setMikrotikUser] = useState('');
  const [mikrotikPass, setMikrotikPass] = useState('');
  const [showMikrotikPass, setShowMikrotikPass] = useState(false);
  const [mikrotikList, setMikrotikList] = useState<MikrotikDevice[]>([]);
  const [isLogoutConfirmOpen, setIsLogoutConfirmOpen] = useState(false);
  const [deletingRouterTarget, setDeletingRouterTarget] = useState<MikrotikDevice | null>(null);

  const [demoSecrets, setDemoSecrets] = useState<DemoSecret[]>([]);
  const [demoProfiles, setDemoProfiles] = useState<DemoProfile[]>([]);
  const [demoActive, setDemoActive] = useState<DemoActive[]>([]);

  // Progressive Lazy Loading visible limits
  const [visiblePppSecrets, setVisiblePppSecrets] = useState(25);
  const [visiblePppProfiles, setVisiblePppProfiles] = useState(25);
  const [visiblePppActive, setVisiblePppActive] = useState(25);
  const [visibleHotspotUsers, setVisibleHotspotUsers] = useState(25);
  const [visibleHotspotActive, setVisibleHotspotActive] = useState(25);
  const [visibleHotspotProfiles, setVisibleHotspotProfiles] = useState(25);
  const [visibleDhcpLeases, setVisibleDhcpLeases] = useState(25);

  // Reset lazy load visible limits when filters or search change
  useEffect(() => {
    setVisiblePppSecrets(25);
  }, [pppSearch, pppFilter]);

  useEffect(() => {
    setVisiblePppProfiles(25);
  }, [profileSearch, profileFilter]);

  useEffect(() => {
    setVisiblePppActive(25);
  }, [activeSearch, activeFilter]);

  useEffect(() => {
    setVisibleHotspotUsers(25);
  }, [hotspotUserSearch, hotspotUserFilter]);

  useEffect(() => {
    setVisibleHotspotActive(25);
  }, [hotspotActiveSearch]);

  useEffect(() => {
    setVisibleHotspotProfiles(25);
  }, [hotspotProfileSearch]);

  useEffect(() => {
    setVisibleDhcpLeases(25);
  }, [dhcpSearch, dhcpFilter, dhcpServerFilter]);

  const poolOptions = useMemo(() => {
    const map = new Map<string, { name: string; ranges?: string }>();

    for (const pool of ipPools) {
      if (pool.name) {
        map.set(pool.name, { name: pool.name, ranges: pool.ranges });
      }
    }

    for (const prof of demoProfiles) {
      if (prof.remotePool && prof.remotePool !== '-' && !map.has(prof.remotePool)) {
        map.set(prof.remotePool, { name: prof.remotePool });
      }
    }

    if (map.size === 0) {
      map.set('pool-pppoe', { name: 'pool-pppoe' });
      map.set('pool1', { name: 'pool1' });
      map.set('default-dhcp', { name: 'default-dhcp' });
    }

    return Array.from(map.values());
  }, [ipPools, demoProfiles]);

  const getSelectedProfile = useCallback((): RouterProfile | null => {
    if (!selectedMikrotikId) return null;
    const device = mikrotikList.find((d) => d.id === selectedMikrotikId);
    if (!device) return null;
    return {
      id: device.id,
      name: device.ip,
      host: device.ip,
      port: parseInt(device.port, 10) || 80,
      useHttps: device.port === '443',
      username: device.user,
      password: device.pass,
      timeoutSeconds: 6,
    };
  }, [selectedMikrotikId, mikrotikList]);

  const handleToggleIsolir = async (id: string) => {
    const target = demoSecrets.find((s) => s.id === id);
    if (!target) return;
    const nextDisabled = !target.disabled;

    // Optimistic UI update
    setDemoSecrets((prev) =>
      prev.map((s) => (s.id === id ? { ...s, disabled: nextDisabled } : s))
    );

    const routerProfile = getSelectedProfile();
    if (routerProfile) {
      try {
        await mikrotikApiService.updatePppSecret(routerProfile, id, {
          disabled: nextDisabled ? 'true' : 'false',
        });
        // Jika di-isolir, kick juga sesi aktifnya dari router
        if (nextDisabled) {
          const activeSessions = demoActive.filter(
            (a) => a.name.toLowerCase() === target.name.toLowerCase()
          );
          for (const session of activeSessions) {
            try {
              await mikrotikApiService.disconnectPppActive(routerProfile, session.id);
            } catch {
              // ignore
            }
          }
          setDemoActive((prev) =>
            prev.filter((a) => a.name.toLowerCase() !== target.name.toLowerCase())
          );
        }
        showToast(
          nextDisabled
            ? `Pelanggan ${target.name} berhasil di-isolir.`
            : `Isolir pelanggan ${target.name} berhasil dibuka.`,
          nextDisabled ? 'error' : 'success'
        );
        fetchPppoeData();
      } catch (err: any) {
        // Rollback on network failure
        setDemoSecrets((prev) =>
          prev.map((s) => (s.id === id ? { ...s, disabled: !nextDisabled } : s))
        );
        showToast(`Gagal update status di MikroTik: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      showToast(
        nextDisabled
          ? `Pelanggan ${target.name} berhasil di-isolir.`
          : `Isolir pelanggan ${target.name} berhasil dibuka.`,
        nextDisabled ? 'error' : 'success'
      );
    }
  };

  const handleExtendSecret = async (id: string) => {
    const target = demoSecrets.find((s) => s.id === id);
    if (!target) return;
    const nextComment = extendExpiryDate(target.comment, 30);
    const oldComment = target.comment;
    const oldDisabled = target.disabled;

    // Optimistic UI update
    setDemoSecrets((prev) =>
      prev.map((s) => (s.id === id ? { ...s, comment: nextComment, disabled: false } : s))
    );

    const routerProfile = getSelectedProfile();
    if (routerProfile) {
      try {
        await mikrotikApiService.updatePppSecret(routerProfile, id, {
          comment: nextComment,
          disabled: 'false',
        });
        showToast(`Masa aktif ${target.name} diperpanjang +30 hari (tersimpan ke MikroTik)!`, 'success');
        fetchPppoeData();
      } catch (err: any) {
        // Rollback
        setDemoSecrets((prev) =>
          prev.map((s) => (s.id === id ? { ...s, comment: oldComment, disabled: oldDisabled } : s))
        );
        showToast(`Gagal menyimpan ke MikroTik: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      showToast(`Masa aktif ${target.name} diperpanjang +30 hari!`, 'success');
    }
  };

  const handleUpdateExpiryDate = async (id: string, newDateIso: string) => {
    const target = demoSecrets.find((s) => s.id === id);
    if (!target) return;
    const nextComment = buildExpiryComment(newDateIso, target.comment);
    const oldComment = target.comment;

    // Optimistic UI update
    setDemoSecrets((prev) =>
      prev.map((s) => (s.id === id ? { ...s, comment: nextComment } : s))
    );
    setEditingExpiryDate(null);

    const routerProfile = getSelectedProfile();
    if (routerProfile) {
      try {
        await mikrotikApiService.updatePppSecret(routerProfile, id, {
          comment: nextComment,
        });
        showToast(`Jatuh tempo ${target.name} diubah & tersimpan ke MikroTik!`, 'success');
        fetchPppoeData();
      } catch (err: any) {
        // Rollback
        setDemoSecrets((prev) =>
          prev.map((s) => (s.id === id ? { ...s, comment: oldComment } : s))
        );
        showToast(`Gagal update comment di MikroTik: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      showToast(`Jatuh tempo ${target.name} diubah ke ${newDateIso}`, 'success');
    }
  };

  const handleUpdateProfile = async (id: string, newProfile: string) => {
    const target = demoSecrets.find((s) => s.id === id);
    if (!target) return;
    const oldProfile = target.profile;

    // Optimistic UI update
    setDemoSecrets((prev) =>
      prev.map((s) => (s.id === id ? { ...s, profile: newProfile } : s))
    );
    setEditingProfile(null);

    const routerProfile = getSelectedProfile();
    if (routerProfile) {
      try {
        await mikrotikApiService.updatePppSecret(routerProfile, id, {
          profile: newProfile,
        });
        showToast(`Paket ${target.name} diubah ke ${newProfile} & tersimpan ke MikroTik!`, 'success');
        fetchPppoeData();
      } catch (err: any) {
        // Rollback
        setDemoSecrets((prev) =>
          prev.map((s) => (s.id === id ? { ...s, profile: oldProfile } : s))
        );
        showToast(`Gagal update paket di MikroTik: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      showToast(`Paket ${target.name} diubah ke ${newProfile}`, 'success');
    }
  };

  const handleCreateNewUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newUserName.trim()) {
      showToast('Username PPPoE tidak boleh kosong', 'error');
      return;
    }

    const assignedProfile = newUserProfile || (demoProfiles[0]?.name || 'default');
    const finalComment = newUserExpiry
      ? buildExpiryComment(newUserExpiry, newUserComment)
      : newUserComment.trim();

    const routerProfile = getSelectedProfile();
    if (routerProfile) {
      try {
        const created = await mikrotikApiService.createPppSecret(routerProfile, {
          name: newUserName.trim(),
          password: newUserPass,
          profile: assignedProfile,
          service: 'pppoe',
          comment: finalComment,
          disabled: 'false',
        });

        const newId = created?.['.id'] || created?.ret || newUserName.trim();
        setDemoSecrets((prev) => [
          {
            id: newId,
            name: newUserName.trim(),
            service: 'pppoe',
            profile: assignedProfile,
            comment: finalComment,
            disabled: false,
            remoteAddress: '',
          },
          ...prev,
        ]);

        showToast(`User ${newUserName.trim()} berhasil ditambahkan ke MikroTik!`, 'success');
        setIsAddUserModalOpen(false);
        setNewUserName('');
        setNewUserPass('');
        setNewUserComment('');
        setNewUserExpiry('');
        fetchPppoeData();
      } catch (err: any) {
        showToast(`Gagal membuat user di MikroTik: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      setDemoSecrets((prev) => [
        {
          id: `sec-${Date.now()}`,
          name: newUserName.trim(),
          service: 'pppoe',
          profile: assignedProfile,
          comment: finalComment,
          disabled: false,
          remoteAddress: '',
        },
        ...prev,
      ]);
      showToast(`User ${newUserName.trim()} berhasil ditambahkan!`, 'success');
      setIsAddUserModalOpen(false);
      setNewUserName('');
      setNewUserPass('');
      setNewUserComment('');
      setNewUserExpiry('');
    }
  };

  const handleOpenAddProfile = () => {
    setEditingProfileId(null);
    setProfileFormName('');
    setProfileFormRateLimit('');
    setProfileFormLocalAddress('');
    setProfileFormRemotePool(poolOptions[0]?.name || 'pool-pppoe');
    setIsManualPool(false);
    setProfileFormOnlyOne('default');
    setProfileFormDnsServer('');
    setProfileFormComment('');
    cancelProfileDeleteHold();
    setIsProfileModalOpen(true);
  };

  const handleOpenEditProfile = (prof: DemoProfile) => {
    setEditingProfileId(prof.id);
    setProfileFormName(prof.name);
    setProfileFormRateLimit(prof.rateLimit === '-' ? '' : prof.rateLimit);
    setProfileFormLocalAddress(prof.localAddress === '-' ? '' : prof.localAddress);
    const targetPool = prof.remotePool === '-' ? '' : prof.remotePool;
    setProfileFormRemotePool(targetPool);
    const isKnownPool = !targetPool || poolOptions.some((p) => p.name === targetPool);
    setIsManualPool(!isKnownPool);
    setProfileFormOnlyOne(prof.onlyOne || 'default');
    setProfileFormDnsServer(prof.dnsServer || '');
    setProfileFormComment(prof.comment || '');
    cancelProfileDeleteHold();
    setIsProfileModalOpen(true);
  };

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmedName = profileFormName.trim();
    if (!trimmedName) {
      showToast('Nama profil tidak boleh kosong', 'error');
      return;
    }

    setIsSavingProfile(true);
    const routerProfile = getSelectedProfile();

    try {
      if (editingProfileId) {
        // Edit Profile
        if (routerProfile) {
          await mikrotikApiService.updatePppProfile(routerProfile, editingProfileId, {
            name: trimmedName,
            'rate-limit': profileFormRateLimit,
            'local-address': profileFormLocalAddress,
            'remote-address': profileFormRemotePool,
            'only-one': profileFormOnlyOne,
            'dns-server': profileFormDnsServer,
            comment: profileFormComment,
          });
        }

        setDemoProfiles((prev) =>
          prev.map((p) =>
            p.id === editingProfileId
              ? {
                  ...p,
                  name: trimmedName,
                  rateLimit: profileFormRateLimit.trim() || '-',
                  localAddress: profileFormLocalAddress.trim() || '-',
                  remotePool: profileFormRemotePool.trim() || '-',
                  onlyOne: profileFormOnlyOne,
                  dnsServer: profileFormDnsServer.trim(),
                  comment: profileFormComment.trim(),
                }
              : p
          )
        );

        showToast(`Profil ${trimmedName} berhasil diperbarui di MikroTik!`, 'success');
      } else {
        // Add Profile
        let newId = `prof-${Date.now()}`;
        if (routerProfile) {
          const res = await mikrotikApiService.createPppProfile(routerProfile, {
            name: trimmedName,
            'rate-limit': profileFormRateLimit,
            'local-address': profileFormLocalAddress,
            'remote-address': profileFormRemotePool,
            'only-one': profileFormOnlyOne,
            'dns-server': profileFormDnsServer,
            comment: profileFormComment,
          });
          newId = res?.['.id'] || res?.ret || trimmedName;
        }

        const newProfItem: DemoProfile = {
          id: newId,
          name: trimmedName,
          rateLimit: profileFormRateLimit.trim() || '-',
          localAddress: profileFormLocalAddress.trim() || '-',
          remotePool: profileFormRemotePool.trim() || '-',
          onlyOne: profileFormOnlyOne,
          dnsServer: profileFormDnsServer.trim(),
          comment: profileFormComment.trim(),
          userCount: 0,
        };

        setDemoProfiles((prev) => [...prev, newProfItem]);
        showToast(`Profil ${trimmedName} berhasil ditambahkan ke MikroTik!`, 'success');
      }

      setIsProfileModalOpen(false);
      fetchPppoeData();
    } catch (err: any) {
      showToast(`Gagal menyimpan profil: ${err?.message || 'Error'}`, 'error');
    } finally {
      setIsSavingProfile(false);
    }
  };

  const cancelProfileDeleteHold = () => {
    if (profileDeleteTimerRef.current) {
      clearTimeout(profileDeleteTimerRef.current);
      profileDeleteTimerRef.current = null;
    }
    if (profileDeleteIntervalRef.current) {
      clearInterval(profileDeleteIntervalRef.current);
      profileDeleteIntervalRef.current = null;
    }
    setProfileDeleteHoldProgress(0);
  };

  const startProfileDeleteHold = () => {
    if (!editingProfileId) return;
    const target = demoProfiles.find((p) => p.id === editingProfileId);
    if (!target) return;

    if (target.userCount > 0) {
      showToast(`Profil "${target.name}" masih digunakan oleh ${target.userCount} pelanggan, tidak dapat dihapus!`, 'error');
      return;
    }

    cancelProfileDeleteHold();
    const startTime = Date.now();
    const duration = 500; // 0.5 detik

    profileDeleteIntervalRef.current = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(100, Math.round((elapsed / duration) * 100));
      setProfileDeleteHoldProgress(progress);
    }, 25);

    profileDeleteTimerRef.current = setTimeout(() => {
      cancelProfileDeleteHold();
      handleDeleteProfile();
    }, duration);
  };

  const handleDeleteProfile = async () => {
    if (!editingProfileId) return;
    const target = demoProfiles.find((p) => p.id === editingProfileId);
    if (!target) return;

    if (target.userCount > 0) {
      showToast(`Profil "${target.name}" masih digunakan oleh ${target.userCount} pelanggan, tidak dapat dihapus!`, 'error');
      return;
    }

    const routerProfile = getSelectedProfile();
    try {
      if (routerProfile) {
        await mikrotikApiService.deletePppProfile(routerProfile, editingProfileId);
      }
      setDemoProfiles((prev) => prev.filter((p) => p.id !== editingProfileId));
      showToast(`Profil ${target.name} berhasil dihapus dari MikroTik.`, 'success');
      setIsProfileModalOpen(false);
      fetchPppoeData();
    } catch (err: any) {
      showToast(`Gagal menghapus profil di MikroTik: ${err?.message || 'Error'}`, 'error');
    }
  };

  const handleDeleteSecret = async (id: string, name: string) => {
    const routerProfile = getSelectedProfile();
    // Kick active sessions first
    setDemoActive((prev) => prev.filter((a) => a.name.toLowerCase() !== name.toLowerCase()));
    setDemoSecrets((prev) => prev.filter((s) => s.id !== id));
    setSelectedSecretId(null);
    setDeleteHoldProgress(0);

    if (routerProfile) {
      try {
        await mikrotikApiService.deletePppSecret(routerProfile, id);
        // Kick session on router too
        const activeSessions = demoActive.filter(
          (a) => a.name.toLowerCase() === name.toLowerCase()
        );
        for (const session of activeSessions) {
          try {
            await mikrotikApiService.disconnectPppActive(routerProfile, session.id);
          } catch {
            // ignore
          }
        }
        showToast(`Pelanggan ${name} berhasil dihapus dari MikroTik.`, 'success');
        fetchPppoeData();
      } catch (err: any) {
        showToast(`Gagal menghapus pelanggan di MikroTik: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      showToast(`Pelanggan ${name} berhasil dihapus.`, 'success');
    }
  };

  const startDeleteHold = (id: string, name: string) => {
    cancelDeleteHold();
    const startTime = Date.now();
    const duration = 500; // 0.5 detik

    deleteIntervalRef.current = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(100, Math.round((elapsed / duration) * 100));
      setDeleteHoldProgress(progress);
    }, 25);

    deleteTimerRef.current = setTimeout(() => {
      cancelDeleteHold();
      handleDeleteSecret(id, name);
    }, duration);
  };

  const cancelDeleteHold = () => {
    if (deleteTimerRef.current) {
      clearTimeout(deleteTimerRef.current);
      deleteTimerRef.current = null;
    }
    if (deleteIntervalRef.current) {
      clearInterval(deleteIntervalRef.current);
      deleteIntervalRef.current = null;
    }
    setDeleteHoldProgress(0);
  };

  const handleDisconnectActive = async (id: string, name: string) => {
    setDemoActive((prev) => prev.filter((a) => a.id !== id));
    const routerProfile = getSelectedProfile();
    if (routerProfile) {
      try {
        await mikrotikApiService.disconnectPppActive(routerProfile, id);
        showToast(`Sesi aktif ${name} berhasil diputus di MikroTik.`, 'info');
        fetchPppoeData();
      } catch (err: any) {
        showToast(`Gagal putus sesi di MikroTik: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      showToast(`Sesi aktif ${name} berhasil diputus.`, 'info');
    }
  };

  // Apple Pill Toast State
  const [toast, setToast] = useState<ToastData | null>(null);

  const showToast = useCallback((message: string, type: 'success' | 'error' | 'info' = 'success') => {
    setToast({ id: Date.now().toString(), message, type });
  }, []);

  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => {
        setToast(null);
      }, 3200);
      return () => clearTimeout(timer);
    }
  }, [toast]);

  // Clean up any hold-to-delete timers on unmount
  useEffect(() => {
    return () => {
      if (deleteTimerRef.current) clearTimeout(deleteTimerRef.current);
      if (deleteIntervalRef.current) clearInterval(deleteIntervalRef.current);
      if (profileDeleteTimerRef.current) clearTimeout(profileDeleteTimerRef.current);
      if (profileDeleteIntervalRef.current) clearInterval(profileDeleteIntervalRef.current);
      if (dhcpDeleteTimerRef.current) clearTimeout(dhcpDeleteTimerRef.current);
      if (dhcpDeleteIntervalRef.current) clearInterval(dhcpDeleteIntervalRef.current);
    };
  }, []);

  // Ping State
  const [isPinging, setIsPinging] = useState(false);
  const [pingStatus, setPingStatus] = useState<'idle' | 'success' | 'failed'>('idle');
  const [pingLatency, setPingLatency] = useState<number | null>(null);

  // Dashboard Live & System Info State (RouterOS v7)
  const defaultDashboardMetrics = {
    cpuLoad: 0,
    cpuCount: 0,
    cpuFreq: 0,
    usedMemoryMb: 0,
    freeMemoryMb: 0,
    totalMemoryMb: 0,
    usedHddMb: 0,
    freeHddMb: 0,
    totalHddMb: 0,
    temperature: null as number | null,
    voltage: null as number | null,
    pppoeActive: 0,
    pppoeIsolir: 0,
    hotspotActive: 0,
    hotspotTotal: 0,
    identity: '-',
    uptime: '-',
    time: '-',
    boardModel: '-',
    architecture: '-',
    rosVersion: '-',
    badBlocks: '-',
  };

  const [metrics, setMetrics] = useState(defaultDashboardMetrics);
  const [liveInterfaces, setLiveInterfaces] = useState<NetworkInterface[]>([]);
  const [syncStatus, setSyncStatus] = useState<'idle' | 'syncing' | 'connected' | 'error'>('idle');
  const [lastLatency, setLastLatency] = useState<number | null>(null);
  const [isDashboardRefreshing, setIsDashboardRefreshing] = useState(false);

  const isFetchingDashboardRef = useRef(false);
  const isFetchingPppoeRef = useRef(false);
  const lastDashboardErrorTimeRef = useRef<number>(0);

  // Router ID tracking ref to eliminate race conditions when user switches router
  const selectedMikrotikIdRef = useRef<string | null>(selectedMikrotikId);
  useEffect(() => {
    selectedMikrotikIdRef.current = selectedMikrotikId;
  }, [selectedMikrotikId]);

  // Fungsi reset total data dashboard, PPPoE & DHCP saat ganti perangkat MikroTik
  const resetAllRouterData = useCallback(() => {
    setMetrics(defaultDashboardMetrics);
    setLiveInterfaces([]);
    setDemoSecrets([]);
    setDemoProfiles([]);
    setDemoActive([]);
    setIpPools([]);
    setDhcpLeases([]);
    setHotspotUsers([]);
    setHotspotActive([]);
    setHotspotProfiles([]);
    setSelectedSecretId(null);
    setSelectedLease(null);
    setSelectedHotspotUser(null);
    setEditingProfileId(null);
    setEditingHotspotProfileId(null);
    setIsProfileModalOpen(false);
    setIsHotspotProfileModalOpen(false);
    setIsAddUserModalOpen(false);
    setIsAddHotspotUserModalOpen(false);
    setSyncStatus('syncing');
    setLastLatency(null);
    setIsDashboardRefreshing(false);
    isFetchingDashboardRef.current = false;
    isFetchingPppoeRef.current = false;
    isFetchingDhcpRef.current = false;
    isFetchingHotspotRef.current = false;
  }, []);

  // Deteksi pergantian router: Reset seketika isi dashboard dan PPPoE agar data lama tidak bocor
  const prevSelectedMikrotikIdRef = useRef<string | null>(null);
  useEffect(() => {
    if (prevSelectedMikrotikIdRef.current && prevSelectedMikrotikIdRef.current !== selectedMikrotikId) {
      resetAllRouterData();
    }
    prevSelectedMikrotikIdRef.current = selectedMikrotikId;
  }, [selectedMikrotikId, resetAllRouterData]);

  const demoSecretsRef = useRef(demoSecrets);
  useEffect(() => {
    demoSecretsRef.current = demoSecrets;
  }, [demoSecrets]);

  // READ-ONLY (Strictly GET requests only) Fetching for Dashboard ONLY
  const fetchDashboardData = useCallback(async (isManual: boolean = false) => {
    if (isFetchingDashboardRef.current) return;
    const profile = getSelectedProfile();
    if (!profile) {
      setSyncStatus('idle');
      return;
    }

    const currentProfileId = profile.id;
    isFetchingDashboardRef.current = true;
    setSyncStatus((prev) => (prev === 'connected' ? 'connected' : 'syncing'));
    const startTime = performance.now();

    try {
      // STRICT GET ONLY - Read-only calls for Dashboard & Hardware Telemetry
      const [
        resResource,
        resIdentity,
        resClock,
        resHealth,
        resInterfaces,
        resPppActive,
        resHotspotActive,
        resHotspotUsers,
      ] = await Promise.allSettled([
        mikrotikApiService.getSystemResource(profile),
        mikrotikApiService.getSystemIdentity(profile),
        mikrotikApiService.getSystemClock(profile),
        mikrotikApiService.getSystemHealth(profile),
        mikrotikApiService.getInterfaces(profile),
        mikrotikApiService.getPppActive(profile),
        mikrotikApiService.getHotspotActive(profile),
        mikrotikApiService.getHotspotUsers(profile),
      ]);

      // Batalkan penyimpanan jika router sudah berganti selama request berlangsung
      if (selectedMikrotikIdRef.current !== currentProfileId) {
        return;
      }

      const identityData = resIdentity.status === 'fulfilled' ? resIdentity.value : {};
      const clockData = resClock.status === 'fulfilled' ? resClock.value : {};
      const healthData = resHealth.status === 'fulfilled' ? resHealth.value : [];
      const ifacesData = resInterfaces.status === 'fulfilled' ? resInterfaces.value : [];
      const pppActiveData = resPppActive.status === 'fulfilled' ? resPppActive.value : [];
      const hotspotActiveData = resHotspotActive.status === 'fulfilled' ? resHotspotActive.value : [];
      const hotspotUsersData = resHotspotUsers.status === 'fulfilled' ? resHotspotUsers.value : [];

      if (resResource.status === 'fulfilled') {
        const resource = resResource.value || {};
        const totalMem = Math.round(Number(resource['total-memory'] || 0) / (1024 * 1024));
        const freeMem = Math.round(Number(resource['free-memory'] || 0) / (1024 * 1024));
        const usedMem = Math.max(0, totalMem - freeMem);

        const totalHdd = Math.round(Number(resource['total-hdd-space'] || 0) / (1024 * 1024));
        const freeHdd = Math.round(Number(resource['free-hdd-space'] || 0) / (1024 * 1024));
        const usedHdd = Math.max(0, totalHdd - freeHdd);

        const cpuLoad = Math.max(0, Math.min(100, Math.round(Number(resource['cpu-load'] || 0))));
        const cpuCount = Number(resource['cpu-count'] || 1);
        const cpuFreq = Number(resource['cpu-frequency'] || 0);

        let temperature: number | null = null;
        let voltage: number | null = null;
        if (Array.isArray(healthData)) {
          const tempEntry = healthData.find((h) => /temp/i.test(h.name));
          if (tempEntry && tempEntry.value !== undefined) {
            temperature = Math.round(parseFloat(String(tempEntry.value)));
          }
          const voltEntry = healthData.find((h) => /volt/i.test(h.name));
          if (voltEntry && voltEntry.value !== undefined) {
            voltage = +(parseFloat(String(voltEntry.value))).toFixed(1);
          }
        }

        const pppoeActiveCount = Array.isArray(pppActiveData) ? pppActiveData.length : 0;
        const hotspotActiveCount = Array.isArray(hotspotActiveData) ? hotspotActiveData.length : 0;
        const hotspotTotalCount = Array.isArray(hotspotUsersData) ? hotspotUsersData.length : 0;

        const identity = identityData?.name || resource['board-name'] || profile.host;
        const timeStr =
          [clockData?.date, clockData?.time].filter(Boolean).join(' ') || new Date().toLocaleString();

        setMetrics((prev) => ({
          ...prev,
          cpuLoad,
          cpuCount,
          cpuFreq,
          usedMemoryMb: usedMem || 0,
          freeMemoryMb: freeMem || 0,
          totalMemoryMb: totalMem || 1,
          usedHddMb: usedHdd || 0,
          freeHddMb: freeHdd || 0,
          totalHddMb: totalHdd || 1,
          temperature,
          voltage,
          pppoeActive: pppoeActiveCount,
          pppoeIsolir: demoSecretsRef.current.length > 0 ? demoSecretsRef.current.filter((s) => s.disabled).length : prev.pppoeIsolir,
          hotspotActive: hotspotActiveCount,
          hotspotTotal: hotspotTotalCount,
          identity,
          uptime: String(resource['uptime'] || '-'),
          time: timeStr,
          boardModel: String(resource['board-name'] || resource['platform'] || '-'),
          architecture: String(resource['architecture-name'] || '-'),
          rosVersion: String(resource['version'] || '-'),
          badBlocks:
            resource['bad-blocks'] !== undefined
              ? `${resource['bad-blocks']}% (Normal / Sehat)`
              : '0.0% (Normal / Sehat)',
        }));
      }

      if (Array.isArray(ifacesData) && ifacesData.length > 0) {
        setLiveInterfaces(ifacesData);
      }

      if (resResource.status === 'fulfilled') {
        const duration = Math.round(performance.now() - startTime);
        setLastLatency(duration);
        setSyncStatus('connected');
      } else {
        setSyncStatus('error');
        const reason =
          resResource.status === 'rejected'
            ? resResource.reason?.message || 'Gagal koneksi ke router'
            : 'Gagal memuat data Dashboard';
        const now = Date.now();
        if (isManual || now - lastDashboardErrorTimeRef.current > 10000) {
          lastDashboardErrorTimeRef.current = now;
          showToast(`Gagal memuat data Dashboard: ${reason}`, 'error');
        }
      }
    } catch (err: any) {
      if (selectedMikrotikIdRef.current === currentProfileId) {
        setSyncStatus('error');
        const now = Date.now();
        if (isManual || now - lastDashboardErrorTimeRef.current > 10000) {
          lastDashboardErrorTimeRef.current = now;
          showToast(`Gagal memuat data Dashboard: ${err?.message || 'Error koneksi'}`, 'error');
        }
      }
    } finally {
      isFetchingDashboardRef.current = false;
      setIsDashboardRefreshing(false);
    }
  }, [getSelectedProfile]);

  // READ-ONLY (Strictly GET requests only) Fetching for PPPoE ONLY
  const fetchPppoeData = useCallback(async () => {
    if (isFetchingPppoeRef.current) return;
    const profile = getSelectedProfile();
    if (!profile) {
      setSyncStatus('idle');
      return;
    }

    const currentProfileId = profile.id;
    isFetchingPppoeRef.current = true;
    setIsPppRefreshing(true);
    const startTime = performance.now();

    try {
      // STRICT GET ONLY - Read-only calls for PPPoE Secrets, Profiles, Active Sessions & IP Pools
      const [resPppSecrets, resPppProfiles, resPppActive, resPools] = await Promise.allSettled([
        mikrotikApiService.getPppSecrets(profile),
        mikrotikApiService.getPppProfiles(profile),
        mikrotikApiService.getPppActive(profile),
        mikrotikApiService.getIpPools(profile),
      ]);

      // Batalkan penyimpanan jika router sudah berganti selama request berlangsung
      if (selectedMikrotikIdRef.current !== currentProfileId) {
        return;
      }

      const pppSecretsData = resPppSecrets.status === 'fulfilled' ? resPppSecrets.value : [];
      const pppProfilesData = resPppProfiles.status === 'fulfilled' ? resPppProfiles.value : [];
      const pppActiveData = resPppActive.status === 'fulfilled' ? resPppActive.value : [];

      if (resPools.status === 'fulfilled' && Array.isArray(resPools.value)) {
        setIpPools(resPools.value);
      }

      if (resPppSecrets.status === 'fulfilled' && Array.isArray(pppSecretsData)) {
        setDemoSecrets(
          pppSecretsData.map((s) => ({
            id: s['.id'] || s.name,
            name: s.name,
            service: s.service || 'pppoe',
            profile: s.profile || 'default',
            comment: s.comment || '',
            disabled: s.disabled === true || s.disabled === 'true',
            remoteAddress: s['remote-address'] || '',
          }))
        );

        const isolirCount = pppSecretsData.filter(
          (s) => s.disabled === true || s.disabled === 'true'
        ).length;
        setMetrics((prev) => ({ ...prev, pppoeIsolir: isolirCount }));
      }

      if (resPppActive.status === 'fulfilled' && Array.isArray(pppActiveData)) {
        setDemoActive(
          pppActiveData.map((a) => ({
            id: a['.id'] || a['session-id'] || a.name,
            name: a.name,
            service: a.service || 'pppoe',
            callerId: a['caller-id'] || '-',
            address: a.address || '-',
            uptime: a.uptime || '-',
          }))
        );
        setMetrics((prev) => ({ ...prev, pppoeActive: pppActiveData.length }));
      }

      if (resPppProfiles.status === 'fulfilled' && Array.isArray(pppProfilesData)) {
        const secList = Array.isArray(pppSecretsData) ? pppSecretsData : [];
        const isHiddenDefault = (name: string) => {
          const lower = (name || '').toLowerCase().trim();
          return lower === 'default' || lower === 'default-encryption';
        };

        setDemoProfiles(
          pppProfilesData
            .filter((p) => !isHiddenDefault(p.name))
            .map((p) => ({
              id: p['.id'] || p.name,
              name: p.name,
              rateLimit: p['rate-limit'] || '-',
              localAddress: p['local-address'] || '-',
              remotePool: p['remote-address'] || '-',
              onlyOne: p['only-one'] ? String(p['only-one']) : 'default',
              dnsServer: p['dns-server'] || '',
              comment: p.comment || '',
              userCount: secList.filter((s) => s.profile === p.name).length,
            }))
        );
      }

      if (
        resPppSecrets.status === 'fulfilled' ||
        resPppActive.status === 'fulfilled' ||
        resPppProfiles.status === 'fulfilled'
      ) {
        const duration = Math.round(performance.now() - startTime);
        setLastLatency(duration);
        setSyncStatus('connected');
      } else {
        setSyncStatus('error');
        const reason =
          (resPppSecrets.status === 'rejected' && resPppSecrets.reason?.message) ||
          (resPppProfiles.status === 'rejected' && resPppProfiles.reason?.message) ||
          (resPppActive.status === 'rejected' && resPppActive.reason?.message) ||
          'Gagal menghubungi router';
        showToast(`Gagal memuat data PPPoE: ${reason}`, 'error');
      }
    } catch (err: any) {
      if (selectedMikrotikIdRef.current === currentProfileId) {
        setSyncStatus('error');
        showToast(`Gagal memuat data PPPoE: ${err?.message || 'Error koneksi'}`, 'error');
      }
    } finally {
      isFetchingPppoeRef.current = false;
      setIsPppRefreshing(false);
    }
  }, [getSelectedProfile]);

  // READ-ONLY Fetching for DHCP Leases ONLY
  const fetchDhcpData = useCallback(async () => {
    if (isFetchingDhcpRef.current) return;
    const profile = getSelectedProfile();
    if (!profile) return;

    const currentProfileId = profile.id;
    isFetchingDhcpRef.current = true;
    setIsDhcpRefreshing(true);
    const startTime = performance.now();

    try {
      const leases = await mikrotikApiService.getDhcpLeases(profile);
      if (selectedMikrotikIdRef.current !== currentProfileId) return;
      const duration = Math.round(performance.now() - startTime);
      setLastLatency(duration);
      if (Array.isArray(leases)) {
        setDhcpLeases(leases);
      }
    } catch (err: any) {
      if (selectedMikrotikIdRef.current === currentProfileId) {
        showToast(`Gagal memuat DHCP Leases: ${err?.message || 'Error'}`, 'error');
      }
    } finally {
      isFetchingDhcpRef.current = false;
      setIsDhcpRefreshing(false);
    }
  }, [getSelectedProfile]);

  const handleMakeStaticLease = async (lease: DhcpLease) => {
    const routerProfile = getSelectedProfile();
    if (!routerProfile) {
      showToast('Pilih router terlebih dahulu.', 'error');
      return;
    }

    try {
      await mikrotikApiService.makeDhcpLeaseStatic(routerProfile, lease['.id']);
      showToast(`Lease ${lease.address} dijadikan Static!`, 'success');
      setDhcpLeases((prev) =>
        prev.map((l) => (l['.id'] === lease['.id'] ? { ...l, dynamic: false } : l))
      );
      if (selectedLease && selectedLease['.id'] === lease['.id']) {
        setSelectedLease((prev) => (prev ? { ...prev, dynamic: false } : null));
      }
      fetchDhcpData();
    } catch (err: any) {
      showToast(`Gagal menjadikan static: ${err?.message || 'Error'}`, 'error');
    }
  };

  const handleReleaseStaticLease = async (lease: DhcpLease) => {
    const routerProfile = getSelectedProfile();
    if (!routerProfile) {
      showToast(`Reservasi static ${lease.address} dilepas (kembali dynamic)!`, 'success');
      setDhcpLeases((prev) =>
        prev.map((l) => (l['.id'] === lease['.id'] ? { ...l, dynamic: true } : l))
      );
      if (selectedLease && selectedLease['.id'] === lease['.id']) {
        setSelectedLease((prev) => (prev ? { ...prev, dynamic: true } : null));
      }
      return;
    }

    try {
      await mikrotikApiService.releaseDhcpLeaseStatic(routerProfile, lease['.id']);
      showToast(`Reservasi static ${lease.address} dilepas (kembali dynamic)!`, 'success');
      setDhcpLeases((prev) =>
        prev.map((l) => (l['.id'] === lease['.id'] ? { ...l, dynamic: true } : l))
      );
      if (selectedLease && selectedLease['.id'] === lease['.id']) {
        setSelectedLease((prev) => (prev ? { ...prev, dynamic: true } : null));
      }
      fetchDhcpData();
    } catch (err: any) {
      showToast(`Gagal melepas static: ${err?.message || 'Error'}`, 'error');
    }
  };

  const handleDeleteDhcpLease = async (lease: DhcpLease) => {
    const routerProfile = getSelectedProfile();
    if (!routerProfile) {
      showToast('Pilih router terlebih dahulu.', 'error');
      return;
    }

    try {
      await mikrotikApiService.deleteDhcpLease(routerProfile, lease['.id']);
      showToast(`Lease ${lease.address} (${lease['mac-address']}) berhasil dihapus.`, 'success');
      setDhcpLeases((prev) => prev.filter((l) => l['.id'] !== lease['.id']));
      setSelectedLease(null);
      fetchDhcpData();
    } catch (err: any) {
      showToast(`Gagal menghapus lease: ${err?.message || 'Error'}`, 'error');
    }
  };

  const startDhcpDeleteHold = (lease: DhcpLease) => {
    cancelDhcpDeleteHold();
    setDhcpDeleteHoldId(lease['.id']);
    const startTime = Date.now();
    const duration = 500; // 0.5s hold

    dhcpDeleteIntervalRef.current = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(100, Math.round((elapsed / duration) * 100));
      setDhcpDeleteHoldProgress(progress);
    }, 25);

    dhcpDeleteTimerRef.current = setTimeout(() => {
      cancelDhcpDeleteHold();
      handleDeleteDhcpLease(lease);
    }, duration);
  };

  const cancelDhcpDeleteHold = () => {
    if (dhcpDeleteTimerRef.current) {
      clearTimeout(dhcpDeleteTimerRef.current);
      dhcpDeleteTimerRef.current = null;
    }
    if (dhcpDeleteIntervalRef.current) {
      clearInterval(dhcpDeleteIntervalRef.current);
      dhcpDeleteIntervalRef.current = null;
    }
    setDhcpDeleteHoldId(null);
    setDhcpDeleteHoldProgress(0);
  };

  // READ-ONLY Fetching for Hotspot ONLY
  const fetchHotspotData = useCallback(async () => {
    if (isFetchingHotspotRef.current) return;
    const profile = getSelectedProfile();
    if (!profile) return;

    const currentProfileId = profile.id;
    isFetchingHotspotRef.current = true;
    setIsHotspotRefreshing(true);
    const startTime = performance.now();

    try {
      const [resUsers, resActive, resProfiles] = await Promise.allSettled([
        mikrotikApiService.getHotspotUsers(profile),
        mikrotikApiService.getHotspotActive(profile),
        mikrotikApiService.getHotspotProfiles(profile),
      ]);

      if (selectedMikrotikIdRef.current !== currentProfileId) return;

      if (
        resUsers.status === 'fulfilled' ||
        resActive.status === 'fulfilled' ||
        resProfiles.status === 'fulfilled'
      ) {
        const duration = Math.round(performance.now() - startTime);
        setLastLatency(duration);

        if (resUsers.status === 'fulfilled' && Array.isArray(resUsers.value)) {
          setHotspotUsers(resUsers.value.filter((u) => !isHiddenDefaultUser(u.name)));
        }
        if (resActive.status === 'fulfilled' && Array.isArray(resActive.value)) {
          setHotspotActive(resActive.value);
        }
        if (resProfiles.status === 'fulfilled' && Array.isArray(resProfiles.value)) {
          setHotspotProfiles(resProfiles.value.filter((p) => !isHiddenDefaultProfile(p.name)));
        }
      } else {
        const reason =
          (resUsers.status === 'rejected' && resUsers.reason?.message) ||
          (resProfiles.status === 'rejected' && resProfiles.reason?.message) ||
          (resActive.status === 'rejected' && resActive.reason?.message) ||
          'Gagal menghubungi router';
        showToast(`Gagal memuat data Hotspot: ${reason}`, 'error');
      }
    } catch (err: any) {
      if (selectedMikrotikIdRef.current === currentProfileId) {
        showToast(`Gagal memuat data Hotspot: ${err?.message || 'Error koneksi'}`, 'error');
      }
    } finally {
      isFetchingHotspotRef.current = false;
      setIsHotspotRefreshing(false);
    }
  }, [getSelectedProfile]);

  const handleCreateHotspotUser = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmedName = newHotspotUserName.trim();
    if (!trimmedName) {
      showToast('Username Hotspot tidak boleh kosong', 'error');
      return;
    }

    const routerProfile = getSelectedProfile();
    const newUserData: Partial<HotspotUser> = {
      name: trimmedName,
      password: newHotspotUserPass.trim() || undefined,
      profile: newHotspotUserProfile || 'default',
      'limit-uptime': newHotspotUserLimitUptime.trim() || undefined,
      comment: newHotspotUserComment.trim() || undefined,
    };

    if (routerProfile) {
      try {
        await mikrotikApiService.createHotspotUser(routerProfile, newUserData);
        showToast(`User Hotspot ${trimmedName} berhasil dibuat di MikroTik!`, 'success');
        setIsAddHotspotUserModalOpen(false);
        setNewHotspotUserName('');
        setNewHotspotUserPass('');
        setNewHotspotUserProfile('default');
        setNewHotspotUserLimitUptime('');
        setNewHotspotUserComment('');
        fetchHotspotData();
      } catch (err: any) {
        showToast(`Gagal membuat user Hotspot: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      const dummy: HotspotUser = {
        '.id': `*H${Date.now()}`,
        name: trimmedName,
        password: newHotspotUserPass.trim() || undefined,
        profile: newHotspotUserProfile || 'default',
        uptime: '0s',
        'bytes-in': '0',
        'bytes-out': '0',
        'limit-uptime': newHotspotUserLimitUptime.trim() || undefined,
        comment: newHotspotUserComment.trim() || undefined,
        disabled: false,
      };
      setHotspotUsers((prev) => [dummy, ...prev]);
      showToast(`User Hotspot ${trimmedName} berhasil ditambahkan!`, 'success');
      setIsAddHotspotUserModalOpen(false);
      setNewHotspotUserName('');
      setNewHotspotUserPass('');
      setNewHotspotUserProfile('default');
      setNewHotspotUserLimitUptime('');
      setNewHotspotUserComment('');
    }
  };

  const handleOpenEditHotspotUser = (user: HotspotUser) => {
    setSelectedHotspotUser(user);
    setEditHotspotUserPass(user.password || '');
    setEditHotspotUserProfile(user.profile || 'default');
    setEditHotspotUserLimitUptime(user['limit-uptime'] || '');
    setEditHotspotUserComment(user.comment || '');
    cancelHotspotDeleteHold();
  };

  const handleSaveEditHotspotUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedHotspotUser) return;

    const routerProfile = getSelectedProfile();
    const updates: Partial<HotspotUser> = {
      profile: editHotspotUserProfile || 'default',
      'limit-uptime': editHotspotUserLimitUptime.trim() || undefined,
      comment: editHotspotUserComment.trim() || undefined,
    };
    if (editHotspotUserPass.trim()) {
      updates.password = editHotspotUserPass.trim();
    }

    if (routerProfile) {
      try {
        await mikrotikApiService.updateHotspotUser(routerProfile, selectedHotspotUser['.id'], updates);
        showToast(`User ${selectedHotspotUser.name} berhasil diperbarui di MikroTik!`, 'success');
        setHotspotUsers((prev) =>
          prev.map((u) => (u['.id'] === selectedHotspotUser['.id'] ? { ...u, ...updates } : u))
        );
        setSelectedHotspotUser(null);
        fetchHotspotData();
      } catch (err: any) {
        showToast(`Gagal update user Hotspot: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      setHotspotUsers((prev) =>
        prev.map((u) => (u['.id'] === selectedHotspotUser['.id'] ? { ...u, ...updates } : u))
      );
      showToast(`User ${selectedHotspotUser.name} berhasil diperbarui!`, 'success');
      setSelectedHotspotUser(null);
    }
  };

  const handleToggleDisableHotspotUser = async (user: HotspotUser) => {
    const nextDisabled = !(user.disabled === true || user.disabled === 'true');
    const routerProfile = getSelectedProfile();

    setHotspotUsers((prev) =>
      prev.map((u) => (u['.id'] === user['.id'] ? { ...u, disabled: nextDisabled } : u))
    );
    if (selectedHotspotUser && selectedHotspotUser['.id'] === user['.id']) {
      setSelectedHotspotUser((prev) => (prev ? { ...prev, disabled: nextDisabled } : null));
    }

    if (routerProfile) {
      try {
        await mikrotikApiService.updateHotspotUser(routerProfile, user['.id'], {
          disabled: nextDisabled ? 'true' : 'false',
        });
        if (nextDisabled) {
          const activeSession = hotspotActive.find(
            (a) => a.user.toLowerCase() === user.name.toLowerCase()
          );
          if (activeSession) {
            try {
              await mikrotikApiService.disconnectHotspotActive(routerProfile, activeSession['.id']);
            } catch {
              // ignore
            }
            setHotspotActive((prev) =>
              prev.filter((a) => a.user.toLowerCase() !== user.name.toLowerCase())
            );
          }
        }
        showToast(
          nextDisabled
            ? `User ${user.name} berhasil dinonaktifkan.`
            : `User ${user.name} berhasil diaktifkan kembali.`,
          nextDisabled ? 'error' : 'success'
        );
        fetchHotspotData();
      } catch (err: any) {
        setHotspotUsers((prev) =>
          prev.map((u) => (u['.id'] === user['.id'] ? { ...u, disabled: !nextDisabled } : u))
        );
        showToast(`Gagal update status: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      showToast(
        nextDisabled
          ? `User ${user.name} dinonaktifkan.`
          : `User ${user.name} diaktifkan kembali.`,
        nextDisabled ? 'error' : 'success'
      );
    }
  };

  const handleDeleteHotspotUser = async (user: HotspotUser) => {
    const routerProfile = getSelectedProfile();
    if (routerProfile) {
      try {
        await mikrotikApiService.deleteHotspotUser(routerProfile, user['.id']);
        showToast(`User ${user.name} berhasil dihapus dari MikroTik.`, 'success');
        setHotspotUsers((prev) => prev.filter((u) => u['.id'] !== user['.id']));
        setSelectedHotspotUser(null);
        fetchHotspotData();
      } catch (err: any) {
        showToast(`Gagal menghapus user: ${err?.message || 'Error'}`, 'error');
      }
    } else {
      setHotspotUsers((prev) => prev.filter((u) => u['.id'] !== user['.id']));
      setSelectedHotspotUser(null);
      showToast(`User ${user.name} berhasil dihapus.`, 'success');
    }
  };

  const startHotspotDeleteHold = (user: HotspotUser) => {
    cancelHotspotDeleteHold();
    setHotspotDeleteHoldId(user['.id']);
    const startTime = Date.now();
    const duration = 500;

    hotspotDeleteIntervalRef.current = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(100, Math.round((elapsed / duration) * 100));
      setHotspotDeleteHoldProgress(progress);
    }, 25);

    hotspotDeleteTimerRef.current = setTimeout(() => {
      cancelHotspotDeleteHold();
      handleDeleteHotspotUser(user);
    }, duration);
  };

  const cancelHotspotDeleteHold = () => {
    if (hotspotDeleteTimerRef.current) {
      clearTimeout(hotspotDeleteTimerRef.current);
      hotspotDeleteTimerRef.current = null;
    }
    if (hotspotDeleteIntervalRef.current) {
      clearInterval(hotspotDeleteIntervalRef.current);
      hotspotDeleteIntervalRef.current = null;
    }
    setHotspotDeleteHoldId(null);
    setHotspotDeleteHoldProgress(0);
  };


  const handleClearHotspotActiveMac = async (session: HotspotActive) => {
    const routerProfile = getSelectedProfile();
    const targetUser = hotspotUsers.find(
      (u) => u.name.toLowerCase() === session.user.toLowerCase()
    );

    try {
      if (routerProfile) {
        if (targetUser && targetUser['.id']) {
          await mikrotikApiService.clearHotspotUserMac(routerProfile, targetUser['.id']);
        } else {
          await mikrotikApiService.clearHotspotUserMacByName(routerProfile, session.user);
        }
        await mikrotikApiService.disconnectHotspotActive(routerProfile, session['.id']);
        setHotspotActive((prev) => prev.filter((a) => a['.id'] !== session['.id']));
        setHotspotUsers((prev) =>
          prev.map((u) =>
            u.name.toLowerCase() === session.user.toLowerCase()
              ? { ...u, 'mac-address': '' }
              : u
          )
        );
        showToast(`Lock MAC ${session.user} berhasil di-clear & sesi di-reset!`, 'success');
        fetchHotspotData();
      } else {
        setHotspotActive((prev) => prev.filter((a) => a['.id'] !== session['.id']));
        setHotspotUsers((prev) =>
          prev.map((u) =>
            u.name.toLowerCase() === session.user.toLowerCase()
              ? { ...u, 'mac-address': '' }
              : u
          )
        );
        showToast(`Lock MAC ${session.user} berhasil di-clear & sesi di-reset!`, 'success');
      }
    } catch (err: any) {
      showToast(`Gagal clear MAC: ${err?.message || 'Error'}`, 'error');
    }
  };

  const handleClearHotspotUserMac = async (user: HotspotUser) => {
    const routerProfile = getSelectedProfile();
    try {
      if (routerProfile) {
        await mikrotikApiService.clearHotspotUserMac(routerProfile, user['.id']);
        showToast(`Lock MAC user ${user.name} berhasil di-clear!`, 'success');
        fetchHotspotData();
      } else {
        showToast(`Lock MAC user ${user.name} berhasil di-clear!`, 'success');
      }
      setHotspotUsers((prev) =>
        prev.map((u) => (u['.id'] === user['.id'] ? { ...u, 'mac-address': '' } : u))
      );
      if (selectedHotspotUser && selectedHotspotUser['.id'] === user['.id']) {
        setSelectedHotspotUser((prev) => (prev ? { ...prev, 'mac-address': '' } : null));
      }
    } catch (err: any) {
      showToast(`Gagal clear MAC user: ${err?.message || 'Error'}`, 'error');
    }
  };

  const handleOpenAddHotspotProfile = () => {
    setEditingHotspotProfileId(null);
    setHotspotProfileFormName('');
    setHotspotProfileFormRateLimit('');
    setHotspotProfileFormSharedUsers('1');
    const defaultPool = poolOptions[0]?.name || '';
    setHotspotProfileFormAddressPool(defaultPool);
    setIsHotspotManualPool(false);
    setHotspotProfileFormAutorefresh('1m');
    setHotspotProfileFormValidity('');
    cancelHotspotProfileDeleteHold();
    setIsHotspotProfileModalOpen(true);
  };

  const handleOpenEditHotspotProfile = (prof: HotspotProfile) => {
    setEditingHotspotProfileId(prof['.id']);
    setHotspotProfileFormName(prof.name);
    setHotspotProfileFormRateLimit(prof['rate-limit'] || '');
    setHotspotProfileFormSharedUsers(String(prof['shared-users'] || '1'));
    const targetPool = prof['address-pool'] || '';
    setHotspotProfileFormAddressPool(targetPool);
    const isKnownPool = !targetPool || poolOptions.some((p) => p.name === targetPool);
    setIsHotspotManualPool(!isKnownPool);
    setHotspotProfileFormAutorefresh(prof['status-autorefresh'] || '1m');
    const existingValidity =
      prof.validity ||
      prof.comment?.match(/validity:\s*([^\s,;]+)/i)?.[1] ||
      prof.comment ||
      '';
    setHotspotProfileFormValidity(existingValidity);
    cancelHotspotProfileDeleteHold();
    setIsHotspotProfileModalOpen(true);
  };

  const handleSaveHotspotProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmedName = hotspotProfileFormName.trim();
    if (!trimmedName) {
      showToast('Nama profil hotspot tidak boleh kosong', 'error');
      return;
    }

    setIsSavingHotspotProfile(true);
    const routerProfile = getSelectedProfile();
    const trimmedValidity = hotspotProfileFormValidity.trim();
    const payload: Partial<HotspotProfile> = {
      name: trimmedName,
      'rate-limit': hotspotProfileFormRateLimit.trim() || undefined,
      'shared-users': hotspotProfileFormSharedUsers.trim() || '1',
      'address-pool': hotspotProfileFormAddressPool.trim() || undefined,
      'status-autorefresh': hotspotProfileFormAutorefresh.trim() || '1m',
      validity: trimmedValidity || undefined,
      comment: trimmedValidity ? `validity: ${trimmedValidity}` : undefined,
    };

    try {
      if (editingHotspotProfileId) {
        if (routerProfile) {
          await mikrotikApiService.updateHotspotProfile(routerProfile, editingHotspotProfileId, payload);
        }
        setHotspotProfiles((prev) =>
          prev.map((p) =>
            p['.id'] === editingHotspotProfileId
              ? { ...p, ...payload }
              : p
          )
        );
        showToast(`Profil Hotspot ${trimmedName} berhasil diperbarui!`, 'success');
      } else {
        let newId = `*HP${Date.now()}`;
        if (routerProfile) {
          const res = await mikrotikApiService.createHotspotProfile(routerProfile, payload);
          newId = res?.['.id'] || res?.ret || trimmedName;
        }
        const newProf: HotspotProfile = {
          '.id': newId,
          name: trimmedName,
          ...payload,
        };
        setHotspotProfiles((prev) => [...prev, newProf]);
        showToast(`Profil Hotspot ${trimmedName} berhasil ditambahkan!`, 'success');
      }
      setIsHotspotProfileModalOpen(false);
      fetchHotspotData();
    } catch (err: any) {
      showToast(`Gagal menyimpan profil hotspot: ${err?.message || 'Error'}`, 'error');
    } finally {
      setIsSavingHotspotProfile(false);
    }
  };

  const cancelHotspotProfileDeleteHold = () => {
    if (hotspotProfileDeleteTimerRef.current) {
      clearTimeout(hotspotProfileDeleteTimerRef.current);
      hotspotProfileDeleteTimerRef.current = null;
    }
    if (hotspotProfileDeleteIntervalRef.current) {
      clearInterval(hotspotProfileDeleteIntervalRef.current);
      hotspotProfileDeleteIntervalRef.current = null;
    }
    setHotspotProfileDeleteHoldProgress(0);
  };

  const startHotspotProfileDeleteHold = () => {
    if (!editingHotspotProfileId) return;
    const target = hotspotProfiles.find((p) => p['.id'] === editingHotspotProfileId);
    if (!target) return;

    const userCount = hotspotUsers.filter((u) => u.profile === target.name && !isHiddenDefaultUser(u.name)).length;
    if (userCount > 0) {
      showToast(`Profil "${target.name}" masih digunakan oleh ${userCount} user hotspot, tidak dapat dihapus!`, 'error');
      return;
    }

    cancelHotspotProfileDeleteHold();
    const startTime = Date.now();
    const duration = 500;

    hotspotProfileDeleteIntervalRef.current = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(100, Math.round((elapsed / duration) * 100));
      setHotspotProfileDeleteHoldProgress(progress);
    }, 25);

    hotspotProfileDeleteTimerRef.current = setTimeout(() => {
      cancelHotspotProfileDeleteHold();
      handleDeleteHotspotProfile();
    }, duration);
  };

  const handleDeleteHotspotProfile = async () => {
    if (!editingHotspotProfileId) return;
    const target = hotspotProfiles.find((p) => p['.id'] === editingHotspotProfileId);
    if (!target) return;

    const userCount = hotspotUsers.filter((u) => u.profile === target.name && !isHiddenDefaultUser(u.name)).length;
    if (userCount > 0) {
      showToast(`Profil "${target.name}" masih digunakan oleh ${userCount} user hotspot, tidak dapat dihapus!`, 'error');
      return;
    }

    const routerProfile = getSelectedProfile();
    try {
      if (routerProfile) {
        await mikrotikApiService.deleteHotspotProfile(routerProfile, editingHotspotProfileId);
      }
      setHotspotProfiles((prev) => prev.filter((p) => p['.id'] !== editingHotspotProfileId));
      showToast(`Profil Hotspot ${target.name} berhasil dihapus.`, 'success');
      setIsHotspotProfileModalOpen(false);
      fetchHotspotData();
    } catch (err: any) {
      showToast(`Gagal menghapus profil: ${err?.message || 'Error'}`, 'error');
    }
  };

  const handleCopyText = (text: string, label: string) => {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text);
      }
      showToast(`${label} disalin ke clipboard!`, 'info');
    } catch {
      showToast(`Gagal menyalin: ${text}`, 'error');
    }
  };

  // Polling Dashboard Real-Time: Berjalan setiap 1 detik HANYA saat user membuka tab Beranda
  useEffect(() => {
    if (!selectedMikrotikId) return;

    if (activeTab === 'beranda') {
      fetchDashboardData();
      // Pre-fetch data PPPoE 1x saat buka dashboard agar saat pindah tab langsung siap
      fetchPppoeData();

      const interval = setInterval(() => {
        fetchDashboardData();
      }, 1000);

      return () => {
        clearInterval(interval);
      };
    }
  }, [selectedMikrotikId, activeTab]);

  // Halaman PPPoE: Cukup read 1x saja saat buka tab PPPoE atau saat ganti sub-tab (User / Profile / Active)
  // Tidak ada looping polling interval otomatis jika tidak ada aksi dari pengguna
  useEffect(() => {
    if (!selectedMikrotikId) return;

    if (activeTab === 'pppoe') {
      fetchPppoeData();
    }
  }, [selectedMikrotikId, activeTab, pppSubTab]);

  // Halaman DHCP Leases: Cukup read 1x saja saat buka tab DHCP
  // Tidak ada looping polling interval otomatis jika tidak ada aksi dari pengguna
  useEffect(() => {
    if (!selectedMikrotikId) return;

    if (activeTab === 'dhcp') {
      fetchDhcpData();
    }
  }, [selectedMikrotikId, activeTab]);

  // Halaman Hotspot: Cukup read 1x saja saat buka tab Hotspot atau ganti sub-tab
  useEffect(() => {
    if (!selectedMikrotikId) return;

    if (activeTab === 'hotspot') {
      fetchHotspotData();
    }
  }, [selectedMikrotikId, activeTab, hotspotSubTab]);

  // Restore saved login session, master credentials, and MikroTik list on mount
  useEffect(() => {
    try {
      const master = getStoredMasterAuth();
      setMasterUsername(master.username);
      setMasterPassword(master.password);

      const saved = localStorage.getItem('fnet_auth_user');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed?.username) {
          setSession(parsed);
        }
      }

      const savedList = localStorage.getItem('fnet_mikrotik_list');
      let loadedList: MikrotikDevice[] = [];
      if (savedList) {
        const parsedList = JSON.parse(savedList);
        if (Array.isArray(parsedList)) {
          loadedList = parsedList;
          setMikrotikList(parsedList);
        }
      }

      const savedSelected = localStorage.getItem('fnet_selected_mikrotik_id');
      if (savedSelected && loadedList.some((d) => d.id === savedSelected)) {
        setSelectedMikrotikId(savedSelected);
      } else if (loadedList.length > 0) {
        setSelectedMikrotikId(loadedList[0].id);
        localStorage.setItem('fnet_selected_mikrotik_id', loadedList[0].id);
      }
    } catch {
      // ignore
    }
  }, []);

  // Lock body scroll completely when in login screen (anti-overscroll for Chrome mobile)
  useEffect(() => {
    if (!session) {
      document.documentElement.style.overflow = 'hidden';
      document.documentElement.style.height = '100%';
      document.body.style.overflow = 'hidden';
      document.body.style.height = '100%';
      document.body.style.position = 'fixed';
      document.body.style.width = '100%';
    } else {
      document.documentElement.style.overflow = '';
      document.documentElement.style.height = '';
      document.body.style.overflow = '';
      document.body.style.height = '';
      document.body.style.position = '';
      document.body.style.width = '';
    }
    return () => {
      document.documentElement.style.overflow = '';
      document.documentElement.style.height = '';
      document.body.style.overflow = '';
      document.body.style.height = '';
      document.body.style.position = '';
      document.body.style.width = '';
    };
  }, [session]);

  const closeModal = () => {
    setIsModalOpen(false);
    setEditingId(null);
    setPingStatus('idle');
    setPingLatency(null);
    setShowMikrotikPass(false);
  };

  const handleOpenAddModal = () => {
    setEditingId(null);
    setMikrotikIp('');
    setMikrotikPort('80');
    setMikrotikUser('');
    setMikrotikPass('');
    setShowMikrotikPass(false);
    setIsPinging(false);
    setPingStatus('idle');
    setPingLatency(null);
    setIsModalOpen(true);
  };

  const handleOpenEditModal = (device: MikrotikDevice) => {
    setEditingId(device.id);
    setMikrotikIp(device.ip);
    setMikrotikPort(device.port);
    setMikrotikUser(device.user);
    setMikrotikPass(device.pass);
    setShowMikrotikPass(false);
    setIsPinging(false);
    setPingStatus('idle');
    setPingLatency(null);
    setIsModalOpen(true);
  };

  /* ============================================================= */
  /* ANDROID NAVIGATION, BACK BUTTON & VIRTUAL KEYBOARD CONTROLLER */
  /* ============================================================= */
  const lastBackPressRef = useRef<number>(0);

  // Android Virtual Keyboard Detection (auto-hides bottom bar)
  useEffect(() => {
    const vv = window.visualViewport;
    if (!vv) return;
    const onResize = () => {
      const diff = window.innerHeight - vv.height;
      setIsKeyboardOpen(diff > 140);
    };
    vv.addEventListener('resize', onResize);
    return () => vv.removeEventListener('resize', onResize);
  }, []);

  // Ref tracking current navigation and overlay state for back button handling
  const navigationStateRef = useRef({
    deletingRouterTarget,
    isLogoutConfirmOpen,
    isModalOpen,
    selectedSecretId,
    isAddUserModalOpen,
    isProfileModalOpen,
    selectedHotspotUser,
    isAddHotspotUserModalOpen,
    isHotspotProfileModalOpen,
    selectedLease,
    filterMenuOpen,
    hotspotUserFilterOpen,
    dhcpFilterMenuOpen,
    activeTab,
  });

  useEffect(() => {
    navigationStateRef.current = {
      deletingRouterTarget,
      isLogoutConfirmOpen,
      isModalOpen,
      selectedSecretId,
      isAddUserModalOpen,
      isProfileModalOpen,
      selectedHotspotUser,
      isAddHotspotUserModalOpen,
      isHotspotProfileModalOpen,
      selectedLease,
      filterMenuOpen,
      hotspotUserFilterOpen,
      dhcpFilterMenuOpen,
      activeTab,
    };
  }, [
    deletingRouterTarget,
    isLogoutConfirmOpen,
    isModalOpen,
    selectedSecretId,
    isAddUserModalOpen,
    isProfileModalOpen,
    selectedHotspotUser,
    isAddHotspotUserModalOpen,
    isHotspotProfileModalOpen,
    selectedLease,
    filterMenuOpen,
    hotspotUserFilterOpen,
    dhcpFilterMenuOpen,
    activeTab,
  ]);

  const handleAndroidBack = useCallback(() => {
    const s = navigationStateRef.current;

    // 1. Critical Confirmation Dialogs
    if (s.deletingRouterTarget) {
      setDeletingRouterTarget(null);
      return true;
    }
    if (s.isLogoutConfirmOpen) {
      setIsLogoutConfirmOpen(false);
      return true;
    }

    // 2. Add / Edit MikroTik Router Drawer (The one user specifically mentioned!)
    if (s.isModalOpen) {
      closeModal();
      return true;
    }

    // 3. PPPoE Modals
    if (s.selectedSecretId) {
      setSelectedSecretId(null);
      setEditingExpiryDate(null);
      setEditingProfile(null);
      return true;
    }
    if (s.isAddUserModalOpen) {
      setIsAddUserModalOpen(false);
      return true;
    }
    if (s.isProfileModalOpen) {
      setIsProfileModalOpen(false);
      return true;
    }

    // 4. Hotspot Modals
    if (s.selectedHotspotUser) {
      setSelectedHotspotUser(null);
      return true;
    }
    if (s.isAddHotspotUserModalOpen) {
      setIsAddHotspotUserModalOpen(false);
      return true;
    }
    if (s.isHotspotProfileModalOpen) {
      setIsHotspotProfileModalOpen(false);
      return true;
    }

    // 5. DHCP Sheet
    if (s.selectedLease) {
      setSelectedLease(null);
      return true;
    }

    // 6. Filter Menus & Dropdowns
    if (s.filterMenuOpen) {
      setFilterMenuOpen(false);
      return true;
    }
    if (s.hotspotUserFilterOpen) {
      setHotspotUserFilterOpen(false);
      return true;
    }
    if (s.dhcpFilterMenuOpen) {
      setDhcpFilterMenuOpen(false);
      return true;
    }

    // 7. Tab fallback: If not on 'beranda', back returns to 'beranda'
    if (s.activeTab !== 'beranda') {
      setActiveTab('beranda');
      return true;
    }

    // 8. On Home Tab: Double-press back to exit app
    const now = Date.now();
    if (now - lastBackPressRef.current < 2000) {
      try {
        CapApp.exitApp();
      } catch {
        // Fallback for web
      }
      return true;
    } else {
      lastBackPressRef.current = now;
      showToast('Tekan sekali lagi untuk keluar dari FNet', 'info');
      return true;
    }
  }, [closeModal, showToast]);

  // Synchronize history state for browser / PWA swipe gestures
  useEffect(() => {
    const isAnyModalOpen =
      isModalOpen ||
      !!deletingRouterTarget ||
      isLogoutConfirmOpen ||
      isAddUserModalOpen ||
      !!selectedSecretId ||
      isProfileModalOpen ||
      isAddHotspotUserModalOpen ||
      !!selectedHotspotUser ||
      isHotspotProfileModalOpen ||
      !!selectedLease;

    if (isAnyModalOpen) {
      window.history.pushState({ fnetModal: true }, '');
    }
  }, [
    isModalOpen,
    deletingRouterTarget,
    isLogoutConfirmOpen,
    isAddUserModalOpen,
    selectedSecretId,
    isProfileModalOpen,
    isAddHotspotUserModalOpen,
    selectedHotspotUser,
    isHotspotProfileModalOpen,
    selectedLease,
  ]);

  // Register Capacitor native Android hardware/gesture back button & web popstate
  useEffect(() => {
    let listenerHandle: { remove: () => void } | null = null;

    try {
      CapApp.addListener('backButton', () => {
        handleAndroidBack();
      }).then((handle) => {
        listenerHandle = handle;
      });
    } catch {
      // In web browser environment
    }

    const handlePopState = () => {
      handleAndroidBack();
    };
    window.addEventListener('popstate', handlePopState);

    return () => {
      if (listenerHandle) {
        listenerHandle.remove();
      }
      window.removeEventListener('popstate', handlePopState);
    };
  }, [handleAndroidBack]);

  const handlePingIp = async () => {
    const rawIp = mikrotikIp.trim();
    if (!rawIp || isPinging) return;

    setIsPinging(true);
    setPingStatus('idle');

    try {
      const cleanHost = rawIp.replace(/^https?:\/\//i, '').split('/')[0].split(':')[0].trim();
      const port = mikrotikPort.trim() || '80';

      const res = await fetch(`/api-ping?host=${encodeURIComponent(cleanHost)}&port=${encodeURIComponent(port)}`, {
        signal: AbortSignal.timeout(3500),
      });

      if (res.ok) {
        const data = await res.json();
        if (data.reply) {
          const lat = typeof data.timeMs === 'number' ? data.timeMs : 1;
          setPingStatus('success');
          setPingLatency(lat);
          showToast(`Reply from ${cleanHost} (${lat}ms)`, 'success');
          return;
        }
      }
      setPingStatus('failed');
      setPingLatency(null);
      showToast(`Request timed out (RTO) dari ${cleanHost}`, 'error');
    } catch {
      // Fallback via /api-proxy probe
      try {
        const cleanHost = rawIp.replace(/^https?:\/\//i, '').split('/')[0].split(':')[0].trim();
        const port = mikrotikPort.trim() || '80';
        const start = performance.now();
        const probeRes = await fetch('/api-proxy', {
          headers: { 'x-target-url': `http://${cleanHost}:${port}/` },
          signal: AbortSignal.timeout(3000),
        });
        const duration = Math.round(performance.now() - start);
        if (probeRes.status !== 502 && probeRes.status !== 504) {
          setPingStatus('success');
          setPingLatency(duration);
          showToast(`Reply from ${cleanHost} (${duration}ms)`, 'success');
          return;
        }
      } catch {
        // probe failed
      }
      setPingStatus('failed');
      setPingLatency(null);
      const cleanHost = rawIp.replace(/^https?:\/\//i, '').split('/')[0].split(':')[0].trim();
      showToast(`Host ${cleanHost} tidak merespon (RTO)`, 'error');
    } finally {
      setIsPinging(false);
    }
  };

  const handleSaveMikrotik = (e: React.FormEvent) => {
    e.preventDefault();
    if (!mikrotikIp.trim() || !mikrotikUser.trim()) {
      showToast('Mohon lengkapi IP dan Username.', 'error');
      return;
    }

    if (editingId) {
      // Update existing item
      const updated = mikrotikList.map((item) =>
        item.id === editingId
          ? {
              ...item,
              ip: mikrotikIp.trim(),
              port: mikrotikPort.trim() || '80',
              user: mikrotikUser.trim(),
              pass: mikrotikPass,
            }
          : item
      );
      setMikrotikList(updated);
      localStorage.setItem('fnet_mikrotik_list', JSON.stringify(updated));
      showToast('Perangkat MikroTik berhasil diperbarui.', 'success');
    } else {
      // Add new item
      const newDevice: MikrotikDevice = {
        id: Date.now().toString(),
        ip: mikrotikIp.trim(),
        port: mikrotikPort.trim() || '80',
        user: mikrotikUser.trim(),
        pass: mikrotikPass,
      };

      const updated = [newDevice, ...mikrotikList];
      setMikrotikList(updated);
      localStorage.setItem('fnet_mikrotik_list', JSON.stringify(updated));
      showToast('Perangkat MikroTik berhasil ditambahkan.', 'success');
      if (!selectedMikrotikId) {
        setSelectedMikrotikId(newDevice.id);
        localStorage.setItem('fnet_selected_mikrotik_id', newDevice.id);
      }
    }

    // Reset input fields and close modal
    setMikrotikIp('');
    setMikrotikPort('80');
    setMikrotikUser('');
    setMikrotikPass('');
    setEditingId(null);
    setPingStatus('idle');
    setPingLatency(null);
    setIsModalOpen(false);
  };

  const handleSelectMikrotik = (id: string) => {
    if (selectedMikrotikId === id) return;
    resetAllRouterData();
    selectedMikrotikIdRef.current = id;
    setSelectedMikrotikId(id);
    localStorage.setItem('fnet_selected_mikrotik_id', id);
    const item = mikrotikList.find((d) => d.id === id);
    if (item) {
      showToast(`Router ${item.ip}:${item.port} aktif`, 'info');
    }
  };

  const handleDeleteMikrotik = (id: string) => {
    const target = mikrotikList.find((item) => item.id === id);
    const updated = mikrotikList.filter((item) => item.id !== id);
    setMikrotikList(updated);
    localStorage.setItem('fnet_mikrotik_list', JSON.stringify(updated));

    if (selectedMikrotikId === id) {
      resetAllRouterData();
      const nextId = updated.length > 0 ? updated[0].id : null;
      selectedMikrotikIdRef.current = nextId;
      setSelectedMikrotikId(nextId);
      if (nextId) {
        localStorage.setItem('fnet_selected_mikrotik_id', nextId);
      } else {
        localStorage.removeItem('fnet_selected_mikrotik_id');
        setSyncStatus('idle');
      }
    }
    showToast(
      target
        ? `Router ${target.ip} berhasil dihapus.`
        : 'Perangkat MikroTik berhasil dihapus.',
      'info'
    );
  };

  const handleLogin = (e?: React.FormEvent) => {
    if (e) e.preventDefault();

    const trimmedUser = username.trim();

    if (!trimmedUser || !password) {
      showToast('Silakan isi ID User dan Password.', 'error');
      return;
    }

    setIsLoading(true);

    setTimeout(() => {
      setIsLoading(false);
      const master = getStoredMasterAuth();
      if (trimmedUser.toLowerCase() === master.username.toLowerCase() && password === master.password) {
        const authData: AuthSession = {
          username: master.username,
          loggedInAt: new Date().toLocaleTimeString('id-ID', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
          }),
        };
        localStorage.setItem('fnet_auth_user', JSON.stringify(authData));
        showToast('Autentikasi berhasil! Masuk ke sistem.', 'success');
        setTimeout(() => {
          setSession(authData);
        }, 400);
      } else {
        showToast('ID User atau Password salah.', 'error');
      }
    }, 400);
  };

  const handleSaveMasterAuth = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = masterUsername.trim();
    if (!trimmed) {
      showToast('ID User Master tidak boleh kosong.', 'error');
      return;
    }
    if (!masterPassword) {
      showToast('Password Master tidak boleh kosong.', 'error');
      return;
    }

    const newMaster: MasterAuth = {
      username: trimmed,
      password: masterPassword,
    };
    localStorage.setItem('fnet_master_auth', JSON.stringify(newMaster));
    setMasterUsername(trimmed);

    // Update current session username if logged in so UI updates immediately
    if (session) {
      const updatedSession: AuthSession = {
        ...session,
        username: trimmed,
      };
      setSession(updatedSession);
      localStorage.setItem('fnet_auth_user', JSON.stringify(updatedSession));
    }

    showToast('Kredensial master login berhasil disimpan! Gunakan akun ini saat login.', 'success');
  };

  const handleLogout = () => {
    localStorage.removeItem('fnet_auth_user');
    setSession(null);
    setUsername('');
    setPassword('');
    showToast('Anda telah keluar dari akun.', 'info');
  };

  /* Authentic iOS Notification Banner Component */
  const renderToast = () => {
    return (
      <AnimatePresence>
        {toast && (
          <motion.aside
            key="fnet-toast-banner"
            variants={toastBannerVariants}
            initial="initial"
            animate="animate"
            exit="exit"
            aria-live="polite"
            className="fixed left-1/2 -translate-x-1/2 z-[100] w-[calc(100vw-28px)] max-w-sm sm:max-w-md pointer-events-auto"
            style={{
              top: 'max(2.5rem, calc(env(safe-area-inset-top, 0px) + 0.85rem))',
            }}
          >
            <div
              onClick={() => setToast(null)}
              className="cursor-pointer select-none rounded-[22px] bg-[#1c1c1e]/92 text-white p-3 sm:p-3.5 shadow-[0_16px_40px_rgba(0,0,0,0.4),0_2px_8px_rgba(0,0,0,0.25)] border border-white/15 backdrop-blur-2xl active:scale-[0.98] transition-transform flex items-start gap-3 tap-spring"
            >
              {/* iOS App Icon / Type Badge */}
              <div
                className={`h-8 w-8 rounded-xl flex items-center justify-center shrink-0 shadow-sm mt-0.5 ${
                  toast.type === 'success'
                    ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                    : toast.type === 'error'
                    ? 'bg-rose-500/20 text-rose-400 border border-rose-500/30'
                    : 'bg-sky-500/20 text-sky-400 border border-sky-500/30'
                }`}
              >
                {toast.type === 'success' && <CheckCircle2 className="h-4 w-4 stroke-[2.2]" />}
                {toast.type === 'error' && <AlertCircle className="h-4 w-4 stroke-[2.2]" />}
                {toast.type === 'info' && <Zap className="h-4 w-4 stroke-[2.2]" />}
              </div>

              {/* iOS Notification Content */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between gap-2 mb-0.5">
                  <span className="text-[11px] font-bold tracking-wider uppercase text-white/50">
                    {toast.type === 'success'
                      ? 'FNet • Berhasil'
                      : toast.type === 'error'
                      ? 'FNet • Perhatian'
                      : 'FNet • Sistem'}
                  </span>
                  <span className="text-[10px] text-white/40 font-mono">sekarang</span>
                </div>
                <p className="text-[13px] font-medium leading-snug text-white/95 break-words">
                  {toast.message}
                </p>
              </div>

              {/* Dismiss button */}
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation();
                  setToast(null);
                }}
                className="text-white/40 hover:text-white p-1 rounded-full hover:bg-white/10 transition-colors shrink-0 -mr-1 -mt-0.5"
                aria-label="Tutup notifikasi"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          </motion.aside>
        )}
      </AnimatePresence>
    );
  };

  /* ============================================================= */
  /* LOGIN VIEW (Fixed Inset-0, Locked Anti-Scroll Chrome Mobile)  */
  /* ============================================================= */
  if (!session) {
    return (
      <div className="fixed inset-0 w-full h-full bg-apple-bg font-sans text-apple-text antialiased flex items-center justify-center p-4 overflow-hidden overscroll-none touch-none selection:bg-apple-blue selection:text-white">
        {renderToast()}
        <div className="w-full max-w-[420px] relative transform overflow-hidden rounded-[26px] sm:rounded-3xl bg-apple-card text-left shadow-ios-modal transition-all border border-black/[0.08] touch-auto">
          {/* Header Modal */}
          <div className="px-5 sm:px-6 py-4 border-b border-black/[0.06] flex items-center justify-between bg-[#fbfbfd]">
            <div className="flex items-center gap-3">
              <div className="h-9 w-9 sm:h-10 sm:w-10 rounded-2xl bg-apple-blue/10 text-apple-blue flex items-center justify-center font-bold shrink-0">
                <Lock className="h-4 w-4 sm:h-5 sm:w-5 stroke-[2.2]" />
              </div>
              <div>
                <h3 className="text-sm sm:text-base font-bold text-apple-text tracking-tight">
                  Autentikasi Petugas
                </h3>
                <p className="text-[11px] sm:text-xs text-apple-subtext font-medium">
                  Masuk untuk mengelola sistem node
                </p>
              </div>
            </div>
            <div className="h-6 px-2 rounded-full bg-black/[0.04] border border-black/[0.04] flex items-center gap-1 text-[10px] font-semibold text-apple-subtext">
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-500"></span>
              v1.0
            </div>
          </div>

          {/* Form Input */}
          <form onSubmit={handleLogin} className="p-5 sm:p-6 space-y-3.5 sm:space-y-4">
            {/* ID USER */}
            <div>
              <div className="mb-1">
                <label
                  htmlFor="username"
                  className="block text-[11px] sm:text-xs font-bold text-apple-subtext uppercase tracking-wider"
                >
                  ID USER <span className="text-rose-500">*</span>
                </label>
              </div>
              <div className="relative">
                <input
                  type="text"
                  id="username"
                  name="username"
                  required
                  autoComplete="username"
                  placeholder="ID User"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-10 py-2.5 text-sm text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm font-medium"
                />
                <div className="absolute right-3.5 top-1/2 -translate-y-1/2 text-apple-subtext pointer-events-none">
                  <User className="h-4 w-4" />
                </div>
              </div>
            </div>

            {/* PASSWORD */}
            <div>
              <div className="mb-1">
                <label
                  htmlFor="password"
                  className="block text-[11px] sm:text-xs font-bold text-apple-subtext uppercase tracking-wider"
                >
                  PASSWORD <span className="text-rose-500">*</span>
                </label>
              </div>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  id="password"
                  name="password"
                  required
                  autoComplete="current-password"
                  placeholder="Password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-12 py-2.5 text-sm text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm font-medium font-mono"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-1 top-1/2 -translate-y-1/2 text-apple-subtext hover:text-apple-blue p-2 rounded-xl transition-all min-h-[48px] min-w-[48px] flex items-center justify-center active:scale-90"
                  title={showPassword ? 'Sembunyikan password' : 'Lihat password'}
                  aria-label={showPassword ? 'Sembunyikan password' : 'Lihat password'}
                >
                  {showPassword ? (
                    <EyeOff className="h-4 w-4 stroke-[2.2]" />
                  ) : (
                    <Eye className="h-4 w-4 stroke-[2.2]" />
                  )}
                </button>
              </div>
            </div>

            {/* Action Submit Button */}
            <div className="pt-1.5">
              <button
                type="submit"
                disabled={isLoading}
                className="w-full min-h-[48px] inline-flex items-center justify-center gap-2 rounded-2xl bg-apple-blue px-6 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-apple-blueHover active:scale-[0.98] transition-all disabled:opacity-60"
              >
                {isLoading ? (
                  <span className="inline-flex items-center gap-2">
                    <svg
                      className="animate-spin h-4 w-4 text-white"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        className="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        strokeWidth="4"
                      ></circle>
                      <path
                        className="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      ></path>
                    </svg>
                    <span>Memverifikasi...</span>
                  </span>
                ) : (
                  <>
                    <span>Masuk ke Sistem</span>
                    <ArrowRight className="h-4 w-4 stroke-[2.5]" />
                  </>
                )}
              </button>
            </div>
          </form>

          {/* Modal Footer Info */}
          <div className="px-5 sm:px-6 py-3 bg-[#fbfbfd] border-t border-black/[0.04] text-center text-[10px] sm:text-[11px] text-apple-subtext flex items-center justify-center gap-2">
            <Shield className="h-3.5 w-3.5 text-apple-subtext/70" />
            <span>Protected Node Session · NOC - System</span>
          </div>
        </div>
      </div>
    );
  }

  /* ============================================================= */
  /* LOGGED IN VIEW (Dashboard & Pengaturan - App Shell Architecture)*/
  /* ============================================================= */
  return (
    <div className="fixed inset-0 w-full h-full bg-apple-bg font-sans text-apple-text antialiased flex flex-col overflow-hidden overscroll-none selection:bg-apple-blue selection:text-white">
      {renderToast()}
      {/* Dynamic Header */}
      <header className="sticky top-0 z-30 shrink-0 bg-white/90 backdrop-blur-xl saturate-150 border-b border-black/[0.05] shadow-[0_2px_12px_rgba(0,0,0,0.03)] transition-all pt-[env(safe-area-inset-top)]">
        <div className="max-w-[1400px] mx-auto px-4 sm:px-6 lg:px-10">
          <div className="flex h-14 items-center justify-between gap-2">
            <div className="flex items-center gap-2.5">
              <div className="h-8 w-8 rounded-xl bg-apple-blue/10 text-apple-blue flex items-center justify-center font-bold shadow-xs shrink-0">
                {activeTab === 'pengaturan' ? (
                  <Settings className="h-4 w-4" />
                ) : activeTab === 'pppoe' ? (
                  <Users className="h-4 w-4" />
                ) : activeTab === 'hotspot' ? (
                  <Wifi className="h-4 w-4" />
                ) : activeTab === 'dhcp' ? (
                  <Network className="h-4 w-4" />
                ) : (
                  <Home className="h-4 w-4" />
                )}
              </div>
              <h1 className="text-base font-bold tracking-tight text-apple-text">
                {activeTab === 'pengaturan'
                  ? 'Pengaturan'
                  : activeTab === 'pppoe'
                  ? 'PPPoE'
                  : activeTab === 'hotspot'
                  ? 'Hotspot'
                  : activeTab === 'dhcp'
                  ? 'DHCP Leases'
                  : 'Dashboard'}
              </h1>
            </div>

            {/* Right Action: Tombol Refresh & Icon Logout */}
            <div className="flex items-center gap-1.5 sm:gap-2">
              {(activeTab === 'beranda' || activeTab === 'pppoe' || activeTab === 'hotspot' || activeTab === 'dhcp') && (() => {
                const isRefreshing = isDashboardRefreshing || isPppRefreshing || isHotspotRefreshing || isDhcpRefreshing;
                return (
                  <button
                    type="button"
                    onClick={() => {
                      const profile = getSelectedProfile();
                      if (!profile) {
                        showToast('Pilih perangkat MikroTik terlebih dahulu di Pengaturan.', 'error');
                        return;
                      }
                      if (activeTab === 'beranda') {
                        setIsDashboardRefreshing(true);
                        fetchDashboardData(true);
                      } else if (activeTab === 'pppoe') {
                        fetchPppoeData();
                      } else if (activeTab === 'hotspot') {
                        fetchHotspotData();
                      } else if (activeTab === 'dhcp') {
                        fetchDhcpData();
                      }
                    }}
                    disabled={isRefreshing}
                    className={`h-8 w-8 rounded-full flex items-center justify-center transition-all active:scale-90 shrink-0 ${
                      isRefreshing
                        ? 'bg-apple-blue/10 text-apple-blue cursor-wait'
                        : 'text-apple-subtext hover:text-apple-blue bg-black/[0.04] hover:bg-black/[0.08]'
                    }`}
                    title={
                      activeTab === 'beranda'
                        ? 'Segarkan data Dashboard'
                        : activeTab === 'pppoe'
                        ? 'Segarkan data PPPoE'
                        : activeTab === 'hotspot'
                        ? 'Segarkan data Hotspot'
                        : 'Segarkan data DHCP Leases'
                    }
                    aria-label="Segarkan data"
                  >
                    {isRefreshing ? (
                      <svg
                        className="h-3.5 w-3.5 animate-spin text-apple-blue"
                        viewBox="0 0 24 24"
                        fill="none"
                      >
                        <circle
                          className="opacity-25"
                          cx="12"
                          cy="12"
                          r="10"
                          stroke="currentColor"
                          strokeWidth="3"
                        />
                        <path
                          className="opacity-100"
                          fill="currentColor"
                          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                        />
                      </svg>
                    ) : (
                      <RefreshCw className="h-3.5 w-3.5 stroke-[2.2]" />
                    )}
                  </button>
                );
              })()}
              <button
                type="button"
                onClick={() => setIsLogoutConfirmOpen(true)}
                className="h-8 w-8 rounded-full flex items-center justify-center text-rose-600 bg-rose-500/10 hover:bg-rose-500/20 active:scale-90 transition-all shrink-0"
                title="Keluar dari akun"
                aria-label="Keluar dari akun"
              >
                <LogOut className="h-3.5 w-3.5 stroke-[2.2]" />
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content Area: Smooth internal scroll without window bounce */}
      <main className="flex-1 w-full overflow-y-auto overscroll-contain">
        <div className="max-w-[1400px] mx-auto px-3.5 sm:px-6 lg:px-10 pt-2 sm:pt-2.5 pb-36 sm:pb-40 space-y-2.5 sm:space-y-3 flex flex-col">
          <AnimatePresence mode="wait">
            {activeTab === 'pengaturan' ? (
              /* ============================================================= */
              /* HALAMAN PENGATURAN: LANGSUNG DAFTAR PERANGKAT                 */
              /* ============================================================= */
              <motion.div
                key="tab-pengaturan"
                variants={pageVariants}
                initial="initial"
                animate="animate"
                exit="exit"
                className="space-y-2.5 sm:space-y-3.5 w-full max-w-2xl mx-auto"
              >
              {/* Langsung List MikroTik */}
              <section className="bg-white rounded-2xl sm:rounded-3xl border border-black/[0.08] shadow-apple overflow-hidden flex flex-col">
                <div className="px-4 py-2.5 sm:px-5 sm:py-3 border-b border-black/[0.04] bg-[#fbfbfd] flex items-center justify-between shrink-0">
                  <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider">
                    Daftar Perangkat MikroTik:
                  </span>
                  <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider font-mono">
                    {mikrotikList.length} Perangkat
                  </span>
                </div>

                {mikrotikList.length === 0 ? (
                  <div className="flex flex-col items-center justify-center gap-3 px-4 py-16 text-center">
                    <div className="h-12 w-12 rounded-full bg-apple-bg flex items-center justify-center text-apple-subtext">
                      <Server className="h-6 w-6 stroke-[1.5]" />
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-apple-text">
                        Belum Ada Perangkat
                      </p>
                      <p className="text-xs text-apple-subtext mt-0.5">
                        Tekan tombol tambah (+) untuk memasukkan perangkat MikroTik.
                      </p>
                    </div>
                    <button
                      type="button"
                      onClick={handleOpenAddModal}
                      className="mt-3 inline-flex items-center gap-1.5 rounded-2xl bg-apple-blue px-5 py-2.5 text-xs font-semibold text-white shadow-xs hover:bg-apple-blueHover active:scale-95 transition-all min-h-[48px]"
                    >
                      <Plus className="h-4 w-4 stroke-[2.5]" />
                      <span>Tambah MikroTik</span>
                    </button>
                  </div>
                ) : (
                  <div className="divide-y divide-black/[0.04] overflow-y-auto max-h-[515px] sm:max-h-[600px] overscroll-contain pb-2">
                    {mikrotikList.map((item) => {
                      const isSelected = selectedMikrotikId === item.id;
                      return (
                        <div
                          key={item.id}
                          className={`px-4 py-2.5 sm:px-5 sm:py-3 flex items-center justify-between gap-3 transition-all ${
                            isSelected
                              ? 'bg-apple-blue/[0.03]'
                              : 'bg-white hover:bg-apple-lightGray/60'
                          }`}
                        >
                          {/* Clickable Area to Select Router */}
                          <button
                            type="button"
                            role="radio"
                            aria-checked={isSelected}
                            aria-label={`Pilih router ${item.ip}:${item.port}`}
                            onClick={() => handleSelectMikrotik(item.id)}
                            className="flex items-center gap-2.5 min-w-0 flex-1 text-left min-h-[38px]"
                          >
                            {/* Checklist Indicator */}
                            <div className="h-5 w-5 rounded-full flex items-center justify-center shrink-0">
                              {isSelected ? (
                                <div className="h-4 w-4 rounded-full bg-apple-blue flex items-center justify-center text-white shadow-sm">
                                  <Check className="h-3 w-3 stroke-[3]" />
                                </div>
                              ) : (
                                <div className="h-4 w-4 rounded-full border-2 border-black/[0.18]" />
                              )}
                            </div>

                            <div className="min-w-0">
                              <p className="font-mono font-bold text-base sm:text-sm text-apple-text tracking-tight truncate">
                                {item.ip}:{item.port}
                              </p>
                              <div className="flex items-center gap-2 text-xs text-apple-subtext font-mono mt-0.5">
                                <span>
                                  User:{' '}
                                  <strong className="text-apple-text font-semibold">
                                    {item.user}
                                  </strong>
                                </span>
                                <span>•</span>
                                <span>
                                  Pass:{' '}
                                  <strong className="text-apple-text font-semibold">
                                    {item.pass ? '••••••' : '—'}
                                  </strong>
                                </span>
                              </div>
                            </div>
                          </button>

                          {/* Actions: Edit & Delete */}
                          <div className="flex items-center gap-1 shrink-0">
                            <button
                              type="button"
                              onClick={() => handleOpenEditModal(item)}
                              className="min-h-[44px] min-w-[44px] flex items-center justify-center text-apple-subtext hover:text-apple-blue rounded-xl hover:bg-black/[0.04] active:scale-95 transition-all"
                              title="Edit perangkat"
                              aria-label={`Edit perangkat ${item.ip}`}
                            >
                              <Pencil className="h-4 w-4" />
                            </button>
                            <button
                              type="button"
                              onClick={() => setDeletingRouterTarget(item)}
                              className="min-h-[44px] min-w-[44px] flex items-center justify-center text-apple-subtext hover:text-rose-600 rounded-xl hover:bg-rose-500/10 active:scale-95 transition-colors"
                              title="Hapus dari list"
                              aria-label={`Hapus perangkat ${item.ip}`}
                            >
                              <Trash2 className="h-4 w-4" />
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </section>

              {/* Kredensial Master Akun Login */}
              <section className="bg-white rounded-2xl sm:rounded-3xl border border-black/[0.08] p-4 sm:p-5 shadow-apple">
                <div className="flex items-center gap-2.5 mb-3.5 pb-3 border-b border-black/[0.04]">
                  <div className="h-9 w-9 rounded-xl bg-apple-blue/10 text-apple-blue flex items-center justify-center shrink-0">
                    <KeyRound className="h-4 w-4 stroke-[2.2]" />
                  </div>
                  <div>
                    <h3 className="text-sm sm:text-base font-bold text-apple-text tracking-tight">
                      Kredensial Master Login
                    </h3>
                    <p className="text-xs text-apple-subtext mt-0.5">
                      ID User & Password master untuk masuk ke aplikasi setelah logout
                    </p>
                  </div>
                </div>

                <form onSubmit={handleSaveMasterAuth} className="space-y-3.5">
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {/* Input ID User Master */}
                    <div>
                      <label
                        htmlFor="master-username-input"
                        className="block text-[11px] font-bold text-apple-subtext mb-1 uppercase tracking-wider"
                      >
                        ID User Master <span className="text-rose-500">*</span>
                      </label>
                      <div className="relative">
                        <input
                          type="text"
                          id="master-username-input"
                          value={masterUsername}
                          onChange={(e) => setMasterUsername(e.target.value)}
                          required
                          placeholder="misal: ihwan"
                          className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-10 py-2.5 text-sm font-semibold font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                        />
                        <div className="absolute right-3.5 top-1/2 -translate-y-1/2 text-apple-subtext pointer-events-none">
                          <User className="h-4 w-4" />
                        </div>
                      </div>
                    </div>

                    {/* Input Password Master */}
                    <div>
                      <label
                        htmlFor="master-password-input"
                        className="block text-[11px] font-bold text-apple-subtext mb-1 uppercase tracking-wider"
                      >
                        Password Master <span className="text-rose-500">*</span>
                      </label>
                      <div className="relative">
                        <input
                          type={showMasterPassword ? 'text' : 'password'}
                          id="master-password-input"
                          value={masterPassword}
                          onChange={(e) => setMasterPassword(e.target.value)}
                          required
                          placeholder="Password Master"
                          className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-12 py-2.5 text-sm font-semibold font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                        />
                        <button
                          type="button"
                          onClick={() => setShowMasterPassword(!showMasterPassword)}
                          className="absolute right-1 top-1/2 -translate-y-1/2 text-apple-subtext hover:text-apple-blue p-2 rounded-xl transition-all min-h-[44px] min-w-[44px] flex items-center justify-center active:scale-90"
                          title={showMasterPassword ? 'Sembunyikan password' : 'Lihat password'}
                          aria-label={showMasterPassword ? 'Sembunyikan password' : 'Lihat password'}
                        >
                          {showMasterPassword ? (
                            <EyeOff className="h-4 w-4 stroke-[2.2]" />
                          ) : (
                            <Eye className="h-4 w-4 stroke-[2.2]" />
                          )}
                        </button>
                      </div>
                    </div>
                  </div>

                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 pt-1">
                    <span className="text-[11px] text-apple-subtext">
                      Disimpan aman secara lokal di perangkat ini (tanpa server pihak ketiga)
                    </span>
                    <button
                      type="submit"
                      className="min-h-[48px] px-5 py-2.5 rounded-2xl bg-apple-blue hover:bg-apple-blueHover text-white font-semibold text-xs sm:text-sm flex items-center justify-center gap-1.5 shadow-sm active:scale-[0.98] transition-all cursor-pointer shrink-0"
                    >
                      <Save className="h-4 w-4 stroke-[2.2]" />
                      <span>Simpan Kredensial</span>
                    </button>
                  </div>
                </form>
              </section>

              {/* Sesi Pengguna & Tombol Logout di Pengaturan */}
              <section className="bg-white rounded-2xl sm:rounded-3xl border border-black/[0.08] p-4 sm:p-5 shadow-apple">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div>
                    <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider">
                      Sesi Pengguna
                    </span>
                    <p className="text-sm font-semibold text-apple-text mt-0.5">
                      Masuk sebagai <strong className="font-mono text-apple-blue font-bold">{session?.username || 'ihwan'}</strong>
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => setIsLogoutConfirmOpen(true)}
                    className="min-h-[48px] px-4 py-2.5 rounded-2xl bg-rose-500/10 hover:bg-rose-500/15 text-rose-600 border border-rose-500/20 font-semibold text-xs sm:text-sm flex items-center justify-center gap-2 active:scale-[0.98] transition-all"
                  >
                    <LogOut className="h-4 w-4 stroke-[2.2]" />
                    <span>Keluar dari Akun FNet</span>
                  </button>
                </div>
              </section>

              {/* Floating Action Button (FAB) Mobile Style */}
              <button
                type="button"
                onClick={handleOpenAddModal}
                className="fixed bottom-20 right-5 sm:bottom-22 sm:right-8 z-40 h-14 w-14 rounded-full bg-apple-blue text-white shadow-lg shadow-apple-blue/25 flex items-center justify-center hover:bg-apple-blueHover active:scale-95 transition-all min-h-[48px] min-w-[48px]"
                title="Tambah MikroTik"
                aria-label="Tambah MikroTik"
              >
                <Plus className="h-6 w-6 stroke-[2.5]" />
              </button>

              {/* MODAL TAMBAH / EDIT MIKROTIK (APPLE iOS HIG STYLE) */}
              <AnimatePresence>
                {isModalOpen && (
                  <div
                    className="relative z-50"
                    aria-labelledby="modal-title"
                    role="dialog"
                    aria-modal="true"
                  >
                    {/* Backdrop Blur */}
                    <motion.div
                      variants={modalBackdropVariants}
                      initial="initial"
                      animate="animate"
                      exit="exit"
                      className="fixed inset-0 bg-black/40 backdrop-blur-sm"
                      onClick={closeModal}
                    />

                    {/* Modal Container */}
                    <div className="fixed inset-0 z-50 w-screen overflow-y-auto">
                      <div className="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4">
                        <motion.div
                          variants={modalSheetVariants}
                          initial="initial"
                          animate="animate"
                          exit="exit"
                          className="relative transform overflow-hidden rounded-t-[32px] sm:rounded-3xl bg-apple-card text-left shadow-[0_-10px_40px_rgba(0,0,0,0.14)] sm:shadow-ios-modal my-0 sm:my-auto w-full max-w-lg border-t sm:border border-black/[0.08] max-h-[92vh] sm:max-h-[85vh] flex flex-col"
                        >
                        {/* iOS Drawer Grabber Handle */}
                        <div className="w-full pt-3 pb-1 flex justify-center sm:hidden bg-[#fbfbfd] shrink-0">
                          <div className="w-10 h-1.5 rounded-full bg-black/20" />
                        </div>

                        {/* Header Modal */}
                        <div className="px-5 pt-2 pb-3.5 sm:px-6 sm:pt-5 sm:pb-4 border-b border-black/[0.06] flex items-center justify-between bg-[#fbfbfd] shrink-0">
                          <div className="flex items-center gap-3">
                            <div className="h-10 w-10 rounded-2xl bg-apple-blue/10 text-apple-blue flex items-center justify-center font-bold shrink-0">
                              {editingId ? (
                                <Pencil className="h-5 w-5 stroke-[2.2]" />
                              ) : (
                                <Server className="h-5 w-5 stroke-[2.2]" />
                              )}
                            </div>
                            <div>
                              <h3
                                className="text-base font-bold text-apple-text tracking-tight"
                                id="modal-title"
                              >
                                {editingId ? 'Edit MikroTik' : 'Tambah MikroTik'}
                              </h3>
                              <p className="text-xs text-apple-subtext font-medium">
                                {editingId
                                  ? 'Perbarui IP, Port, dan Kredensial'
                                  : 'Input IP, Port, dan Kredensial'}
                              </p>
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={closeModal}
                            className="text-apple-subtext hover:text-apple-text rounded-full p-2 bg-black/[0.04] hover:bg-black/[0.08] transition-all min-h-[36px] min-w-[36px] flex items-center justify-center"
                            title="Tutup modal"
                            aria-label="Tutup modal"
                          >
                            <X className="h-4 w-4" />
                          </button>
                        </div>

                        {/* Form Input Modal */}
                        <form onSubmit={handleSaveMikrotik} className="p-5 sm:p-6 space-y-4 overflow-y-auto overscroll-contain flex-1">
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            {/* IP */}
                            <div>
                              <label
                                htmlFor="modal-mikrotik-ip"
                                className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider"
                              >
                                IP <span className="text-rose-500">*</span>
                              </label>
                              <div className="flex items-center gap-2">
                                <input
                                  type="text"
                                  id="modal-mikrotik-ip"
                                  required
                                  value={mikrotikIp}
                                  onChange={(e) => {
                                    setMikrotikIp(e.target.value);
                                    if (pingStatus !== 'idle') {
                                      setPingStatus('idle');
                                      setPingLatency(null);
                                    }
                                  }}
                                  placeholder="Contoh: 192.168.88.1"
                                  className="flex-1 min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-3 sm:py-2.5 text-base sm:text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                />
                                <button
                                  type="button"
                                  onClick={handlePingIp}
                                  disabled={!mikrotikIp.trim() || isPinging}
                                  title={
                                    pingStatus === 'success'
                                      ? `Reply! ${pingLatency ? `${pingLatency}ms` : ''}`
                                      : pingStatus === 'failed'
                                      ? 'RTO (Request Timed Out)'
                                      : 'Ping IP'
                                  }
                                  className={`min-h-[48px] min-w-[48px] h-12 w-12 shrink-0 rounded-2xl flex items-center justify-center transition-all ${
                                    pingStatus === 'success'
                                      ? 'bg-emerald-50 text-emerald-600 ring-1 ring-emerald-500/30'
                                      : pingStatus === 'failed'
                                      ? 'bg-rose-50 text-rose-500 ring-1 ring-rose-500/20'
                                      : 'bg-apple-bg text-apple-subtext hover:text-apple-text ring-1 ring-inset ring-black/[0.06] hover:bg-black/[0.04]'
                                  } ${!mikrotikIp.trim() || isPinging ? 'opacity-50 cursor-not-allowed' : 'active:scale-95'}`}
                                >
                                  <Zap
                                    className={`h-5 w-5 transition-all ${
                                      isPinging
                                        ? 'animate-pulse text-amber-500 fill-amber-500'
                                        : pingStatus === 'success'
                                        ? 'text-emerald-500 fill-emerald-500'
                                        : pingStatus === 'failed'
                                        ? 'text-rose-500'
                                        : ''
                                    }`}
                                  />
                                </button>
                              </div>
                            </div>

                            {/* PORT */}
                            <div>
                              <label
                                htmlFor="modal-mikrotik-port"
                                className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider"
                              >
                                PORT <span className="text-rose-500">*</span>
                              </label>
                              <input
                                type="text"
                                id="modal-mikrotik-port"
                                required
                                value={mikrotikPort}
                                onChange={(e) => setMikrotikPort(e.target.value)}
                                placeholder="Contoh: 80"
                                className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-3 sm:py-2.5 text-base sm:text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                              />
                            </div>
                          </div>

                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            {/* USER */}
                            <div>
                              <label
                                htmlFor="modal-mikrotik-user"
                                className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider"
                              >
                                USER <span className="text-rose-500">*</span>
                              </label>
                              <input
                                type="text"
                                id="modal-mikrotik-user"
                                required
                                value={mikrotikUser}
                                onChange={(e) => setMikrotikUser(e.target.value)}
                                placeholder="Contoh: admin"
                                className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-3 sm:py-2.5 text-base sm:text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                              />
                            </div>

                            {/* PASS */}
                            <div>
                              <label
                                htmlFor="modal-mikrotik-pass"
                                className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider"
                              >
                                PASS
                              </label>
                              <div className="relative">
                                <input
                                  type={showMikrotikPass ? 'text' : 'password'}
                                  id="modal-mikrotik-pass"
                                  value={mikrotikPass}
                                  onChange={(e) => setMikrotikPass(e.target.value)}
                                  placeholder="Password"
                                  className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-12 py-3 sm:py-2.5 text-base sm:text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                />
                                <button
                                  type="button"
                                  onClick={() => setShowMikrotikPass(!showMikrotikPass)}
                                  className="absolute right-1 top-1/2 -translate-y-1/2 text-apple-subtext hover:text-apple-blue p-2 rounded-xl transition-all min-h-[44px] min-w-[44px] flex items-center justify-center active:scale-90"
                                  title={showMikrotikPass ? 'Sembunyikan password' : 'Lihat password'}
                                  aria-label={showMikrotikPass ? 'Sembunyikan password' : 'Lihat password'}
                                >
                                  {showMikrotikPass ? (
                                    <EyeOff className="h-4 w-4 stroke-[2.2]" />
                                  ) : (
                                    <Eye className="h-4 w-4 stroke-[2.2]" />
                                  )}
                                </button>
                              </div>
                            </div>
                          </div>

                          {/* Action Buttons */}
                          <div className="mt-6 pt-4 border-t border-black/[0.06] flex flex-col sm:flex-row-reverse sm:items-center justify-start gap-2.5 pb-[calc(1.25rem+env(safe-area-inset-bottom,0px))] sm:pb-0">
                            <button
                              type="submit"
                              className="w-full sm:w-auto inline-flex items-center justify-center gap-1.5 rounded-2xl bg-apple-blue px-6 py-3.5 sm:py-2.5 text-base sm:text-sm font-semibold text-white shadow-sm hover:bg-apple-blueHover active:scale-[0.98] transition-all"
                            >
                              {editingId ? (
                                <>
                                  <CheckCircle2 className="h-4 w-4 stroke-[2.5]" />
                                  <span>Simpan Perubahan</span>
                                </>
                              ) : (
                                <>
                                  <Plus className="h-4 w-4 stroke-[2.5]" />
                                  <span>Tambah Perangkat</span>
                                </>
                              )}
                            </button>
                            <button
                              type="button"
                              onClick={closeModal}
                              className="w-full sm:w-auto rounded-2xl px-6 py-3 sm:py-2.5 text-base sm:text-sm font-semibold text-apple-blue hover:bg-black/[0.04] transition-all text-center"
                            >
                              Batal
                            </button>
                          </div>
                        </form>
                      </motion.div>
                    </div>
                  </div>
                </div>
              )}
            </AnimatePresence>
          </motion.div>
          ) : activeTab === 'pppoe' ? (
            /* ============================================================= */
            /* HALAMAN PPPOE: APPLE SEGMENTED CONTROL [ USER | PROFILE | ACTIVE ] */
            /* ============================================================= */
            <motion.div
              key="tab-pppoe"
              variants={pageVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              className="space-y-2.5 sm:space-y-3.5 w-full max-w-2xl mx-auto"
            >
              {/* STICKY TOP CONTROLS: Segmented Control + Search & Filter Bar */}
              <div className="sticky top-0 z-20 bg-apple-bg pt-0.5 pb-1 space-y-1.5">
                {/* Apple Segmented Control Bar (Authentic iOS HIG Style) */}
                <div
                  role="tablist"
                  aria-label="PPPoE Sub-Navigation"
                  className="bg-[#747480]/[0.10] p-[3px] rounded-[13px] sm:rounded-[14px] flex items-center border border-black/[0.04] shadow-[inset_0_1px_2px_rgba(0,0,0,0.04)]"
                >
                  {[
                    { id: 'user' as const, label: 'User', icon: Users, count: demoSecrets.length },
                    { id: 'profile' as const, label: 'Profile', icon: Zap, count: demoProfiles.length },
                    { id: 'active' as const, label: 'Active', icon: Activity, count: demoActive.length },
                  ].map((tab, idx, arr) => {
                    const isSelected = pppSubTab === tab.id;
                    const prevSelected = idx > 0 && pppSubTab === arr[idx - 1].id;
                    const showDivider = idx > 0 && !isSelected && !prevSelected;
                    const IconComponent = tab.icon;

                    return (
                      <React.Fragment key={tab.id}>
                        {showDivider && (
                          <div className="w-[1px] h-3.5 bg-black/[0.12] shrink-0" aria-hidden="true" />
                        )}
                        <button
                          type="button"
                          role="tab"
                          aria-selected={isSelected}
                          onClick={() => {
                            setPppSubTab(tab.id);
                            setFilterMenuOpen(false);
                          }}
                          className={`relative flex-1 py-1.5 px-1.5 text-xs font-semibold rounded-[10px] sm:rounded-[11px] active:scale-[0.98] transition-transform flex items-center justify-center gap-1.5 min-h-[40px] select-none ${
                            isSelected
                              ? 'text-apple-text'
                              : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.02]'
                          }`}
                        >
                          {isSelected && (
                            <motion.div
                              layoutId="pppSubTabActivePill"
                              className="absolute inset-0 bg-white rounded-[10px] sm:rounded-[11px] shadow-[0_1px_3px_rgba(0,0,0,0.10),0_1px_2px_rgba(0,0,0,0.06)] z-0"
                              transition={figmaSpring.quick}
                            />
                          )}
                          <IconComponent
                            className={`h-3.5 w-3.5 stroke-[2.2] relative z-10 ${
                              isSelected ? 'text-apple-blue' : 'text-apple-subtext'
                            }`}
                          />
                          <span className="tracking-tight relative z-10">{tab.label}</span>
                          <span
                            className={`text-[10px] px-1.5 py-0.5 rounded-md font-mono relative z-10 ${
                              isSelected
                                ? 'bg-apple-blue/10 text-apple-blue font-bold'
                                : 'bg-black/[0.05] text-apple-subtext font-medium'
                            }`}
                          >
                            {tab.count}
                          </span>
                          {tab.id === 'active' && isSelected && (
                            <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse -ml-0.5 relative z-10" />
                          )}
                        </button>
                      </React.Fragment>
                    );
                  })}
                </div>

                {/* Sub-tab 1: USER Search & Embedded Filter Menu + Add User Button */}
                {pppSubTab === 'user' && (
                  <div className="relative">
                    <div className="flex items-center gap-2">
                      <div className="relative flex-1">
                        <Search className="h-4 w-4 text-[#8e8e93] absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                        <input
                          type="text"
                          value={pppSearch}
                          onChange={(e) => setPppSearch(e.target.value)}
                          placeholder="Cari user, status, paket..."
                          className="w-full pl-10 pr-20 py-2.5 rounded-2xl bg-white border border-black/[0.06] shadow-xs text-xs sm:text-sm font-mono placeholder:font-sans placeholder:text-apple-subtext focus:outline-none focus:ring-2 focus:ring-apple-blue/30 focus:bg-white transition-all min-h-[48px]"
                        />
                        <div className="absolute right-1.5 top-1/2 -translate-y-1/2 flex items-center gap-1">
                          {pppSearch && (
                            <button
                              type="button"
                              onClick={() => setPppSearch('')}
                              className="h-7 w-7 min-h-[36px] min-w-[36px] rounded-full bg-black/[0.08] hover:bg-black/[0.14] text-apple-subtext hover:text-apple-text flex items-center justify-center transition-all"
                              title="Hapus pencarian"
                              aria-label="Hapus pencarian"
                            >
                              <X className="h-3.5 w-3.5 stroke-[2.5]" />
                            </button>
                          )}
                          {/* Apple Filter Button */}
                          <button
                            type="button"
                            onClick={() => setFilterMenuOpen(!filterMenuOpen)}
                            className={`min-h-[38px] px-2.5 rounded-xl flex items-center gap-1 transition-all ${
                              pppFilter !== 'all'
                                ? 'bg-apple-blue text-white shadow-xs font-semibold'
                                : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.04]'
                            }`}
                            title="Opsi Filter Pelanggan"
                            aria-label="Opsi Filter Pelanggan"
                          >
                            <ListFilter className="h-3.5 w-3.5 stroke-[2.2]" />
                            {pppFilter !== 'all' && (
                              <span className="text-[10px] capitalize max-w-[50px] truncate">
                                {pppFilter === 'active' ? 'Aktif' : 'Isolir'}
                              </span>
                            )}
                          </button>
                        </div>
                      </div>

                      {/* Tombol Add User PPPoE Baru */}
                      <button
                        type="button"
                        onClick={() => setIsAddUserModalOpen(true)}
                        className="min-h-[48px] px-3.5 sm:px-4 rounded-2xl bg-apple-blue text-white shadow-xs hover:bg-apple-blueHover active:scale-95 transition-all flex items-center justify-center gap-1.5 text-xs font-semibold shrink-0"
                        title="Tambah User PPPoE"
                        aria-label="Tambah User PPPoE"
                      >
                        <Plus className="h-4 w-4 stroke-[2.5]" />
                        <span className="hidden xs:inline">Tambah User</span>
                      </button>
                    </div>

                    {/* Apple UIMenu Popover */}
                    {filterMenuOpen && (
                      <>
                        <div
                          className="fixed inset-0 z-30"
                          onClick={() => setFilterMenuOpen(false)}
                        />
                        <div className="absolute right-0 top-full mt-2 z-40 w-56 rounded-2xl bg-white border border-black/[0.08] shadow-[0_12px_36px_rgba(0,0,0,0.12),0_4px_12px_rgba(0,0,0,0.06)] p-1.5">
                          <div className="px-3 pt-2 pb-1 text-[10px] font-bold text-apple-subtext uppercase tracking-wider">
                            Filter Status Pelanggan
                          </div>
                          <div className="space-y-0.5">
                            {(
                              [
                                { key: 'all', label: 'Semua Status', count: demoSecrets.length },
                                {
                                  key: 'active',
                                  label: 'Aktif',
                                  count: demoSecrets.filter((s) => !s.disabled).length,
                                },
                                {
                                  key: 'isolir',
                                  label: 'Terisolir',
                                  count: demoSecrets.filter((s) => s.disabled).length,
                                },
                              ] as const
                            ).map((opt) => {
                              const isSel = pppFilter === opt.key;
                              return (
                                <button
                                  key={opt.key}
                                  type="button"
                                  onClick={() => {
                                    setPppFilter(opt.key);
                                    setFilterMenuOpen(false);
                                  }}
                                  className={`w-full flex items-center justify-between px-2.5 py-1.5 text-xs rounded-xl select-none ${
                                    isSel
                                      ? 'bg-apple-blue/10 text-apple-blue font-semibold'
                                      : 'text-apple-text hover:bg-black/[0.04] font-normal'
                                  }`}
                                >
                                  <div className="flex items-center gap-2 min-w-0">
                                    <div className="w-4 h-4 flex items-center justify-center shrink-0">
                                      {isSel && (
                                        <Check className="h-3.5 w-3.5 text-apple-blue stroke-[2.5]" />
                                      )}
                                    </div>
                                    <span className="truncate">{opt.label}</span>
                                  </div>
                                  <span className="font-mono text-[10px] px-1.5 py-0.5 rounded-md bg-black/[0.05] text-apple-subtext shrink-0">
                                    {opt.count}
                                  </span>
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      </>
                    )}
                  </div>
                )}

                {/* Sub-tab 2: PROFILE Search & Embedded Filter Menu */}
                {pppSubTab === 'profile' && (
                  <div className="flex items-center gap-2">
                    <div className="relative flex-1">
                      <Search className="h-4 w-4 text-[#8e8e93] absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                      <input
                        type="text"
                        value={profileSearch}
                        onChange={(e) => setProfileSearch(e.target.value)}
                        placeholder="Cari profil, rate limit, pool..."
                        className="w-full pl-10 pr-20 py-2.5 rounded-2xl bg-white border border-black/[0.06] shadow-xs text-xs sm:text-sm font-mono placeholder:font-sans placeholder:text-apple-subtext focus:outline-none focus:ring-2 focus:ring-apple-blue/30 focus:bg-white transition-all min-h-[48px]"
                      />
                      <div className="absolute right-1.5 top-1/2 -translate-y-1/2 flex items-center gap-1">
                        {profileSearch && (
                          <button
                            type="button"
                            onClick={() => setProfileSearch('')}
                            className="h-7 w-7 min-h-[36px] min-w-[36px] rounded-full bg-black/[0.08] hover:bg-black/[0.14] text-apple-subtext hover:text-apple-text flex items-center justify-center transition-all"
                            title="Hapus pencarian"
                            aria-label="Hapus pencarian"
                          >
                            <X className="h-3.5 w-3.5 stroke-[2.5]" />
                          </button>
                        )}
                        {/* Apple Filter Button */}
                        <button
                          type="button"
                          onClick={() => setFilterMenuOpen(!filterMenuOpen)}
                          className={`min-h-[38px] px-2.5 rounded-xl flex items-center gap-1 transition-all ${
                            profileFilter !== 'all'
                              ? 'bg-apple-blue text-white shadow-xs font-semibold'
                              : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.04]'
                          }`}
                          title="Opsi Filter Profil"
                          aria-label="Opsi Filter Profil"
                        >
                          <ListFilter className="h-3.5 w-3.5 stroke-[2.2]" />
                          {profileFilter !== 'all' && (
                            <span className="text-[10px] capitalize max-w-[50px] truncate">
                              {profileFilter === 'used' ? 'Dipakai' : 'Kosong'}
                            </span>
                          )}
                        </button>
                      </div>

                      {/* Apple UIMenu Popover */}
                      {filterMenuOpen && (
                        <>
                          <div
                            className="fixed inset-0 z-30"
                            onClick={() => setFilterMenuOpen(false)}
                          />
                          <div className="absolute right-0 top-full mt-2 z-40 w-56 rounded-2xl bg-white border border-black/[0.08] shadow-[0_12px_36px_rgba(0,0,0,0.12),0_4px_12px_rgba(0,0,0,0.06)] p-1.5">
                            <div className="px-3 pt-2 pb-1 text-[10px] font-bold text-apple-subtext uppercase tracking-wider">
                              Filter Status Profil
                            </div>
                            <div className="space-y-0.5">
                              {(
                                [
                                  { key: 'all', label: 'Semua Profil', count: demoProfiles.length },
                                  {
                                    key: 'used',
                                    label: 'Digunakan',
                                    count: demoProfiles.filter((p) => p.userCount > 0).length,
                                  },
                                  {
                                    key: 'unused',
                                    label: 'Kosong (0 Pelanggan)',
                                    count: demoProfiles.filter((p) => p.userCount === 0).length,
                                  },
                                ] as const
                              ).map((opt) => {
                                const isSel = profileFilter === opt.key;
                                return (
                                  <button
                                    key={opt.key}
                                    type="button"
                                    onClick={() => {
                                      setProfileFilter(opt.key);
                                      setFilterMenuOpen(false);
                                    }}
                                    className={`w-full flex items-center justify-between px-2.5 py-1.5 text-xs rounded-xl select-none ${
                                      isSel
                                        ? 'bg-apple-blue/10 text-apple-blue font-semibold'
                                        : 'text-apple-text hover:bg-black/[0.04] font-normal'
                                    }`}
                                  >
                                    <div className="flex items-center gap-2 min-w-0">
                                      <div className="w-4 h-4 flex items-center justify-center shrink-0">
                                        {isSel && (
                                          <Check className="h-3.5 w-3.5 text-apple-blue stroke-[2.5]" />
                                        )}
                                      </div>
                                      <span className="truncate">{opt.label}</span>
                                    </div>
                                    <span className="font-mono text-[10px] px-1.5 py-0.5 rounded-md bg-black/[0.05] text-apple-subtext shrink-0">
                                      {opt.count}
                                    </span>
                                  </button>
                                );
                              })}
                            </div>
                          </div>
                        </>
                      )}
                    </div>

                    {/* Tombol Add Profile Baru */}
                    <button
                      type="button"
                      onClick={handleOpenAddProfile}
                      className="min-h-[48px] px-3.5 sm:px-4 rounded-2xl bg-apple-blue text-white shadow-xs hover:bg-apple-blueHover active:scale-95 transition-all flex items-center justify-center gap-1.5 text-xs font-semibold shrink-0"
                      title="Tambah Profil Bandwidth"
                      aria-label="Tambah Profil Bandwidth"
                    >
                      <Plus className="h-4 w-4 stroke-[2.5]" />
                      <span className="hidden xs:inline">Tambah Profil</span>
                    </button>
                  </div>
                )}

                {/* Sub-tab 3: ACTIVE Search & Embedded Filter Menu */}
                {pppSubTab === 'active' && (
                  <div className="relative">
                    <Search className="h-4 w-4 text-[#8e8e93] absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                    <input
                      type="text"
                      value={activeSearch}
                      onChange={(e) => setActiveSearch(e.target.value)}
                      placeholder="Cari user aktif, IP, MAC caller-id..."
                      className="w-full pl-10 pr-20 py-2.5 rounded-2xl bg-white border border-black/[0.06] shadow-xs text-xs sm:text-sm font-mono placeholder:font-sans placeholder:text-apple-subtext focus:outline-none focus:ring-2 focus:ring-apple-blue/30 focus:bg-white transition-all min-h-[48px]"
                    />
                    <div className="absolute right-1.5 top-1/2 -translate-y-1/2 flex items-center gap-1">
                      {activeSearch && (
                        <button
                          type="button"
                          onClick={() => setActiveSearch('')}
                          className="h-7 w-7 min-h-[36px] min-w-[36px] rounded-full bg-black/[0.08] hover:bg-black/[0.14] text-apple-subtext hover:text-apple-text flex items-center justify-center transition-all"
                          title="Hapus pencarian"
                          aria-label="Hapus pencarian"
                        >
                          <X className="h-3.5 w-3.5 stroke-[2.5]" />
                        </button>
                      )}
                      {/* Apple Filter Button */}
                      <button
                        type="button"
                        onClick={() => setFilterMenuOpen(!filterMenuOpen)}
                        className={`min-h-[38px] px-2.5 rounded-xl flex items-center gap-1 transition-all ${
                          activeFilter !== 'all'
                            ? 'bg-apple-blue text-white shadow-xs font-semibold'
                            : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.04]'
                        }`}
                        title="Opsi Filter Paket"
                        aria-label="Opsi Filter Paket"
                      >
                        <ListFilter className="h-3.5 w-3.5 stroke-[2.2]" />
                        {activeFilter !== 'all' && (
                          <span className="text-[10px] capitalize max-w-[50px] truncate">
                            {activeFilter}
                          </span>
                        )}
                      </button>
                    </div>

                    {/* Apple UIMenu Popover */}
                    {filterMenuOpen && (
                      <>
                        <div
                          className="fixed inset-0 z-30"
                          onClick={() => setFilterMenuOpen(false)}
                        />
                        <div className="absolute right-0 top-full mt-2 z-40 w-56 rounded-2xl bg-white border border-black/[0.08] shadow-[0_12px_36px_rgba(0,0,0,0.12),0_4px_12px_rgba(0,0,0,0.06)] p-1.5 max-h-64 overflow-y-auto">
                          <div className="px-3 pt-2 pb-1 text-[10px] font-bold text-apple-subtext uppercase tracking-wider">
                            Filter Paket Online
                          </div>
                          <div className="space-y-0.5">
                            <button
                              type="button"
                              onClick={() => {
                                setActiveFilter('all');
                                setFilterMenuOpen(false);
                              }}
                              className={`w-full flex items-center justify-between px-2.5 py-1.5 text-xs rounded-xl select-none ${
                                activeFilter === 'all'
                                  ? 'bg-apple-blue/10 text-apple-blue font-semibold'
                                  : 'text-apple-text hover:bg-black/[0.04] font-normal'
                              }`}
                            >
                              <div className="flex items-center gap-2 min-w-0">
                                <div className="w-4 h-4 flex items-center justify-center shrink-0">
                                  {activeFilter === 'all' && (
                                    <Check className="h-3.5 w-3.5 text-apple-blue stroke-[2.5]" />
                                  )}
                                </div>
                                <span className="truncate">Semua Sesi</span>
                              </div>
                              <span className="font-mono text-[10px] px-1.5 py-0.5 rounded-md bg-black/[0.05] text-apple-subtext shrink-0">
                                {demoActive.length}
                              </span>
                            </button>
                            {Array.from(
                              new Set(
                                demoActive
                                  .map(
                                    (act) =>
                                      demoSecrets.find(
                                        (s) =>
                                          s.name.toLowerCase() === act.name.toLowerCase()
                                      )?.profile
                                  )
                                  .filter(Boolean) as string[]
                              )
                            ).map((profName) => {
                              const count = demoActive.filter(
                                (act) =>
                                  demoSecrets.find(
                                    (s) =>
                                      s.name.toLowerCase() === act.name.toLowerCase()
                                  )?.profile === profName
                              ).length;
                              const isSel = activeFilter === profName;

                              return (
                                <button
                                  key={profName}
                                  type="button"
                                  onClick={() => {
                                    setActiveFilter(profName);
                                    setFilterMenuOpen(false);
                                  }}
                                  className={`w-full flex items-center justify-between px-2.5 py-1.5 text-xs rounded-xl select-none ${
                                    isSel
                                      ? 'bg-apple-blue/10 text-apple-blue font-semibold'
                                      : 'text-apple-text hover:bg-black/[0.04] font-normal'
                                  }`}
                                >
                                  <div className="flex items-center gap-2 min-w-0">
                                    <div className="w-4 h-4 flex items-center justify-center shrink-0">
                                      {isSel && (
                                        <Check className="h-3.5 w-3.5 text-apple-blue stroke-[2.5]" />
                                      )}
                                    </div>
                                    <span className="truncate">{profName}</span>
                                  </div>
                                  <span className="font-mono text-[10px] px-1.5 py-0.5 rounded-md bg-black/[0.05] text-apple-subtext shrink-0">
                                    {count}
                                  </span>
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      </>
                    )}
                  </div>
                )}
              </div>

              {/* Sub-tab 1: USER (PPPoE Secrets & Pelanggan) */}
              {pppSubTab === 'user' && (
                <div className="space-y-2.5 sm:space-y-3">
                  {/* Apple Inset Grouped Table View */}
                  <section className="bg-white rounded-2xl sm:rounded-3xl border border-black/[0.08] shadow-apple overflow-hidden flex flex-col">
                    {(() => {
                      const activeMap = new Map<string, DemoActive>();
                      for (const act of demoActive) {
                        activeMap.set(act.name.toLowerCase(), act);
                      }

                      const filtered = demoSecrets.filter((s) => {
                        const matchFilter =
                          pppFilter === 'all'
                            ? true
                            : pppFilter === 'active'
                            ? !s.disabled
                            : s.disabled;
                        const q = pppSearch.toLowerCase().trim();
                        const act = activeMap.get((s.name || '').toLowerCase());
                        const userIp = act?.address || s.remoteAddress || '';
                        const matchSearch =
                          !q ||
                          (s.name || '').toLowerCase().includes(q) ||
                          (s.comment || '').toLowerCase().includes(q) ||
                          userIp.toLowerCase().includes(q) ||
                          (s.remoteAddress || '').includes(q) ||
                          (s.profile || '').toLowerCase().includes(q);
                        return matchFilter && matchSearch;
                      });

                      return (
                        <>
                          <div className="px-4 py-2.5 sm:px-5 sm:py-3 border-b border-black/[0.04] bg-[#fbfbfd] flex items-center justify-between shrink-0">
                            <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider">
                              Daftar Pelanggan PPPoE:
                            </span>
                            <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider font-mono">
                              {filtered.length} Pelanggan
                            </span>
                          </div>

                          {filtered.length === 0 ? (
                            <div className="flex flex-col items-center justify-center gap-3 px-4 py-16 text-center">
                              <div className="h-12 w-12 rounded-full bg-apple-bg flex items-center justify-center text-apple-subtext">
                                <User className="h-6 w-6 stroke-[1.5]" />
                              </div>
                              <div>
                                <p className="text-sm font-semibold text-apple-text">
                                  Tidak Ada Pelanggan
                                </p>
                                <p className="text-xs text-apple-subtext mt-0.5">
                                  Tidak ditemukan pelanggan yang sesuai dengan pencarian atau filter.
                                </p>
                              </div>
                            </div>
                          ) : (
                            <div
                              onScroll={(e) => {
                                const el = e.currentTarget;
                                if (el.scrollTop + el.clientHeight >= el.scrollHeight - 80) {
                                  if (visiblePppSecrets < filtered.length) {
                                    setVisiblePppSecrets((prev) => Math.min(prev + 25, filtered.length));
                                  }
                                }
                              }}
                              className="divide-y divide-black/[0.04] overflow-y-auto max-h-[515px] sm:max-h-[600px] overscroll-contain pb-2"
                            >
                              {filtered.slice(0, visiblePppSecrets).map((secret) => {
                                const parsed = parseExpiryFromComment(secret.comment);
                                const activeSession = activeMap.get(secret.name.toLowerCase());
                                const userIp = activeSession?.address || secret.remoteAddress || 'Dynamic IP';

                                return (
                                  <div
                                    key={secret.id}
                                    onClick={() => setSelectedSecretId(secret.id)}
                                    className="px-4 py-2.5 sm:px-5 sm:py-3 flex items-center justify-between gap-3 bg-white hover:bg-[#fbfbfd] active:bg-black/[0.02] transition-colors cursor-pointer group"
                                  >
                                    <div className="min-w-0 flex-1">
                                      <div className="flex items-center gap-2">
                                        <p className="font-mono font-bold text-sm sm:text-base text-apple-text tracking-tight truncate group-hover:text-apple-blue transition-colors">
                                          {secret.name}
                                        </p>
                                        <span className="font-mono text-xs font-semibold px-2 py-0.5 rounded-md bg-apple-blue/10 text-apple-blue border border-apple-blue/15 shrink-0">
                                          {secret.profile}
                                        </span>
                                      </div>
                                      <div className="flex items-center gap-2 text-xs text-apple-subtext mt-0.5 flex-wrap">
                                        <span className={`font-mono font-semibold ${userIp !== 'Dynamic IP' ? 'text-apple-text' : 'text-apple-subtext'}`}>
                                          {userIp}
                                        </span>
                                        <span>•</span>
                                        {secret.disabled ? (
                                          <span className="font-semibold text-rose-600">
                                            Isolir
                                          </span>
                                        ) : parsed.daysRemaining !== null ? (
                                          parsed.daysRemaining < 0 ? (
                                            <span className="font-semibold text-rose-600">
                                              Habis ({Math.abs(parsed.daysRemaining)}h lalu)
                                            </span>
                                          ) : parsed.daysRemaining === 0 ? (
                                            <span className="font-semibold text-amber-600">
                                              Habis Hari Ini
                                            </span>
                                          ) : (
                                            <span className="font-semibold text-emerald-600">
                                              Sisa {parsed.daysRemaining} hari
                                            </span>
                                          )
                                        ) : (
                                          <span className="font-medium text-apple-subtext">
                                            Aktif
                                          </span>
                                        )}
                                      </div>
                                    </div>

                                    {/* Action: Edit Icon Button (style sama seperti di PPPoE Profile) */}
                                    <div className="flex items-center gap-2 shrink-0">
                                      <button
                                        type="button"
                                        onClick={(e) => {
                                          e.stopPropagation();
                                          setSelectedSecretId(secret.id);
                                        }}
                                        className="h-9 w-9 sm:h-8 sm:w-8 min-h-[44px] min-w-[44px] sm:min-h-[36px] sm:min-w-[36px] rounded-full flex items-center justify-center text-apple-subtext hover:text-apple-blue hover:bg-apple-blue/10 transition-colors"
                                        title="Edit Pelanggan"
                                        aria-label={`Edit pelanggan ${secret.name}`}
                                      >
                                        <Pencil className="h-3.5 w-3.5 stroke-[2.2]" />
                                      </button>
                                    </div>
                                  </div>
                                );
                              })}

                              {filtered.length > visiblePppSecrets && (
                                <div className="p-3 text-center border-t border-black/[0.04] bg-[#fbfbfd]">
                                  <button
                                    type="button"
                                    onClick={() => setVisiblePppSecrets((prev) => Math.min(prev + 50, filtered.length))}
                                    className="w-full py-2.5 px-4 text-xs font-semibold text-apple-blue bg-apple-blue/10 hover:bg-apple-blue/15 active:scale-[0.98] rounded-xl transition-all min-h-[44px] flex items-center justify-center gap-1.5"
                                  >
                                    <ChevronDown className="h-4 w-4 stroke-[2.2]" />
                                    <span>Muat Lebih Banyak ({filtered.length - visiblePppSecrets} lagi)</span>
                                    <span className="font-mono text-[11px] opacity-70">· Menampilkan {visiblePppSecrets} dari {filtered.length}</span>
                                  </button>
                                </div>
                              )}

                              {visiblePppSecrets >= filtered.length && filtered.length > 25 && (
                                <div className="py-2.5 px-4 text-center border-t border-black/[0.04] bg-[#fbfbfd]/60 text-[11px] font-mono text-apple-subtext">
                                  Semua {filtered.length} pelanggan telah dimuat
                                </div>
                              )}
                            </div>
                          )}
                        </>
                      );
                    })()}
                  </section>
                </div>
              )}

              {/* Sub-tab 2: PROFILE (Profil Bandwidth) */}
              {pppSubTab === 'profile' && (
                <div className="space-y-2.5 sm:space-y-3">
                  {(() => {
                    const filtered = demoProfiles.filter((prof) => {
                      const matchFilter =
                        profileFilter === 'all'
                          ? true
                          : profileFilter === 'used'
                          ? prof.userCount > 0
                          : prof.userCount === 0;
                      const q = profileSearch.toLowerCase().trim();
                      const matchSearch =
                        !q ||
                        (prof.name || '').toLowerCase().includes(q) ||
                        (prof.rateLimit || '').toLowerCase().includes(q) ||
                        (prof.remotePool || '').toLowerCase().includes(q) ||
                        (prof.localAddress || '').toLowerCase().includes(q);
                      return matchFilter && matchSearch;
                    });

                    return (
                      <section className="bg-white rounded-2xl sm:rounded-3xl border border-black/[0.08] shadow-apple overflow-hidden flex flex-col">
                        <div className="px-4 py-2.5 sm:px-5 sm:py-3 border-b border-black/[0.04] bg-[#fbfbfd] flex items-center justify-between shrink-0">
                          <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider">
                            Daftar Profil Bandwidth:
                          </span>
                          <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider font-mono">
                            {filtered.length} Profil
                          </span>
                        </div>

                        {filtered.length === 0 ? (
                          <div className="flex flex-col items-center justify-center gap-3 px-4 py-16 text-center">
                            <div className="h-12 w-12 rounded-full bg-apple-bg flex items-center justify-center text-apple-subtext">
                              <Zap className="h-6 w-6 stroke-[1.5]" />
                            </div>
                            <div>
                              <p className="text-sm font-semibold text-apple-text">
                                Tidak Ada Profil
                              </p>
                              <p className="text-xs text-apple-subtext mt-0.5">
                                Tidak ditemukan profil yang sesuai dengan pencarian atau filter.
                              </p>
                            </div>
                          </div>
                        ) : (
                          <div
                            onScroll={(e) => {
                              const el = e.currentTarget;
                              if (el.scrollTop + el.clientHeight >= el.scrollHeight - 80) {
                                if (visiblePppProfiles < filtered.length) {
                                  setVisiblePppProfiles((prev) => Math.min(prev + 25, filtered.length));
                                }
                              }
                            }}
                            className="divide-y divide-black/[0.04] overflow-y-auto max-h-[515px] sm:max-h-[600px] overscroll-contain pb-2"
                          >
                            {filtered.slice(0, visiblePppProfiles).map((prof) => (
                              <div
                                key={prof.id}
                                onClick={() => handleOpenEditProfile(prof)}
                                className="px-4 py-2.5 sm:px-5 sm:py-3 flex items-center justify-between gap-3 bg-white hover:bg-[#fbfbfd] cursor-pointer group"
                              >
                                <div className="min-w-0 flex-1">
                                  <div className="flex items-center gap-2">
                                    <p className="font-mono font-bold text-sm sm:text-base text-apple-text tracking-tight truncate group-hover:text-apple-blue transition-colors">
                                      {prof.name}
                                    </p>
                                    <span className="font-mono text-xs font-semibold px-2 py-0.5 rounded-md bg-emerald-500/10 text-emerald-700 border border-emerald-500/15">
                                      {prof.rateLimit}
                                    </span>
                                  </div>
                                  <div className="text-xs text-apple-subtext mt-0.5 truncate">
                                    <span>
                                      Gateway:{' '}
                                      <strong className="text-apple-text font-semibold font-mono">
                                        {prof.localAddress && prof.localAddress !== '-' ? prof.localAddress : '—'}
                                      </strong>
                                    </span>
                                  </div>
                                </div>

                                <div className="flex items-center gap-2 shrink-0">
                                  <span className="font-mono text-xs font-semibold bg-[#747480]/[0.08] px-2.5 py-1 rounded-full text-apple-text border border-black/[0.04]">
                                    {prof.userCount} Pelanggan
                                  </span>
                                  <button
                                    type="button"
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      handleOpenEditProfile(prof);
                                    }}
                                    className="h-9 w-9 sm:h-8 sm:w-8 min-h-[44px] min-w-[44px] sm:min-h-[36px] sm:min-w-[36px] rounded-full flex items-center justify-center text-apple-subtext hover:text-apple-blue hover:bg-apple-blue/10 transition-colors"
                                    title="Edit Profil"
                                    aria-label="Edit Profil"
                                  >
                                    <Pencil className="h-3.5 w-3.5 stroke-[2.2]" />
                                  </button>
                                </div>
                              </div>
                            ))}

                            {filtered.length > visiblePppProfiles && (
                              <div className="p-3 text-center border-t border-black/[0.04] bg-[#fbfbfd]">
                                <button
                                  type="button"
                                  onClick={() => setVisiblePppProfiles((prev) => Math.min(prev + 50, filtered.length))}
                                  className="w-full py-2.5 px-4 text-xs font-semibold text-apple-blue bg-apple-blue/10 hover:bg-apple-blue/15 active:scale-[0.98] rounded-xl transition-all min-h-[44px] flex items-center justify-center gap-1.5"
                                >
                                  <ChevronDown className="h-4 w-4 stroke-[2.2]" />
                                  <span>Muat Lebih Banyak ({filtered.length - visiblePppProfiles} lagi)</span>
                                  <span className="font-mono text-[11px] opacity-70">· Menampilkan {visiblePppProfiles} dari {filtered.length}</span>
                                </button>
                              </div>
                            )}

                            {visiblePppProfiles >= filtered.length && filtered.length > 25 && (
                              <div className="py-2.5 px-4 text-center border-t border-black/[0.04] bg-[#fbfbfd]/60 text-[11px] font-mono text-apple-subtext">
                                Semua {filtered.length} profil telah dimuat
                              </div>
                            )}
                          </div>
                        )}
                      </section>
                    );
                  })()}
                </div>
              )}

              {/* Sub-tab 3: ACTIVE (Sesi Aktif Online) */}
              {pppSubTab === 'active' && (
                <div className="space-y-2.5 sm:space-y-3">
                  {(() => {
                    const filtered = demoActive.filter((act) => {
                      const userSecret = demoSecrets.find(
                        (s) => s.name.toLowerCase() === act.name.toLowerCase()
                      );
                      const userProfile = userSecret?.profile;
                      const matchFilter =
                        activeFilter === 'all'
                          ? true
                          : userProfile === activeFilter;
                      const q = activeSearch.toLowerCase().trim();
                      const matchSearch =
                        !q ||
                        (act.name || '').toLowerCase().includes(q) ||
                        (act.address || '').includes(q) ||
                        (act.callerId || '').toLowerCase().includes(q) ||
                        (act.uptime || '').toLowerCase().includes(q);
                      return matchFilter && matchSearch;
                    });

                    return (
                      <section className="bg-white rounded-2xl sm:rounded-3xl border border-black/[0.08] shadow-apple overflow-hidden flex flex-col">
                        <div className="px-4 py-2.5 sm:px-5 sm:py-3 border-b border-black/[0.04] bg-[#fbfbfd] flex items-center justify-between shrink-0">
                          <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider">
                            Daftar Sesi Online Aktif:
                          </span>
                          <div className="flex items-center gap-2">
                            <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider font-mono">
                              {filtered.length} Sesi Terhubung
                            </span>
                            <span className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
                          </div>
                        </div>

                        {filtered.length === 0 ? (
                          <div className="flex flex-col items-center justify-center gap-3 px-4 py-16 text-center">
                            <div className="h-12 w-12 rounded-full bg-apple-bg flex items-center justify-center text-apple-subtext">
                              <Activity className="h-6 w-6 stroke-[1.5]" />
                            </div>
                            <div>
                              <p className="text-sm font-semibold text-apple-text">
                                Tidak Ada Sesi Aktif
                              </p>
                              <p className="text-xs text-apple-subtext mt-0.5">
                                Tidak ditemukan sesi aktif yang sesuai dengan pencarian atau filter.
                              </p>
                            </div>
                          </div>
                        ) : (
                          <div
                            onScroll={(e) => {
                              const el = e.currentTarget;
                              if (el.scrollTop + el.clientHeight >= el.scrollHeight - 80) {
                                if (visiblePppActive < filtered.length) {
                                  setVisiblePppActive((prev) => Math.min(prev + 25, filtered.length));
                                }
                              }
                            }}
                            className="divide-y divide-black/[0.04] overflow-y-auto max-h-[515px] sm:max-h-[600px] overscroll-contain pb-2"
                          >
                            {filtered.slice(0, visiblePppActive).map((act) => (
                              <div
                                key={act.id}
                                className="px-4 py-2.5 sm:px-5 sm:py-3 flex items-center justify-between gap-3 bg-white hover:bg-[#fbfbfd]"
                              >
                                <div className="min-w-0 flex-1">
                                  <div className="flex items-center gap-2">
                                    <span className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse shrink-0" />
                                    <p className="font-mono font-bold text-sm sm:text-base text-apple-text tracking-tight truncate">
                                      {act.name}
                                    </p>
                                    <span className="font-mono text-xs font-semibold text-emerald-700 bg-emerald-500/10 px-2 py-0.5 rounded-md border border-emerald-500/15">
                                      {act.address}
                                    </span>
                                  </div>
                                  <div className="flex items-center gap-2 text-xs text-apple-subtext mt-0.5 truncate">
                                    <span>
                                      MAC:{' '}
                                      <strong className="text-apple-text font-semibold font-mono">
                                        {act.callerId}
                                      </strong>
                                    </span>
                                    <span>•</span>
                                    <span>
                                      Uptime:{' '}
                                      <strong className="text-apple-text font-semibold font-mono">
                                        {act.uptime}
                                      </strong>
                                    </span>
                                  </div>
                                </div>

                                <div className="flex items-center gap-1 shrink-0">
                                  <button
                                    type="button"
                                    onClick={() => handleDisconnectActive(act.id, act.name)}
                                    className="h-9 w-9 sm:h-8 sm:w-8 min-h-[44px] min-w-[44px] sm:min-h-[36px] sm:min-w-[36px] rounded-full bg-rose-500/10 text-rose-600 hover:bg-rose-500/20 border border-rose-500/15 flex items-center justify-center active:scale-90 transition-all"
                                    title="Putus Sesi Online"
                                    aria-label={`Putus sesi ${act.name}`}
                                  >
                                    <LogOut className="h-3.5 w-3.5 text-rose-600 stroke-[2.2]" />
                                  </button>
                                </div>
                              </div>
                            ))}

                            {filtered.length > visiblePppActive && (
                              <div className="p-3 text-center border-t border-black/[0.04] bg-[#fbfbfd]">
                                <button
                                  type="button"
                                  onClick={() => setVisiblePppActive((prev) => Math.min(prev + 50, filtered.length))}
                                  className="w-full py-2.5 px-4 text-xs font-semibold text-apple-blue bg-apple-blue/10 hover:bg-apple-blue/15 active:scale-[0.98] rounded-xl transition-all min-h-[44px] flex items-center justify-center gap-1.5"
                                >
                                  <ChevronDown className="h-4 w-4 stroke-[2.2]" />
                                  <span>Muat Lebih Banyak ({filtered.length - visiblePppActive} lagi)</span>
                                  <span className="font-mono text-[11px] opacity-70">· Menampilkan {visiblePppActive} dari {filtered.length}</span>
                                </button>
                              </div>
                            )}

                            {visiblePppActive >= filtered.length && filtered.length > 25 && (
                              <div className="py-2.5 px-4 text-center border-t border-black/[0.04] bg-[#fbfbfd]/60 text-[11px] font-mono text-apple-subtext">
                                Semua {filtered.length} sesi terhubung telah dimuat
                              </div>
                            )}
                          </div>
                        )}
                      </section>
                    );
                  })()}
                </div>
              )}

              {/* MODAL DETAIL PELANGGAN PPPOE (APPLE iOS HIG STYLE) */}
              {selectedSecretId && (() => {
                const activeSecret = demoSecrets.find((s) => s.id === selectedSecretId);
                if (!activeSecret) return null;
                const parsed = parseExpiryFromComment(activeSecret.comment);
                const isExpired = parsed.status === 'expired';
                const displayName = parsed.customerName || activeSecret.name;
                const activeSession = demoActive.find(
                  (a) => a.name.toLowerCase() === activeSecret.name.toLowerCase()
                );

                return (
                  <div
                    className="relative z-50"
                    aria-labelledby="secret-modal-title"
                    role="dialog"
                    aria-modal="true"
                  >
                    {/* Backdrop */}
                    <div
                      className="fixed inset-0 bg-black/40 backdrop-blur-sm transition-opacity"
                      onClick={() => setSelectedSecretId(null)}
                    />

                    <div
                      className="fixed inset-0 z-50 w-screen overflow-y-auto"
                      onClick={() => setSelectedSecretId(null)}
                    >
                      <div className="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4">
                        <div
                          className="relative transform overflow-hidden rounded-t-[32px] sm:rounded-3xl bg-apple-card text-left shadow-[0_-10px_40px_rgba(0,0,0,0.14)] sm:shadow-ios-modal transition-all my-0 sm:my-auto w-full max-w-lg border-t sm:border border-black/[0.08] max-h-[92vh] sm:max-h-[85vh] flex flex-col animate-in slide-in-from-bottom duration-300 ease-out sm:zoom-in-95"
                          onClick={(e) => e.stopPropagation()}
                        >
                          {/* iOS Drawer Grabber Handle */}
                          <div className="w-full pt-3 pb-1 flex justify-center sm:hidden bg-[#fbfbfd] shrink-0">
                            <div className="w-10 h-1.5 rounded-full bg-black/20" />
                          </div>

                          {/* Header Modal */}
                          <div className="px-5 pt-2 pb-3.5 sm:px-6 sm:pt-5 sm:pb-4 border-b border-black/[0.06] flex items-center justify-between bg-[#fbfbfd] shrink-0">
                            <div className="flex items-center gap-3">
                              <div
                                className={`h-11 w-11 rounded-2xl flex items-center justify-center font-bold shrink-0 ${
                                  activeSecret.disabled
                                    ? 'bg-rose-500/10 text-rose-600'
                                    : isExpired
                                    ? 'bg-amber-500/10 text-amber-600'
                                    : 'bg-emerald-500/10 text-emerald-600'
                                }`}
                              >
                                <User className="h-5 w-5 stroke-[2.2]" />
                              </div>
                              <div>
                                <h3
                                  className="text-base font-bold text-apple-text tracking-tight truncate max-w-[240px]"
                                  id="secret-modal-title"
                                >
                                  {displayName}
                                </h3>
                                <p className="text-xs text-apple-subtext font-mono mt-0.5">
                                  User:{' '}
                                  <strong className="text-apple-text font-semibold">
                                    {activeSecret.name}
                                  </strong>
                                </p>
                              </div>
                            </div>
                            <button
                              type="button"
                              onClick={() => setSelectedSecretId(null)}
                              className="text-apple-subtext hover:text-apple-text rounded-full p-2 bg-black/[0.04] hover:bg-black/[0.08] transition-all min-h-[36px] min-w-[36px] flex items-center justify-center"
                              title="Tutup modal"
                              aria-label="Tutup modal"
                            >
                              <X className="h-4 w-4" />
                            </button>
                          </div>

                          {/* Modal Body: Inset Grouped Info Details */}
                          <div className="p-5 sm:p-6 space-y-4 overflow-y-auto overscroll-contain flex-1">
                            {/* Quick Status Pill Bar */}
                            <div className="flex items-center gap-2 flex-wrap">
                              <span
                                className={`text-xs font-semibold px-2.5 py-1 rounded-full ${
                                  activeSecret.disabled
                                    ? 'bg-rose-500/10 text-rose-600 border border-rose-500/20'
                                    : isExpired
                                    ? 'bg-amber-500/10 text-amber-600 border border-amber-500/20'
                                    : 'bg-emerald-500/10 text-emerald-700 border border-emerald-500/20'
                                }`}
                              >
                                {activeSecret.disabled
                                  ? 'Isolir'
                                  : isExpired
                                  ? 'Kadaluarsa'
                                  : 'Aktif'}
                              </span>

                              <span className="text-xs font-semibold px-2.5 py-1 rounded-full bg-apple-blue/10 text-apple-blue border border-apple-blue/20">
                                Paket: {activeSecret.profile}
                              </span>
                            </div>

                            {/* Data Technical Grid */}
                            <div className="bg-black/[0.02] border border-black/[0.05] rounded-2xl p-4 divide-y divide-black/[0.04] text-xs">
                              <div className="py-2.5 flex items-center justify-between first:pt-0">
                                <span className="text-apple-subtext font-medium">Username PPPoE</span>
                                <span className="font-mono font-bold text-apple-text">
                                  {activeSecret.name}
                                </span>
                              </div>
                              <div className="py-2.5 flex items-center justify-between gap-3">
                                <span className="text-apple-subtext font-medium shrink-0">Paket Bandwidth</span>
                                {editingProfile !== null ? (
                                  <div className="flex items-center gap-1.5 shrink-0">
                                    <select
                                      value={editingProfile}
                                      onChange={(e) => setEditingProfile(e.target.value)}
                                      className="font-mono text-xs font-semibold bg-white border border-black/[0.12] rounded-lg px-2 py-1 text-apple-text focus:outline-none focus:ring-2 focus:ring-apple-blue/30 max-w-[140px] truncate"
                                      aria-label="Pilih Paket Bandwidth"
                                    >
                                      {demoProfiles.map((p) => (
                                        <option key={p.id} value={p.name}>
                                          {p.name}
                                        </option>
                                      ))}
                                    </select>
                                    <button
                                      type="button"
                                      onClick={() => handleUpdateProfile(activeSecret.id, editingProfile)}
                                      className="h-7 w-7 rounded-lg bg-apple-blue text-white flex items-center justify-center hover:bg-apple-blueHover transition-colors shrink-0"
                                      title="Simpan Paket"
                                      aria-label="Simpan Paket"
                                    >
                                      <Check className="h-3.5 w-3.5 stroke-[2.5]" />
                                    </button>
                                    <button
                                      type="button"
                                      onClick={() => setEditingProfile(null)}
                                      className="h-7 w-7 rounded-lg bg-black/[0.05] text-apple-subtext flex items-center justify-center hover:bg-black/[0.1] transition-colors shrink-0"
                                      title="Batal"
                                      aria-label="Batal Ubah Paket"
                                    >
                                      <X className="h-3.5 w-3.5 stroke-[2.5]" />
                                    </button>
                                  </div>
                                ) : (
                                  <div className="flex items-center gap-2">
                                    <span className="font-semibold font-mono text-apple-text">
                                      {activeSecret.profile}
                                    </span>
                                    <button
                                      type="button"
                                      onClick={() => setEditingProfile(activeSecret.profile)}
                                      className="h-6 w-6 rounded-md bg-black/[0.04] hover:bg-black/[0.08] text-apple-subtext hover:text-apple-blue flex items-center justify-center transition-all"
                                      title="Ubah Paket"
                                      aria-label="Ubah Paket Pelanggan"
                                    >
                                      <Pencil className="h-3 w-3 stroke-[2.2]" />
                                    </button>
                                  </div>
                                )}
                              </div>
                              <div className="py-2.5 flex items-center justify-between">
                                <span className="text-apple-subtext font-medium">IP Remote</span>
                                <span className="font-mono font-bold text-apple-text">
                                  {activeSecret.remoteAddress || activeSession?.address || '— (Dynamic Pool)'}
                                </span>
                              </div>
                              <div className="py-2.5 flex items-center justify-between gap-3">
                                <span className="text-apple-subtext font-medium shrink-0">Jatuh Tempo</span>
                                {editingExpiryDate !== null ? (
                                  <div className="flex items-center gap-1.5 shrink-0">
                                    <input
                                      type="date"
                                      value={editingExpiryDate}
                                      onChange={(e) => setEditingExpiryDate(e.target.value)}
                                      className="font-mono text-xs font-semibold bg-white border border-black/[0.12] rounded-lg px-2 py-1 text-apple-text focus:outline-none focus:ring-2 focus:ring-apple-blue/30"
                                    />
                                    <button
                                      type="button"
                                      onClick={() => handleUpdateExpiryDate(activeSecret.id, editingExpiryDate)}
                                      className="h-7 w-7 rounded-lg bg-apple-blue text-white flex items-center justify-center hover:bg-apple-blueHover transition-colors"
                                      title="Simpan Tanggal"
                                      aria-label="Simpan Tanggal"
                                    >
                                      <Check className="h-3.5 w-3.5 stroke-[2.5]" />
                                    </button>
                                    <button
                                      type="button"
                                      onClick={() => setEditingExpiryDate(null)}
                                      className="h-7 w-7 rounded-lg bg-black/[0.05] text-apple-subtext flex items-center justify-center hover:bg-black/[0.1] transition-colors"
                                      title="Batal"
                                      aria-label="Batal Edit"
                                    >
                                      <X className="h-3.5 w-3.5 stroke-[2.5]" />
                                    </button>
                                  </div>
                                ) : (
                                  <div className="flex items-center gap-2">
                                    <span
                                      className={`font-mono font-bold ${
                                        isExpired ? 'text-rose-600' : 'text-apple-text'
                                      }`}
                                    >
                                      {parsed.formattedExpiry || '—'}
                                      {parsed.daysRemaining !== null && (
                                        <span className="font-normal font-sans text-apple-subtext ml-1.5">
                                          ({parsed.daysRemaining < 0
                                            ? `Lewat ${Math.abs(parsed.daysRemaining)}h`
                                            : `${parsed.daysRemaining}h lagi`}
                                          )
                                        </span>
                                      )}
                                    </span>
                                    <button
                                      type="button"
                                      onClick={() => {
                                        const now = parsed.expiryDate || new Date();
                                        const yyyy = now.getFullYear();
                                        const mm = String(now.getMonth() + 1).padStart(2, '0');
                                        const dd = String(now.getDate()).padStart(2, '0');
                                        setEditingExpiryDate(`${yyyy}-${mm}-${dd}`);
                                      }}
                                      className="h-6 w-6 rounded-md bg-black/[0.04] hover:bg-black/[0.08] text-apple-subtext hover:text-apple-blue flex items-center justify-center transition-all"
                                      title="Ubah Tanggal Expired"
                                      aria-label="Ubah Tanggal Expired"
                                    >
                                      <Pencil className="h-3 w-3 stroke-[2.2]" />
                                    </button>
                                  </div>
                                )}
                              </div>
                              {activeSession && (
                                <>
                                  <div className="py-2.5 flex items-center justify-between">
                                    <span className="text-apple-subtext font-medium">MAC Caller-ID</span>
                                    <span className="font-mono font-bold text-apple-text">
                                      {activeSession.callerId}
                                    </span>
                                  </div>
                                  <div className="py-2.5 flex items-center justify-between">
                                    <span className="text-apple-subtext font-medium">Sesi Terhubung</span>
                                    <span className="font-mono font-bold text-emerald-700">
                                      {activeSession.uptime}
                                    </span>
                                  </div>
                                </>
                              )}
                              {activeSecret.comment && (
                                <div className="py-2.5 flex items-start justify-between gap-4 last:pb-0">
                                  <span className="text-apple-subtext font-medium shrink-0">Catatan</span>
                                  <span className="text-apple-text text-right font-medium">
                                    {activeSecret.comment}
                                  </span>
                                </div>
                              )}
                            </div>

                            {/* Action Buttons in Modal */}
                            <div className="pt-2 flex flex-col gap-2 pb-[calc(1.25rem+env(safe-area-inset-bottom,0px))] sm:pb-0">
                              {/* Baris 1: Tombol Isolir & Extend */}
                              <div className="flex items-center gap-2">
                                <button
                                  type="button"
                                  onClick={() => handleToggleIsolir(activeSecret.id)}
                                  className={`flex-1 py-2.5 px-3 rounded-2xl text-xs font-semibold flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px] truncate ${
                                    activeSecret.disabled
                                      ? 'bg-emerald-600 text-white shadow-xs hover:bg-emerald-700'
                                      : 'bg-rose-600 text-white shadow-xs hover:bg-rose-700'
                                  }`}
                                >
                                  {activeSecret.disabled ? (
                                    <>
                                      <Unlock className="h-3.5 w-3.5 shrink-0" />
                                      <span className="truncate">Buka Isolir</span>
                                    </>
                                  ) : (
                                    <>
                                      <Ban className="h-3.5 w-3.5 shrink-0" />
                                      <span className="truncate">Isolir</span>
                                    </>
                                  )}
                                </button>

                                <button
                                  type="button"
                                  onClick={() => handleExtendSecret(activeSecret.id)}
                                  className="flex-1 py-2.5 px-3 rounded-2xl text-xs font-semibold bg-amber-500 text-white shadow-xs hover:bg-amber-600 flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px] truncate"
                                >
                                  <CalendarPlus className="h-3.5 w-3.5 shrink-0" />
                                  <span className="truncate">Extend (+30 Hari)</span>
                                </button>
                              </div>

                              {/* Baris 2: Tombol Hapus di kiri, Simpan di kanan */}
                              <div className="flex items-center gap-2">
                                {/* Hold-to-delete Button (Tahan 0.5s) di KIRI */}
                                <div className="relative flex-1 select-none">
                                  <button
                                    type="button"
                                    onMouseDown={() => startDeleteHold(activeSecret.id, activeSecret.name)}
                                    onMouseUp={cancelDeleteHold}
                                    onMouseLeave={cancelDeleteHold}
                                    onTouchStart={() => startDeleteHold(activeSecret.id, activeSecret.name)}
                                    onTouchEnd={cancelDeleteHold}
                                    onTouchCancel={cancelDeleteHold}
                                    onContextMenu={(e) => e.preventDefault()}
                                    className="w-full relative overflow-hidden py-2.5 px-3.5 rounded-2xl text-xs font-semibold bg-rose-500/10 text-rose-600 hover:bg-rose-500/15 border border-rose-500/20 flex items-center justify-center gap-1.5 active:scale-95 transition-all min-h-[48px]"
                                    title="Tahan 0.5 detik untuk menghapus pelanggan"
                                  >
                                    {/* Fill Progress Bar during 0.5s hold */}
                                    {deleteHoldProgress > 0 && (
                                      <div
                                        className="absolute inset-0 bg-rose-600 transition-all duration-75 pointer-events-none"
                                        style={{ width: `${deleteHoldProgress}%` }}
                                      />
                                    )}
                                    <Trash2
                                      className={`h-4 w-4 shrink-0 relative z-10 ${
                                        deleteHoldProgress > 30 ? 'text-white' : 'text-rose-600'
                                      }`}
                                    />
                                    <span
                                      className={`relative z-10 ${
                                        deleteHoldProgress > 30 ? 'text-white' : 'text-rose-600'
                                      }`}
                                    >
                                      {deleteHoldProgress > 0 ? 'Tahan...' : 'Hapus'}
                                    </span>
                                  </button>
                                </div>

                                {/* Tombol Simpan di KANAN */}
                                <button
                                  type="button"
                                  onClick={() => {
                                    if (editingExpiryDate) {
                                      handleUpdateExpiryDate(activeSecret.id, editingExpiryDate);
                                    }
                                    if (editingProfile) {
                                      handleUpdateProfile(activeSecret.id, editingProfile);
                                    }
                                    setSelectedSecretId(null);
                                  }}
                                  className="flex-1 py-2.5 px-4 rounded-2xl text-xs font-semibold bg-apple-blue text-white shadow-xs hover:bg-apple-blueHover flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px]"
                                >
                                  <Check className="h-4 w-4 stroke-[2.5]" />
                                  <span>Simpan</span>
                                </button>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })()}

              {/* MODAL TAMBAH USER PPPOE BARU (APPLE iOS HIG STYLE) */}
              {isAddUserModalOpen && (
                <div
                  className="relative z-50"
                  aria-labelledby="add-user-modal-title"
                  role="dialog"
                  aria-modal="true"
                >
                  <div
                    className="fixed inset-0 bg-black/40 backdrop-blur-sm transition-opacity"
                    onClick={() => setIsAddUserModalOpen(false)}
                  />

                  <div
                    className="fixed inset-0 z-50 w-screen overflow-y-auto"
                    onClick={() => setIsAddUserModalOpen(false)}
                  >
                    <div className="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4">
                      <div
                        className="relative transform overflow-hidden rounded-t-[32px] sm:rounded-3xl bg-apple-card text-left shadow-[0_-10px_40px_rgba(0,0,0,0.14)] sm:shadow-ios-modal transition-all my-0 sm:my-auto w-full max-w-lg border-t sm:border border-black/[0.08] max-h-[92vh] sm:max-h-[85vh] flex flex-col animate-in slide-in-from-bottom duration-300 ease-out sm:zoom-in-95"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {/* iOS Drawer Grabber Handle */}
                        <div className="w-full pt-3 pb-1 flex justify-center sm:hidden bg-[#fbfbfd] shrink-0">
                          <div className="w-10 h-1.5 rounded-full bg-black/20" />
                        </div>

                        {/* Header Modal */}
                        <div className="px-5 pt-2 pb-3.5 sm:px-6 sm:pt-5 sm:pb-4 border-b border-black/[0.06] flex items-center justify-between bg-[#fbfbfd] shrink-0">
                          <div className="flex items-center gap-3">
                            <div className="h-10 w-10 rounded-2xl bg-apple-blue/10 text-apple-blue flex items-center justify-center font-bold shrink-0">
                              <Plus className="h-5 w-5 stroke-[2.2]" />
                            </div>
                            <div>
                              <h3
                                className="text-base font-bold text-apple-text tracking-tight"
                                id="add-user-modal-title"
                              >
                                Tambah User PPPoE
                              </h3>
                              <p className="text-xs text-apple-subtext font-medium">
                                Buat secret dan paket langganan baru di MikroTik
                              </p>
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => setIsAddUserModalOpen(false)}
                            className="text-apple-subtext hover:text-apple-text rounded-full p-2 bg-black/[0.04] hover:bg-black/[0.08] transition-all min-h-[36px] min-w-[36px] flex items-center justify-center"
                            title="Tutup modal"
                            aria-label="Tutup modal"
                          >
                            <X className="h-4 w-4" />
                          </button>
                        </div>

                        {/* Form Body */}
                        <form onSubmit={handleCreateNewUser} className="p-5 sm:p-6 space-y-4 overflow-y-auto overscroll-contain flex-1">
                          <div>
                            <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                              Username PPPoE <span className="text-rose-500">*</span>
                            </label>
                            <input
                              type="text"
                              required
                              value={newUserName}
                              onChange={(e) => setNewUserName(e.target.value)}
                              placeholder="misal: pelanggan01"
                              className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                            />
                          </div>

                          <div>
                            <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                              Password PPPoE
                            </label>
                            <div className="relative">
                              <input
                                type={showNewUserPass ? 'text' : 'password'}
                                value={newUserPass}
                                onChange={(e) => setNewUserPass(e.target.value)}
                                placeholder="misal: 123456 (opsional)"
                                className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-12 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                              />
                              <button
                                type="button"
                                onClick={() => setShowNewUserPass(!showNewUserPass)}
                                className="absolute right-1 top-1/2 -translate-y-1/2 text-apple-subtext hover:text-apple-blue p-2 rounded-xl transition-all min-h-[44px] min-w-[44px] flex items-center justify-center active:scale-90"
                                title={showNewUserPass ? 'Sembunyikan password' : 'Lihat password'}
                                aria-label={showNewUserPass ? 'Sembunyikan password' : 'Lihat password'}
                              >
                                {showNewUserPass ? (
                                  <EyeOff className="h-4 w-4 stroke-[2.2]" />
                                ) : (
                                  <Eye className="h-4 w-4 stroke-[2.2]" />
                                )}
                              </button>
                            </div>
                          </div>

                          <div>
                            <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                              Paket Bandwidth (Profile)
                            </label>
                            <div className="relative">
                              <select
                                value={newUserProfile}
                                onChange={(e) => setNewUserProfile(e.target.value)}
                                className="w-full min-h-[48px] appearance-none rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-10 py-2.5 text-sm font-mono text-apple-text focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                              >
                                {demoProfiles.length === 0 ? (
                                  <option value="default">default</option>
                                ) : (
                                  demoProfiles.map((p) => (
                                    <option key={p.id} value={p.name}>
                                      {p.name} {p.rateLimit !== '-' ? `(${p.rateLimit})` : ''}
                                    </option>
                                  ))
                                )}
                              </select>
                              <ChevronDown className="h-4 w-4 text-apple-subtext absolute right-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                            </div>
                          </div>

                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <div>
                              <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                Jatuh Tempo
                              </label>
                              <input
                                type="date"
                                value={newUserExpiry}
                                onChange={(e) => setNewUserExpiry(e.target.value)}
                                className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                              />
                            </div>

                            <div>
                              <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                Catatan / Nama Pelanggan
                              </label>
                              <input
                                type="text"
                                value={newUserComment}
                                onChange={(e) => setNewUserComment(e.target.value)}
                                placeholder="misal: Bpk Ahmad - Blok A2"
                                className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                              />
                            </div>
                          </div>

                          <div className="pt-2 flex items-center justify-end gap-2 pb-[calc(1.25rem+env(safe-area-inset-bottom,0px))] sm:pb-0">
                            <button
                              type="button"
                              onClick={() => setIsAddUserModalOpen(false)}
                              className="py-2.5 px-4 rounded-2xl text-xs font-semibold text-apple-subtext hover:text-apple-text hover:bg-black/[0.04] transition-all min-h-[48px]"
                            >
                              Batal
                            </button>
                            <button
                              type="submit"
                              className="py-2.5 px-6 rounded-2xl text-xs font-semibold bg-apple-blue text-white shadow-xs hover:bg-apple-blueHover flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px]"
                            >
                              <Plus className="h-4 w-4 stroke-[2.5]" />
                              <span>Simpan User</span>
                            </button>
                          </div>
                        </form>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* MODAL TAMBAH & EDIT PROFIL PPPOE (APPLE iOS HIG STYLE) */}
              {isProfileModalOpen && (
                <div
                  className="relative z-50"
                  aria-labelledby="profile-modal-title"
                  role="dialog"
                  aria-modal="true"
                >
                  <div
                    className="fixed inset-0 bg-black/40 backdrop-blur-sm transition-opacity"
                    onClick={() => setIsProfileModalOpen(false)}
                  />

                  <div
                    className="fixed inset-0 z-50 w-screen overflow-y-auto"
                    onClick={() => setIsProfileModalOpen(false)}
                  >
                    <div className="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4">
                      <div
                        className="relative transform overflow-hidden rounded-t-[32px] sm:rounded-3xl bg-apple-card text-left shadow-[0_-10px_40px_rgba(0,0,0,0.14)] sm:shadow-ios-modal transition-all my-0 sm:my-auto w-full max-w-lg border-t sm:border border-black/[0.08] max-h-[92vh] sm:max-h-[85vh] flex flex-col animate-in slide-in-from-bottom duration-300 ease-out sm:zoom-in-95"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {/* iOS Drawer Grabber Handle */}
                        <div className="w-full pt-3 pb-1 flex justify-center sm:hidden bg-[#fbfbfd] shrink-0">
                          <div className="w-10 h-1.5 rounded-full bg-black/20" />
                        </div>

                        {/* Header Modal */}
                        <div className="px-5 pt-2 pb-3.5 sm:px-6 sm:pt-5 sm:pb-4 border-b border-black/[0.06] flex items-center justify-between bg-[#fbfbfd] shrink-0">
                          <div className="flex items-center gap-3">
                            <div className="h-10 w-10 rounded-2xl bg-apple-blue/10 text-apple-blue flex items-center justify-center font-bold shrink-0">
                              {editingProfileId ? (
                                <Pencil className="h-5 w-5 stroke-[2.2]" />
                              ) : (
                                <Plus className="h-5 w-5 stroke-[2.2]" />
                              )}
                            </div>
                            <div>
                              <h3
                                className="text-base font-bold text-apple-text tracking-tight"
                                id="profile-modal-title"
                              >
                                {editingProfileId ? 'Edit Profil PPPoE' : 'Tambah Profil PPPoE'}
                              </h3>
                              <p className="text-xs text-apple-subtext font-medium">
                                {editingProfileId
                                  ? 'Ubah konfigurasi limit bandwidth & IP pool di MikroTik'
                                  : 'Buat paket bandwidth baru di MikroTik'}
                              </p>
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => setIsProfileModalOpen(false)}
                            className="text-apple-subtext hover:text-apple-text rounded-full p-2 bg-black/[0.04] hover:bg-black/[0.08] transition-all min-h-[36px] min-w-[36px] flex items-center justify-center"
                            title="Tutup modal"
                            aria-label="Tutup modal"
                          >
                            <X className="h-4 w-4" />
                          </button>
                        </div>

                        {/* Form Body */}
                        <form onSubmit={handleSaveProfile} className="p-5 sm:p-6 space-y-4 overflow-y-auto overscroll-contain flex-1">
                          <div>
                            <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                              Nama Profil <span className="text-rose-500">*</span>
                            </label>
                            <input
                              type="text"
                              required
                              value={profileFormName}
                              onChange={(e) => setProfileFormName(e.target.value)}
                              placeholder="misal: 10Mbps_Home"
                              className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                            />
                          </div>

                          <div>
                            <div className="flex items-center justify-between mb-1.5">
                              <label className="block text-xs font-bold text-apple-subtext uppercase tracking-wider">
                                Rate Limit (Rx / Tx)
                              </label>
                              <span className="text-[10px] text-apple-subtext font-medium">
                                Upload / Download
                              </span>
                            </div>
                            <input
                              type="text"
                              value={profileFormRateLimit}
                              onChange={(e) => setProfileFormRateLimit(e.target.value)}
                              placeholder="misal: 10M/10M atau 5M/10M"
                              className="w-full min-h-[44px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                            />
                            {/* Quick preset chips */}
                            <div className="flex flex-wrap items-center gap-1.5 mt-2">
                              <span className="text-[10px] text-apple-subtext font-medium mr-1">Preset:</span>
                              {['5M/5M', '10M/10M', '20M/20M', '30M/30M', '50M/50M', '100M/100M'].map((preset) => (
                                <button
                                  key={preset}
                                  type="button"
                                  onClick={() => setProfileFormRateLimit(preset)}
                                  className={`text-[11px] font-mono font-semibold px-2 py-0.5 rounded-lg border transition-all ${
                                    profileFormRateLimit === preset
                                      ? 'bg-apple-blue text-white border-apple-blue'
                                      : 'bg-black/[0.04] text-apple-subtext border-black/[0.06] hover:bg-black/[0.08] hover:text-apple-text'
                                  }`}
                                >
                                  {preset}
                                </button>
                              ))}
                            </div>
                          </div>

                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <div>
                              <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                Local Address (Gateway)
                              </label>
                              <input
                                type="text"
                                value={profileFormLocalAddress}
                                onChange={(e) => setProfileFormLocalAddress(e.target.value)}
                                placeholder="misal: 192.168.10.1"
                                className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                              />
                            </div>

                            <div>
                              <div className="flex items-center justify-between mb-1.5">
                                <label className="block text-xs font-bold text-apple-subtext uppercase tracking-wider">
                                  Remote Address / Pool
                                </label>
                                <button
                                  type="button"
                                  onClick={() => setIsManualPool(!isManualPool)}
                                  className="text-[11px] font-medium text-apple-blue hover:underline"
                                >
                                  {isManualPool ? 'Pilih dari Pool' : 'Ketik Manual'}
                                </button>
                              </div>

                              {isManualPool ? (
                                <input
                                  type="text"
                                  value={profileFormRemotePool}
                                  onChange={(e) => setProfileFormRemotePool(e.target.value)}
                                  placeholder="misal: pool-pppoe atau 192.168.10.2"
                                  className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                />
                              ) : (
                                <div className="relative">
                                  <select
                                    value={profileFormRemotePool}
                                    onChange={(e) => {
                                      if (e.target.value === '__custom__') {
                                        setIsManualPool(true);
                                      } else {
                                        setProfileFormRemotePool(e.target.value);
                                      }
                                    }}
                                    className="w-full min-h-[48px] appearance-none rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-10 py-2.5 text-sm font-mono text-apple-text focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                  >
                                    <option value="">-- Pilih Pool IP --</option>
                                    {poolOptions.map((pool) => (
                                      <option key={pool.name} value={pool.name}>
                                        {pool.name} {pool.ranges ? `(${pool.ranges})` : ''}
                                      </option>
                                    ))}
                                    <option value="__custom__">+ Ketik Manual / IP Kustom...</option>
                                  </select>
                                  <ChevronDown className="h-4 w-4 text-apple-subtext absolute right-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                                </div>
                              )}
                            </div>
                          </div>

                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <div>
                              <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                Only One (1 Sesi / User)
                              </label>
                              <div className="relative">
                                <select
                                  value={profileFormOnlyOne}
                                  onChange={(e) => setProfileFormOnlyOne(e.target.value)}
                                  className="w-full min-h-[48px] appearance-none rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-10 py-2.5 text-sm font-mono text-apple-text focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                >
                                  <option value="default">default</option>
                                  <option value="yes">yes (hanya 1 login)</option>
                                  <option value="no">no (multi login)</option>
                                </select>
                                <ChevronDown className="h-4 w-4 text-apple-subtext absolute right-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                              </div>
                            </div>

                            <div>
                              <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                DNS Server
                              </label>
                              <input
                                type="text"
                                value={profileFormDnsServer}
                                onChange={(e) => setProfileFormDnsServer(e.target.value)}
                                placeholder="misal: 8.8.8.8,1.1.1.1"
                                className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                              />
                            </div>
                          </div>

                          <div>
                            <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                              Catatan / Keterangan
                            </label>
                            <input
                              type="text"
                              value={profileFormComment}
                              onChange={(e) => setProfileFormComment(e.target.value)}
                              placeholder="misal: Paket Rumah Tangga FNet Unlimited"
                              className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                            />
                          </div>

                          <div className="pt-3 border-t border-black/[0.06] flex items-center justify-between gap-2">
                            {editingProfileId ? (
                              <div className="relative shrink-0 select-none">
                                <button
                                  type="button"
                                  onMouseDown={startProfileDeleteHold}
                                  onMouseUp={cancelProfileDeleteHold}
                                  onMouseLeave={cancelProfileDeleteHold}
                                  onTouchStart={startProfileDeleteHold}
                                  onTouchEnd={cancelProfileDeleteHold}
                                  onTouchCancel={cancelProfileDeleteHold}
                                  onContextMenu={(e) => e.preventDefault()}
                                  className="relative overflow-hidden py-2.5 px-3.5 rounded-2xl text-xs font-semibold bg-rose-500/10 text-rose-600 hover:bg-rose-500/15 border border-rose-500/20 flex items-center justify-center gap-1.5 active:scale-95 transition-all min-h-[48px]"
                                  title="Tahan 0.5 detik untuk menghapus profil"
                                >
                                  {/* Fill Progress Bar during 0.5s hold */}
                                  {profileDeleteHoldProgress > 0 && (
                                    <div
                                      className="absolute inset-0 bg-rose-600 transition-all duration-75 pointer-events-none"
                                      style={{ width: `${profileDeleteHoldProgress}%` }}
                                    />
                                  )}
                                  <Trash2
                                    className={`h-4 w-4 shrink-0 relative z-10 ${
                                      profileDeleteHoldProgress > 30 ? 'text-white' : 'text-rose-600'
                                    }`}
                                  />
                                  <span
                                    className={`relative z-10 ${
                                      profileDeleteHoldProgress > 30 ? 'text-white' : 'text-rose-600'
                                    }`}
                                  >
                                    {profileDeleteHoldProgress > 0 ? 'Tahan...' : 'Hapus'}
                                  </span>
                                </button>
                              </div>
                            ) : (
                              <div />
                            )}

                            <div className="flex items-center gap-2">
                              <button
                                type="button"
                                onClick={() => setIsProfileModalOpen(false)}
                                className="py-2.5 px-4 rounded-2xl text-xs font-semibold text-apple-subtext hover:text-apple-text hover:bg-black/[0.04] transition-all min-h-[48px]"
                              >
                                Batal
                              </button>
                              <button
                                type="submit"
                                disabled={isSavingProfile}
                                className="py-2.5 px-5 rounded-2xl text-xs font-semibold bg-apple-blue text-white shadow-xs hover:bg-apple-blueHover flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px] disabled:opacity-50"
                              >
                                {isSavingProfile ? (
                                  <span>Menyimpan...</span>
                                ) : editingProfileId ? (
                                  <>
                                    <Check className="h-4 w-4 stroke-[2.5]" />
                                    <span>Simpan</span>
                                  </>
                                ) : (
                                  <>
                                    <Plus className="h-4 w-4 stroke-[2.5]" />
                                    <span>Simpan</span>
                                  </>
                                )}
                              </button>
                            </div>
                          </div>
                        </form>
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </motion.div>
          ) : activeTab === 'hotspot' ? (
            /* ============================================================= */
            /* HALAMAN HOTSPOT: APPLE SEGMENTED CONTROL [ USER | ACTIVE | PROFILE ] */
            /* ============================================================= */
            (() => {
              const filteredUsers = hotspotUsers.filter((u) => {
                if (isHiddenDefaultUser(u.name)) return false;
                const q = hotspotUserSearch.toLowerCase().trim();
                const matchSearch =
                  !q ||
                  u.name.toLowerCase().includes(q) ||
                  (u.profile || '').toLowerCase().includes(q) ||
                  (u.comment || '').toLowerCase().includes(q);

                if (!matchSearch) return false;

                const userProf = hotspotProfiles.find((p) => p.name === u.profile);
                const isOnline = hotspotActive.some((a) => a.user.toLowerCase() === u.name.toLowerCase());
                const expiryInfo = calculateHotspotUserExpiry(u, userProf, new Date(), isOnline);

                if (hotspotUserFilter === 'used') {
                  return expiryInfo.isUsed && u.disabled !== true && u.disabled !== 'true';
                }
                if (hotspotUserFilter === 'unused') {
                  return !expiryInfo.isUsed && u.disabled !== true && u.disabled !== 'true';
                }
                if (hotspotUserFilter === 'expiring-soon') {
                  return expiryInfo.status === 'expiring-soon';
                }
                if (hotspotUserFilter === 'expired') {
                  return expiryInfo.status === 'expired';
                }
                if (hotspotUserFilter === 'disabled') {
                  return u.disabled === true || u.disabled === 'true';
                }
                return true;
              });

              const filteredActive = hotspotActive.filter((a) => {
                const q = hotspotActiveSearch.toLowerCase().trim();
                if (!q) return true;
                return (
                  a.user.toLowerCase().includes(q) ||
                  a.address.toLowerCase().includes(q) ||
                  a['mac-address'].toLowerCase().includes(q) ||
                  (a.server || '').toLowerCase().includes(q)
                );
              });

              const filteredProfiles = hotspotProfiles.filter((p) => {
                if (isHiddenDefaultProfile(p.name)) return false;
                const q = hotspotProfileSearch.toLowerCase().trim();
                if (!q) return true;
                return (
                  p.name.toLowerCase().includes(q) ||
                  (p['rate-limit'] || '').toLowerCase().includes(q) ||
                  (p['address-pool'] || '').toLowerCase().includes(q)
                );
              });

              return (
                <motion.div
                  key="tab-hotspot"
                  variants={pageVariants}
                  initial="initial"
                  animate="animate"
                  exit="exit"
                  className="space-y-2.5 sm:space-y-3.5 w-full max-w-2xl mx-auto"
                >
                  {/* STICKY TOP CONTROLS: Segmented Control + Search & Filter Bar */}
                  <div className="sticky top-0 z-20 bg-apple-bg pt-0.5 pb-1 space-y-1.5">
                    {/* Apple Segmented Control Bar */}
                    <div
                      role="tablist"
                      aria-label="Hotspot Sub-Navigation"
                      className="bg-[#747480]/[0.10] p-[3px] rounded-[13px] sm:rounded-[14px] flex items-center border border-black/[0.04] shadow-[inset_0_1px_2px_rgba(0,0,0,0.04)]"
                    >
                      {[
                        {
                          id: 'user' as const,
                          label: 'User',
                          icon: Users,
                          count: hotspotUsers.filter((u) => !isHiddenDefaultUser(u.name)).length,
                        },
                        {
                          id: 'profile' as const,
                          label: 'Profile',
                          icon: Zap,
                          count: hotspotProfiles.filter((p) => !isHiddenDefaultProfile(p.name)).length,
                        },
                        { id: 'active' as const, label: 'Active', icon: Activity, count: hotspotActive.length },
                      ].map((tab, idx, arr) => {
                        const isSelected = hotspotSubTab === tab.id;
                        const prevSelected = idx > 0 && hotspotSubTab === arr[idx - 1].id;
                        const showDivider = idx > 0 && !isSelected && !prevSelected;
                        const IconComponent = tab.icon;

                        return (
                          <React.Fragment key={tab.id}>
                            {showDivider && (
                              <div className="w-[1px] h-3.5 bg-black/[0.12] shrink-0" aria-hidden="true" />
                            )}
                            <button
                              type="button"
                              role="tab"
                              aria-selected={isSelected}
                              onClick={() => {
                                setHotspotSubTab(tab.id);
                                setHotspotUserFilterOpen(false);
                              }}
                              className={`relative flex-1 py-1.5 px-1.5 text-xs font-semibold rounded-[10px] sm:rounded-[11px] active:scale-[0.98] transition-transform flex items-center justify-center gap-1.5 min-h-[40px] select-none ${
                                isSelected
                                  ? 'text-apple-text'
                                  : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.02]'
                              }`}
                            >
                              {isSelected && (
                                <motion.div
                                  layoutId="hotspotSubTabActivePill"
                                  className="absolute inset-0 bg-white rounded-[10px] sm:rounded-[11px] shadow-[0_1px_3px_rgba(0,0,0,0.10),0_1px_2px_rgba(0,0,0,0.06)] z-0"
                                  transition={figmaSpring.quick}
                                />
                              )}
                              <IconComponent
                                className={`h-3.5 w-3.5 stroke-[2.2] relative z-10 ${
                                  isSelected ? 'text-apple-blue' : 'text-apple-subtext'
                                }`}
                              />
                              <span className="tracking-tight relative z-10">{tab.label}</span>
                              <span
                                className={`text-[10px] px-1.5 py-0.5 rounded-md font-mono relative z-10 ${
                                  isSelected
                                    ? 'bg-apple-blue/10 text-apple-blue font-bold'
                                    : 'bg-black/[0.05] text-apple-subtext font-medium'
                                }`}
                              >
                                {tab.count}
                              </span>
                              {tab.id === 'active' && isSelected && (
                                <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse -ml-0.5 relative z-10" />
                              )}
                            </button>
                          </React.Fragment>
                        );
                      })}
                    </div>

                    {/* Sub-tab 1: USER Search & Embedded Filter Menu + Add User Button */}
                    {hotspotSubTab === 'user' && (
                      <div className="relative">
                        <div className="flex items-center gap-2">
                          <div className="relative flex-1">
                            <Search className="h-4 w-4 text-[#8e8e93] absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                            <input
                              type="text"
                              value={hotspotUserSearch}
                              onChange={(e) => setHotspotUserSearch(e.target.value)}
                              placeholder="Cari user, voucher, profile, komentar..."
                              className="w-full pl-10 pr-20 py-2.5 rounded-2xl bg-white border border-black/[0.06] shadow-xs text-xs sm:text-sm font-mono placeholder:font-sans placeholder:text-apple-subtext focus:outline-none focus:ring-2 focus:ring-apple-blue/30 focus:bg-white transition-all min-h-[48px]"
                            />
                            <div className="absolute right-1.5 top-1/2 -translate-y-1/2 flex items-center gap-1">
                              {hotspotUserSearch && (
                                <button
                                  type="button"
                                  onClick={() => setHotspotUserSearch('')}
                                  className="h-7 w-7 min-h-[36px] min-w-[36px] rounded-full bg-black/[0.08] hover:bg-black/[0.14] text-apple-subtext hover:text-apple-text flex items-center justify-center transition-all"
                                  title="Hapus pencarian"
                                  aria-label="Hapus pencarian"
                                >
                                  <X className="h-3.5 w-3.5 stroke-[2.5]" />
                                </button>
                              )}
                              <button
                                type="button"
                                onClick={() => setHotspotUserFilterOpen(!hotspotUserFilterOpen)}
                                className={`min-h-[38px] px-2.5 rounded-xl flex items-center gap-1 transition-all ${
                                  hotspotUserFilter !== 'all'
                                    ? 'bg-apple-blue text-white shadow-xs font-semibold'
                                    : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.04]'
                                }`}
                                title="Opsi Filter User Hotspot"
                                aria-label="Opsi Filter User Hotspot"
                              >
                                <ListFilter className="h-3.5 w-3.5 stroke-[2.2]" />
                                {hotspotUserFilter !== 'all' && (
                                  <span className="text-[10px] capitalize max-w-[65px] truncate">
                                    {hotspotUserFilter === 'used'
                                      ? 'Terpakai'
                                      : hotspotUserFilter === 'unused'
                                      ? 'Belum Pakai'
                                      : hotspotUserFilter === 'expiring-soon'
                                      ? 'Segera Habis'
                                      : hotspotUserFilter === 'expired'
                                      ? 'Habis'
                                      : 'Nonaktif'}
                                  </span>
                                )}
                              </button>
                            </div>
                          </div>

                          <button
                            type="button"
                            onClick={() => {
                              const firstProf = hotspotProfiles.find((p) => !isHiddenDefaultProfile(p.name))?.name || 'default';
                              setNewHotspotUserProfile(firstProf);
                              setIsAddHotspotUserModalOpen(true);
                            }}
                            className="min-h-[48px] px-3.5 sm:px-4 rounded-2xl bg-apple-blue text-white shadow-xs hover:bg-apple-blueHover active:scale-95 transition-all flex items-center justify-center gap-1.5 text-xs font-semibold shrink-0"
                            title="Tambah User / Voucher Hotspot"
                            aria-label="Tambah User / Voucher Hotspot"
                          >
                            <Plus className="h-4 w-4 stroke-[2.5]" />
                            <span className="hidden xs:inline">Tambah User</span>
                          </button>
                        </div>

                        {hotspotUserFilterOpen && (
                          <>
                            <div
                              className="fixed inset-0 z-30"
                              onClick={() => setHotspotUserFilterOpen(false)}
                            />
                            <div className="absolute right-0 top-full mt-2 z-40 w-56 rounded-2xl bg-white border border-black/[0.08] shadow-[0_12px_36px_rgba(0,0,0,0.12),0_4px_12px_rgba(0,0,0,0.06)] p-1.5">
                              <div className="px-3 pt-2 pb-1 text-[10px] font-bold text-apple-subtext uppercase tracking-wider">
                                Filter Status Hotspot
                              </div>
                              <div className="space-y-0.5">
                                {(() => {
                                  const activeUsers = hotspotUsers.filter((u) => !isHiddenDefaultUser(u.name));
                                  const filterOptions = [
                                    {
                                      key: 'all' as const,
                                      label: 'Semua Status',
                                      count: activeUsers.length,
                                    },
                                    {
                                      key: 'used' as const,
                                      label: 'Terpakai (Aktif)',
                                      count: activeUsers.filter((u) => {
                                        if (u.disabled === true || u.disabled === 'true') return false;
                                        const p = hotspotProfiles.find((pr) => pr.name === u.profile);
                                        const onl = hotspotActive.some((a) => a.user.toLowerCase() === u.name.toLowerCase());
                                        return calculateHotspotUserExpiry(u, p, new Date(), onl).isUsed;
                                      }).length,
                                    },
                                    {
                                      key: 'unused' as const,
                                      label: 'Belum Dipakai (Baru)',
                                      count: activeUsers.filter((u) => {
                                        if (u.disabled === true || u.disabled === 'true') return false;
                                        const p = hotspotProfiles.find((pr) => pr.name === u.profile);
                                        const onl = hotspotActive.some((a) => a.user.toLowerCase() === u.name.toLowerCase());
                                        return !calculateHotspotUserExpiry(u, p, new Date(), onl).isUsed;
                                      }).length,
                                    },
                                    {
                                      key: 'expiring-soon' as const,
                                      label: 'Segera Habis (≤24j)',
                                      count: activeUsers.filter((u) => {
                                        const p = hotspotProfiles.find((pr) => pr.name === u.profile);
                                        const onl = hotspotActive.some((a) => a.user.toLowerCase() === u.name.toLowerCase());
                                        return calculateHotspotUserExpiry(u, p, new Date(), onl).status === 'expiring-soon';
                                      }).length,
                                    },
                                    {
                                      key: 'expired' as const,
                                      label: 'Habis (Kadaluarsa)',
                                      count: activeUsers.filter((u) => {
                                        const p = hotspotProfiles.find((pr) => pr.name === u.profile);
                                        const onl = hotspotActive.some((a) => a.user.toLowerCase() === u.name.toLowerCase());
                                        return calculateHotspotUserExpiry(u, p, new Date(), onl).status === 'expired';
                                      }).length,
                                    },
                                    {
                                      key: 'disabled' as const,
                                      label: 'Nonaktif',
                                      count: activeUsers.filter(
                                        (u) => u.disabled === true || u.disabled === 'true'
                                      ).length,
                                    },
                                  ];

                                  return filterOptions.map((opt) => {
                                    const isSel = hotspotUserFilter === opt.key;
                                    return (
                                      <button
                                        key={opt.key}
                                        type="button"
                                        onClick={() => {
                                          setHotspotUserFilter(opt.key);
                                          setHotspotUserFilterOpen(false);
                                        }}
                                        className={`w-full flex items-center justify-between px-2.5 py-1.5 text-xs rounded-xl select-none ${
                                          isSel
                                            ? 'bg-apple-blue/10 text-apple-blue font-semibold'
                                            : 'text-apple-text hover:bg-black/[0.04] font-normal'
                                        }`}
                                      >
                                        <span className="font-medium">{opt.label}</span>
                                        <span className="text-[10px] font-mono text-apple-subtext">({opt.count})</span>
                                      </button>
                                    );
                                  });
                                })()}
                              </div>
                            </div>
                          </>
                        )}
                      </div>
                    )}

                    {/* Sub-tab 2: ACTIVE Search */}
                    {hotspotSubTab === 'active' && (
                      <div className="relative">
                        <Search className="h-4 w-4 text-[#8e8e93] absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                        <input
                          type="text"
                          value={hotspotActiveSearch}
                          onChange={(e) => setHotspotActiveSearch(e.target.value)}
                          placeholder="Cari user, IP, MAC address, server..."
                          className="w-full pl-10 pr-10 py-2.5 rounded-2xl bg-white border border-black/[0.06] shadow-xs text-xs sm:text-sm font-mono placeholder:font-sans placeholder:text-apple-subtext focus:outline-none focus:ring-2 focus:ring-apple-blue/30 focus:bg-white transition-all min-h-[48px]"
                        />
                        {hotspotActiveSearch && (
                          <button
                            type="button"
                            onClick={() => setHotspotActiveSearch('')}
                            className="absolute right-2 top-1/2 -translate-y-1/2 h-7 w-7 min-h-[36px] min-w-[36px] rounded-full bg-black/[0.08] hover:bg-black/[0.14] text-apple-subtext hover:text-apple-text flex items-center justify-center transition-all"
                            title="Hapus pencarian"
                            aria-label="Hapus pencarian"
                          >
                            <X className="h-3.5 w-3.5 stroke-[2.5]" />
                          </button>
                        )}
                      </div>
                    )}

                    {/* Sub-tab 3: PROFILE Search & Add Profile Button */}
                    {hotspotSubTab === 'profile' && (
                      <div className="flex items-center gap-2">
                        <div className="relative flex-1">
                          <Search className="h-4 w-4 text-[#8e8e93] absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                          <input
                            type="text"
                            value={hotspotProfileSearch}
                            onChange={(e) => setHotspotProfileSearch(e.target.value)}
                            placeholder="Cari profil hotspot, rate limit, pool..."
                            className="w-full pl-10 pr-10 py-2.5 rounded-2xl bg-white border border-black/[0.06] shadow-xs text-xs sm:text-sm font-mono placeholder:font-sans placeholder:text-apple-subtext focus:outline-none focus:ring-2 focus:ring-apple-blue/30 focus:bg-white transition-all min-h-[48px]"
                          />
                          {hotspotProfileSearch && (
                            <button
                              type="button"
                              onClick={() => setHotspotProfileSearch('')}
                              className="absolute right-2 top-1/2 -translate-y-1/2 h-7 w-7 min-h-[36px] min-w-[36px] rounded-full bg-black/[0.08] hover:bg-black/[0.14] text-apple-subtext hover:text-apple-text flex items-center justify-center transition-all"
                              title="Hapus pencarian"
                              aria-label="Hapus pencarian"
                            >
                              <X className="h-3.5 w-3.5 stroke-[2.5]" />
                            </button>
                          )}
                        </div>

                        {/* Tombol Add Profile Hotspot Baru */}
                        <button
                          type="button"
                          onClick={handleOpenAddHotspotProfile}
                          className="min-h-[48px] px-3.5 sm:px-4 rounded-2xl bg-apple-blue text-white shadow-xs hover:bg-apple-blueHover active:scale-95 transition-all flex items-center justify-center gap-1.5 text-xs font-semibold shrink-0"
                          title="Tambah Profil Hotspot"
                          aria-label="Tambah Profil Hotspot"
                        >
                          <Plus className="h-4 w-4 stroke-[2.5]" />
                          <span className="hidden xs:inline">Tambah Profil</span>
                        </button>
                      </div>
                    )}
                  </div>

                  {/* SUB-TAB 1 CONTENT: DAFTAR USER / VOUCHER HOTSPOT */}
                  {hotspotSubTab === 'user' && (
                    <section className="bg-white rounded-2xl sm:rounded-3xl border border-black/[0.08] shadow-apple overflow-hidden flex flex-col">
                      <div className="px-4 py-2.5 sm:px-5 sm:py-3 border-b border-black/[0.04] bg-[#fbfbfd] flex items-center justify-between shrink-0">
                        <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider">
                          Daftar User / Voucher Hotspot:
                        </span>
                        <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider font-mono">
                          {filteredUsers.length} User
                        </span>
                      </div>

                      {filteredUsers.length === 0 ? (
                        <div className="flex flex-col items-center justify-center gap-3 px-4 py-16 text-center">
                          <div className="h-12 w-12 rounded-full bg-apple-bg flex items-center justify-center text-apple-subtext">
                            <Ticket className="h-6 w-6 stroke-[1.5]" />
                          </div>
                          <div>
                            <p className="text-sm font-semibold text-apple-text">
                              Tidak Ada User Hotspot
                            </p>
                            <p className="text-xs text-apple-subtext mt-0.5">
                              {hotspotUserSearch || hotspotUserFilter !== 'all'
                                ? 'Tidak ada user hotspot yang cocok dengan pencarian atau filter.'
                                : 'Belum ada user hotspot terdaftar di MikroTik.'}
                            </p>
                          </div>
                        </div>
                      ) : (
                        <div
                          onScroll={(e) => {
                            const el = e.currentTarget;
                            if (el.scrollTop + el.clientHeight >= el.scrollHeight - 80) {
                              if (visibleHotspotUsers < filteredUsers.length) {
                                setVisibleHotspotUsers((prev) => Math.min(prev + 25, filteredUsers.length));
                              }
                            }
                          }}
                          className="divide-y divide-black/[0.04] overflow-y-auto max-h-[515px] sm:max-h-[600px] overscroll-contain pb-2"
                        >
                          {filteredUsers.slice(0, visibleHotspotUsers).map((user) => {
                            const userProf = hotspotProfiles.find((p) => p.name === user.profile);
                            const activeSession = hotspotActive.find(
                              (a) => a.user.toLowerCase() === user.name.toLowerCase()
                            );
                            const isOnline = Boolean(activeSession);
                            const expiryInfo = calculateHotspotUserExpiry(user, userProf, new Date(), isOnline);
                            const userIp = activeSession?.address;
                            const rateLimitOrProfile = userProf?.['rate-limit'] || user.profile || 'Hotspot';

                            return (
                              <div
                                key={user['.id']}
                                onClick={() => handleOpenEditHotspotUser(user)}
                                className="px-4 py-2.5 sm:px-5 sm:py-3 flex items-center justify-between gap-3 bg-white hover:bg-[#fbfbfd] active:bg-black/[0.02] transition-colors cursor-pointer group"
                              >
                                <div className="min-w-0 flex-1">
                                  {/* Top Line: Username, Profile badge, and Status badge */}
                                  <div className="flex items-center gap-2 flex-wrap">
                                    <span className="font-mono font-bold text-sm text-apple-text">
                                      {user.name}
                                    </span>
                                    <span className="text-[10px] font-mono font-semibold px-2 py-0.5 rounded-md bg-black/[0.05] text-apple-subtext">
                                      {user.profile || 'default'}
                                    </span>
                                    {user.disabled === true || user.disabled === 'true' ? (
                                      <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-rose-500/10 text-rose-600">
                                        Nonaktif
                                      </span>
                                    ) : isOnline ? (
                                      <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-emerald-500/10 text-emerald-600 flex items-center gap-1">
                                        <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                                        Online
                                      </span>
                                    ) : expiryInfo.isUsed ? (
                                      <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-sky-500/10 text-sky-700">
                                        Terpakai
                                      </span>
                                    ) : (
                                      <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-black/[0.05] text-apple-subtext">
                                        Belum Dipakai
                                      </span>
                                    )}
                                  </div>

                                  {/* Bottom Line: Exact style matching PPPoE: IP • Rate/Profile • Sisa */}
                                  <div className="flex items-center gap-2 text-xs text-apple-subtext mt-1 flex-wrap">
                                    <span className={`font-mono font-semibold ${isOnline ? 'text-apple-text' : 'text-apple-subtext'}`}>
                                      {isOnline ? userIp : (user.uptime && user.uptime !== '0s') ? user.uptime : 'Offline'}
                                    </span>
                                    <span>•</span>
                                    <span className="font-mono text-apple-subtext">
                                      {rateLimitOrProfile}
                                    </span>
                                    <span>•</span>
                                    {user.disabled === true || user.disabled === 'true' ? (
                                      <span className="font-semibold text-rose-600">
                                        Nonaktif
                                      </span>
                                    ) : (
                                      <span className={`font-semibold ${expiryInfo.colorClass}`}>
                                        {expiryInfo.sisaText}
                                      </span>
                                    )}
                                  </div>
                                </div>

                                <button
                                  type="button"
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    handleOpenEditHotspotUser(user);
                                  }}
                                  className="h-9 w-9 sm:h-8 sm:w-8 min-h-[44px] min-w-[44px] rounded-full flex items-center justify-center text-apple-subtext hover:text-apple-blue hover:bg-apple-blue/10 active:scale-95 transition-all shrink-0"
                                  title="Edit User Hotspot"
                                  aria-label={`Edit ${user.name}`}
                                >
                                  <Pencil className="h-4 w-4" />
                                </button>
                              </div>
                            );
                          })}

                          {filteredUsers.length > visibleHotspotUsers && (
                            <div className="p-3 text-center border-t border-black/[0.04] bg-[#fbfbfd]">
                              <button
                                type="button"
                                onClick={() => setVisibleHotspotUsers((prev) => Math.min(prev + 50, filteredUsers.length))}
                                className="w-full py-2.5 px-4 text-xs font-semibold text-apple-blue bg-apple-blue/10 hover:bg-apple-blue/15 active:scale-[0.98] rounded-xl transition-all min-h-[44px] flex items-center justify-center gap-1.5"
                              >
                                <ChevronDown className="h-4 w-4 stroke-[2.2]" />
                                <span>Muat Lebih Banyak ({filteredUsers.length - visibleHotspotUsers} lagi)</span>
                                <span className="font-mono text-[11px] opacity-70">· Menampilkan {visibleHotspotUsers} dari {filteredUsers.length}</span>
                              </button>
                            </div>
                          )}

                          {visibleHotspotUsers >= filteredUsers.length && filteredUsers.length > 25 && (
                            <div className="py-2.5 px-4 text-center border-t border-black/[0.04] bg-[#fbfbfd]/60 text-[11px] font-mono text-apple-subtext">
                              Semua {filteredUsers.length} user telah dimuat
                            </div>
                          )}
                        </div>
                      )}
                    </section>
                  )}

                  {/* SUB-TAB 2 CONTENT: DAFTAR ACTIVE HOTSPOT */}
                  {hotspotSubTab === 'active' && (
                    <section className="bg-white rounded-2xl sm:rounded-3xl border border-black/[0.08] shadow-apple overflow-hidden flex flex-col">
                      <div className="px-4 py-2.5 sm:px-5 sm:py-3 border-b border-black/[0.04] bg-[#fbfbfd] flex items-center justify-between shrink-0">
                        <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider flex items-center gap-1.5">
                          <span className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
                          Sesi Hotspot Aktif:
                        </span>
                        <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider font-mono">
                          {filteredActive.length} Online
                        </span>
                      </div>

                      {filteredActive.length === 0 ? (
                        <div className="flex flex-col items-center justify-center gap-3 px-4 py-16 text-center">
                          <div className="h-12 w-12 rounded-full bg-apple-bg flex items-center justify-center text-apple-subtext">
                            <Activity className="h-6 w-6 stroke-[1.5]" />
                          </div>
                          <div>
                            <p className="text-sm font-semibold text-apple-text">
                              Tidak Ada Sesi Aktif
                            </p>
                            <p className="text-xs text-apple-subtext mt-0.5">
                              {hotspotActiveSearch
                                ? 'Tidak ada sesi aktif yang cocok dengan pencarian.'
                                : 'Tidak ada user hotspot yang sedang login saat ini.'}
                            </p>
                          </div>
                        </div>
                      ) : (
                        <div
                          onScroll={(e) => {
                            const el = e.currentTarget;
                            if (el.scrollTop + el.clientHeight >= el.scrollHeight - 80) {
                              if (visibleHotspotActive < filteredActive.length) {
                                setVisibleHotspotActive((prev) => Math.min(prev + 25, filteredActive.length));
                              }
                            }
                          }}
                          className="divide-y divide-black/[0.04] overflow-y-auto max-h-[515px] sm:max-h-[600px] overscroll-contain pb-2"
                        >
                          {filteredActive.slice(0, visibleHotspotActive).map((session) => {
                            const userObj = hotspotUsers.find(
                              (u) => u.name.toLowerCase() === session.user.toLowerCase()
                            );
                            const userProf = userObj
                              ? hotspotProfiles.find((p) => p.name === userObj.profile)
                              : undefined;

                            let sisaText = '';
                            let sisaColor = 'text-emerald-600';

                            if (userObj) {
                              const expiryInfo = calculateHotspotUserExpiry(userObj, userProf, new Date(), true);
                              if (expiryInfo.sisaText && expiryInfo.sisaText !== 'Aktif' && expiryInfo.sisaText !== 'Belum Dipakai') {
                                sisaText = expiryInfo.sisaText;
                                sisaColor = expiryInfo.colorClass;
                              }
                            }

                            if (!sisaText && session['session-time-left']) {
                              sisaText = `Sisa: ${session['session-time-left']}`;
                              sisaColor = 'text-amber-600';
                            }

                            return (
                              <div
                                key={session['.id']}
                                onClick={() => {
                                  if (userObj) {
                                    handleOpenEditHotspotUser(userObj);
                                  }
                                }}
                                className={`px-4 py-2.5 sm:px-5 sm:py-3 flex items-center justify-between gap-3 bg-white hover:bg-[#fbfbfd] transition-colors ${
                                  userObj ? 'cursor-pointer' : ''
                                }`}
                              >
                                <div className="min-w-0 flex-1">
                                  <div className="flex items-center gap-2 flex-wrap">
                                    <span className="font-mono font-bold text-sm text-apple-text">
                                      {session.user}
                                    </span>
                                    <span className="font-mono text-xs px-2 py-0.5 rounded-md bg-apple-blue/10 text-apple-blue font-bold">
                                      {session.address}
                                    </span>
                                    {userObj?.profile && (
                                      <span className="text-[10px] font-mono font-semibold px-2 py-0.5 rounded-md bg-black/[0.05] text-apple-subtext">
                                        {userObj.profile}
                                      </span>
                                    )}
                                    {session.server && (
                                      <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-black/[0.04] text-apple-subtext">
                                        {session.server}
                                      </span>
                                    )}
                                    <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-emerald-500/10 text-emerald-600 flex items-center gap-1">
                                      <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                                      Online
                                    </span>
                                  </div>

                                  <div className="flex items-center gap-2 text-xs text-apple-subtext mt-1 flex-wrap font-mono">
                                    <span className="text-apple-subtext font-semibold">
                                      {session['mac-address']}
                                    </span>
                                    <span>•</span>
                                    <span className="text-emerald-600 font-semibold flex items-center gap-1">
                                      <Clock className="h-3 w-3 stroke-[2.2]" />
                                      {session.uptime || '0s'}
                                    </span>
                                    {sisaText && (
                                      <>
                                        <span>•</span>
                                        <span className={`font-semibold ${sisaColor}`}>
                                          {sisaText}
                                        </span>
                                      </>
                                    )}
                                    <span>•</span>
                                    <span className="text-apple-subtext/80">
                                      ↓{formatBytes(session['bytes-in'])} ↑{formatBytes(session['bytes-out'])}
                                    </span>
                                  </div>
                                </div>

                                <button
                                  type="button"
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    handleClearHotspotActiveMac(session);
                                  }}
                                  className="h-9 w-9 sm:h-8 sm:w-8 min-h-[44px] min-w-[44px] rounded-full flex items-center justify-center text-amber-600 bg-amber-500/10 hover:bg-amber-500/20 active:scale-95 transition-all shrink-0"
                                  title="Clear Lock MAC & Reset Sesi"
                                  aria-label={`Clear Lock MAC ${session.user}`}
                                >
                                  <Unlock className="h-4 w-4" />
                                </button>
                              </div>
                            );
                          })}

                          {filteredActive.length > visibleHotspotActive && (
                            <div className="p-3 text-center border-t border-black/[0.04] bg-[#fbfbfd]">
                              <button
                                type="button"
                                onClick={() => setVisibleHotspotActive((prev) => Math.min(prev + 50, filteredActive.length))}
                                className="w-full py-2.5 px-4 text-xs font-semibold text-apple-blue bg-apple-blue/10 hover:bg-apple-blue/15 active:scale-[0.98] rounded-xl transition-all min-h-[44px] flex items-center justify-center gap-1.5"
                              >
                                <ChevronDown className="h-4 w-4 stroke-[2.2]" />
                                <span>Muat Lebih Banyak ({filteredActive.length - visibleHotspotActive} lagi)</span>
                                <span className="font-mono text-[11px] opacity-70">· Menampilkan {visibleHotspotActive} dari {filteredActive.length}</span>
                              </button>
                            </div>
                          )}

                          {visibleHotspotActive >= filteredActive.length && filteredActive.length > 25 && (
                            <div className="py-2.5 px-4 text-center border-t border-black/[0.04] bg-[#fbfbfd]/60 text-[11px] font-mono text-apple-subtext">
                              Semua {filteredActive.length} sesi online telah dimuat
                            </div>
                          )}
                        </div>
                      )}
                    </section>
                  )}

                  {/* SUB-TAB 3 CONTENT: DAFTAR PROFIL HOTSPOT */}
                  {hotspotSubTab === 'profile' && (
                    <section className="bg-white rounded-2xl sm:rounded-3xl border border-black/[0.08] shadow-apple overflow-hidden flex flex-col">
                      <div className="px-4 py-2.5 sm:px-5 sm:py-3 border-b border-black/[0.04] bg-[#fbfbfd] flex items-center justify-between shrink-0">
                        <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider">
                          Daftar Profil Hotspot:
                        </span>
                        <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider font-mono">
                          {filteredProfiles.length} Profil
                        </span>
                      </div>

                      {filteredProfiles.length === 0 ? (
                        <div className="flex flex-col items-center justify-center gap-3 px-4 py-16 text-center">
                          <div className="h-12 w-12 rounded-full bg-apple-bg flex items-center justify-center text-apple-subtext">
                            <Zap className="h-6 w-6 stroke-[1.5]" />
                          </div>
                          <div>
                            <p className="text-sm font-semibold text-apple-text">
                              Tidak Ada Profil
                            </p>
                            <p className="text-xs text-apple-subtext mt-0.5">
                              {hotspotProfileSearch
                                ? 'Tidak ada profil hotspot yang cocok dengan pencarian.'
                                : 'Belum ada profil user hotspot terdaftar di MikroTik.'}
                            </p>
                          </div>
                        </div>
                      ) : (
                        <div
                          onScroll={(e) => {
                            const el = e.currentTarget;
                            if (el.scrollTop + el.clientHeight >= el.scrollHeight - 80) {
                              if (visibleHotspotProfiles < filteredProfiles.length) {
                                setVisibleHotspotProfiles((prev) => Math.min(prev + 25, filteredProfiles.length));
                              }
                            }
                          }}
                          className="divide-y divide-black/[0.04] overflow-y-auto max-h-[515px] sm:max-h-[600px] overscroll-contain pb-2"
                        >
                          {filteredProfiles.slice(0, visibleHotspotProfiles).map((profile) => {
                            const userCount = hotspotUsers.filter(
                              (u) => u.profile === profile.name && !isHiddenDefaultUser(u.name)
                            ).length;
                            return (
                              <div
                                key={profile['.id']}
                                onClick={() => handleOpenEditHotspotProfile(profile)}
                                className="px-4 py-2.5 sm:px-5 sm:py-3 flex items-center justify-between gap-3 bg-white hover:bg-[#fbfbfd] active:bg-black/[0.02] transition-colors cursor-pointer group"
                              >
                                <div className="min-w-0 flex-1">
                                  <div className="flex items-center gap-2 flex-wrap">
                                    <p className="font-mono font-bold text-sm sm:text-base text-apple-text tracking-tight truncate group-hover:text-apple-blue transition-colors">
                                      {profile.name}
                                    </p>
                                    {profile['rate-limit'] ? (
                                      <span className="font-mono text-xs font-semibold px-2 py-0.5 rounded-md bg-emerald-500/10 text-emerald-700 border border-emerald-500/15">
                                        {profile['rate-limit']}
                                      </span>
                                    ) : (
                                      <span className="font-mono text-xs font-semibold px-2 py-0.5 rounded-md bg-emerald-500/10 text-emerald-700 border border-emerald-500/15">
                                        Unlimited
                                      </span>
                                    )}
                                  </div>

                                  <div className="flex items-center gap-2.5 text-xs text-apple-subtext mt-1 flex-wrap font-mono">
                                    <span>
                                      Shared:{' '}
                                      <strong className="text-apple-text font-semibold">
                                        {profile['shared-users'] || '1'} User
                                      </strong>
                                    </span>
                                    {profile['address-pool'] && (
                                      <span>
                                        Pool:{' '}
                                        <strong className="text-apple-text font-semibold">
                                          {profile['address-pool']}
                                        </strong>
                                      </span>
                                    )}
                                    {(profile.validity || profile.comment?.match(/validity:\s*([^\s,;]+)/i)?.[1]) && (
                                      <span>
                                        Masa Aktif:{' '}
                                        <strong className="text-apple-text font-semibold">
                                          {profile.validity || profile.comment?.match(/validity:\s*([^\s,;]+)/i)?.[1]}
                                        </strong>
                                      </span>
                                    )}
                                    {profile['status-autorefresh'] && (
                                      <span className="text-apple-subtext/80">
                                        Refresh: {profile['status-autorefresh']}
                                      </span>
                                    )}
                                  </div>
                                </div>

                                <div className="flex items-center gap-2 shrink-0">
                                  <span className="font-mono text-xs font-semibold bg-[#747480]/[0.08] px-2.5 py-1 rounded-full text-apple-text border border-black/[0.04]">
                                    {userCount} User
                                  </span>
                                  <button
                                    type="button"
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      handleOpenEditHotspotProfile(profile);
                                    }}
                                    className="h-9 w-9 sm:h-8 sm:w-8 min-h-[44px] min-w-[44px] rounded-full flex items-center justify-center text-apple-subtext hover:text-apple-blue hover:bg-apple-blue/10 active:scale-95 transition-all"
                                    title="Edit Profil Hotspot"
                                    aria-label={`Edit ${profile.name}`}
                                  >
                                    <Pencil className="h-4 w-4" />
                                  </button>
                                </div>
                              </div>
                            );
                          })}

                          {filteredProfiles.length > visibleHotspotProfiles && (
                            <div className="p-3 text-center border-t border-black/[0.04] bg-[#fbfbfd]">
                              <button
                                type="button"
                                onClick={() => setVisibleHotspotProfiles((prev) => Math.min(prev + 50, filteredProfiles.length))}
                                className="w-full py-2.5 px-4 text-xs font-semibold text-apple-blue bg-apple-blue/10 hover:bg-apple-blue/15 active:scale-[0.98] rounded-xl transition-all min-h-[44px] flex items-center justify-center gap-1.5"
                              >
                                <ChevronDown className="h-4 w-4 stroke-[2.2]" />
                                <span>Muat Lebih Banyak ({filteredProfiles.length - visibleHotspotProfiles} lagi)</span>
                                <span className="font-mono text-[11px] opacity-70">· Menampilkan {visibleHotspotProfiles} dari {filteredProfiles.length}</span>
                              </button>
                            </div>
                          )}

                          {visibleHotspotProfiles >= filteredProfiles.length && filteredProfiles.length > 25 && (
                            <div className="py-2.5 px-4 text-center border-t border-black/[0.04] bg-[#fbfbfd]/60 text-[11px] font-mono text-apple-subtext">
                              Semua {filteredProfiles.length} profil telah dimuat
                            </div>
                          )}
                        </div>
                      )}
                    </section>
                  )}

                  {/* MODAL 1: TAMBAH USER / VOUCHER HOTSPOT */}
                  {isAddHotspotUserModalOpen && (
                    <div
                      className="relative z-50"
                      aria-labelledby="add-hotspot-user-modal-title"
                      role="dialog"
                      aria-modal="true"
                    >
                      <div
                        className="fixed inset-0 bg-black/40 backdrop-blur-sm transition-opacity"
                        onClick={() => setIsAddHotspotUserModalOpen(false)}
                      />

                      <div
                        className="fixed inset-0 z-50 w-screen overflow-y-auto"
                        onClick={() => setIsAddHotspotUserModalOpen(false)}
                      >
                        <div className="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4">
                          <div
                            className="relative transform overflow-hidden rounded-t-[32px] sm:rounded-3xl bg-apple-card text-left shadow-[0_-10px_40px_rgba(0,0,0,0.14)] sm:shadow-ios-modal transition-all my-0 sm:my-auto w-full max-w-lg border-t sm:border border-black/[0.08] max-h-[92vh] sm:max-h-[85vh] flex flex-col animate-in slide-in-from-bottom duration-300 ease-out sm:zoom-in-95"
                            onClick={(e) => e.stopPropagation()}
                          >
                            {/* iOS Drawer Grabber Handle */}
                            <div className="w-full pt-3 pb-1 flex justify-center sm:hidden bg-[#fbfbfd] shrink-0">
                              <div className="w-10 h-1.5 rounded-full bg-black/20" />
                            </div>

                            {/* Header Modal */}
                            <div className="px-5 pt-2 pb-3.5 sm:px-6 sm:pt-5 sm:pb-4 border-b border-black/[0.06] flex items-center justify-between bg-[#fbfbfd] shrink-0">
                              <div className="flex items-center gap-3">
                                <div className="h-10 w-10 rounded-2xl bg-apple-blue/10 text-apple-blue flex items-center justify-center font-bold shrink-0">
                                  <Ticket className="h-5 w-5 stroke-[2.2]" />
                                </div>
                                <div>
                                  <h3
                                    className="text-base font-bold text-apple-text tracking-tight"
                                    id="add-hotspot-user-modal-title"
                                  >
                                    Tambah User Hotspot
                                  </h3>
                                  <p className="text-xs text-apple-subtext font-medium">
                                    Buat user voucher atau akun login baru di MikroTik
                                  </p>
                                </div>
                              </div>
                              <button
                                type="button"
                                onClick={() => setIsAddHotspotUserModalOpen(false)}
                                className="text-apple-subtext hover:text-apple-text rounded-full p-2 bg-black/[0.04] hover:bg-black/[0.08] transition-all min-h-[36px] min-w-[36px] flex items-center justify-center"
                                title="Tutup modal"
                                aria-label="Tutup modal"
                              >
                                <X className="h-4 w-4" />
                              </button>
                            </div>

                            {/* Form Body */}
                            <form onSubmit={handleCreateHotspotUser} className="p-5 sm:p-6 space-y-4 overflow-y-auto overscroll-contain flex-1">
                              <div>
                                <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                  Username Hotspot <span className="text-rose-500">*</span>
                                </label>
                                <input
                                  type="text"
                                  required
                                  value={newHotspotUserName}
                                  onChange={(e) => setNewHotspotUserName(e.target.value)}
                                  placeholder="misal: vc-1hari-01 atau nama user"
                                  className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                />
                              </div>

                              <div>
                                <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                  Password Hotspot
                                </label>
                                <div className="relative">
                                  <input
                                    type={showNewHotspotPass ? 'text' : 'password'}
                                    value={newHotspotUserPass}
                                    onChange={(e) => setNewHotspotUserPass(e.target.value)}
                                    placeholder="misal: 123456 (opsional untuk voucher)"
                                    className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-12 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                  />
                                  <button
                                    type="button"
                                    onClick={() => setShowNewHotspotPass(!showNewHotspotPass)}
                                    className="absolute right-1 top-1/2 -translate-y-1/2 text-apple-subtext hover:text-apple-blue p-2 rounded-xl transition-all min-h-[44px] min-w-[44px] flex items-center justify-center active:scale-90"
                                    title={showNewHotspotPass ? 'Sembunyikan password' : 'Lihat password'}
                                    aria-label={showNewHotspotPass ? 'Sembunyikan password' : 'Lihat password'}
                                  >
                                    {showNewHotspotPass ? (
                                      <EyeOff className="h-4 w-4 stroke-[2.2]" />
                                    ) : (
                                      <Eye className="h-4 w-4 stroke-[2.2]" />
                                    )}
                                  </button>
                                </div>
                              </div>

                              <div>
                                <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                  Profil Kecepatan
                                </label>
                                <div className="relative">
                                  <select
                                    value={newHotspotUserProfile}
                                    onChange={(e) => setNewHotspotUserProfile(e.target.value)}
                                    className="w-full min-h-[48px] appearance-none rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-10 py-2.5 text-sm font-mono text-apple-text focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                  >
                                    {hotspotProfiles.filter((p) => !isHiddenDefaultProfile(p.name)).length === 0 ? (
                                      <option value="default">default</option>
                                    ) : (
                                      hotspotProfiles
                                        .filter((p) => !isHiddenDefaultProfile(p.name))
                                        .map((p) => (
                                          <option key={p['.id']} value={p.name}>
                                            {p.name} {p['rate-limit'] ? `(${p['rate-limit']})` : ''}
                                          </option>
                                        ))
                                    )}
                                  </select>
                                  <ChevronDown className="h-4 w-4 text-apple-subtext absolute right-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                                </div>
                              </div>

                              <div>
                                <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                  Catatan / Keterangan
                                </label>
                                <input
                                  type="text"
                                  value={newHotspotUserComment}
                                  onChange={(e) => setNewHotspotUserComment(e.target.value)}
                                  placeholder="misal: Voucher Kasir 1 / Tamu Kantor"
                                  className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                />
                              </div>

                              {/* Footer Action Buttons */}
                              <div className="pt-3 border-t border-black/[0.06] flex items-center justify-end gap-2 pb-[calc(1.25rem+env(safe-area-inset-bottom,0px))] sm:pb-0">
                                <button
                                  type="button"
                                  onClick={() => setIsAddHotspotUserModalOpen(false)}
                                  className="py-2.5 px-4 rounded-2xl text-xs font-semibold text-apple-subtext hover:text-apple-text hover:bg-black/[0.04] transition-all min-h-[48px]"
                                >
                                  Batal
                                </button>
                                <button
                                  type="submit"
                                  className="py-2.5 px-5 rounded-2xl text-xs font-semibold bg-apple-blue text-white shadow-xs hover:bg-apple-blueHover flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px]"
                                >
                                  <Plus className="h-4 w-4 stroke-[2.5]" />
                                  <span>Simpan User</span>
                                </button>
                              </div>
                            </form>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* MODAL 2: DETAIL / EDIT USER HOTSPOT */}
                  {selectedHotspotUser && (
                    <div
                      className="relative z-50"
                      aria-labelledby="edit-hotspot-user-modal-title"
                      role="dialog"
                      aria-modal="true"
                    >
                      <div
                        className="fixed inset-0 bg-black/40 backdrop-blur-sm transition-opacity"
                        onClick={() => setSelectedHotspotUser(null)}
                      />

                      <div
                        className="fixed inset-0 z-50 w-screen overflow-y-auto"
                        onClick={() => setSelectedHotspotUser(null)}
                      >
                        <div className="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4">
                          <div
                            className="relative transform overflow-hidden rounded-t-[32px] sm:rounded-3xl bg-apple-card text-left shadow-[0_-10px_40px_rgba(0,0,0,0.14)] sm:shadow-ios-modal transition-all my-0 sm:my-auto w-full max-w-lg border-t sm:border border-black/[0.08] max-h-[92vh] sm:max-h-[85vh] flex flex-col animate-in slide-in-from-bottom duration-300 ease-out sm:zoom-in-95"
                            onClick={(e) => e.stopPropagation()}
                          >
                            {/* iOS Drawer Grabber Handle */}
                            <div className="w-full pt-3 pb-1 flex justify-center sm:hidden bg-[#fbfbfd] shrink-0">
                              <div className="w-10 h-1.5 rounded-full bg-black/20" />
                            </div>

                            {/* Header Modal */}
                            <div className="px-5 pt-2 pb-3.5 sm:px-6 sm:pt-5 sm:pb-4 border-b border-black/[0.06] flex items-center justify-between bg-[#fbfbfd] shrink-0">
                              <div className="flex items-center gap-3">
                                <div className="h-10 w-10 rounded-2xl bg-apple-blue/10 text-apple-blue flex items-center justify-center font-bold shrink-0">
                                  <Pencil className="h-5 w-5 stroke-[2.2]" />
                                </div>
                                <div>
                                  <h3
                                    className="text-base font-bold text-apple-text tracking-tight font-mono"
                                    id="edit-hotspot-user-modal-title"
                                  >
                                    {selectedHotspotUser.name}
                                  </h3>
                                  <p className="text-xs text-apple-subtext font-medium">
                                    Detail & Konfigurasi User Hotspot
                                  </p>
                                </div>
                              </div>
                              <button
                                type="button"
                                onClick={() => setSelectedHotspotUser(null)}
                                className="text-apple-subtext hover:text-apple-text rounded-full p-2 bg-black/[0.04] hover:bg-black/[0.08] transition-all min-h-[36px] min-w-[36px] flex items-center justify-center"
                                title="Tutup modal"
                                aria-label="Tutup modal"
                              >
                                <X className="h-4 w-4" />
                              </button>
                            </div>

                            {/* Form & Content */}
                            <form onSubmit={handleSaveEditHotspotUser} className="p-5 sm:p-6 space-y-4 overflow-y-auto overscroll-contain flex-1">
                              {/* Summary Info Card */}
                              {(() => {
                                const modalProf = hotspotProfiles.find((p) => p.name === selectedHotspotUser.profile);
                                const isSelectedOnline = hotspotActive.some(
                                  (a) => a.user.toLowerCase() === selectedHotspotUser.name.toLowerCase()
                                );
                                const modalExpiryInfo = calculateHotspotUserExpiry(
                                  selectedHotspotUser,
                                  modalProf,
                                  new Date(),
                                  isSelectedOnline
                                );

                                return (
                                  <div className="bg-apple-bg rounded-2xl p-4 space-y-2.5 border border-black/[0.04]">
                                    <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                                      <span className="text-apple-subtext font-medium">Status Akun:</span>
                                      <div className="flex items-center gap-2">
                                        {modalExpiryInfo.status === 'disabled' ? (
                                          <span className="text-[11px] font-bold px-2 py-0.5 rounded-md bg-rose-500/10 text-rose-600">
                                            Nonaktif
                                          </span>
                                        ) : isSelectedOnline ? (
                                          <span className="text-[11px] font-bold px-2 py-0.5 rounded-md bg-emerald-500/10 text-emerald-600 flex items-center gap-1">
                                            <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                                            Online
                                          </span>
                                        ) : modalExpiryInfo.isUsed ? (
                                          <span className="text-[11px] font-bold px-2 py-0.5 rounded-md bg-sky-500/10 text-sky-700">
                                            Terpakai
                                          </span>
                                        ) : (
                                          <span className="text-[11px] font-bold px-2 py-0.5 rounded-md bg-black/[0.05] text-apple-subtext">
                                            Belum Dipakai
                                          </span>
                                        )}
                                        <button
                                          type="button"
                                          onClick={() => handleToggleDisableHotspotUser(selectedHotspotUser)}
                                          className={`px-2.5 py-1 rounded-xl text-xs font-semibold transition-all min-h-[36px] ${
                                            selectedHotspotUser.disabled === true || selectedHotspotUser.disabled === 'true'
                                              ? 'bg-emerald-600 text-white hover:bg-emerald-700'
                                              : 'bg-rose-500/10 text-rose-600 hover:bg-rose-500/20'
                                          }`}
                                        >
                                          {selectedHotspotUser.disabled === true || selectedHotspotUser.disabled === 'true'
                                            ? 'Aktifkan'
                                            : 'Nonaktifkan'}
                                        </button>
                                      </div>
                                    </div>

                                    <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                                      <span className="text-apple-subtext font-medium">Sisa Masa Aktif:</span>
                                      <span className={`font-mono font-bold ${modalExpiryInfo.colorClass}`}>
                                        {modalExpiryInfo.sisaText}
                                      </span>
                                    </div>

                                    {modalExpiryInfo.hasTimestamp && (
                                      <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                                        <span className="text-apple-subtext font-medium">Waktu / Expire:</span>
                                        <span className="font-mono font-semibold text-apple-text">
                                          {modalExpiryInfo.formattedDate}
                                        </span>
                                      </div>
                                    )}

                                    <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                                      <span className="text-apple-subtext font-medium">Total Uptime:</span>
                                      <span className="font-mono font-semibold text-apple-text">
                                        {selectedHotspotUser.uptime || '0s'}
                                      </span>
                                    </div>

                                    <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                                      <span className="text-apple-subtext font-medium">Penggunaan Data:</span>
                                      <span className="font-mono font-semibold text-apple-text">
                                        ↓{formatBytes(selectedHotspotUser['bytes-in'])} · ↑{formatBytes(selectedHotspotUser['bytes-out'])}
                                      </span>
                                    </div>

                                    <div className="flex items-center justify-between text-xs py-1">
                                      <span className="text-apple-subtext font-medium">Kunci MAC (Lock):</span>
                                      <div className="flex items-center gap-1.5">
                                        <span className="font-mono font-semibold text-apple-text">
                                          {selectedHotspotUser['mac-address'] && selectedHotspotUser['mac-address'] !== '00:00:00:00:00:00'
                                            ? selectedHotspotUser['mac-address']
                                            : 'Bebas (Tidak Terkunci)'}
                                        </span>
                                        {selectedHotspotUser['mac-address'] && selectedHotspotUser['mac-address'] !== '00:00:00:00:00:00' && (
                                          <button
                                            type="button"
                                            onClick={() => handleClearHotspotUserMac(selectedHotspotUser)}
                                            className="px-2 py-0.5 rounded-lg text-[10px] font-semibold bg-amber-500/10 text-amber-600 hover:bg-amber-500/20 active:scale-95 transition-all flex items-center gap-1 min-h-[30px]"
                                            title="Buka Kunci MAC"
                                          >
                                            <Unlock className="h-3 w-3" />
                                            <span>Clear MAC</span>
                                          </button>
                                        )}
                                      </div>
                                    </div>
                                  </div>
                                );
                              })()}

                              {/* Form Inputs */}
                              <div>
                                <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                  Password Baru
                                </label>
                                <div className="relative">
                                  <input
                                    type={showEditHotspotPass ? 'text' : 'password'}
                                    value={editHotspotUserPass}
                                    onChange={(e) => setEditHotspotUserPass(e.target.value)}
                                    placeholder="Biarkan kosong jika tidak ingin mengubah password"
                                    className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-12 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                  />
                                  <button
                                    type="button"
                                    onClick={() => setShowEditHotspotPass(!showEditHotspotPass)}
                                    className="absolute right-1 top-1/2 -translate-y-1/2 text-apple-subtext hover:text-apple-blue p-2 rounded-xl transition-all min-h-[44px] min-w-[44px] flex items-center justify-center active:scale-90"
                                    title={showEditHotspotPass ? 'Sembunyikan password' : 'Lihat password'}
                                    aria-label={showEditHotspotPass ? 'Sembunyikan password' : 'Lihat password'}
                                  >
                                    {showEditHotspotPass ? (
                                      <EyeOff className="h-4 w-4 stroke-[2.2]" />
                                    ) : (
                                      <Eye className="h-4 w-4 stroke-[2.2]" />
                                    )}
                                  </button>
                                </div>
                              </div>

                              <div>
                                <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                  Profil Kecepatan
                                </label>
                                <div className="relative">
                                  <select
                                    value={editHotspotUserProfile}
                                    onChange={(e) => setEditHotspotUserProfile(e.target.value)}
                                    className="w-full min-h-[48px] appearance-none rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-10 py-2.5 text-sm font-mono text-apple-text focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                  >
                                    {hotspotProfiles.filter((p) => !isHiddenDefaultProfile(p.name)).length === 0 ? (
                                      <option value="default">default</option>
                                    ) : (
                                      hotspotProfiles
                                        .filter((p) => !isHiddenDefaultProfile(p.name))
                                        .map((p) => (
                                          <option key={p['.id']} value={p.name}>
                                            {p.name} {p['rate-limit'] ? `(${p['rate-limit']})` : ''}
                                          </option>
                                        ))
                                    )}
                                  </select>
                                  <ChevronDown className="h-4 w-4 text-apple-subtext absolute right-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                                </div>
                              </div>

                              <div>
                                <div className="flex items-center justify-between mb-1.5">
                                  <label className="text-xs font-bold text-apple-subtext uppercase tracking-wider">
                                    Catatan / Waktu Aktivasi
                                  </label>
                                  <span className="text-[10px] text-apple-subtext font-mono">misal: 2026-11-07 11:23:28</span>
                                </div>
                                <input
                                  type="text"
                                  value={editHotspotUserComment}
                                  onChange={(e) => setEditHotspotUserComment(e.target.value)}
                                  placeholder="misal: 2026-11-07 11:23:28 atau Catatan Pelanggan"
                                  className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                />
                              </div>

                              {/* Footer Action Buttons: Hapus di KIRI, Simpan di KANAN */}
                              <div className="pt-3 border-t border-black/[0.06] flex items-center justify-between gap-2">
                                <div className="relative shrink-0 select-none">
                                  <button
                                    type="button"
                                    onMouseDown={() => startHotspotDeleteHold(selectedHotspotUser)}
                                    onMouseUp={cancelHotspotDeleteHold}
                                    onMouseLeave={cancelHotspotDeleteHold}
                                    onTouchStart={() => startHotspotDeleteHold(selectedHotspotUser)}
                                    onTouchEnd={cancelHotspotDeleteHold}
                                    onTouchCancel={cancelHotspotDeleteHold}
                                    onContextMenu={(e) => e.preventDefault()}
                                    className="relative overflow-hidden py-2.5 px-3.5 rounded-2xl text-xs font-semibold bg-rose-500/10 text-rose-600 hover:bg-rose-500/15 border border-rose-500/20 flex items-center justify-center gap-1.5 active:scale-95 transition-all min-h-[48px]"
                                    title="Tahan 0.5 detik untuk menghapus user"
                                  >
                                    {hotspotDeleteHoldId === selectedHotspotUser['.id'] && hotspotDeleteHoldProgress > 0 && (
                                      <div
                                        className="absolute inset-0 bg-rose-600 transition-all duration-75 pointer-events-none"
                                        style={{ width: `${hotspotDeleteHoldProgress}%` }}
                                      />
                                    )}
                                    <Trash2
                                      className={`h-4 w-4 shrink-0 relative z-10 ${
                                        hotspotDeleteHoldId === selectedHotspotUser['.id'] && hotspotDeleteHoldProgress > 30 ? 'text-white' : 'text-rose-600'
                                      }`}
                                    />
                                    <span
                                      className={`relative z-10 ${
                                        hotspotDeleteHoldId === selectedHotspotUser['.id'] && hotspotDeleteHoldProgress > 30 ? 'text-white' : 'text-rose-600'
                                      }`}
                                    >
                                      {hotspotDeleteHoldId === selectedHotspotUser['.id'] && hotspotDeleteHoldProgress > 0 ? 'Tahan...' : 'Hapus'}
                                    </span>
                                  </button>
                                </div>

                                <div className="flex items-center gap-2">
                                  <button
                                    type="button"
                                    onClick={() => setSelectedHotspotUser(null)}
                                    className="py-2.5 px-4 rounded-2xl text-xs font-semibold text-apple-subtext hover:text-apple-text hover:bg-black/[0.04] transition-all min-h-[48px]"
                                  >
                                    Batal
                                  </button>
                                  <button
                                    type="submit"
                                    className="py-2.5 px-5 rounded-2xl text-xs font-semibold bg-apple-blue text-white shadow-xs hover:bg-apple-blueHover flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px]"
                                  >
                                    <Check className="h-4 w-4 stroke-[2.5]" />
                                    <span>Simpan</span>
                                  </button>
                                </div>
                              </div>
                            </form>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* MODAL 3: TAMBAH / EDIT PROFIL HOTSPOT */}
                  {isHotspotProfileModalOpen && (
                    <div
                      className="relative z-50"
                      aria-labelledby="hotspot-profile-modal-title"
                      role="dialog"
                      aria-modal="true"
                    >
                      <div
                        className="fixed inset-0 bg-black/40 backdrop-blur-sm transition-opacity"
                        onClick={() => setIsHotspotProfileModalOpen(false)}
                      />

                      <div
                        className="fixed inset-0 z-50 w-screen overflow-y-auto"
                        onClick={() => setIsHotspotProfileModalOpen(false)}
                      >
                        <div className="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4">
                          <div
                            className="relative transform overflow-hidden rounded-t-[32px] sm:rounded-3xl bg-apple-card text-left shadow-[0_-10px_40px_rgba(0,0,0,0.14)] sm:shadow-ios-modal transition-all my-0 sm:my-auto w-full max-w-lg border-t sm:border border-black/[0.08] max-h-[92vh] sm:max-h-[85vh] flex flex-col animate-in slide-in-from-bottom duration-300 ease-out sm:zoom-in-95"
                            onClick={(e) => e.stopPropagation()}
                          >
                            {/* iOS Drawer Grabber Handle */}
                            <div className="w-full pt-3 pb-1 flex justify-center sm:hidden bg-[#fbfbfd] shrink-0">
                              <div className="w-10 h-1.5 rounded-full bg-black/20" />
                            </div>

                            {/* Header Modal */}
                            <div className="px-5 pt-2 pb-3.5 sm:px-6 sm:pt-5 sm:pb-4 border-b border-black/[0.06] flex items-center justify-between bg-[#fbfbfd] shrink-0">
                              <div className="flex items-center gap-3">
                                <div className="h-10 w-10 rounded-2xl bg-apple-blue/10 text-apple-blue flex items-center justify-center font-bold shrink-0">
                                  {editingHotspotProfileId ? (
                                    <Pencil className="h-5 w-5 stroke-[2.2]" />
                                  ) : (
                                    <Zap className="h-5 w-5 stroke-[2.2]" />
                                  )}
                                </div>
                                <div>
                                  <h3
                                    className="text-base font-bold text-apple-text tracking-tight"
                                    id="hotspot-profile-modal-title"
                                  >
                                    {editingHotspotProfileId
                                      ? 'Edit Profil Hotspot'
                                      : 'Tambah Profil Hotspot'}
                                  </h3>
                                  <p className="text-xs text-apple-subtext font-medium">
                                    {editingHotspotProfileId
                                      ? 'Perbarui konfigurasi bandwidth dan kuota sesi'
                                      : 'Buat paket kecepatan voucher baru di MikroTik'}
                                  </p>
                                </div>
                              </div>
                              <button
                                type="button"
                                onClick={() => setIsHotspotProfileModalOpen(false)}
                                className="text-apple-subtext hover:text-apple-text rounded-full p-2 bg-black/[0.04] hover:bg-black/[0.08] transition-all min-h-[36px] min-w-[36px] flex items-center justify-center"
                                title="Tutup modal"
                                aria-label="Tutup modal"
                              >
                                <X className="h-4 w-4" />
                              </button>
                            </div>

                            {/* Form Body */}
                            <form onSubmit={handleSaveHotspotProfile} className="p-5 sm:p-6 space-y-4 overflow-y-auto overscroll-contain flex-1">
                              <div>
                                <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                  Nama Profil <span className="text-rose-500">*</span>
                                </label>
                                <input
                                  type="text"
                                  required
                                  value={hotspotProfileFormName}
                                  onChange={(e) => setHotspotProfileFormName(e.target.value)}
                                  placeholder="misal: Voucher-5M atau VIP-Cafe"
                                  className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                />
                              </div>

                              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                                <div>
                                  <div className="flex items-center justify-between mb-1.5">
                                    <label className="block text-xs font-bold text-apple-subtext uppercase tracking-wider">
                                      Rate Limit (Rx/Tx)
                                    </label>
                                    <span className="text-[10px] text-apple-subtext font-medium">
                                      Upload / Download
                                    </span>
                                  </div>
                                  <input
                                    type="text"
                                    value={hotspotProfileFormRateLimit}
                                    onChange={(e) => setHotspotProfileFormRateLimit(e.target.value)}
                                    placeholder="misal: 3M/3M atau 512k/2M"
                                    className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                  />
                                  {/* Quick preset chips */}
                                  <div className="flex flex-wrap items-center gap-1.5 mt-2">
                                    <span className="text-[10px] text-apple-subtext font-medium mr-1">Preset:</span>
                                    {['512k/1M', '1M/2M', '2M/3M', '3M/5M', '5M/10M', '10M/10M'].map((preset) => (
                                      <button
                                        key={preset}
                                        type="button"
                                        onClick={() => setHotspotProfileFormRateLimit(preset)}
                                        className={`text-[10px] font-mono px-2 py-0.5 rounded-md border transition-all ${
                                          hotspotProfileFormRateLimit === preset
                                            ? 'bg-apple-blue text-white border-apple-blue font-bold shadow-xs'
                                            : 'bg-black/[0.04] text-apple-subtext border-black/[0.04] hover:bg-black/[0.08] hover:text-apple-text'
                                        }`}
                                      >
                                        {preset}
                                      </button>
                                    ))}
                                  </div>
                                </div>

                                <div>
                                  <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                    Shared Users (Perangkat)
                                  </label>
                                  <input
                                    type="number"
                                    min="1"
                                    max="50"
                                    value={hotspotProfileFormSharedUsers}
                                    onChange={(e) => setHotspotProfileFormSharedUsers(e.target.value)}
                                    placeholder="1"
                                    className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                  />
                                </div>
                              </div>

                              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                                <div>
                                  <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                    Address Pool (IP Pool)
                                  </label>
                                  {isHotspotManualPool ? (
                                    <div className="flex items-center gap-1.5">
                                      <input
                                        type="text"
                                        value={hotspotProfileFormAddressPool}
                                        onChange={(e) => setHotspotProfileFormAddressPool(e.target.value)}
                                        placeholder="Ketik nama pool..."
                                        className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                      />
                                      <button
                                        type="button"
                                        onClick={() => {
                                          setIsHotspotManualPool(false);
                                          setHotspotProfileFormAddressPool(poolOptions[0]?.name || '');
                                        }}
                                        className="min-h-[48px] px-3 rounded-2xl text-xs bg-black/[0.05] hover:bg-black/[0.10] text-apple-subtext shrink-0"
                                        title="Pilih dari daftar pool"
                                      >
                                        Pilih
                                      </button>
                                    </div>
                                  ) : (
                                    <div className="relative">
                                      <select
                                        value={hotspotProfileFormAddressPool}
                                        onChange={(e) => {
                                          if (e.target.value === '__custom__') {
                                            setIsHotspotManualPool(true);
                                          } else {
                                            setHotspotProfileFormAddressPool(e.target.value);
                                          }
                                        }}
                                        className="w-full min-h-[48px] appearance-none rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] pl-4 pr-10 py-2.5 text-sm font-mono text-apple-text focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                      >
                                        <option value="">-- Tanpa Pool (Default) --</option>
                                        {poolOptions.map((pool) => (
                                          <option key={pool.name} value={pool.name}>
                                            {pool.name} {pool.ranges ? `(${pool.ranges})` : ''}
                                          </option>
                                        ))}
                                        <option value="__custom__">+ Ketik Manual / Pool Kustom...</option>
                                      </select>
                                      <ChevronDown className="h-4 w-4 text-apple-subtext absolute right-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                                    </div>
                                  )}
                                </div>

                                <div>
                                  <label className="block text-xs font-bold text-apple-subtext mb-1.5 uppercase tracking-wider">
                                    Status Auto-refresh
                                  </label>
                                  <input
                                    type="text"
                                    value={hotspotProfileFormAutorefresh}
                                    onChange={(e) => setHotspotProfileFormAutorefresh(e.target.value)}
                                    placeholder="misal: 1m, 30s"
                                    className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                  />
                                </div>
                              </div>

                              <div>
                                <div className="flex items-center justify-between mb-1.5">
                                  <label className="text-xs font-bold text-apple-subtext uppercase tracking-wider">
                                    Masa Aktif / Validity
                                  </label>
                                  <span className="text-[10px] text-apple-subtext font-mono">opsional</span>
                                </div>
                                <input
                                  type="text"
                                  value={hotspotProfileFormValidity}
                                  onChange={(e) => setHotspotProfileFormValidity(e.target.value)}
                                  placeholder="misal: 1d, 3h, 7d, 30Hari"
                                  className="w-full min-h-[48px] rounded-2xl bg-apple-bg border-0 ring-1 ring-inset ring-black/[0.06] px-4 py-2.5 text-sm font-mono text-apple-text placeholder:text-apple-subtext/60 focus:outline-none focus:ring-2 focus:ring-apple-blue focus:bg-white transition-all shadow-sm"
                                />
                                <div className="flex items-center gap-1.5 mt-2 flex-wrap">
                                  {['1h', '3h', '1d', '7d', '30d'].map((preset) => (
                                    <button
                                      key={preset}
                                      type="button"
                                      onClick={() => setHotspotProfileFormValidity(preset)}
                                      className="px-2.5 py-1 rounded-xl text-xs font-mono font-semibold bg-black/[0.04] hover:bg-black/[0.08] text-apple-subtext hover:text-apple-text transition-all min-h-[36px]"
                                    >
                                      +{preset}
                                    </button>
                                  ))}
                                </div>
                              </div>

                              {/* Footer Action Buttons: Hapus di KIRI, Simpan di KANAN */}
                              <div className="pt-3 border-t border-black/[0.06] flex items-center justify-between gap-2">
                                {editingHotspotProfileId ? (
                                  <div className="relative shrink-0 select-none">
                                    <button
                                      type="button"
                                      onMouseDown={startHotspotProfileDeleteHold}
                                      onMouseUp={cancelHotspotProfileDeleteHold}
                                      onMouseLeave={cancelHotspotProfileDeleteHold}
                                      onTouchStart={startHotspotProfileDeleteHold}
                                      onTouchEnd={cancelHotspotProfileDeleteHold}
                                      onTouchCancel={cancelHotspotProfileDeleteHold}
                                      onContextMenu={(e) => e.preventDefault()}
                                      className="relative overflow-hidden py-2.5 px-3.5 rounded-2xl text-xs font-semibold bg-rose-500/10 text-rose-600 hover:bg-rose-500/15 border border-rose-500/20 flex items-center justify-center gap-1.5 active:scale-95 transition-all min-h-[48px]"
                                      title="Tahan 0.5 detik untuk menghapus profil"
                                    >
                                      {hotspotProfileDeleteHoldProgress > 0 && (
                                        <div
                                          className="absolute inset-0 bg-rose-600 transition-all duration-75 pointer-events-none"
                                          style={{ width: `${hotspotProfileDeleteHoldProgress}%` }}
                                        />
                                      )}
                                      <Trash2
                                        className={`h-4 w-4 shrink-0 relative z-10 ${
                                          hotspotProfileDeleteHoldProgress > 30 ? 'text-white' : 'text-rose-600'
                                        }`}
                                      />
                                      <span
                                        className={`relative z-10 ${
                                          hotspotProfileDeleteHoldProgress > 30 ? 'text-white' : 'text-rose-600'
                                        }`}
                                      >
                                        {hotspotProfileDeleteHoldProgress > 0 ? 'Tahan...' : 'Hapus Profil'}
                                      </span>
                                    </button>
                                  </div>
                                ) : (
                                  <div />
                                )}

                                <div className="flex items-center gap-2">
                                  <button
                                    type="button"
                                    onClick={() => setIsHotspotProfileModalOpen(false)}
                                    className="py-2.5 px-4 rounded-2xl text-xs font-semibold text-apple-subtext hover:text-apple-text hover:bg-black/[0.04] transition-all min-h-[48px]"
                                  >
                                    Batal
                                  </button>
                                  <button
                                    type="submit"
                                    disabled={isSavingHotspotProfile}
                                    className="py-2.5 px-5 rounded-2xl text-xs font-semibold bg-apple-blue text-white shadow-xs hover:bg-apple-blueHover flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px] disabled:opacity-50"
                                  >
                                    {isSavingHotspotProfile ? (
                                      <span>Menyimpan...</span>
                                    ) : editingHotspotProfileId ? (
                                      <>
                                        <Check className="h-4 w-4 stroke-[2.5]" />
                                        <span>Simpan</span>
                                      </>
                                    ) : (
                                      <>
                                        <Plus className="h-4 w-4 stroke-[2.5]" />
                                        <span>Simpan Profil</span>
                                      </>
                                    )}
                                  </button>
                                </div>
                              </div>
                            </form>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}
                </motion.div>
              );
            })()
          ) : activeTab === 'dhcp' ? (
            /* ============================================================= */
            /* HALAMAN DHCP LEASES (APPLE HIG STYLE)                         */
            /* ============================================================= */
            <motion.div
              key="tab-dhcp"
              variants={pageVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              className="space-y-2.5 sm:space-y-3.5 w-full max-w-2xl mx-auto"
            >
              {/* STICKY TOP CONTROLS: Segmented Filter Bar + Search Bar */}
              <div className="sticky top-0 z-20 bg-apple-bg pt-0.5 pb-1 space-y-1.5">
                {/* Apple Segmented Control Filter */}
                <div
                  role="tablist"
                  aria-label="Filter DHCP Leases"
                  className="bg-[#747480]/[0.10] p-[3px] rounded-[13px] sm:rounded-[14px] flex items-center border border-black/[0.04] shadow-[inset_0_1px_2px_rgba(0,0,0,0.04)]"
                >
                  {[
                    { id: 'all' as const, label: 'Semua', count: dhcpLeases.length },
                    {
                      id: 'bound' as const,
                      label: 'Bound',
                      count: dhcpLeases.filter((l) => (l.status || '').toLowerCase() === 'bound').length,
                    },
                    {
                      id: 'dynamic' as const,
                      label: 'Dynamic',
                      count: dhcpLeases.filter((l) => l.dynamic === true || l.dynamic === 'true').length,
                    },
                    {
                      id: 'static' as const,
                      label: 'Static',
                      count: dhcpLeases.filter((l) => l.dynamic !== true && l.dynamic !== 'true').length,
                    },
                  ].map((tab, idx, arr) => {
                    const isSelected = dhcpFilter === tab.id;
                    const prevSelected = idx > 0 && dhcpFilter === arr[idx - 1].id;
                    const showDivider = idx > 0 && !isSelected && !prevSelected;

                    return (
                      <React.Fragment key={tab.id}>
                        {showDivider && (
                          <div className="w-[1px] h-3.5 bg-black/[0.12] shrink-0" aria-hidden="true" />
                        )}
                        <button
                          type="button"
                          role="tab"
                          aria-selected={isSelected}
                          onClick={() => setDhcpFilter(tab.id)}
                          className={`relative flex-1 py-1.5 px-1.5 text-xs font-semibold rounded-[10px] sm:rounded-[11px] active:scale-[0.98] transition-transform flex items-center justify-center gap-1.5 min-h-[40px] select-none ${
                            isSelected
                              ? 'bg-white text-apple-text shadow-[0_1px_3px_rgba(0,0,0,0.10),0_1px_2px_rgba(0,0,0,0.06)]'
                              : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.02]'
                          }`}
                        >
                          <span className="tracking-tight">{tab.label}</span>
                          <span
                            className={`text-[10px] px-1.5 py-0.5 rounded-md font-mono ${
                              isSelected
                                ? 'bg-apple-blue/10 text-apple-blue font-bold'
                                : 'bg-black/[0.05] text-apple-subtext font-medium'
                            }`}
                          >
                            {tab.count}
                          </span>
                          {tab.id === 'bound' && isSelected && (
                            <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse -ml-0.5" />
                          )}
                        </button>
                      </React.Fragment>
                    );
                  })}
                </div>

                {/* Search Bar & Server Filter Popover */}
                <div className="relative">
                  <div className="flex items-center gap-2">
                    <div className="relative flex-1">
                      <Search className="h-4 w-4 text-[#8e8e93] absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                      <input
                        type="text"
                        value={dhcpSearch}
                        onChange={(e) => setDhcpSearch(e.target.value)}
                        placeholder="Cari IP, MAC, hostname, komentar, server..."
                        className="w-full pl-10 pr-20 py-2.5 rounded-2xl bg-white border border-black/[0.06] shadow-xs text-xs sm:text-sm font-mono placeholder:font-sans placeholder:text-apple-subtext focus:outline-none focus:ring-2 focus:ring-apple-blue/30 focus:bg-white transition-all min-h-[48px]"
                      />
                      <div className="absolute right-1.5 top-1/2 -translate-y-1/2 flex items-center gap-1">
                        {dhcpSearch && (
                          <button
                            type="button"
                            onClick={() => setDhcpSearch('')}
                            className="h-7 w-7 min-h-[36px] min-w-[36px] rounded-full bg-black/[0.08] hover:bg-black/[0.14] text-apple-subtext hover:text-apple-text flex items-center justify-center transition-all"
                            title="Hapus pencarian"
                            aria-label="Hapus pencarian"
                          >
                            <X className="h-3.5 w-3.5 stroke-[2.5]" />
                          </button>
                        )}
                        {/* Apple Filter Button */}
                        <button
                          type="button"
                          onClick={() => setDhcpFilterMenuOpen(!dhcpFilterMenuOpen)}
                          className={`min-h-[38px] px-2.5 rounded-xl flex items-center gap-1 transition-all ${
                            dhcpServerFilter !== 'all'
                              ? 'bg-apple-blue text-white shadow-xs font-semibold'
                              : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.04]'
                          }`}
                          title="Filter DHCP Server"
                          aria-label="Filter DHCP Server"
                        >
                          <ListFilter className="h-3.5 w-3.5 stroke-[2.2]" />
                          {dhcpServerFilter !== 'all' && (
                            <span className="text-[10px] max-w-[60px] truncate">
                              {dhcpServerFilter}
                            </span>
                          )}
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Filter Popover */}
                  {dhcpFilterMenuOpen && (
                    <>
                      <div
                        className="fixed inset-0 z-30"
                        onClick={() => setDhcpFilterMenuOpen(false)}
                      />
                      <div className="absolute right-0 top-full mt-2 z-40 w-60 rounded-2xl bg-white border border-black/[0.08] shadow-[0_12px_36px_rgba(0,0,0,0.12),0_4px_12px_rgba(0,0,0,0.06)] p-1.5">
                        <div className="px-3 pt-2 pb-1 text-[10px] font-bold text-apple-subtext uppercase tracking-wider">
                          Filter DHCP Server
                        </div>
                        <div className="space-y-0.5 max-h-56 overflow-y-auto">
                          {(() => {
                            const distinct = Array.from(new Set(dhcpLeases.map((l) => l.server).filter(Boolean)));
                            const servers = ['all', ...distinct];
                            return servers.map((srv) => {
                              const isSel = dhcpServerFilter === srv;
                              const count = srv === 'all'
                                ? dhcpLeases.length
                                : dhcpLeases.filter((l) => l.server === srv).length;

                              return (
                                <button
                                  key={srv}
                                  type="button"
                                  onClick={() => {
                                    setDhcpServerFilter(srv as string);
                                    setDhcpFilterMenuOpen(false);
                                  }}
                                  className={`w-full flex items-center justify-between px-2.5 py-1.5 text-xs rounded-xl select-none ${
                                    isSel
                                      ? 'bg-apple-blue/10 text-apple-blue font-semibold'
                                      : 'text-apple-text hover:bg-black/[0.04] font-normal'
                                  }`}
                                >
                                  <div className="flex items-center gap-2 min-w-0">
                                    <div className="w-4 h-4 flex items-center justify-center shrink-0">
                                      {isSel && (
                                        <Check className="h-3.5 w-3.5 text-apple-blue stroke-[2.5]" />
                                      )}
                                    </div>
                                    <span className="truncate font-mono">
                                      {srv === 'all' ? 'Semua Server' : srv}
                                    </span>
                                  </div>
                                  <span className="font-mono text-[10px] px-1.5 py-0.5 rounded-md bg-black/[0.05] text-apple-subtext shrink-0">
                                    {count}
                                  </span>
                                </button>
                              );
                            });
                          })()}
                        </div>
                      </div>
                    </>
                  )}
                </div>
              </div>

              {/* DHCP LEASES CARD LIST */}
              {(() => {
                const compareIp = (a: string, b: string) => {
                  const numA = (a || '').split('.').map((n) => parseInt(n, 10) || 0);
                  const numB = (b || '').split('.').map((n) => parseInt(n, 10) || 0);
                  for (let i = 0; i < 4; i++) {
                    const diff = (numA[i] || 0) - (numB[i] || 0);
                    if (diff !== 0) return diff;
                  }
                  return 0;
                };

                const filtered = dhcpLeases
                  .filter((lease) => {
                    const status = (lease.status || '').toLowerCase();
                    const isDynamic = lease.dynamic === true || lease.dynamic === 'true';

                    let matchFilter = true;
                    if (dhcpFilter === 'bound') {
                      matchFilter = status === 'bound';
                    } else if (dhcpFilter === 'dynamic') {
                      matchFilter = isDynamic;
                    } else if (dhcpFilter === 'static') {
                      matchFilter = !isDynamic;
                    } else if (dhcpFilter === 'waiting') {
                      matchFilter = status === 'waiting';
                    }

                    let matchServer = true;
                    if (dhcpServerFilter !== 'all') {
                      matchServer = lease.server === dhcpServerFilter;
                    }

                    const q = dhcpSearch.toLowerCase().trim();
                    const matchSearch =
                      !q ||
                      (lease.address || '').includes(q) ||
                      (lease['mac-address'] || '').toLowerCase().includes(q) ||
                      (lease['host-name'] || '').toLowerCase().includes(q) ||
                      (lease.comment || '').toLowerCase().includes(q) ||
                      (lease.server || '').toLowerCase().includes(q);

                    return matchFilter && matchServer && matchSearch;
                  })
                  .sort((a, b) => compareIp(a.address, b.address));

                return (
                  <section className="bg-white rounded-2xl sm:rounded-3xl border border-black/[0.08] shadow-apple overflow-hidden flex flex-col">
                    <div className="px-4 py-2.5 sm:px-5 sm:py-3 border-b border-black/[0.04] bg-[#fbfbfd] flex items-center justify-between shrink-0">
                      <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider">
                        Daftar DHCP Leases:
                      </span>
                      <span className="text-[11px] font-bold text-apple-subtext uppercase tracking-wider font-mono">
                        {filtered.length} Perangkat
                      </span>
                    </div>

                    {filtered.length === 0 ? (
                      <div className="flex flex-col items-center justify-center gap-3 px-4 py-16 text-center">
                        <div className="h-12 w-12 rounded-full bg-apple-bg flex items-center justify-center text-apple-subtext">
                          <Network className="h-6 w-6 stroke-[1.5]" />
                        </div>
                        <div>
                          <p className="text-sm font-semibold text-apple-text">
                            Tidak Ada DHCP Lease
                          </p>
                          <p className="text-xs text-apple-subtext mt-0.5">
                            Tidak ditemukan lease yang sesuai dengan pencarian atau filter.
                          </p>
                        </div>
                      </div>
                    ) : (
                      <div
                        onScroll={(e) => {
                          const el = e.currentTarget;
                          if (el.scrollTop + el.clientHeight >= el.scrollHeight - 80) {
                            if (visibleDhcpLeases < filtered.length) {
                              setVisibleDhcpLeases((prev) => Math.min(prev + 25, filtered.length));
                            }
                          }
                        }}
                        className="divide-y divide-black/[0.04] overflow-y-auto max-h-[515px] sm:max-h-[600px] overscroll-contain pb-2"
                      >
                        {filtered.slice(0, visibleDhcpLeases).map((lease) => {
                          const status = (lease.status || 'unknown').toLowerCase();
                          const isBound = status === 'bound';
                          const isDynamic = lease.dynamic === true || lease.dynamic === 'true';
                          const hostDisplay = lease['host-name'] || lease.comment || 'Unknown Device';

                          return (
                            <div
                              key={lease['.id'] || lease.address}
                              onClick={() => setSelectedLease(lease)}
                              className="px-4 py-2.5 sm:px-5 sm:py-3 flex items-center justify-between gap-3 bg-white hover:bg-[#fbfbfd] active:bg-black/[0.02] transition-colors cursor-pointer group"
                            >
                              {/* Left Info: MAC Address (Top) with Badges, IP & Hostname underneath */}
                              <div className="min-w-0 flex-1">
                                <div className="flex items-center gap-1.5 sm:gap-2 flex-wrap">
                                  {/* MAC Address as top primary identifier */}
                                  <p className="font-mono font-bold text-xs sm:text-sm text-apple-text tracking-tight group-hover:text-apple-blue transition-colors">
                                    {lease['mac-address']}
                                  </p>

                                  {/* Non-bound Warning Badge (hanya tampil jika status bukan Bound, misal Waiting) */}
                                  {!isBound && status && status !== 'unknown' && (
                                    <span className="inline-flex items-center gap-1 font-mono text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-amber-500/10 text-amber-700 border border-amber-500/15 capitalize">
                                      <span className="h-1.5 w-1.5 rounded-full bg-amber-500 inline-block shrink-0" />
                                      {status}
                                    </span>
                                  )}

                                  {/* Dynamic vs Static Badge */}
                                  <span
                                    className={`font-mono text-[10px] px-1.5 py-0.5 rounded-md font-semibold ${
                                      isDynamic
                                        ? 'bg-slate-100 text-slate-600 border border-slate-200'
                                        : 'bg-purple-500/10 text-purple-700 border border-purple-500/20'
                                    }`}
                                  >
                                    {isDynamic ? 'Dynamic' : 'Static'}
                                  </span>
                                </div>

                                {/* Secondary Line: IP Address (Bold) • Hostname/Device • Server • Sisa Waktu */}
                                <div className="flex items-center gap-1.5 text-xs text-apple-subtext mt-1 flex-wrap">
                                  <span className="font-mono font-bold text-apple-text text-xs sm:text-sm">
                                    {lease.address}
                                  </span>
                                  <span>•</span>
                                  <span className="font-medium text-apple-subtext truncate max-w-[140px] sm:max-w-[220px]">
                                    {hostDisplay}
                                  </span>
                                  {lease.server && (
                                    <>
                                      <span>•</span>
                                      <span className="font-mono text-[11px] text-apple-subtext truncate max-w-[90px]">
                                        {lease.server}
                                      </span>
                                    </>
                                  )}
                                  {lease['expires-after'] && isBound && (
                                    <>
                                      <span>•</span>
                                      <span className="font-mono text-[11px] text-apple-subtext truncate">
                                        sisa {lease['expires-after']}
                                      </span>
                                    </>
                                  )}
                                </div>
                              </div>

                              {/* Right Action Group: [ Copy IP ] [ > ] */}
                              <div className="flex items-center gap-1.5 shrink-0 pl-1 border-l border-black/[0.04]">
                                {/* Copy IP Button */}
                                <button
                                  type="button"
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    handleCopyText(lease.address, 'Alamat IP');
                                  }}
                                  className="h-9 w-9 sm:h-8 sm:w-8 min-h-[44px] min-w-[44px] sm:min-h-[36px] sm:min-w-[36px] rounded-full bg-black/[0.03] text-apple-subtext hover:bg-apple-blue/10 hover:text-apple-blue hover:border-apple-blue/20 border border-black/[0.05] flex items-center justify-center transition-all active:scale-90"
                                  title="Salin Alamat IP"
                                  aria-label={`Salin IP ${lease.address}`}
                                >
                                  <Copy className="h-3.5 w-3.5 stroke-[2.2]" />
                                </button>

                                {/* Detail Chevron */}
                                <ChevronRight className="h-4 w-4 text-black/20 group-hover:text-apple-blue group-hover:translate-x-0.5 transition-all shrink-0 ml-0.5" />
                              </div>
                            </div>
                          );
                        })}

                        {filtered.length > visibleDhcpLeases && (
                          <div className="p-3 text-center border-t border-black/[0.04] bg-[#fbfbfd]">
                            <button
                              type="button"
                              onClick={() => setVisibleDhcpLeases((prev) => Math.min(prev + 50, filtered.length))}
                              className="w-full py-2.5 px-4 text-xs font-semibold text-apple-blue bg-apple-blue/10 hover:bg-apple-blue/15 active:scale-[0.98] rounded-xl transition-all min-h-[44px] flex items-center justify-center gap-1.5"
                            >
                              <ChevronDown className="h-4 w-4 stroke-[2.2]" />
                              <span>Muat Lebih Banyak ({filtered.length - visibleDhcpLeases} lagi)</span>
                              <span className="font-mono text-[11px] opacity-70">· Menampilkan {visibleDhcpLeases} dari {filtered.length}</span>
                            </button>
                          </div>
                        )}

                        {visibleDhcpLeases >= filtered.length && filtered.length > 25 && (
                          <div className="py-2.5 px-4 text-center border-t border-black/[0.04] bg-[#fbfbfd]/60 text-[11px] font-mono text-apple-subtext">
                            Semua {filtered.length} perangkat telah dimuat
                          </div>
                        )}
                      </div>
                    )}
                  </section>
                );
              })()}

              {/* MODAL DETAIL DHCP LEASE (APPLE iOS HIG STYLE) */}
              {selectedLease && (
                <div
                  className="relative z-50"
                  aria-labelledby="lease-modal-title"
                  role="dialog"
                  aria-modal="true"
                >
                  <div
                    className="fixed inset-0 bg-black/40 backdrop-blur-sm transition-opacity"
                    onClick={() => setSelectedLease(null)}
                  />

                  <div
                    className="fixed inset-0 z-50 w-screen overflow-y-auto"
                    onClick={() => setSelectedLease(null)}
                  >
                    <div className="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4">
                      <div
                        className="relative transform overflow-hidden rounded-t-[32px] sm:rounded-3xl bg-apple-card text-left shadow-[0_-10px_40px_rgba(0,0,0,0.14)] sm:shadow-ios-modal transition-all my-0 sm:my-auto w-full max-w-lg border-t sm:border border-black/[0.08] max-h-[92vh] sm:max-h-[85vh] flex flex-col animate-in slide-in-from-bottom duration-300 ease-out sm:zoom-in-95"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {/* iOS Drawer Grabber Handle */}
                        <div className="w-full pt-3 pb-1 flex justify-center sm:hidden bg-[#fbfbfd] shrink-0">
                          <div className="w-10 h-1.5 rounded-full bg-black/20" />
                        </div>

                        {/* Header Modal */}
                        <div className="px-5 pt-2 pb-3.5 sm:px-6 sm:pt-5 sm:pb-4 border-b border-black/[0.06] flex items-center justify-between bg-[#fbfbfd] shrink-0">
                          <div className="flex items-center gap-3">
                            <div className="h-10 w-10 rounded-2xl bg-apple-blue/10 text-apple-blue flex items-center justify-center font-bold shrink-0">
                              <Network className="h-5 w-5 stroke-[2.2]" />
                            </div>
                            <div>
                              <h3
                                className="text-base font-bold text-apple-text tracking-tight"
                                id="lease-modal-title"
                              >
                                {selectedLease['host-name'] || selectedLease.address}
                              </h3>
                              <p className="text-xs text-apple-subtext font-medium font-mono">
                                DHCP Lease · {selectedLease.server || 'All Servers'}
                              </p>
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => setSelectedLease(null)}
                            className="text-apple-subtext hover:text-apple-text rounded-full p-2 bg-black/[0.04] hover:bg-black/[0.08] transition-all min-h-[36px] min-w-[36px] flex items-center justify-center"
                            title="Tutup modal"
                            aria-label="Tutup modal"
                          >
                            <X className="h-4 w-4 stroke-[2.2]" />
                          </button>
                        </div>

                        {/* Content Body: Inset Grouped Details */}
                        <div className="p-5 sm:p-6 space-y-4 overflow-y-auto overscroll-contain flex-1">
                          <div className="bg-apple-bg rounded-2xl p-4 space-y-3 border border-black/[0.04]">
                            <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                              <span className="text-apple-subtext font-medium">Alamat IP:</span>
                              <div className="flex items-center gap-2">
                                <span className="font-mono font-bold text-apple-text text-sm">
                                  {selectedLease.address}
                                </span>
                                <button
                                  type="button"
                                  onClick={() => handleCopyText(selectedLease.address, 'Alamat IP')}
                                  className="h-6 w-6 rounded-md bg-white border border-black/[0.08] text-apple-subtext hover:text-apple-blue flex items-center justify-center active:scale-95 transition-all"
                                  title="Salin IP"
                                >
                                  <Copy className="h-3 w-3" />
                                </button>
                              </div>
                            </div>

                            <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                              <span className="text-apple-subtext font-medium">MAC Address:</span>
                              <div className="flex items-center gap-2">
                                <span className="font-mono font-semibold text-apple-text">
                                  {selectedLease['mac-address']}
                                </span>
                                <button
                                  type="button"
                                  onClick={() => handleCopyText(selectedLease['mac-address'], 'MAC Address')}
                                  className="h-6 w-6 rounded-md bg-white border border-black/[0.08] text-apple-subtext hover:text-apple-blue flex items-center justify-center active:scale-95 transition-all"
                                  title="Salin MAC"
                                >
                                  <Copy className="h-3 w-3" />
                                </button>
                              </div>
                            </div>

                            <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                              <span className="text-apple-subtext font-medium">Host Name:</span>
                              <span className="font-semibold text-apple-text">
                                {selectedLease['host-name'] || '-'}
                              </span>
                            </div>

                            <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                              <span className="text-apple-subtext font-medium">Status:</span>
                              <span className="font-mono font-bold uppercase text-[11px] px-2 py-0.5 rounded-md bg-emerald-500/10 text-emerald-700">
                                {selectedLease.status || 'unknown'}
                              </span>
                            </div>

                            <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                              <span className="text-apple-subtext font-medium">Tipe:</span>
                              <span className="font-mono font-semibold text-xs text-apple-text">
                                {selectedLease.dynamic === true || selectedLease.dynamic === 'true'
                                  ? 'Dynamic Lease'
                                  : 'Static Reservation'}
                              </span>
                            </div>

                            <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                              <span className="text-apple-subtext font-medium">DHCP Server:</span>
                              <span className="font-mono text-apple-text font-semibold">
                                {selectedLease.server || '-'}
                              </span>
                            </div>

                            {selectedLease['expires-after'] && (
                              <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                                <span className="text-apple-subtext font-medium">Expires After:</span>
                                <span className="font-mono text-apple-text">
                                  {selectedLease['expires-after']}
                                </span>
                              </div>
                            )}

                            {selectedLease['last-seen'] && (
                              <div className="flex items-center justify-between text-xs py-1 border-b border-black/[0.04]">
                                <span className="text-apple-subtext font-medium">Last Seen:</span>
                                <span className="font-mono text-apple-text">
                                  {selectedLease['last-seen']}
                                </span>
                              </div>
                            )}

                            {selectedLease.comment && (
                              <div className="flex items-center justify-between text-xs py-1">
                                <span className="text-apple-subtext font-medium">Komentar:</span>
                                <span className="italic text-apple-text">
                                  {selectedLease.comment}
                                </span>
                              </div>
                            )}
                          </div>

                          {/* Action Buttons */}
                          <div className="space-y-2.5 pt-2 pb-[calc(1.25rem+env(safe-area-inset-bottom,0px))] sm:pb-0">
                            {/* Baris 1: Jadikan Static / Lepas Static & Buat Akun PPPoE */}
                            <div className="grid grid-cols-2 gap-2">
                              {selectedLease.dynamic === true || selectedLease.dynamic === 'true' ? (
                                <button
                                  type="button"
                                  onClick={() => handleMakeStaticLease(selectedLease)}
                                  className="py-3 px-3 rounded-2xl font-semibold text-xs flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px] bg-purple-600 text-white shadow-xs hover:bg-purple-700 cursor-pointer"
                                  title="Jadikan IP-MAC Static (Reservasi)"
                                >
                                  <Lock className="h-4 w-4 shrink-0" />
                                  <span className="truncate">Jadikan Static</span>
                                </button>
                              ) : (
                                <button
                                  type="button"
                                  onClick={() => handleReleaseStaticLease(selectedLease)}
                                  className="py-3 px-3 rounded-2xl font-semibold text-xs flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px] bg-amber-600 text-white shadow-xs hover:bg-amber-700 cursor-pointer"
                                  title="Lepas reservasi static agar kembali dynamic"
                                >
                                  <Unlock className="h-4 w-4 shrink-0" />
                                  <span className="truncate">Lepas Static</span>
                                </button>
                              )}

                              <button
                                type="button"
                                onClick={() => {
                                  // Prefill ke PPPoE Modal
                                  const suggestedName = (selectedLease['host-name'] || selectedLease.address)
                                    .toLowerCase()
                                    .replace(/[^a-z0-9_-]/g, '');
                                  setNewUserName(suggestedName);
                                  setNewUserComment(`MAC: ${selectedLease['mac-address']}`);
                                  setSelectedLease(null);
                                  setActiveTab('pppoe');
                                  setIsAddUserModalOpen(true);
                                }}
                                className="py-3 px-3 rounded-2xl bg-apple-blue/10 text-apple-blue font-semibold text-xs hover:bg-apple-blue/20 flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px]"
                              >
                                <Users className="h-4 w-4 shrink-0" />
                                <span className="truncate">Buat Akun PPPoE</span>
                              </button>
                            </div>

                            {/* Baris 2: Hapus & Tutup */}
                            <div className="grid grid-cols-2 gap-2">
                              <div className="relative select-none">
                                <button
                                  type="button"
                                  onMouseDown={() => startDhcpDeleteHold(selectedLease)}
                                  onMouseUp={cancelDhcpDeleteHold}
                                  onMouseLeave={cancelDhcpDeleteHold}
                                  onTouchStart={() => startDhcpDeleteHold(selectedLease)}
                                  onTouchEnd={cancelDhcpDeleteHold}
                                  onTouchCancel={cancelDhcpDeleteHold}
                                  onContextMenu={(e) => e.preventDefault()}
                                  className="w-full relative overflow-hidden py-3 px-3 rounded-2xl bg-rose-500/10 text-rose-600 font-semibold text-xs hover:bg-rose-500/15 border border-rose-500/20 flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px]"
                                  title="Tahan 0.5 detik untuk menghapus lease"
                                >
                                  {dhcpDeleteHoldId === selectedLease['.id'] && dhcpDeleteHoldProgress > 0 && (
                                    <div
                                      className="absolute inset-0 bg-rose-600 transition-all duration-75 pointer-events-none"
                                      style={{ width: `${dhcpDeleteHoldProgress}%` }}
                                    />
                                  )}
                                  <Trash2
                                    className={`h-4 w-4 stroke-[2.2] relative z-10 shrink-0 ${
                                      dhcpDeleteHoldId === selectedLease['.id'] && dhcpDeleteHoldProgress > 30
                                        ? 'text-white'
                                        : 'text-rose-600'
                                    }`}
                                  />
                                  <span
                                    className={`relative z-10 truncate ${
                                      dhcpDeleteHoldId === selectedLease['.id'] && dhcpDeleteHoldProgress > 30
                                        ? 'text-white'
                                        : 'text-rose-600'
                                    }`}
                                  >
                                    {dhcpDeleteHoldId === selectedLease['.id'] && dhcpDeleteHoldProgress > 0
                                      ? 'Tahan...'
                                      : 'Hapus'}
                                  </span>
                                </button>
                              </div>

                              <button
                                type="button"
                                onClick={() => setSelectedLease(null)}
                                className="w-full py-3 px-3 rounded-2xl bg-black/[0.05] hover:bg-black/[0.10] text-apple-subtext hover:text-apple-text font-semibold text-xs flex items-center justify-center gap-1.5 active:scale-[0.98] transition-all min-h-[48px] border border-black/[0.06]"
                              >
                                <X className="h-4 w-4 shrink-0" />
                                <span className="truncate">Tutup</span>
                              </button>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </motion.div>
          ) : (
            /* ============================================================= */
            /* HALAMAN DASHBOARD (SYSTEM INFO MIKROTIK - APPLE HIG STYLE)   */
            /* ============================================================= */
            <motion.div
              key="tab-beranda"
              variants={pageVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              className="space-y-3 sm:space-y-4 w-full max-w-4xl mx-auto"
            >
              {/* Top Router Status & Latency Banner */}
              <div className="bg-apple-card rounded-2xl border border-black/[0.06] p-3 sm:px-4 sm:py-3 shadow-apple flex items-center justify-between gap-3">
                <div className="flex items-center gap-2.5 min-w-0">
                  <span className="relative flex h-2.5 w-2.5 shrink-0">
                    <span
                      className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${
                        syncStatus === 'connected' ? 'bg-emerald-400' : syncStatus === 'syncing' ? 'bg-amber-400' : 'bg-rose-400'
                      }`}
                    />
                    <span
                      className={`relative inline-flex rounded-full h-2.5 w-2.5 ${
                        syncStatus === 'connected' ? 'bg-emerald-500' : syncStatus === 'syncing' ? 'bg-amber-500' : 'bg-rose-500'
                      }`}
                    />
                  </span>
                  <div className="min-w-0 flex items-center gap-2">
                    <span className="text-xs sm:text-sm font-bold text-apple-text truncate">
                      {metrics.identity || 'MikroTik Router'}
                    </span>
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-black/[0.04] text-apple-subtext font-medium hidden sm:inline-block truncate max-w-[150px]">
                      {metrics.boardModel !== '-' ? metrics.boardModel : 'RouterOS'}
                    </span>
                  </div>
                </div>

                {/* Respon API / Latency Indicator - Angka saja tanpa badge/pill */}
                <div className="flex items-center gap-1.5 shrink-0">
                  <span className="text-xs font-medium text-apple-subtext">
                    Respon API:
                  </span>
                  <span
                    className={`font-mono text-xs sm:text-sm font-bold ${
                      lastLatency === null
                        ? 'text-apple-subtext'
                        : lastLatency < 150
                        ? 'text-emerald-600'
                        : lastLatency < 400
                        ? 'text-amber-600'
                        : 'text-rose-600'
                    }`}
                  >
                    {lastLatency !== null ? `${lastLatency} ms` : '-'}
                  </span>
                </div>
              </div>

              {/* Metric Gauges Grid (CPU, RAM, HDD) - Adaptif Hijau, Kuning, Merah */}
              <div className="grid grid-cols-3 gap-2 sm:gap-4">
                {/* 1. CPU */}
                {(() => {
                  const cpuPercent = metrics.cpuLoad;
                  const isCritical = cpuPercent >= 80;
                  const isWarning = cpuPercent >= 50 && !isCritical;
                  const badgeClass = isCritical
                    ? 'bg-rose-500/10 text-rose-600'
                    : isWarning
                    ? 'bg-amber-500/10 text-amber-600'
                    : 'bg-emerald-500/10 text-emerald-600';

                  return (
                    <div className="bg-apple-card rounded-2xl sm:rounded-[24px] border border-black/[0.06] p-2.5 sm:p-5 shadow-apple flex flex-col justify-between">
                      {/* Card Header */}
                      <div className="flex items-center justify-between mb-1">
                        <div className="flex items-center gap-1.5 sm:gap-2 min-w-0">
                          <div className={`h-6 w-6 sm:h-8 sm:w-8 rounded-lg sm:rounded-xl flex items-center justify-center shrink-0 ${badgeClass}`}>
                            <Cpu className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                          </div>
                          <span className="text-[10px] sm:text-xs font-bold text-apple-subtext uppercase tracking-wider truncate">
                            CPU
                          </span>
                        </div>
                        <span className="hidden sm:inline-block text-xs font-mono font-semibold px-2 py-0.5 rounded-full bg-black/[0.04] text-apple-text">
                          {metrics.cpuCount ? `${metrics.cpuCount} Cores` : '-'}
                        </span>
                      </div>

                      {/* Smooth Arc Gauge dengan Gradasi Hijau / Kuning / Merah Adaptif */}
                      <SmoothGauge
                        id="gauge-cpu"
                        percent={cpuPercent}
                        secondaryText={metrics.cpuFreq ? `${metrics.cpuFreq} MHz` : (metrics.cpuCount ? `${metrics.cpuLoad}%` : '0%')}
                        gradientStops={getHealthStops(cpuPercent)}
                      />

                      {/* Footer Stats: Core X Core */}
                      <div className="pt-1.5 sm:pt-2 border-t border-black/[0.04] flex items-center justify-between text-[10px] sm:text-[11px] text-apple-subtext font-medium gap-1">
                        <span className="shrink-0">Core</span>
                        <span className="font-mono font-bold text-apple-text text-right truncate">
                          {metrics.cpuCount ? `${metrics.cpuCount} Core` : '-'}
                        </span>
                      </div>
                    </div>
                  );
                })()}

                {/* 2. RAM */}
                {(() => {
                  const ramPct =
                    metrics.totalMemoryMb > 0
                      ? Math.round((metrics.usedMemoryMb / metrics.totalMemoryMb) * 100)
                      : 0;
                  const isCritical = ramPct >= 80;
                  const isWarning = ramPct >= 50 && !isCritical;
                  const badgeClass = isCritical
                    ? 'bg-rose-500/10 text-rose-600'
                    : isWarning
                    ? 'bg-amber-500/10 text-amber-600'
                    : 'bg-emerald-500/10 text-emerald-600';

                  return (
                    <div className="bg-apple-card rounded-2xl sm:rounded-[24px] border border-black/[0.06] p-2.5 sm:p-5 shadow-apple flex flex-col justify-between">
                      {/* Card Header */}
                      <div className="flex items-center justify-between mb-1">
                        <div className="flex items-center gap-1.5 sm:gap-2 min-w-0">
                          <div className={`h-6 w-6 sm:h-8 sm:w-8 rounded-lg sm:rounded-xl flex items-center justify-center shrink-0 ${badgeClass}`}>
                            <Activity className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                          </div>
                          <span className="text-[10px] sm:text-xs font-bold text-apple-subtext uppercase tracking-wider truncate">
                            RAM
                          </span>
                        </div>
                        <span className="hidden sm:inline-block text-xs font-mono font-semibold px-2 py-0.5 rounded-full bg-black/[0.04] text-apple-text">
                          {metrics.totalMemoryMb ? `${metrics.totalMemoryMb} MB` : '-'}
                        </span>
                      </div>

                      {/* Smooth Arc Gauge dengan Gradasi Hijau / Kuning / Merah Adaptif */}
                      <SmoothGauge
                        id="gauge-ram"
                        percent={ramPct}
                        secondaryText={metrics.totalMemoryMb ? `${metrics.usedMemoryMb} MB` : '0 MB'}
                        gradientStops={getHealthStops(ramPct)}
                      />

                      {/* Footer Stats: Sisa X MB */}
                      <div className="pt-1.5 sm:pt-2 border-t border-black/[0.04] flex items-center justify-between text-[10px] sm:text-[11px] text-apple-subtext font-medium gap-1">
                        <span className="shrink-0">Sisa</span>
                        <span className="font-mono font-bold text-apple-text text-right truncate">
                          {metrics.totalMemoryMb ? `${metrics.freeMemoryMb} MB` : '-'}
                        </span>
                      </div>
                    </div>
                  );
                })()}

                {/* 3. HDD */}
                {(() => {
                  const hddPct =
                    metrics.totalHddMb > 0
                      ? Math.round((metrics.usedHddMb / metrics.totalHddMb) * 100)
                      : 0;
                  const isCritical = hddPct >= 80;
                  const isWarning = hddPct >= 50 && !isCritical;
                  const badgeClass = isCritical
                    ? 'bg-rose-500/10 text-rose-600'
                    : isWarning
                    ? 'bg-amber-500/10 text-amber-600'
                    : 'bg-emerald-500/10 text-emerald-600';

                  return (
                    <div className="bg-apple-card rounded-2xl sm:rounded-[24px] border border-black/[0.06] p-2.5 sm:p-5 shadow-apple flex flex-col justify-between">
                      {/* Card Header */}
                      <div className="flex items-center justify-between mb-1">
                        <div className="flex items-center gap-1.5 sm:gap-2 min-w-0">
                          <div className={`h-6 w-6 sm:h-8 sm:w-8 rounded-lg sm:rounded-xl flex items-center justify-center shrink-0 ${badgeClass}`}>
                            <HardDrive className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                          </div>
                          <span className="text-[10px] sm:text-xs font-bold text-apple-subtext uppercase tracking-wider truncate">
                            HDD
                          </span>
                        </div>
                        <span className="hidden sm:inline-block text-xs font-mono font-semibold px-2 py-0.5 rounded-full bg-black/[0.04] text-apple-text">
                          {metrics.totalHddMb ? `${metrics.totalHddMb} MB` : '-'}
                        </span>
                      </div>

                      {/* Smooth Arc Gauge dengan Gradasi Hijau / Kuning / Merah Adaptif */}
                      <SmoothGauge
                        id="gauge-hdd"
                        percent={hddPct}
                        secondaryText={metrics.totalHddMb ? `${metrics.usedHddMb} MB` : '0 MB'}
                        gradientStops={getHealthStops(hddPct)}
                      />

                      {/* Footer Stats: Sisa X MB */}
                      <div className="pt-1.5 sm:pt-2 border-t border-black/[0.04] flex items-center justify-between text-[10px] sm:text-[11px] text-apple-subtext font-medium gap-1">
                        <span className="shrink-0">Sisa</span>
                        <span className="font-mono font-bold text-apple-text text-right truncate">
                          {metrics.totalHddMb ? `${metrics.freeHddMb} MB` : '-'}
                        </span>
                      </div>
                    </div>
                  );
                })()}
              </div>

              {/* Mini Telemetry Bar: Suhu, Voltase, PPPoE Aktif, Hotspot Aktif */}
              {(() => {
                const tempHealth = getTemperatureHealth(metrics.temperature);
                const voltHealth = getVoltageHealth(metrics.voltage);

                return (
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-3">
                    {/* 1. Suhu Router (Adaptif: Normal / Hangat / Overheat Merah) */}
                    <div
                      className={`bg-apple-card rounded-2xl border ${tempHealth.cardBorder} p-2.5 sm:p-3 shadow-apple flex items-center gap-2.5 sm:gap-3 transition-colors`}
                    >
                      <div
                        className={`h-8 w-8 sm:h-9 sm:w-9 rounded-xl flex items-center justify-center shrink-0 ${tempHealth.badgeBg}`}
                      >
                        <Thermometer className="h-4 w-4" />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[10px] font-bold text-apple-subtext uppercase tracking-wider truncate">
                          Suhu Router
                        </div>
                        <div className="font-mono text-xs sm:text-sm font-bold flex items-center gap-1">
                          <span className={tempHealth.colorText}>
                            {metrics.temperature !== null ? `${metrics.temperature}°C` : 'N/A'}
                          </span>
                          <span className={`text-[10px] font-semibold ${tempHealth.colorText}`}>
                            {tempHealth.status}
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* 2. Tegangan Daya (Adaptif: Stabil / Fluktuasi / Undervolt Merah / Overvolt Merah) */}
                    <div
                      className={`bg-apple-card rounded-2xl border ${voltHealth.cardBorder} p-2.5 sm:p-3 shadow-apple flex items-center gap-2.5 sm:gap-3 transition-colors`}
                    >
                      <div
                        className={`h-8 w-8 sm:h-9 sm:w-9 rounded-xl flex items-center justify-center shrink-0 ${voltHealth.badgeBg}`}
                      >
                        <Zap className="h-4 w-4" />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[10px] font-bold text-apple-subtext uppercase tracking-wider truncate">
                          Tegangan
                        </div>
                        <div className="font-mono text-xs sm:text-sm font-bold flex items-center gap-1">
                          <span className={voltHealth.colorText}>
                            {metrics.voltage !== null ? `${metrics.voltage} V` : 'N/A'}
                          </span>
                          <span className={`text-[10px] font-semibold ${voltHealth.colorText}`}>
                            {voltHealth.status}
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* 3. PPPoE (100 / 8 Isolir) */}
                    <div className="bg-apple-card rounded-2xl border border-black/[0.06] p-2.5 sm:p-3 shadow-apple flex items-center gap-2.5 sm:gap-3">
                      <div className="h-8 w-8 sm:h-9 sm:w-9 rounded-xl bg-apple-blue/10 text-apple-blue flex items-center justify-center shrink-0">
                        <Users className="h-4 w-4" />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[10px] font-bold text-apple-subtext uppercase tracking-wider truncate">
                          PPPoE
                        </div>
                        <div className="font-mono text-xs sm:text-sm font-bold text-apple-text flex items-center gap-1">
                          <span>{metrics.pppoeActive}</span>
                          <span className="text-apple-subtext font-normal text-[11px]">
                            / {metrics.pppoeIsolir}
                          </span>
                          <span className="text-[10px] text-rose-600 font-semibold ml-0.5">
                            Isolir
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* 4. Hotspot (48 / 100 48 ini yg aktif) */}
                    <div className="bg-apple-card rounded-2xl border border-black/[0.06] p-2.5 sm:p-3 shadow-apple flex items-center gap-2.5 sm:gap-3">
                      <div className="h-8 w-8 sm:h-9 sm:w-9 rounded-xl bg-indigo-500/10 text-indigo-600 flex items-center justify-center shrink-0">
                        <Wifi className="h-4 w-4" />
                      </div>
                      <div className="min-w-0">
                        <div className="text-[10px] font-bold text-apple-subtext uppercase tracking-wider truncate">
                          Hotspot
                        </div>
                        <div className="font-mono text-xs sm:text-sm font-bold text-apple-text flex items-center gap-1">
                          <span>{metrics.hotspotActive}</span>
                          <span className="text-apple-subtext font-normal text-[11px]">
                            / {metrics.hotspotTotal}
                          </span>
                          <span className="text-[10px] text-emerald-600 font-semibold ml-0.5">
                            Aktif
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })()}

              {/* Live Graphic Traffic Card with Select Interface */}
              <LiveTrafficCard
                liveInterfaces={liveInterfaces}
                isLive={syncStatus === 'connected'}
              />

              {/* Detailed Specs Card (Apple Grouped Inset List) */}
              <section className="bg-apple-card rounded-[26px] sm:rounded-3xl border border-black/[0.06] shadow-apple overflow-hidden">
                <div className="p-4 sm:p-5 border-b border-black/[0.04] bg-[#fbfbfd]">
                  <h3 className="text-xs font-bold text-apple-subtext uppercase tracking-wider">
                    Spesifikasi Perangkat Keras & Sistem
                  </h3>
                </div>

                <div className="divide-y divide-black/[0.04] text-xs sm:text-sm">
                  <div className="p-4 sm:px-5 flex items-center justify-between gap-4">
                    <span className="text-apple-subtext font-medium">Identity MikroTik</span>
                    <span className="font-mono font-semibold text-apple-text text-right truncate">
                      {metrics.identity}
                    </span>
                  </div>

                  <div className="p-4 sm:px-5 flex items-center justify-between gap-4">
                    <span className="text-apple-subtext font-medium">Uptime Sistem</span>
                    <span className="font-mono font-semibold text-apple-text text-right truncate">
                      {metrics.uptime}
                    </span>
                  </div>

                  <div className="p-4 sm:px-5 flex items-center justify-between gap-4">
                    <span className="text-apple-subtext font-medium">Time MikroTik</span>
                    <span className="font-mono font-semibold text-apple-text text-right truncate">
                      {metrics.time}
                    </span>
                  </div>

                  <div className="p-4 sm:px-5 flex items-center justify-between gap-4">
                    <span className="text-apple-subtext font-medium">Model Board</span>
                    <span className="font-mono font-semibold text-apple-text text-right truncate">
                      {metrics.boardModel}
                    </span>
                  </div>

                  <div className="p-4 sm:px-5 flex items-center justify-between gap-4">
                    <span className="text-apple-subtext font-medium">Arsitektur Hardware</span>
                    <span className="font-mono font-semibold text-apple-text text-right truncate">
                      {metrics.architecture}
                    </span>
                  </div>

                  <div className="p-4 sm:px-5 flex items-center justify-between gap-4">
                    <span className="text-apple-subtext font-medium">Versi RouterOS</span>
                    <span className="font-mono font-semibold text-apple-text text-right truncate">
                      {metrics.rosVersion}
                    </span>
                  </div>

                  <div className="p-4 sm:px-5 flex items-center justify-between gap-4">
                    <span className="text-apple-subtext font-medium">Kondisi Bad Blocks</span>
                    <span className="font-mono font-semibold text-emerald-600 text-right truncate">
                      {metrics.badBlocks}
                    </span>
                  </div>

                  <div className="p-4 sm:px-5 flex items-center justify-between gap-4">
                    <span className="text-apple-subtext font-medium">Latensi Respon API</span>
                    <span
                      className={`font-mono font-semibold text-right truncate ${
                        lastLatency === null
                          ? 'text-apple-text'
                          : lastLatency < 150
                          ? 'text-emerald-600'
                          : lastLatency < 400
                          ? 'text-amber-600'
                          : 'text-rose-600'
                      }`}
                    >
                      {lastLatency !== null ? `${lastLatency} ms` : '-'}
                    </span>
                  </div>
                </div>
              </section>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </main>

      {/* MODAL KONFIRMASI LOGOUT (APPLE iOS HIG) */}
      <AnimatePresence>
        {isLogoutConfirmOpen && (
          <div
            className="relative z-50"
            aria-labelledby="logout-confirm-title"
            role="dialog"
            aria-modal="true"
          >
            <motion.div
              variants={modalBackdropVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              className="fixed inset-0 bg-black/40 backdrop-blur-sm"
              onClick={() => setIsLogoutConfirmOpen(false)}
            />
            <div className="fixed inset-0 z-50 overflow-y-auto">
              <div className="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4 text-center">
                <motion.div
                  variants={modalSheetVariants}
                  initial="initial"
                  animate="animate"
                  exit="exit"
                  className="relative transform overflow-hidden rounded-t-[32px] sm:rounded-3xl bg-apple-card text-left shadow-[0_-10px_40px_rgba(0,0,0,0.14)] sm:shadow-ios-modal w-full sm:max-w-md flex flex-col border-t sm:border border-black/[0.08]"
                >
                  {/* iOS Drawer Grabber Handle */}
                  <div className="w-full pt-3 pb-1 flex justify-center sm:hidden bg-[#fbfbfd] shrink-0">
                    <div className="w-10 h-1.5 rounded-full bg-black/20" />
                  </div>

                  <div className="p-6 text-center">
                    <div className="h-12 w-12 rounded-full bg-rose-500/10 text-rose-600 mx-auto flex items-center justify-center mb-4">
                      <LogOut className="h-6 w-6 stroke-[2.2]" />
                    </div>
                    <h3 id="logout-confirm-title" className="text-base sm:text-lg font-bold text-apple-text tracking-tight mb-2">
                      Keluar dari Akun?
                    </h3>
                    <p className="text-xs sm:text-sm text-apple-subtext leading-relaxed mb-6">
                      Apakah Anda yakin ingin mengakhiri sesi monitor saat ini? Anda perlu memasukkan kembali ID User dan Password untuk masuk.
                    </p>

                    <div className="flex items-center gap-3 pb-[calc(0.5rem+env(safe-area-inset-bottom,0px))] sm:pb-0">
                      <button
                        type="button"
                        onClick={() => setIsLogoutConfirmOpen(false)}
                        className="flex-1 min-h-[48px] rounded-2xl bg-black/[0.05] hover:bg-black/[0.08] active:scale-[0.98] text-apple-text font-semibold text-xs sm:text-sm transition-all tap-spring"
                      >
                        Batal
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setIsLogoutConfirmOpen(false);
                          handleLogout();
                        }}
                        className="flex-1 min-h-[48px] rounded-2xl bg-rose-600 hover:bg-rose-700 active:scale-[0.98] text-white font-semibold text-xs sm:text-sm shadow-xs transition-all flex items-center justify-center gap-1.5 tap-spring"
                      >
                        <LogOut className="h-4 w-4 stroke-[2.2]" />
                        <span>Ya, Keluar</span>
                      </button>
                    </div>
                  </div>
                </motion.div>
              </div>
            </div>
          </div>
        )}
      </AnimatePresence>

      {/* MODAL KONFIRMASI HAPUS ROUTER MIKROTIK (APPLE iOS HIG) */}
      <AnimatePresence>
        {deletingRouterTarget && (
          <div
            className="relative z-50"
            aria-labelledby="delete-router-title"
            role="dialog"
            aria-modal="true"
          >
            <motion.div
              variants={modalBackdropVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              className="fixed inset-0 bg-black/40 backdrop-blur-sm"
              onClick={() => setDeletingRouterTarget(null)}
            />
            <div className="fixed inset-0 z-50 overflow-y-auto">
              <div className="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4 text-center">
                <motion.div
                  variants={modalSheetVariants}
                  initial="initial"
                  animate="animate"
                  exit="exit"
                  className="relative transform overflow-hidden rounded-t-[32px] sm:rounded-3xl bg-apple-card text-left shadow-[0_-10px_40px_rgba(0,0,0,0.14)] sm:shadow-ios-modal w-full sm:max-w-md flex flex-col border-t sm:border border-black/[0.08]"
                >
                  {/* iOS Drawer Grabber Handle */}
                  <div className="w-full pt-3 pb-1 flex justify-center sm:hidden bg-[#fbfbfd] shrink-0">
                    <div className="w-10 h-1.5 rounded-full bg-black/20" />
                  </div>

                  <div className="p-6 text-center">
                    <div className="h-12 w-12 rounded-full bg-rose-500/10 text-rose-600 mx-auto flex items-center justify-center mb-4">
                      <Trash2 className="h-6 w-6 stroke-[2.2]" />
                    </div>
                    <h3 id="delete-router-title" className="text-base sm:text-lg font-bold text-apple-text tracking-tight mb-2">
                      Hapus Konfigurasi Router?
                    </h3>
                    <p className="text-xs sm:text-sm text-apple-subtext leading-relaxed mb-3">
                      Anda akan menghapus router <strong className="font-mono text-apple-text">{deletingRouterTarget.ip}:{deletingRouterTarget.port}</strong> ({deletingRouterTarget.user}) dari daftar FNet.
                    </p>
                    <p className="text-[11px] text-amber-600 bg-amber-500/10 border border-amber-500/20 rounded-xl p-2.5 mb-6 text-left">
                      Kredensial router yang tersimpan di perangkat lokal Anda akan dihapus. Perangkat fisik MikroTik tidak akan terpengaruh.
                    </p>

                    <div className="flex items-center gap-3 pb-[calc(0.5rem+env(safe-area-inset-bottom,0px))] sm:pb-0">
                      <button
                        type="button"
                        onClick={() => setDeletingRouterTarget(null)}
                        className="flex-1 min-h-[48px] rounded-2xl bg-black/[0.05] hover:bg-black/[0.08] active:scale-[0.98] text-apple-text font-semibold text-xs sm:text-sm transition-all tap-spring"
                      >
                        Batal
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          const targetId = deletingRouterTarget.id;
                          setDeletingRouterTarget(null);
                          handleDeleteMikrotik(targetId);
                        }}
                        className="flex-1 min-h-[48px] rounded-2xl bg-rose-600 hover:bg-rose-700 active:scale-[0.98] text-white font-semibold text-xs sm:text-sm shadow-xs transition-all flex items-center justify-center gap-1.5 tap-spring"
                      >
                        <Trash2 className="h-4 w-4 stroke-[2.2]" />
                        <span>Hapus Router</span>
                      </button>
                    </div>
                  </div>
                </motion.div>
              </div>
            </div>
          </div>
        )}
      </AnimatePresence>

      {/* Mobile Style Bottom Bar */}
      <nav
        aria-label="Navigasi Utama"
        className={`fixed bottom-0 left-0 right-0 z-30 bg-white/90 backdrop-blur-xl saturate-150 border-t border-black/[0.05] shadow-[0_-4px_16px_rgba(0,0,0,0.04)] pb-[env(safe-area-inset-bottom)] shrink-0 transition-transform duration-200 ease-out ${
          isKeyboardOpen ? 'translate-y-full opacity-0 pointer-events-none' : 'translate-y-0 opacity-100'
        }`}
      >
        <div className="max-w-lg mx-auto grid grid-cols-5 h-14 px-1 sm:px-2">
          <motion.button
            type="button"
            whileTap={{ scale: 0.92 }}
            transition={figmaSpring.quick}
            onClick={() => setActiveTab('beranda')}
            aria-label="Dashboard"
            aria-current={activeTab === 'beranda' ? 'page' : undefined}
            className={`relative flex flex-col items-center justify-center min-h-[48px] py-1 my-1 rounded-xl transition-colors select-none ${
              activeTab === 'beranda'
                ? 'text-apple-blue font-semibold'
                : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.03]'
            }`}
          >
            {activeTab === 'beranda' && (
              <motion.div
                layoutId="bottomNavActivePill"
                className="absolute inset-0 bg-apple-blue/[0.09] rounded-xl z-0"
                transition={figmaSpring.quick}
              />
            )}
            <Home className="h-5 w-5 relative z-10" />
            <span className="text-[10px] sm:text-[11px] mt-0.5 relative z-10">Dashboard</span>
          </motion.button>

          <motion.button
            type="button"
            whileTap={{ scale: 0.92 }}
            transition={figmaSpring.quick}
            onClick={() => setActiveTab('pppoe')}
            aria-label="PPPoE"
            aria-current={activeTab === 'pppoe' ? 'page' : undefined}
            className={`relative flex flex-col items-center justify-center min-h-[48px] py-1 my-1 rounded-xl transition-colors select-none ${
              activeTab === 'pppoe'
                ? 'text-apple-blue font-semibold'
                : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.03]'
            }`}
          >
            {activeTab === 'pppoe' && (
              <motion.div
                layoutId="bottomNavActivePill"
                className="absolute inset-0 bg-apple-blue/[0.09] rounded-xl z-0"
                transition={figmaSpring.quick}
              />
            )}
            <Users className="h-5 w-5 relative z-10" />
            <span className="text-[10px] sm:text-[11px] mt-0.5 relative z-10">PPPoE</span>
          </motion.button>

          <motion.button
            type="button"
            whileTap={{ scale: 0.92 }}
            transition={figmaSpring.quick}
            onClick={() => setActiveTab('hotspot')}
            aria-label="Hotspot"
            aria-current={activeTab === 'hotspot' ? 'page' : undefined}
            className={`relative flex flex-col items-center justify-center min-h-[48px] py-1 my-1 rounded-xl transition-colors select-none ${
              activeTab === 'hotspot'
                ? 'text-apple-blue font-semibold'
                : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.03]'
            }`}
          >
            {activeTab === 'hotspot' && (
              <motion.div
                layoutId="bottomNavActivePill"
                className="absolute inset-0 bg-apple-blue/[0.09] rounded-xl z-0"
                transition={figmaSpring.quick}
              />
            )}
            <Wifi className="h-5 w-5 relative z-10" />
            <span className="text-[10px] sm:text-[11px] mt-0.5 relative z-10">Hotspot</span>
          </motion.button>

          <motion.button
            type="button"
            whileTap={{ scale: 0.92 }}
            transition={figmaSpring.quick}
            onClick={() => setActiveTab('dhcp')}
            aria-label="DHCP Leases"
            aria-current={activeTab === 'dhcp' ? 'page' : undefined}
            className={`relative flex flex-col items-center justify-center min-h-[48px] py-1 my-1 rounded-xl transition-colors select-none ${
              activeTab === 'dhcp'
                ? 'text-apple-blue font-semibold'
                : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.03]'
            }`}
          >
            {activeTab === 'dhcp' && (
              <motion.div
                layoutId="bottomNavActivePill"
                className="absolute inset-0 bg-apple-blue/[0.09] rounded-xl z-0"
                transition={figmaSpring.quick}
              />
            )}
            <Network className="h-5 w-5 relative z-10" />
            <span className="text-[10px] sm:text-[11px] mt-0.5 relative z-10">DHCP</span>
          </motion.button>

          <motion.button
            type="button"
            whileTap={{ scale: 0.92 }}
            transition={figmaSpring.quick}
            onClick={() => setActiveTab('pengaturan')}
            aria-label="Pengaturan"
            aria-current={activeTab === 'pengaturan' ? 'page' : undefined}
            className={`relative flex flex-col items-center justify-center min-h-[48px] py-1 my-1 rounded-xl transition-colors select-none ${
              activeTab === 'pengaturan'
                ? 'text-apple-blue font-semibold'
                : 'text-apple-subtext hover:text-apple-text hover:bg-black/[0.03]'
            }`}
          >
            {activeTab === 'pengaturan' && (
              <motion.div
                layoutId="bottomNavActivePill"
                className="absolute inset-0 bg-apple-blue/[0.09] rounded-xl z-0"
                transition={figmaSpring.quick}
              />
            )}
            <Settings className="h-5 w-5 relative z-10" />
            <span className="text-[10px] sm:text-[11px] mt-0.5 relative z-10">Pengaturan</span>
          </motion.button>
        </div>
      </nav>
    </div>
  );
}
