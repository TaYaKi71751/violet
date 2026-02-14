import { useEffect } from 'react';
import { useAppStore, type ThemeColor } from '../stores/app-store';

const themeColors: Record<ThemeColor, string> = {
  purple: '#8b5cf6',
  amber: '#f59e0b',
  black: '#1f2937',
  blue: '#3b82f6',
  blueGrey: '#64748b',
  brown: '#a16207',
  cyan: '#06b6d4',
  deepOrange: '#ea580c',
  deepPurple: '#7c3aed',
  green: '#10b981',
  grey: '#6b7280',
  indigo: '#6366f1',
  lightBlue: '#0ea5e9',
  lightGreen: '#84cc16',
  lime: '#a3e635',
  orange: '#f97316',
  pink: '#ec4899',
  red: '#ef4444',
  teal: '#14b8a6',
  yellow: '#eab308',
};

export function ThemeProvider() {
  const { themeColor } = useAppStore();

  useEffect(() => {
    const color = themeColors[themeColor];
    document.documentElement.style.setProperty('--color-primary', color);

    // Calculate lighter and darker variants
    const rgb = hexToRgb(color);
    if (rgb) {
      document.documentElement.style.setProperty(
        '--color-primary-light',
        `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.1)`
      );
      document.documentElement.style.setProperty(
        '--color-primary-dark',
        darkenColor(color, 20)
      );
    }
  }, [themeColor]);

  return null;
}

function hexToRgb(hex: string): { r: number; g: number; b: number } | null {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result
    ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16),
      }
    : null;
}

function darkenColor(hex: string, percent: number): string {
  const rgb = hexToRgb(hex);
  if (!rgb) return hex;

  const factor = 1 - percent / 100;
  const r = Math.round(rgb.r * factor);
  const g = Math.round(rgb.g * factor);
  const b = Math.round(rgb.b * factor);

  return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
}
