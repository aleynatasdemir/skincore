import React, { useState } from 'react';
import { View, Text, StyleSheet, Modal, TouchableOpacity, ScrollView, Switch, Alert, SafeAreaView, Linking } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../theme/colors';
import { useAuthStore } from '../../store/authStore';
import { ChangePasswordSheet } from './ChangePasswordSheet';

interface SettingsSheetProps {
  visible: boolean;
  onClose: () => void;
}

export function SettingsSheet({ visible, onClose }: SettingsSheetProps) {
  const authStore = useAuthStore();
  const user = authStore.currentUser;

  const [notifications, setNotifications] = useState(user?.notificationsEnabled || false);
  const [showChangePassword, setShowChangePassword] = useState(false);

  const toggleNotifications = async (value: boolean) => {
    setNotifications(value);
    try {
      await authStore.updateNotifications(value);
    } catch {
      setNotifications(!value); // revert
    }
  };

  const handleLogout = () => {
    Alert.alert('Çıkış', 'Hesabınızdan çıkış yapmak istediğinize emin misiniz?', [
      { text: 'İptal', style: 'cancel' },
      { 
        text: 'Çıkış Yap', 
        style: 'destructive',
        onPress: async () => {
          await authStore.logout();
          onClose();
        }
      }
    ]);
  };

  const handleDeleteAccount = () => {
    Alert.alert('Hesabı Sil', 'Bu işlem geri alınamaz. Devam etmek istiyor musunuz?', [
      { text: 'İptal', style: 'cancel' },
      { 
        text: 'Sil', 
        style: 'destructive',
        onPress: async () => {
          const success = await authStore.deleteAccount();
          if (success) onClose();
        }
      }
    ]);
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <SafeAreaView style={styles.overlay}>
        <View style={styles.header}>
          <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
             <Ionicons name="close" size={24} color="#111827" />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Ayarlar</Text>
          <View style={{ width: 24 }} />
        </View>

        <ScrollView style={styles.content}>
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>HESAP</Text>
            
            <TouchableOpacity style={styles.row} onPress={() => setShowChangePassword(true)}>
              <View style={styles.rowLeft}>
                <Ionicons name="lock-closed-outline" size={20} color="#4B5563" />
                <Text style={styles.rowText}>Şifreyi Değiştir</Text>
              </View>
              <Ionicons name="chevron-forward" size={20} color="#9CA3AF" />
            </TouchableOpacity>
            
             <View style={styles.row}>
              <View style={styles.rowLeft}>
                <Ionicons name="notifications-outline" size={20} color="#4B5563" />
                <Text style={styles.rowText}>Bildirimler</Text>
              </View>
              <Switch
                value={notifications}
                onValueChange={toggleNotifications}
                trackColor={{ false: '#d1d5db', true: Colors.primary }}
              />
            </View>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>HAKKINDA</Text>
            
            <TouchableOpacity style={styles.row} onPress={() => Linking.openURL('https://skincore.app/privacy')}>
              <View style={styles.rowLeft}>
                <Ionicons name="shield-checkmark-outline" size={20} color="#4B5563" />
                <Text style={styles.rowText}>Gizlilik Politikası</Text>
              </View>
              <Ionicons name="chevron-forward" size={20} color="#9CA3AF" />
            </TouchableOpacity>

            <TouchableOpacity style={styles.row} onPress={() => Linking.openURL('https://skincore.app/terms')}>
              <View style={styles.rowLeft}>
                <Ionicons name="document-text-outline" size={20} color="#4B5563" />
                <Text style={styles.rowText}>Kullanım Koşulları</Text>
              </View>
              <Ionicons name="chevron-forward" size={20} color="#9CA3AF" />
            </TouchableOpacity>
          </View>

          <View style={styles.section}>
            <TouchableOpacity style={[styles.row, { borderBottomWidth: 0 }]} onPress={handleLogout}>
              <View style={styles.rowLeft}>
                <Ionicons name="log-out-outline" size={20} color={Colors.danger} />
                <Text style={[styles.rowText, { color: Colors.danger }]}>Çıkış Yap</Text>
              </View>
            </TouchableOpacity>
          </View>

          <View style={[styles.section, { backgroundColor: 'transparent' }]}>
             <TouchableOpacity style={styles.deleteButton} onPress={handleDeleteAccount}>
                <Text style={styles.deleteButtonText}>Hesabımı Sil</Text>
             </TouchableOpacity>
             <Text style={styles.versionText}>SkinCore v1.0.0</Text>
          </View>

        </ScrollView>
      </SafeAreaView>

      <ChangePasswordSheet 
        visible={showChangePassword} 
        onClose={() => setShowChangePassword(false)} 
      />
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: '#F3F4F6',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 14,
    backgroundColor: '#fff',
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
  content: {
    flex: 1,
  },
  section: {
    backgroundColor: '#fff',
    marginTop: 24,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#D1D5DB',
  },
  sectionTitle: {
    fontSize: 12,
    fontWeight: '600',
    color: '#6B7280',
    marginLeft: 16,
    marginBottom: 8,
    marginTop: -20, // push up above background
    backgroundColor: '#F3F4F6', // hide top-border behind it
    alignSelf: 'flex-start'
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E5E7EB',
  },
  rowLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  rowText: {
    fontSize: 16,
    color: '#111827',
  },
  deleteButton: {
    marginTop: 32,
    alignSelf: 'center',
  },
  deleteButtonText: {
    color: Colors.danger,
    fontSize: 15,
    fontWeight: '600',
  },
  versionText: {
    textAlign: 'center',
    marginTop: 16,
    color: '#9CA3AF',
    fontSize: 13,
  }
});