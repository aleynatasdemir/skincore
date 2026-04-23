import { create } from 'zustand';
import { routinesApi, profileApi } from '../api/apiClient';
import type { RoutineFeedItem, PublicUserProfileResponse } from '../types/social';
import lodash from 'lodash';

type TabState = 'ROUTINES' | 'PEOPLE';

interface SocialState {
  activeTab: TabState;
  searchQuery: string;
  routines: RoutineFeedItem[];
  users: PublicUserProfileResponse[];
  isLoading: boolean;

  setActiveTab: (tab: TabState) => void;
  setSearchQuery: (query: string) => void;
  fetchData: () => Promise<void>;
  debouncedFetch: () => void;
  toggleLike: (routineId: string) => Promise<void>;
}

export const useSocialStore = create<SocialState>((set, get) => {
  const fetchData = async () => {
    const { activeTab, searchQuery } = get();
    set({ isLoading: true });

    try {
      if (activeTab === 'ROUTINES') {
        const query = searchQuery.trim().length >= 2 ? searchQuery.trim() : undefined;
        const results = await routinesApi.getFeed(50, query);
        set({ routines: results, isLoading: false });
      } else {
        // PEOPLE tab
        const query = searchQuery.trim();
        if (query.length >= 2) {
            const results = await profileApi.searchUsers(query);
            set({ users: results, isLoading: false });
        } else {
            // Default to empty or maybe some popular users?
            set({ users: [], isLoading: false });
        }
      }
    } catch (error) {
      console.error('Social fetch error:', error);
      set({ isLoading: false });
    }
  };

  const debouncedFetch = lodash.debounce(() => {
    get().fetchData();
  }, 400);

  return {
    activeTab: 'ROUTINES',
    searchQuery: '',
    routines: [],
    users: [],
    isLoading: false,

    setActiveTab: (tab: TabState) => {
      set({ activeTab: tab, searchQuery: '' });
      get().fetchData();
    },

    setSearchQuery: (query: string) => {
      set({ searchQuery: query });
      get().debouncedFetch();
    },

    fetchData,
    debouncedFetch,

    toggleLike: async (routineId: string) => {
      const { routines } = get();
      
      // OPTIMISTIC UI UPDATE
      set({
        routines: routines.map(r => {
          if (r.id === routineId) {
            return {
              ...r,
              isLiked: !r.isLiked,
              likeCount: r.isLiked ? Math.max(0, r.likeCount - 1) : r.likeCount + 1,
            };
          }
          return r;
        })
      });

      try {
        const response = await routinesApi.toggleLike(routineId);
        // Correct with actual backend state
        set({
          routines: get().routines.map(r => 
            r.id === routineId 
              ? { ...r, isLiked: response.isLiked, likeCount: response.likeCount }
              : r
          )
        });
      } catch (error) {
        console.error('Like toggle error:', error);
        // Revert optimistic update on failure (lazy reload)
        get().fetchData();
      }
    }
  };
});
