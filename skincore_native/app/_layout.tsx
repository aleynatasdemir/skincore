import { useEffect } from 'react';
import { Stack, useRouter, useSegments } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import '../src/i18n';
import { useAuthStore } from '../src/store/authStore';

import { SplashView } from '../src/components/common/SplashView';

// Splash screen'i hemen saklanmasını engelle
SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const { checkAuth, isInitializing, isAuthenticated, needsUsername } = useAuthStore();
  const segments = useSegments();
  const router = useRouter();

  useEffect(() => {
    // Hide native splash immediately so our custom SplashView runs its animation
    SplashScreen.hideAsync();
    
    checkAuth().finally(() => {
      // isInitializing will become false, component updates
    });
  }, []);

  useEffect(() => {
    if (isInitializing) return;

    const inAuthGroup = segments[0] === '(auth)';

    // Eğer giriş yapıldıysa ve kullanıcı auth ekranımlarındaysa, (tabs)'a yönlendir
    if (isAuthenticated) {
      if (needsUsername && segments[1] !== 'username-setup') {
        router.replace('/(auth)/username-setup');
      } else if (inAuthGroup || segments.length === 0) {
        router.replace('/(tabs)');
      }
    } else if (!isAuthenticated && !inAuthGroup) {
      // Çıkış yapıldıysa veya token geçersizse anasayfaya (Login'e) gönder
      router.replace('/(auth)');
    }
  }, [isAuthenticated, isInitializing, segments, needsUsername]);

  if (isInitializing) {
    return <SplashView />;
  }

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="(auth)" />
      <Stack.Screen name="(tabs)" />
    </Stack>
  );
}
