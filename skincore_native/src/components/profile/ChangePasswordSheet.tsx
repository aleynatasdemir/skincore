import React, { useState } from 'react';
import { View, Text, StyleSheet, Modal, TouchableOpacity, TextInput, ActivityIndicator, Alert, SafeAreaView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../theme/colors';
import { authApi, extractErrorMessage } from '../../api/apiClient';

interface ChangePasswordSheetProps {
  visible: boolean;
  onClose: () => void;
}

export function ChangePasswordSheet({ visible, onClose }: ChangePasswordSheetProps) {
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSave = async () => {
    if (!currentPassword || !newPassword || !confirmPassword) {
      Alert.alert('Dikkat', 'Lütfen tüm alanları doldurun.');
      return;
    }
    if (newPassword !== confirmPassword) {
      Alert.alert('Dikkat', 'Yeni şifreler eşleşmiyor.');
      return;
    }
    if (newPassword.length < 6) {
      Alert.alert('Dikkat', 'Yeni şifre en az 6 karakter olmalıdır.');
      return;
    }

    setLoading(true);
    try {
      await authApi.changePassword({ currentPassword, newPassword });
      Alert.alert('Başarılı', 'Şifreniz başarıyla değiştirildi.');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      onClose();
    } catch (error) {
      Alert.alert('Hata', extractErrorMessage(error));
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <SafeAreaView style={styles.overlay}>
        <View style={styles.container}>
          <View style={styles.header}>
            <TouchableOpacity onPress={onClose} disabled={loading} style={styles.closeBtn}>
              <Ionicons name="close" size={24} color="#111827" />
            </TouchableOpacity>
            <Text style={styles.headerTitle}>Şifre Değiştir</Text>
            <TouchableOpacity onPress={handleSave} disabled={loading}>
              {loading ? (
                 <ActivityIndicator size="small" color={Colors.primary} />
              ) : (
                 <Text style={styles.saveBtn}>Kaydet</Text>
              )}
            </TouchableOpacity>
          </View>

          <View style={styles.form}>
            <Text style={styles.label}>MEVCUT ŞİFRE</Text>
            <TextInput
              style={styles.input}
              placeholder="Mevcut Şifre"
              secureTextEntry
              value={currentPassword}
              onChangeText={setCurrentPassword}
            />

            <Text style={styles.label}>YENİ ŞİFRE</Text>
            <TextInput
              style={styles.input}
              placeholder="Yeni Şifre"
              secureTextEntry
              value={newPassword}
              onChangeText={setNewPassword}
            />

             <Text style={styles.label}>YENİ ŞİFRE (TEKRAR)</Text>
            <TextInput
              style={styles.input}
              placeholder="Yeni Şifre (Tekrar)"
              secureTextEntry
              value={confirmPassword}
              onChangeText={setConfirmPassword}
            />
          </View>
        </View>
      </SafeAreaView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: '#fff',
  },
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D1D5DB',
  },
  closeBtn: {
    padding: 4,
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '700',
    color: '#111827',
  },
  saveBtn: {
    fontSize: 16,
    fontWeight: 'bold',
    color: Colors.primary,
    padding: 4,
  },
  form: {
    padding: 20,
  },
  label: {
    fontSize: 12,
    color: '#6B7280',
    marginBottom: 8,
    marginTop: 16,
  },
  input: {
    borderWidth: 1,
    borderColor: '#D1D5DB',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 14,
    fontSize: 16,
    color: '#111827',
    backgroundColor: '#F9FAFB',
  },
});