import { create } from 'zustand';
import { ingredientsApi, IngredientsFilters } from '../api/apiClient';
import type { MatchedIngredient } from '../types/product';
import lodash from 'lodash';

export interface IngredientCategory {
  id: string;
  title: string;
  description: string;
  icon: string; // Ionicons name
  color: string;
  backgroundColor: string;
  minSafety?: number;
  maxSafety?: number;
  comedogenic?: boolean;
}

export const INGREDIENT_CATEGORIES: IngredientCategory[] = [
  {
    id: 'completely_safe',
    title: 'Tamamen Güvenli',
    description: 'EWG 1-2 skoru aralığındaki en güvenli maddelerdir. Rahatlıkla kullanabilirsiniz.',
    icon: 'shield-checkmark',
    color: '#22C55E', // Green
    backgroundColor: '#DCFCE7',
    minSafety: 0,
    maxSafety: 0,
  },
  {
    id: 'safe',
    title: 'Güvenli',
    description: 'Cildiniz için risk oluşturmayan, genel kullanıma uygun maddelerdir.',
    icon: 'checkmark-circle',
    color: '#3B82F6', // Blue
    backgroundColor: '#DBEAFE',
    minSafety: 1,
    maxSafety: 1,
  },
  {
    id: 'acceptable',
    title: 'Kabul Edilebilir',
    description: 'Çoğu cilt tipi için güvenli ancak hassas ciltlerin dikkat etmesi gereken maddeler.',
    icon: 'information-circle',
    color: '#EAB308', // Yellow
    backgroundColor: '#FEF9C3',
    minSafety: 2,
    maxSafety: 2,
  },
  {
    id: 'moderate',
    title: 'Orta Derece',
    description: 'Kullanım oranlarına bağlı olarak risk taşıyabilecek maddeler. Dikkatli kullanılmalı.',
    icon: 'warning',
    color: '#F97316', // Orange
    backgroundColor: '#FFEDD5',
    minSafety: 3,
    maxSafety: 3,
  },
  {
    id: 'risky',
    title: 'Riskli',
    description: 'Alerjen, toksik veya kısıtlamalara tabi olan içerikler. Kaçınılması tavsiye edilir.',
    icon: 'close-circle',
    color: '#EF4444', // Red
    backgroundColor: '#FEE2E2',
    minSafety: 4,
    maxSafety: 4,
  },
  {
    id: 'comedogenic',
    title: 'Komedojenik (Gözenek Tıkayıcı)',
    description: 'Gözenekleri tıkayarak akne ve sivilce oluşumuna zemin hazırlayan içerikler.',
    icon: 'grid',
    color: '#9CA3AF', // Gray
    backgroundColor: '#F3F4F6',
    comedogenic: true,
  },
];

interface IngredientsState {
  searchQuery: string;
  selectedCategory: IngredientCategory | null;
  ingredients: MatchedIngredient[];
  isLoading: boolean;
  currentPage: number;
  hasMore: boolean;

  setSearchQuery: (query: string) => void;
  selectCategory: (category: IngredientCategory | null) => void;
  fetchIngredients: (reset?: boolean) => Promise<void>;
  debouncedFetch: () => void;
}

export const useIngredientsStore = create<IngredientsState>((set, get) => {
  const fetchIngredients = async (reset = false) => {
    const { searchQuery, selectedCategory, currentPage, ingredients, isLoading, hasMore } = get();
    
    if (isLoading) return;
    if (!reset && !hasMore) return;

    set({ isLoading: true });
    
    const pageToFetch = reset ? 1 : currentPage + 1;
    
    const filters: IngredientsFilters = {
      page: pageToFetch,
      pageSize: 1000,
    };

    const trimmedQuery = searchQuery.trim();
    if (trimmedQuery.length >= 2) filters.search = trimmedQuery;

    if (selectedCategory) {
      if (selectedCategory.minSafety !== undefined) filters.minSafety = selectedCategory.minSafety;
      if (selectedCategory.maxSafety !== undefined) filters.maxSafety = selectedCategory.maxSafety;
      if (selectedCategory.comedogenic) filters.comedogenic = true;
    }

    try {
      const results = await ingredientsApi.get(filters);
      
      set({
        ingredients: reset ? results : [...ingredients, ...results],
        currentPage: pageToFetch,
        hasMore: results.length >= 1000,
        isLoading: false,
      });
    } catch (error) {
      console.error('Ingredients fetch error:', error);
      set({ isLoading: false });
    }
  };

  const debouncedFetch = lodash.debounce(() => {
    get().fetchIngredients(true);
  }, 400);

  return {
    searchQuery: '',
    selectedCategory: null,
    ingredients: [],
    isLoading: false,
    currentPage: 1,
    hasMore: true,

    setSearchQuery: (query: string) => {
      set({ searchQuery: query });
      if (query.trim().length >= 2 || query.trim() === '') {
        get().debouncedFetch();
      }
    },

    selectCategory: (category: IngredientCategory | null) => {
      set({ selectedCategory: category, searchQuery: '' });
      get().fetchIngredients(true);
    },

    fetchIngredients,
    debouncedFetch,
  };
});
