import { create } from 'zustand';
import { profileApi, routinesApi, favoritesApi, extractErrorMessage } from '../api/apiClient';
import type { UserProfileResponse, RoutineFeedItem, UpdateProfileRequest } from '../types/social';
import type { FavoriteResponse } from '../types/product';
import { useAuthStore } from './authStore';

export type ProfileTabState = 'ROUTINES' | 'FAVORITES';

interface ProfileStoreState {
  myProfile: UserProfileResponse | null;
  myRoutines: RoutineFeedItem[];
  myFavorites: FavoriteResponse[];
  activeTab: ProfileTabState;
  isLoading: boolean;
  error: string | null;

  fetchProfile: () => Promise<void>;
  setActiveTab: (tab: ProfileTabState) => void;
  updateBio: (bio: string) => Promise<boolean>;
  updateProfile: (data: UpdateProfileRequest) => Promise<boolean>;
  clearError: () => void;
}

export const useProfileStore = create<ProfileStoreState>((set, get) => ({
  myProfile: null,
  myRoutines: [],
  myFavorites: [],
  activeTab: 'ROUTINES',
  isLoading: false,
  error: null,

  setActiveTab: (tab) => set({ activeTab: tab }),

  fetchProfile: async () => {
    set({ isLoading: true, error: null });
    try {
      const profileData = await profileApi.getMyProfile();
      const routinesData = await routinesApi.getMy();
      const favoritesData = await favoritesApi.get();

      set({
        myProfile: profileData,
        myRoutines: routinesData,
        myFavorites: favoritesData,
        isLoading: false
      });

      // Update auth store globally
      useAuthStore.getState().checkAuth();

    } catch (error) {
      set({ error: extractErrorMessage(error), isLoading: false });
    }
  },

  updateBio: async (bio: string) => {
    try {
      await profileApi.updateBio({ bio });
      const { myProfile } = get();
      if (myProfile) {
        set({ myProfile: { ...myProfile, bio } });
      }
      return true;
    } catch (error) {
      set({ error: extractErrorMessage(error) });
      return false;
    }
  },

  updateProfile: async (data: UpdateProfileRequest) => {
    try {
      await profileApi.update({ ...data });
      const { myProfile } = get();
      if (myProfile) {
        set({ 
          myProfile: { 
            ...myProfile, 
            fullName: data.displayName !== undefined ? data.displayName : myProfile.fullName, 
            username: data.username !== undefined ? data.username : myProfile.username, 
            bio: data.bio !== undefined ? data.bio : myProfile.bio
          } 
        });
      }
      return true;
    } catch (error) {
      set({ error: extractErrorMessage(error) });
      return false;
    }
  },

  clearError: () => set({ error: null })
}));
