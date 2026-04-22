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
  Alert,
} from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTranslation } from 'react-i18next';
import { Colors } from '../../src/theme/colors';
import { useAuthStore } from '../../src/store/authStore';

export default function ResetPasswordScreen() {
  const { t } = useTranslation();
  const router = useRouter();
  const { resetPassword, resetPasswordCompleted, isLoading, errorMessage, clearError, pendingEmail } =
    useAuthStore();

  const [code, setCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [localError, setLocalError] = useState('');

  useEffect(() => {
    if (resetPasswordCompleted) {
      Alert.alert(
        t('passwordResetAlertTitle'),
        t('passwordResetSuccess') + ' ' + t('loginAgain'),
        [
          {
            text: t('ok'),
            onPress: () => {
              // Login ekranına geri dön
              router.navigate('/(auth)/email-login');
            },
          },
        ]
      );
    }
  }, [resetPasswordCompleted]);

  const handleReset = async () => {
    setLocalError('');
    clearError();
    if (newPassword !== confirmPassword) {
      setLocalError(t('passwordsNoMatch'));
      return;
    }
    await resetPassword(code, newPassword);
  };

  const displayError = localError || errorMessage;
  const canSubmit =
    code.trim().length === 6 &&
    newPassword.length >= 8 &&
    !isLoading;

  return (
    <SafeAreaView style={styles.safe}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <TouchableOpacity style={styles.back} onPress={() => router.back()} activeOpacity={0.7}>
            <Text style={styles.backIcon}>‹</Text>
          </TouchableOpacity>

          <Text style={styles.logo}>{t('appBrand')}</Text>
          <Text style={styles.title}>{t('resetPassword')}</Text>
          
          <Text style={styles.subtitle}>
            {t('resetCodeSentPrefix')}{'\n'}
            <Text style={styles.emailHighlight}>{pendingEmail}</Text>
          </Text>

          <View style={styles.form}>
            {/* 6 Haneli Kod */}
            <View style={styles.inputWrap}>
              <Text style={styles.inputIcon}>KEY</Text>
              <TextInput
                style={styles.input}
                placeholder={t('resetCode')}
                placeholderTextColor="#9CA3AF"
                value={code}
                onChangeText={setCode}
                keyboardType="number-pad"
                maxLength={6}
                returnKeyType="next"
              />
            </View>

            {/* Yeni Şifre */}
            <View style={styles.inputWrap}>
              <Text style={styles.inputIcon}>🔒</Text>
              <TextInput
                style={styles.input}
                placeholder={t('newPassword')}
                placeholderTextColor="#9CA3AF"
                value={newPassword}
                onChangeText={setNewPassword}
                secureTextEntry
                returnKeyType="next"
              />
            </View>

            {/* Şifre Tekrar */}
            <View style={styles.inputWrap}>
              <Text style={styles.inputIcon}>🔒</Text>
              <TextInput
                style={styles.input}
                placeholder={t('confirmNewPassword')}
                placeholderTextColor="#9CA3AF"
                value={confirmPassword}
                onChangeText={setConfirmPassword}
                secureTextEntry
                returnKeyType="done"
                onSubmitEditing={handleReset}
              />
            </View>
          </View>

          {displayError ? (
            <View style={styles.errorBox}>
              <Text style={styles.errorIcon}>⚠</Text>
              <Text style={styles.errorText}>{displayError}</Text>
            </View>
          ) : null}

          <TouchableOpacity
            style={[styles.btn, !canSubmit && styles.btnDisabled]}
            onPress={handleReset}
            disabled={!canSubmit}
            activeOpacity={0.85}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.btnText}>{t('resetPasswordButton')}</Text>
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
  title: { fontSize: 24, fontWeight: '700', color: Colors.dark, textAlign: 'center', marginBottom: 12 },
  subtitle: { fontSize: 15, color: '#6B7280', textAlign: 'center', paddingHorizontal: 32, marginBottom: 32, lineHeight: 22 },
  emailHighlight: { fontWeight: '600', color: Colors.dark },
  
  form: { paddingHorizontal: 24, gap: 14 },
  inputWrap: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: Colors.surface, borderRadius: 14,
    borderWidth: 1, borderColor: Colors.border, padding: 14, gap: 10,
  },
  inputIcon: { fontSize: 16, width: 24, textAlign: 'center' },
  input: { flex: 1, fontSize: 16, color: Colors.dark },

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
});
