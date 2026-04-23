import { create } from 'zustand';
import { profileApi, routinesApi, favoritesApi } from '../api/apiClient';
import type { UserProfileResponse, RoutineFeedItem, FavoriteResponse } from '../types/social';
import { useAuthStore } from './authStore';

type ProfileTabState = 'ROUTINES' | 'FAVORITES';

interface ProfileState {
  myProfile: UserProfileResponse | null;
  myRoutines: RoutineFeedItem[];
  myFavorites: FavoriteResponse[];
  activeTab: ProfileTabState;
  isLoading: boolean;

  fetchProfile: () => Promise<void>;
  setActiveTab: (tab: ProfileTabState) => void;
}

export const useProfileStore = create<ProfileState>((set, get) => ({
  myProfile: null,
  myRoutines: [],
  myFavorites: [],
  activeTab: 'ROUTINES',
  isLoading: false,

  setActiveTab: (tab) => set({ activeTab: tab }),

  fetchProfile: async () => {
    set({ isLoading: true });
    try {
      const [profileData, routinesData, favoritesData] = await Promise.all([
        profileApi.getMyProfile(),
        routinesApi.getMy(),
        favoritesApi.get()
      ]);

      set({
        myProfile: profileData,
        myRoutines: routinesData,
        myFavorites: favoritesData,
        isLoading: false
      });

      // Update auth store globally if needed
      if (profileData) {
        useAuthStore.getState().checkAuthStatus(); // Can silently sync global user state
      }

    } catch (error) {
      console.error('Profile fetch error:', error);
      set({ isLoading: false });
    }
  }
}));
