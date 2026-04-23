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

export default function RegisterScreen() {
  const { t } = useTranslation();
  const router = useRouter();
  const { register, isLoading, errorMessage, clearError, showVerifyEmail } = useAuthStore();

  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [localError, setLocalError] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  useEffect(() => {
    if (showVerifyEmail) {
      router.replace('/(auth)/verify-email');
    }
  }, [showVerifyEmail]);

  const handleRegister = async () => {
    setLocalError('');
    clearError();
    if (password !== confirmPassword) {
      setLocalError(t('passwordsNoMatch'));
      return;
    }
    await register(email.trim(), password, fullName.trim() || undefined);
  };

  const displayError = localError || errorMessage;
  const canSubmit =
    email.trim().length > 0 &&
    password.length >= 8 &&
    !isLoading;

  return (
    <SafeAreaView style={styles.safe}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          {/* Geri */}
          <TouchableOpacity style={styles.back} onPress={() => router.back()} activeOpacity={0.7}>
            <Ionicons name="chevron-back" size={32} color={Colors.dark} />
          </TouchableOpacity>

          {/* Header */}
          <Text style={styles.logo}>{t('appBrand')}</Text>
          <Text style={styles.title}>{t('createAccount')}</Text>

          {/* Form */}
          <View style={styles.form}>
            {/* Ad Soyad */}
            <View style={styles.inputWrap}>
              <Ionicons name="person-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />
              <TextInput
                style={styles.input}
                placeholder={t('fullName')}
                placeholderTextColor="#9CA3AF"
                value={fullName}
                onChangeText={setFullName}
                autoCapitalize="words"
                returnKeyType="next"
              />

              <TouchableOpacity onPress={() => setShowPassword(!showPassword)}>
                <Ionicons
                  name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                  size={20}
                  color="#9CA3AF"
                />
              </TouchableOpacity>
            </View>

            {/* Email */}
            <View style={styles.inputWrap}>
              <Ionicons name="mail-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />
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

              <TouchableOpacity onPress={() => setShowPassword(!showPassword)}>
                <Ionicons
                  name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                  size={20}
                  color="#9CA3AF"
                />
              </TouchableOpacity>
            </View>

            {/* Şifre */}
            <View style={styles.inputWrap}>
              <Ionicons name="lock-closed-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />
              <TextInput
                style={styles.input}
                placeholder={t('passwordMinChars')}
                placeholderTextColor="#9CA3AF"
                value={password}
                onChangeText={setPassword}
                secureTextEntry={!showPassword}
                returnKeyType="next"
              />

              <TouchableOpacity onPress={() => setShowPassword(!showPassword)}>
                <Ionicons
                  name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                  size={20}
                  color="#9CA3AF"
                />
              </TouchableOpacity>
            </View>

            {/* Şifre tekrar */}
            <View style={styles.inputWrap}>
              <Ionicons name="lock-closed-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />
              <TextInput
                style={styles.input}
                placeholder={t('confirmPassword')}
                placeholderTextColor="#9CA3AF"
                value={confirmPassword}
                onChangeText={setConfirmPassword}
                secureTextEntry={!showConfirmPassword}
                returnKeyType="done"
                onSubmitEditing={handleRegister}
              />

              <TouchableOpacity onPress={() => setShowConfirmPassword(!showConfirmPassword)}>
                <Ionicons
                  name={showConfirmPassword ? 'eye-off-outline' : 'eye-outline'}
                  size={20}
                  color="#9CA3AF"
                />
              </TouchableOpacity>
            </View>
          </View>

          {/* Error */}
          {displayError ? (
            <View style={styles.errorBox}>
              <Ionicons name="warning-outline" size={20} color={Colors.danger} />
              <Text style={styles.errorText}>{displayError}</Text>
            </View>
          ) : null}

          {/* Kayıt Ol */}
          <TouchableOpacity
            style={[styles.btn, !canSubmit && styles.btnDisabled]}
            onPress={handleRegister}
            disabled={!canSubmit}
            activeOpacity={0.85}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.btnText}>{t('createAccount')}</Text>
            )}
          </TouchableOpacity>

          {/* Login link */}
          <TouchableOpacity
            style={styles.linkRow}
            onPress={() => { clearError(); router.push('/(auth)/email-login'); }}
            activeOpacity={0.7}
          >
            <Text style={styles.linkGray}>{t('alreadyHaveAccount')} </Text>
            <Text style={styles.linkDark}>{t('loginButton')}</Text>
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

  btn: {
    marginHorizontal: 24, marginTop: 24,
    height: 56, borderRadius: 28,
    backgroundColor: Colors.dark,
    alignItems: 'center', justifyContent: 'center',
  },
  btnDisabled: { opacity: 0.5 },
  btnText: { fontSize: 17, fontWeight: '600', color: '#fff' },

  linkRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: 20 },
  linkGray: { fontSize: 14, color: '#6B7280' },
  linkDark: { fontSize: 14, fontWeight: '600', color: Colors.dark },
});
