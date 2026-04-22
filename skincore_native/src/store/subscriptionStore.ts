import { create } from 'zustand';
import Purchases, {
  PurchasesPackage,
  CustomerInfo,
} from 'react-native-purchases';
import AsyncStorage from '@react-native-async-storage/async-storage';

const MONTHLY_ID = 'com.skincore.premium.monthly';
const YEARLY_ID = 'com.skincore.premium.yearly';
const FREE_DAILY_LIMIT = 3;

function todayKey() {
  const d = new Date();
  return `scanCount_${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

interface SubscriptionState {
  isPremium: boolean;
  isLoading: boolean;
  purchaseError: string | null;
  showPaywallOnLaunch: boolean;
  selectedProductID: string;
  packages: PurchasesPackage[];
  monthlyPackage: PurchasesPackage | null;
  yearlyPackage: PurchasesPackage | null;

  // Actions
  initialize: () => Promise<void>;
  loadOfferings: () => Promise<void>;
  updatePurchaseStatus: () => Promise<void>;
  purchase: () => Promise<boolean>;
  restorePurchases: () => Promise<void>;
  setSelectedProductID: (id: string) => void;
  setShowPaywallOnLaunch: (show: boolean) => void;

  // Scan limit
  canScan: () => boolean;
  getRemainingScans: () => number;
  incrementScanCount: () => Promise<void>;
}

export const useSubscriptionStore = create<SubscriptionState>((set, get) => ({
  isPremium: false,
  isLoading: false,
  purchaseError: null,
  showPaywallOnLaunch: false,
  selectedProductID: YEARLY_ID,
  packages: [],
  monthlyPackage: null,
  yearlyPackage: null,

  // MARK: - Initialize RevenueCat
  initialize: async () => {
    // RevenueCat API key'i burada set edilmeli (bundle içi config'den çekilebilir)
    // Purchases.configure({ apiKey: 'rc_ios_...' });
    await get().loadOfferings();
    await get().updatePurchaseStatus();
  },

  loadOfferings: async () => {
    set({ isLoading: true });
    try {
      const offerings = await Purchases.getOfferings();
      if (offerings.current?.availablePackages) {
        const pkgs = offerings.current.availablePackages;
        set({
          packages: pkgs,
          monthlyPackage: pkgs.find((p) => p.product.identifier === MONTHLY_ID) ?? null,
          yearlyPackage: pkgs.find((p) => p.product.identifier === YEARLY_ID) ?? null,
        });
      }
    } catch (e) {
      console.warn('Offerings load error:', e);
    }
    set({ isLoading: false });
  },

  updatePurchaseStatus: async () => {
    try {
      const info: CustomerInfo = await Purchases.getCustomerInfo();
      const isPremium = typeof info.entitlements.active['premium'] !== 'undefined';
      set({ isPremium });
    } catch (e) {
      console.warn('Purchase status error:', e);
    }
  },

  purchase: async () => {
    const { packages, selectedProductID } = get();
    const pkg = packages.find((p) => p.product.identifier === selectedProductID);
    if (!pkg) {
      set({ purchaseError: 'Ürün bulunamadı.' });
      return false;
    }
    set({ isLoading: true, purchaseError: null });
    try {
      const { customerInfo } = await Purchases.purchasePackage(pkg);
      const isPremium = typeof customerInfo.entitlements.active['premium'] !== 'undefined';
      set({ isPremium, isLoading: false });
      return isPremium;
    } catch (e: any) {
      if (!e.userCancelled) {
        set({ purchaseError: `Satın alma başarısız: ${e.message}` });
      }
      set({ isLoading: false });
      return false;
    }
  },

  restorePurchases: async () => {
    set({ isLoading: true });
    try {
      const info = await Purchases.restorePurchases();
      const isPremium = typeof info.entitlements.active['premium'] !== 'undefined';
      set({ isPremium });
    } catch (e: any) {
      set({ purchaseError: `Geri yükleme başarısız: ${e.message}` });
    }
    set({ isLoading: false });
  },

  setSelectedProductID: (id) => set({ selectedProductID: id }),
  setShowPaywallOnLaunch: (show) => set({ showPaywallOnLaunch: show }),

  // MARK: - Scan Limit (AsyncStorage)
  canScan: () => {
    if (get().isPremium) return true;
    // Sync check — gerçek count async, store'da tutulabilir
    return true; // İlk render için, incrementScanCount async
  },

  getRemainingScans: () => {
    if (get().isPremium) return Infinity;
    return FREE_DAILY_LIMIT; // async versiyonu aşağıda
  },

  incrementScanCount: async () => {
    const key = todayKey();
    const current = parseInt((await AsyncStorage.getItem(key)) ?? '0', 10);
    await AsyncStorage.setItem(key, String(current + 1));
  },
}));

// Async scan count yardımcı fonksiyonları
export async function getTodaysScanCount(): Promise<number> {
  const val = await AsyncStorage.getItem(todayKey());
  return parseInt(val ?? '0', 10);
}

export async function canScanAsync(isPremium: boolean): Promise<boolean> {
  if (isPremium) return true;
  return (await getTodaysScanCount()) < FREE_DAILY_LIMIT;
}

export async function getRemainingScansAsync(isPremium: boolean): Promise<number> {
  if (isPremium) return Infinity;
  return Math.max(0, FREE_DAILY_LIMIT - (await getTodaysScanCount()));
}

export { MONTHLY_ID, YEARLY_ID, FREE_DAILY_LIMIT };
