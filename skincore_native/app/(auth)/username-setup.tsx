import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  ActivityIndicator,
  Platform,
  KeyboardAvoidingView,
  ScrollView,
} from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTranslation } from 'react-i18next';
import { Colors } from '../../src/theme/colors';
import { Ionicons } from '@expo/vector-icons';
import { useAuthStore } from '../../src/store/authStore';
import { useDebounce } from '../../src/hooks/useDebounce';
import { profileApi } from '../../src/api/apiClient';

export default function UsernameSetupScreen() {
  const { t } = useTranslation();
  const router = useRouter();
  const { setupUsername, isLoading, errorMessage, clearError, logout } = useAuthStore();

  const [username, setUsername] = useState('');
  const debouncedUsername = useDebounce(username, 400);

  const [isChecking, setIsChecking] = useState(false);
  const [isAvailable, setIsAvailable] = useState<boolean | null>(null);

  useEffect(() => {
    const checkAvailability = async (val: string) => {
      // Sadece alphanumeric ve altçizgi, min 3 karakter
      const regex = /^[a-zA-Z0-9_]{3,}$/;
      if (!regex.test(val)) {
        setIsAvailable(null);
        return;
      }
      setIsChecking(true);
      try {
        const available = await profileApi.checkUsername(val);
        setIsAvailable(available);
      } catch {
        setIsAvailable(null);
      } finally {
        setIsChecking(false);
      }
    };

    if (debouncedUsername) {
      checkAvailability(debouncedUsername);
    } else {
      setIsAvailable(null);
    }
  }, [debouncedUsername]);

  const handleContinue = async () => {
    if (!isAvailable || username.length < 3 || isLoading) return;
    clearError();
    await setupUsername(username);
    // Success durumunda store'daki currentUser güncellenecek,
    // app layout / RootLayout `needsUsername` falsy olunca MainTabs'a atacak otomatik.
    // Eğer otomatik geçmiyorsa: router.replace('/(tabs)');
    // Şu an için React Navigation / Expo Router guard kısmı _layout'ta yapılabilir.
    router.replace('/(tabs)');
  };

  const handleLogout = async () => {
    await logout();
    router.replace('/(auth)');
  };

  const isValidFormat = /^[a-zA-Z0-9_]*$/.test(username);

  return (
    <SafeAreaView style={styles.safe}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          {/* Üstte Geri yerine Switch Account var, isterseniz router.back çalışmaz çünkü ilk login oldu */}
          <Text style={styles.logo}>{t('appBrand')}</Text>
          <Text style={styles.title}>{t('usernameTitle')}</Text>
          
          <Text style={styles.subtitle}>{t('usernameSubtitle')}</Text>

          <View style={styles.form}>
            <View style={styles.inputWrap}>
              <Text style={styles.inputIcon}>@</Text>
              <TextInput
                style={styles.input}
                placeholder={t('usernamePlaceholder')}
                placeholderTextColor="#9CA3AF"
                value={username}
                onChangeText={(val) => {
                  if (/^[a-zA-Z0-9_]*$/.test(val)) {
                    setUsername(val.toLowerCase());
                  }
                }}
                autoCapitalize="none"
                autoCorrect={false}
                returnKeyType="done"
                onSubmitEditing={handleContinue}
              />
              {isChecking && <ActivityIndicator size="small" color={Colors.primary} />}
            </View>
            
            {/* Alt Bilgi */}
            {username.length > 0 && username.length < 3 && (
              <Text style={styles.hintText}>{t('usernameMinChars')}</Text>
            )}
            {username.length >= 3 && isAvailable === false && !isChecking && (
              <Text style={styles.errorTextItem}>{t('usernameTaken')}</Text>
            )}
            {username.length >= 3 && isAvailable === true && !isChecking && (
              <Text style={styles.successTextItem}>@{username}{t('usernameAvailable')}</Text>
            )}
          </View>

          {errorMessage ? (
            <View style={styles.errorBox}>
              <Ionicons name="warning-outline" size={20} color={Colors.danger} />
              <Text style={styles.errorText}>{errorMessage}</Text>
            </View>
          ) : null}

          <TouchableOpacity
            style={[styles.btn, (!isAvailable || isLoading) && styles.btnDisabled]}
            onPress={handleContinue}
            disabled={!isAvailable || isLoading}
            activeOpacity={0.85}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.btnText}>{t('continueButton')}</Text>
            )}
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.switchWrap}
            onPress={handleLogout}
            activeOpacity={0.7}
          >
            <Text style={styles.switchText}>{t('switchAccount')}</Text>
          </TouchableOpacity>

        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.background },
  scroll: { flexGrow: 1, paddingBottom: 40, paddingTop: 40 },
  logo: { fontSize: 36, fontWeight: '300', color: Colors.primary, textAlign: 'center', marginBottom: 8 },
  title: { fontSize: 24, fontWeight: '700', color: Colors.dark, textAlign: 'center', marginBottom: 16 },
  subtitle: { fontSize: 15, color: '#6B7280', textAlign: 'center', paddingHorizontal: 32, marginBottom: 32, lineHeight: 22 },
  
  form: { paddingHorizontal: 24, gap: 8 },
  inputWrap: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: Colors.surface, borderRadius: 14,
    borderWidth: 1, borderColor: Colors.border, padding: 14, gap: 10,
  },
  inputIcon: { fontSize: 16, width: 24, textAlign: 'center', color: Colors.dark, fontWeight: '600' },
  input: { flex: 1, fontSize: 16, color: Colors.dark },

  hintText: { fontSize: 13, color: '#6B7280', paddingLeft: 8 },
  errorTextItem: { fontSize: 13, color: Colors.danger, paddingLeft: 8, fontWeight: '500' },
  successTextItem: { fontSize: 13, color: Colors.safeGreen, paddingLeft: 8, fontWeight: '500' },

  errorBox: {
    marginHorizontal: 16, marginTop: 16, padding: 12,
    backgroundColor: '#FEE2E2', borderRadius: 10,
    borderWidth: 1, borderColor: '#FECACA',
    flexDirection: 'row', alignItems: 'flex-start', gap: 10,
  },
  errorIcon: { fontSize: 16, color: Colors.danger },
  errorText: { flex: 1, fontSize: 14, fontWeight: '500', color: '#DC2626' },

  btn: {
    marginHorizontal: 24, marginTop: 24,
    height: 56, borderRadius: 28,
    backgroundColor: Colors.dark,
    alignItems: 'center', justifyContent: 'center',
  },
  btnDisabled: { opacity: 0.5 },
  btnText: { fontSize: 17, fontWeight: '600', color: '#fff' },

  switchWrap: { alignSelf: 'center', marginTop: 24 },
  switchText: { fontSize: 14, color: '#6B7280', fontWeight: '500' },
});
