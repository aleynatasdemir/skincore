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
import { useAuthStore } from '../../src/store/authStore';

export default function EmailLoginScreen() {
  const { t } = useTranslation();
  const router = useRouter();
  const { login, isLoading, errorMessage, clearError, showVerifyEmail } = useAuthStore();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  // E-posta doğrulama gerekiyorsa yönlendir
  useEffect(() => {
    if (showVerifyEmail) {
      router.replace('/(auth)/verify-email');
    }
  }, [showVerifyEmail]);

  const handleLogin = async () => {
    if (!email.trim() || !password) return;
    clearError();
    await login(email.trim(), password);
  };

  const canSubmit = email.trim().length > 0 && password.length > 0 && !isLoading;

  return (
    <SafeAreaView style={styles.safe}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView
          contentContainerStyle={styles.scroll}
          keyboardShouldPersistTaps="handled"
        >
          {/* Geri butonu */}
          <TouchableOpacity style={styles.back} onPress={() => router.back()} activeOpacity={0.7}>
            <Text style={styles.backIcon}>‹</Text>
          </TouchableOpacity>

          {/* Header */}
          <Text style={styles.logo}>{t('appBrand')}</Text>
          <Text style={styles.title}>{t('loginButton')}</Text>

          {/* Form */}
          <View style={styles.form}>
            {/* Email */}
            <View style={styles.inputWrap}>
              <Text style={styles.inputIcon}>✉</Text>
              <TextInput
                style={styles.input}
                placeholder={t('email')}
                placeholderTextColor="#9CA3AF"
                value={email}
                onChangeText={setEmail}
                keyboardType="email-address"
                autoCapitalize="none"
                autoComplete="email"
                returnKeyType="next"
              />
            </View>

            {/* Password */}
            <View style={styles.inputWrap}>
              <Text style={styles.inputIcon}>🔒</Text>
              <TextInput
                style={styles.input}
                placeholder={t('password')}
                placeholderTextColor="#9CA3AF"
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                returnKeyType="done"
                onSubmitEditing={handleLogin}
              />
            </View>
          </View>

          {/* Error */}
          {errorMessage ? (
            <View style={styles.errorBox}>
              <Text style={styles.errorIcon}>⚠</Text>
              <Text style={styles.errorText}>{errorMessage}</Text>
            </View>
          ) : null}

          {/* Forgot password */}
          <TouchableOpacity
            style={styles.forgotWrap}
            onPress={() => { clearError(); router.push('/(auth)/forgot-password'); }}
            activeOpacity={0.7}
          >
            <Text style={styles.forgotText}>{t('forgotPassword')}?</Text>
          </TouchableOpacity>

          {/* Login Button */}
          <TouchableOpacity
            style={[styles.loginBtn, !canSubmit && styles.loginBtnDisabled]}
            onPress={handleLogin}
            disabled={!canSubmit}
            activeOpacity={0.85}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.loginBtnText}>{t('loginButton')}</Text>
            )}
          </TouchableOpacity>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.background },
  scroll: { flexGrow: 1, paddingBottom: 40 },

  back: { padding: 16 },
  backIcon: { fontSize: 32, color: Colors.dark, lineHeight: 36 },

  logo: { fontSize: 36, fontWeight: '300', color: Colors.primary, textAlign: 'center', marginBottom: 8 },
  title: { fontSize: 24, fontWeight: '700', color: Colors.dark, textAlign: 'center', marginBottom: 32 },

  form: { paddingHorizontal: 24, gap: 14 },
  inputWrap: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: Colors.surface, borderRadius: 14,
    borderWidth: 1, borderColor: Colors.border, padding: 14, gap: 10,
  },
  inputIcon: { fontSize: 16, width: 24, textAlign: 'center' },
  input: { flex: 1, fontSize: 16, color: Colors.dark },

  errorBox: {
    marginHorizontal: 16, marginTop: 12, padding: 12,
    backgroundColor: '#FEE2E2', borderRadius: 10,
    borderWidth: 1, borderColor: '#FECACA',
    flexDirection: 'row', alignItems: 'flex-start', gap: 10,
  },
  errorIcon: { fontSize: 16, color: Colors.danger },
  errorText: { flex: 1, fontSize: 14, fontWeight: '500', color: '#DC2626' },

  forgotWrap: { alignSelf: 'flex-end', paddingRight: 24, marginTop: 8 },
  forgotText: { fontSize: 14, color: '#6B7280' },

  loginBtn: {
    marginHorizontal: 24, marginTop: 24,
    height: 56, borderRadius: 28,
    backgroundColor: Colors.dark,
    alignItems: 'center', justifyContent: 'center',
  },
  loginBtnDisabled: { opacity: 0.5 },
  loginBtnText: { fontSize: 17, fontWeight: '600', color: '#fff' },
});
