import { useEffect } from 'react';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import '../src/i18n';
import { useAuthStore } from '../src/store/authStore';

// Splash screen'i hemen saklanmasını engelle
SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const { checkAuth, isInitializing } = useAuthStore();

  useEffect(() => {
    checkAuth().finally(() => {
      SplashScreen.hideAsync();
    });
  }, []);

  if (isInitializing) {
    // Expo splash screen görünmeye devam eder
    return null;
  }

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="(auth)" />
      <Stack.Screen name="(tabs)" />
    </Stack>
  );
}
