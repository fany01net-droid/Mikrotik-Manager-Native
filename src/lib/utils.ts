import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function isValidHost(host: string): boolean {
  if (!host || host.length > 253) return false;
  // If IPv4 pattern (all digits and dots)
  if (/^[0-9.]+$/.test(host)) {
    const parts = host.split('.');
    if (parts.length !== 4) return false;
    return parts.every((p) => {
      if (!p || p.length > 3) return false;
      const n = Number(p);
      return !isNaN(n) && n >= 0 && n <= 255 && String(n) === p;
    });
  }
  // Hostname / domain: RFC 1123 format (e.g. mikrotik.local, myrouter.sn.mynetname.net)
  return /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/.test(host);
}
