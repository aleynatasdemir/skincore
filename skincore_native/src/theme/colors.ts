// HEX renk seti — Swift Color(hex:) karşılığı
export const Colors = {
  primary: '#D4728C',      // Ana pembe
  primaryLight: '#F3D5DC', // Açık pembe
  dark: '#1A1A2E',         // Başlık / koyu metin
  background: '#FFF0F0',   // Sayfa arka planı
  softPink: '#F9D6D6',     // Gradient başlangıcı
  surface: '#FFFFFF',      // Kart / input arka planı
  muted: '#9CA3AF',        // İkincil metin
  mutedLight: '#CBD5E1',   // Çok hafif metin / ikon
  border: '#E5E7EB',       // Kenar çizgisi
  accent: '#7B5455',       // Koyu gül
  accentLight: '#F3E8E8',  // Hafif pembe dolgu
  danger: '#EF4444',       // Kırmızı / hata
  warning: '#F59E0B',      // Sarı / yıldız
  success: '#10B981',      // Yeşil
  disabled: '#D1D5DB',     // Pasif

  // Safety renkleri
  safeGreen: '#22C55E',
  cautionAmber: '#F59E0B',
  riskyRed: '#EF4444',
  unknownGray: '#94A3B8',
} as const;

export type ColorKey = keyof typeof Colors;
