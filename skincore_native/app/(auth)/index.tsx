import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  Platform,
  Linking,
  ScrollView,
  KeyboardAvoidingView,
} from 'react-native';
import { useRouter } from 'expo-router';
import * as AppleAuthentication from 'expo-apple-authentication';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTranslation } from 'react-i18next';
import { Colors } from '../../src/theme/colors';
import { Ionicons } from '@expo/vector-icons';
import { useAuthStore } from '../../src/store/authStore';

export default function LoginScreen() {
  const { t } = useTranslation();
  const router = useRouter();
  const { appleSignIn, isLoading, errorMessage, clearError } = useAuthStore();

  const handleApple = async () => {
    try {
      clearError();
      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
        ],
      });
      const fullName = credential.fullName
        ? `${credential.fullName.givenName ?? ''} ${credential.fullName.familyName ?? ''}`.trim()
        : undefined;
      await appleSignIn(
        credential.identityToken ?? '',
        fullName || undefined,
        credential.email ?? undefined
      );
    } catch (e: any) {
      if (e.code !== 'ERR_REQUEST_CANCELED') {
        Alert.alert('Apple Sign In', e.message);
      }
    }
  };

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
          {/* Logo */}
          <View style={styles.logoWrap}>
            <Text style={styles.logo}>{t('appBrand')}</Text>
            <Text style={styles.title}>{t('loginWelcome')}</Text>
            <Text style={styles.subtitle}>{t('loginSubtitle')}</Text>
          </View>

          {/* Buttons */}
          <View style={styles.actions}>
            {/* Apple Sign In */}
            {Platform.OS === 'ios' && (
              <AppleAuthentication.AppleAuthenticationButton
                buttonType={AppleAuthentication.AppleAuthenticationButtonType.CONTINUE}
                buttonStyle={AppleAuthentication.AppleAuthenticationButtonStyle.BLACK}
                cornerRadius={28}
                style={styles.appleBtn}
                onPress={handleApple}
              />
            )}

            {/* E-posta ile devam */}
            <TouchableOpacity
              style={styles.emailBtn}
              onPress={() => { clearError(); router.push('/(auth)/register'); }}
              activeOpacity={0.85}
            >
              <Ionicons name="mail-outline" size={20} color={Colors.dark} style={styles.emailIcon} />
              <Text style={styles.emailBtnText}>{t('loginContinueEmail')}</Text>
            </TouchableOpacity>
          </View>

          {/* Links */}
          <View style={styles.links}>
            <TouchableOpacity
              style={styles.linkRow}
              onPress={() => { clearError(); router.push('/(auth)/email-login'); }}
              activeOpacity={0.7}
            >
              <Text style={styles.linkGray}>{t('alreadyHaveAccount')} </Text>
              <Text style={styles.linkDark}>{t('loginButton')}</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.linkRow}
              onPress={() => { clearError(); router.push('/(auth)/register'); }}
              activeOpacity={0.7}
            >
              <Text style={styles.linkGray}>{t('newToSkincore')} </Text>
              <Text style={styles.linkDark}>{t('signUp')}</Text>
            </TouchableOpacity>
          </View>

          {/* Error */}
          {errorMessage ? (
            <View style={styles.errorBox}>
              <Ionicons name="warning-outline" size={20} color={Colors.danger} />
              <Text style={styles.errorText}>{errorMessage}</Text>
            </View>
          ) : null}

          {/* Terms */}
          <View style={styles.terms}>
            <Text style={styles.termsText}>{t('termsPrefix')}</Text>
            <View style={styles.termsRow}>
              <TouchableOpacity onPress={() => Linking.openURL('https://skincore.beauty/terms.html')}>
                <Text style={styles.termsLink}>{t('termService')}</Text>
              </TouchableOpacity>
              <Text style={styles.termsText}> {t('termsAnd')} </Text>
              <TouchableOpacity onPress={() => Linking.openURL('https://skincore.beauty/privacy.html')}>
                <Text style={styles.termsLink}>{t('termsPrivacy')}</Text>
              </TouchableOpacity>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: Colors.background },
  scroll: { flexGrow: 1, paddingBottom: 32 },
  logoWrap: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 60, paddingHorizontal: 40 },
  logo: { fontSize: 48, fontWeight: '300', color: Colors.primary, marginBottom: 32 },
  title: { fontSize: 28, fontWeight: '700', color: Colors.dark, marginBottom: 12, textAlign: 'center' },
  subtitle: { fontSize: 15, color: '#6B7280', textAlign: 'center', lineHeight: 22 },

  actions: { paddingHorizontal: 24, gap: 14, marginTop: 32 },
  appleBtn: { height: 56, width: '100%' },
  emailBtn: {
    height: 56, borderRadius: 28, backgroundColor: Colors.surface,
    borderWidth: 1.5, borderColor: Colors.border,
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10,
  },
  emailIcon: { fontSize: 16, color: Colors.dark },
  emailBtnText: { fontSize: 17, fontWeight: '500', color: Colors.dark },

  links: { marginTop: 24, alignItems: 'center', gap: 10 },
  linkRow: { flexDirection: 'row', alignItems: 'center' },
  linkGray: { fontSize: 14, color: '#6B7280' },
  linkDark: { fontSize: 14, fontWeight: '600', color: Colors.dark },

  errorBox: {
    marginHorizontal: 16, marginTop: 16, padding: 12,
    backgroundColor: '#FEE2E2', borderRadius: 10,
    borderWidth: 1, borderColor: '#FECACA',
    flexDirection: 'row', alignItems: 'flex-start', gap: 10,
  },
  errorIcon: { fontSize: 16, color: Colors.danger },
  errorText: { flex: 1, fontSize: 14, fontWeight: '500', color: '#DC2626' },

  terms: { marginTop: 24, alignItems: 'center', paddingHorizontal: 40 },
  termsRow: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', justifyContent: 'center' },
  termsText: { fontSize: 12, color: Colors.muted, textAlign: 'center' },
  termsLink: { fontSize: 12, color: Colors.primary },
});
