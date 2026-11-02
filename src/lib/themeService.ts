export type ThemeMode = 'light' | 'dark';

const THEME_STORAGE_KEY = 'fnet_theme';

type ThemeListener = (theme: ThemeMode) => void;
const listeners = new Set<ThemeListener>();

export const themeService = {
  getTheme(): ThemeMode {
    if (typeof window === 'undefined') return 'light';
    try {
      const saved = localStorage.getItem(THEME_STORAGE_KEY);
      if (saved === 'light' || saved === 'dark') {
        return saved;
      }
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    } catch {
      return 'light';
    }
  },

  setTheme(theme: ThemeMode): void {
    if (typeof window === 'undefined') return;
    try {
      localStorage.setItem(THEME_STORAGE_KEY, theme);
    } catch (e) {
      console.error('Failed to save theme in localStorage', e);
    }
    this.applyTheme(theme);
    listeners.forEach((listener) => {
      try {
        listener(theme);
      } catch (err) {
        console.error('Error executing theme listener', err);
      }
    });
  },

  applyTheme(theme: ThemeMode): void {
    if (typeof document === 'undefined') return;
    const root = document.documentElement;
    const isDark = theme === 'dark';

    if (isDark) {
      root.classList.add('dark');
      root.classList.remove('light');
    } else {
      root.classList.remove('dark');
      root.classList.add('light');
    }
    root.style.colorScheme = theme;

    const metaThemeColor = document.querySelector('meta[name="theme-color"]');
    if (metaThemeColor) {
      metaThemeColor.setAttribute('content', isDark ? '#020617' : '#f8fafc');
    }

    const metaColorScheme = document.querySelector('meta[name="color-scheme"]');
    if (metaColorScheme) {
      metaColorScheme.setAttribute('content', theme);
    }
  },

  toggleTheme(): ThemeMode {
    const current = this.getTheme();
    const next: ThemeMode = current === 'dark' ? 'light' : 'dark';
    this.setTheme(next);
    return next;
  },

  initTheme(): ThemeMode {
    const current = this.getTheme();
    this.applyTheme(current);
    return current;
  },

  subscribe(listener: ThemeListener): () => void {
    listeners.add(listener);
    return () => {
      listeners.delete(listener);
    };
  },
};
