import React, { useState, useRef, useEffect } from 'react';
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

const OTP_LENGTH = 6;

export default function VerifyEmailScreen() {
  const { t } = useTranslation();
  const router = useRouter();
  const { verifyEmail, resendCode, isLoading, errorMessage, clearError, pendingEmail } =
    useAuthStore();

  const [codes, setCodes] = useState(Array(OTP_LENGTH).fill(''));
  const [countdown, setCountdown] = useState(60);
  const [canResend, setCanResend] = useState(false);
  const inputRefs = useRef<Array<TextInput | null>>([]);

  // Geri sayım
  useEffect(() => {
    if (countdown <= 0) { setCanResend(true); return; }
    const timer = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(timer);
  }, [countdown]);

  const handleChange = (text: string, index: number) => {
    if (!/^\d*$/.test(text)) return;
    const newCodes = [...codes];
    newCodes[index] = text.slice(-1);
    setCodes(newCodes);
    if (text && index < OTP_LENGTH - 1) {
      inputRefs.current[index + 1]?.focus();
    }
    // Otomatik doğrula
    const filled = newCodes.join('');
    if (filled.length === OTP_LENGTH) {
      handleVerify(filled);
    }
  };

  const handleKeyPress = (e: any, index: number) => {
    if (e.nativeEvent.key === 'Backspace' && !codes[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  };

  const handleVerify = async (code?: string) => {
    clearError();
    const finalCode = code ?? codes.join('');
    if (finalCode.length < OTP_LENGTH) return;
    await verifyEmail(finalCode);
  };

  const handleResend = async () => {
    if (!canResend) return;
    clearError();
    setCodes(Array(OTP_LENGTH).fill(''));
    setCountdown(60);
    setCanResend(false);
    await resendCode();
  };

  const codeStr = codes.join('');

  return (
    <SafeAreaView style={styles.safe}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <TouchableOpacity style={styles.back} onPress={() => router.back()} activeOpacity={0.7}>
            <Ionicons name="chevron-back" size={32} color={Colors.dark} />
          </TouchableOpacity>

          {/* Header */}
          <Text style={styles.logo}>{t('appBrand')}</Text>
          <Text style={styles.title}>{t('verifyEmail')}</Text>
          <Text style={styles.subtitle}>
            {t('verifyEmailSentPrefix')}{'\n'}
            <Text style={styles.emailHighlight}>{pendingEmail}</Text>
          </Text>

          {/* OTP Inputs */}
          <View style={styles.otpRow}>
            {codes.map((digit, i) => (
              <TextInput
                key={i}
                ref={(ref) => { inputRefs.current[i] = ref; }}
                style={[styles.otpBox, digit ? styles.otpBoxFilled : null]}
                value={digit}
                onChangeText={(t) => handleChange(t, i)}
                onKeyPress={(e) => handleKeyPress(e, i)}
                keyboardType="number-pad"
                maxLength={1}
                textAlign="center"
                selectTextOnFocus
              />
            ))}
          </View>

          {/* Error */}
          {errorMessage ? (
            <View style={styles.errorBox}>
              <Ionicons name="warning-outline" size={20} color={Colors.danger} />
              <Text style={styles.errorText}>{errorMessage}</Text>
            </View>
          ) : null}

          {/* Doğrula butonu */}
          <TouchableOpacity
            style={[styles.btn, (codeStr.length < OTP_LENGTH || isLoading) && styles.btnDisabled]}
            onPress={() => handleVerify()}
            disabled={codeStr.length < OTP_LENGTH || isLoading}
            activeOpacity={0.85}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.btnText}>{t('verifyButton')}</Text>
            )}
          </TouchableOpacity>

          {/* Resend */}
          <TouchableOpacity
            style={[styles.resendBtn, !canResend && styles.resendDisabled]}
            onPress={handleResend}
            disabled={!canResend}
            activeOpacity={0.7}
          >
            {canResend ? (
              <Text style={styles.resendText}>{t('resendCode')}</Text>
            ) : (
              <Text style={styles.resendCountdown}>
                {t('resendCode')} ({countdown}s)
              </Text>
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
  subtitle: { fontSize: 15, color: '#6B7280', textAlign: 'center', lineHeight: 22, marginBottom: 32, paddingHorizontal: 32 },
  emailHighlight: { fontWeight: '600', color: Colors.dark },

  otpRow: { flexDirection: 'row', justifyContent: 'center', gap: 10, paddingHorizontal: 24 },
  otpBox: {
    width: 48, height: 56,
    backgroundColor: Colors.surface, borderRadius: 12,
    borderWidth: 1.5, borderColor: Colors.border,
    fontSize: 22, fontWeight: '700', color: Colors.dark,
  },
  otpBoxFilled: { borderColor: Colors.primary, backgroundColor: Colors.softPink },

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

  resendBtn: { marginTop: 16, alignSelf: 'center', padding: 8 },
  resendDisabled: { opacity: 0.5 },
  resendText: { fontSize: 15, fontWeight: '600', color: Colors.primary },
  resendCountdown: { fontSize: 14, color: '#6B7280' },
});
