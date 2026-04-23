import { create } from 'zustand';
import { productsApi, popularApi, searchHistoryApi } from '../api/apiClient';
import type { Product, PopularProductResponse, SearchHistoryResponse } from '../types/product';

interface HomeState {
  searchResults: Product[];
  isSearching: boolean;
  
  popularProducts: PopularProductResponse[];
  isLoadingPopular: boolean;
  
  searchHistory: SearchHistoryResponse[];
  isLoadingHistory: boolean;

  // Actions
  searchProducts: (query: string) => Promise<void>;
  clearSearchResults: () => void;
  
  fetchPopularProducts: () => Promise<void>;
  
  fetchSearchHistory: () => Promise<void>;
  addSearchHistory: (query: string, productId?: string, productName?: string, category?: string, imageUrl?: string) => Promise<void>;
  deleteHistoryItem: (id: string) => Promise<void>;
  clearHistory: () => Promise<void>;
}

export const useHomeStore = create<HomeState>((set, get) => ({
  searchResults: [],
  isSearching: false,
  
  popularProducts: [],
  isLoadingPopular: false,
  
  searchHistory: [],
  isLoadingHistory: false,

  searchProducts: async (query: string) => {
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      set({ searchResults: [], isSearching: false });
      return;
    }
    set({ isSearching: true });
    try {
      const results = await productsApi.searchByName(trimmed, 10);
      set({ searchResults: results, isSearching: false });
    } catch (error) {
      console.error('Search error:', error);
      set({ searchResults: [], isSearching: false });
    }
  },

  clearSearchResults: () => set({ searchResults: [], isSearching: false }),

  fetchPopularProducts: async () => {
    set({ isLoadingPopular: true });
    try {
      const results = await popularApi.get(10);
      set({ popularProducts: results, isLoadingPopular: false });
    } catch (error) {
      console.error('Popular fetch error:', error);
      set({ popularProducts: [], isLoadingPopular: false });
    }
  },

  fetchSearchHistory: async () => {
    set({ isLoadingHistory: true });
    try {
      const results = await searchHistoryApi.get(5);
      set({ searchHistory: results, isLoadingHistory: false });
    } catch (error) {
      console.error('History fetch error:', error);
      set({ searchHistory: [], isLoadingHistory: false });
    }
  },

  addSearchHistory: async (query, productId, productName, category, imageUrl) => {
    try {
      await searchHistoryApi.add({ query, productId, productName, category });
      // Optimistic upate (aynı kalmasın diye)
      const newItem: SearchHistoryResponse = {
        id: Math.random().toString(), // Geçici ID, fetch edilene kadar.
        query,
        productId,
        productName,
        category,
        imageUrl,
      };
      
      const currentHistory = get().searchHistory;
      let updatedHistory = [newItem, ...currentHistory];
      if (updatedHistory.length > 20) {
        updatedHistory = updatedHistory.slice(0, 20);
      }
      set({ searchHistory: updatedHistory });
    } catch (error) {
      console.error('Add history error:', error);
    }
  },

  deleteHistoryItem: async (id: string) => {
    try {
      await searchHistoryApi.deleteItem(id);
      set((state) => ({
        searchHistory: state.searchHistory.filter((item) => item.id !== id),
      }));
    } catch (error) {
      console.error('Delete history error:', error);
    }
  },

  clearHistory: async () => {
    try {
      await searchHistoryApi.clearAll();
      set({ searchHistory: [] });
    } catch (error) {
      console.error('Clear history error:', error);
    }
  },
}));
