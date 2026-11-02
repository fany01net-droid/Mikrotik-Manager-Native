import { RouterProfile } from '../types/mikrotik';

const PROFILES_KEY = 'fnet_router_profiles';
const ACTIVE_PROFILE_KEY = 'fnet_active_profile_id';

const DEFAULT_PROFILE: RouterProfile = {
  id: 'default-profile',
  name: 'MikroTik Utama',
  host: '192.168.88.1',
  port: 80,
  useHttps: false,
  username: 'admin',
  password: '',
  rememberPassword: true,
  timeoutSeconds: 8,
};

export const storageService = {
  getProfiles(): RouterProfile[] {
    try {
      const data = localStorage.getItem(PROFILES_KEY);
      if (!data) {
        return [DEFAULT_PROFILE];
      }
      const parsed = JSON.parse(data);
      return Array.isArray(parsed) && parsed.length > 0 ? parsed : [DEFAULT_PROFILE];
    } catch (e) {
      console.error('Failed to load router profiles from storage', e);
      return [DEFAULT_PROFILE];
    }
  },

  saveProfile(profile: RouterProfile): RouterProfile[] {
    const profiles = this.getProfiles();
    const existingIndex = profiles.findIndex((p) => p.id === profile.id);

    let updated: RouterProfile[];
    if (existingIndex >= 0) {
      updated = [...profiles];
      updated[existingIndex] = profile;
    } else {
      updated = [...profiles, profile];
    }

    try {
      localStorage.setItem(PROFILES_KEY, JSON.stringify(updated));
    } catch (e) {
      console.error('Failed to save router profile', e);
    }
    return updated;
  },

  deleteProfile(id: string): RouterProfile[] {
    const profiles = this.getProfiles();
    const updated = profiles.filter((p) => p.id !== id);
    try {
      localStorage.setItem(PROFILES_KEY, JSON.stringify(updated));
    } catch (e) {
      console.error('Failed to delete router profile', e);
    }
    return updated;
  },

  getActiveProfileId(): string | null {
    try {
      return localStorage.getItem(ACTIVE_PROFILE_KEY);
    } catch {
      return null;
    }
  },

  setActiveProfileId(id: string): void {
    try {
      localStorage.setItem(ACTIVE_PROFILE_KEY, id);
    } catch (e) {
      console.error('Failed to set active profile id in storage', e);
    }
  },
};
