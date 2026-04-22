import React, { useState } from 'react';
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

export default function ForgotPasswordScreen() {
  const { t } = useTranslation();
  const router = useRouter();
  const { forgotPassword, isLoading, errorMessage, clearError } = useAuthStore();

  const [email, setEmail] = useState('');

  const handleSendCode = async () => {
    if (!email.trim() || isLoading) return;
    clearError();
    await forgotPassword(email.trim());
    // Hata yoksa reset ekranına otomatik yönlendirme için errorMessage'a bakamayız, 
    // ama authStore state'ini kullanabiliriz (async olduğu için await sonrası pendingEmail setlenir).
    // Ancak `errorMessage` set edildiyse throw etmiyor store, reject atmıyor. 
    // Bunun yerine basitçe store'daki errorMessage null mu diye kontrol etmeden önce 
    // authStore içinde pendingEmail dolu mu diye bakabiliriz, veya forgotPassword promise 
    // reject/throw yapacak şekilde güncelleriz. Or hook'ta `forgotPassword` throws kullanabiliriz.
    // Şimdilik route push yapacağız eğer email setlenmişse. 
    
    // Store implementation'umuzda forgotPassword throw YAPIYOR MU? 
    // "try { await authApi.forgotPassword(email); set(...) } catch { set(...) }"
    // Throw etmiyor, sadece state güncelliyor. 
    // Çözüm olarak store'a subscribe olacağız veya reset screen'e geçişi store ile yönetebiliriz.
    // Basit bir timeout ile state'in oturmasını bekleyip errorMessage yoksa gideceğiz:
    setTimeout(() => {
      const { errorMessage: currentError } = useAuthStore.getState();
      if (!currentError) {
        router.push('/(auth)/reset-password');
      }
    }, 100);
  };

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
          <Text style={styles.title}>{t('forgotPassword')}</Text>
          
          <Text style={styles.subtitle}>{t('forgotPasswordSubtitle')}</Text>

          <View style={styles.form}>
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
                returnKeyType="done"
                onSubmitEditing={handleSendCode}
              />
            </View>
          </View>

          {errorMessage ? (
            <View style={styles.errorBox}>
              <Text style={styles.errorIcon}>⚠</Text>
              <Text style={styles.errorText}>{errorMessage}</Text>
            </View>
          ) : null}

          <TouchableOpacity
            style={[styles.btn, (!email.trim() || isLoading) && styles.btnDisabled]}
            onPress={handleSendCode}
            disabled={!email.trim() || isLoading}
            activeOpacity={0.85}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.btnText}>{t('sendResetCode')}</Text>
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
  title: { fontSize: 24, fontWeight: '700', color: Colors.dark, textAlign: 'center', marginBottom: 16 },
  subtitle: { fontSize: 15, color: '#6B7280', textAlign: 'center', paddingHorizontal: 32, marginBottom: 32, lineHeight: 22 },
  
  form: { paddingHorizontal: 24 },
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
