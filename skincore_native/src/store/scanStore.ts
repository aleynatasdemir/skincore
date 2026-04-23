import { create } from 'zustand';
import { productsApi } from '../api/apiClient';
import type { Product } from '../types/product';

interface ScanState {
  capturedImage: string | null;
  isProcessing: boolean;
  searchResults: Product[];
  hasSearched: boolean;

  setCapturedImage: (uri: string | null) => void;
  reset: () => void;
  
  processImage: (uri: string) => Promise<void>;
}

export const useScanStore = create<ScanState>((set) => ({
  capturedImage: null,
  isProcessing: false,
  searchResults: [],
  hasSearched: false,

  setCapturedImage: (uri) => set({ capturedImage: uri }),

  reset: () => set({ 
    capturedImage: null, 
    isProcessing: false, 
    searchResults: [], 
    hasSearched: false 
  }),

  processImage: async (uri: string) => {
    set({ capturedImage: uri, isProcessing: true, hasSearched: false });
    try {
      const formData = new FormData();
      formData.append('image', {
        uri: uri,
        name: 'scan_upload.jpg',
        type: 'image/jpeg',
      } as any);

      // OCR text is omitted since backend disabled it for performance.
      formData.append('maxResults', '5');

      const results = await productsApi.searchByImage(formData);
      set({ searchResults: results, isProcessing: false, hasSearched: true });
    } catch (error) {
      console.error('Scan process error:', error);
      set({ searchResults: [], isProcessing: false, hasSearched: true });
    }
  }
}));
