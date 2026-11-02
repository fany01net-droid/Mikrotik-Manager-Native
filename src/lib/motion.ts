import { type Transition, type Variants } from 'framer-motion';

/**
 * Figma Motion System & Easing Presets
 * Derived from Figma Motion Design System & Plugin API Specification:
 * - Gentle Spring: Natural, physical settling for sheets, cards, and transitions
 * - Quick Spring: Snappy, immediate feedback for buttons, chips, and toggles
 * - Bouncy Spring: Tactile bounce for alerts, badges, and icons
 * - Smooth Ease Out: Figma standard cubic-bezier curve [0.16, 1, 0.3, 1]
 */

export const figmaSpring = {
  gentle: {
    type: 'spring',
    stiffness: 220,
    damping: 24,
    mass: 0.9,
  } as Transition,
  quick: {
    type: 'spring',
    stiffness: 380,
    damping: 28,
    mass: 0.8,
  } as Transition,
  bouncy: {
    type: 'spring',
    stiffness: 280,
    damping: 18,
    mass: 1.0,
  } as Transition,
  slow: {
    type: 'spring',
    stiffness: 140,
    damping: 22,
    mass: 1.1,
  } as Transition,
};

export const figmaEasing = {
  easeOut: [0.16, 1, 0.3, 1] as const,
  easeInOut: [0.4, 0, 0.2, 1] as const,
  anticipate: [0.34, 1.56, 0.64, 1] as const,
};

// Page / Main Tab Switch Transitions
export const pageVariants: Variants = {
  initial: {
    opacity: 0,
    y: 10,
    scale: 0.995,
  },
  animate: {
    opacity: 1,
    y: 0,
    scale: 1,
    transition: {
      duration: 0.26,
      ease: [0.16, 1, 0.3, 1],
    },
  },
  exit: {
    opacity: 0,
    y: -8,
    scale: 0.995,
    transition: {
      duration: 0.18,
      ease: [0.4, 0, 0.2, 1],
    },
  },
};

// Sub-tab Content Transitions (e.g. PPPoE [Pelanggan, Profil, Aktif])
export const subTabVariants: Variants = {
  initial: {
    opacity: 0,
    y: 6,
  },
  animate: {
    opacity: 1,
    y: 0,
    transition: {
      duration: 0.22,
      ease: [0.16, 1, 0.3, 1],
    },
  },
  exit: {
    opacity: 0,
    y: -4,
    transition: {
      duration: 0.15,
      ease: [0.4, 0, 0.2, 1],
    },
  },
};

// Staggered Container for Lists and Card Grids
export const staggerContainer: Variants = {
  initial: {},
  animate: {
    transition: {
      staggerChildren: 0.035,
      delayChildren: 0.04,
    },
  },
};

export const staggerItem: Variants = {
  initial: {
    opacity: 0,
    y: 12,
  },
  animate: {
    opacity: 1,
    y: 0,
    transition: {
      duration: 0.28,
      ease: [0.16, 1, 0.3, 1],
    },
  },
};

// Modal Backdrop Fade
export const modalBackdropVariants: Variants = {
  initial: { opacity: 0 },
  animate: {
    opacity: 1,
    transition: { duration: 0.24, ease: [0.16, 1, 0.3, 1] },
  },
  exit: {
    opacity: 0,
    transition: { duration: 0.18, ease: [0.4, 0, 0.2, 1] },
  },
};

// Modal Bottom Sheet (Mobile Drawer) & Centered Dialog
export const modalSheetVariants: Variants = {
  initial: {
    opacity: 0,
    y: '25%',
    scale: 0.97,
  },
  animate: {
    opacity: 1,
    y: 0,
    scale: 1,
    transition: figmaSpring.gentle,
  },
  exit: {
    opacity: 0,
    y: '20%',
    scale: 0.97,
    transition: {
      duration: 0.2,
      ease: [0.4, 0, 0.2, 1],
    },
  },
};

// Banner / Toast Notification Slide Down
export const toastBannerVariants: Variants = {
  initial: {
    opacity: 0,
    y: -24,
    scale: 0.96,
  },
  animate: {
    opacity: 1,
    y: 0,
    scale: 1,
    transition: figmaSpring.gentle,
  },
  exit: {
    opacity: 0,
    y: -16,
    scale: 0.96,
    transition: {
      duration: 0.18,
      ease: [0.4, 0, 0.2, 1],
    },
  },
};

// Interactive Tactile Springs for Buttons, Chips, and Cards
export const tactilePress = {
  scale: 0.965,
  transition: figmaSpring.quick,
};

export const tactileCardHover = {
  y: -1,
  transition: {
    duration: 0.18,
    ease: [0.16, 1, 0.3, 1],
  },
};
