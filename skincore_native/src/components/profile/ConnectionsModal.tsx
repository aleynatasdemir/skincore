import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Modal, TouchableOpacity, FlatList, ActivityIndicator, Image } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../theme/colors';
import { profileApi, resolveMediaUrl } from '../../api/apiClient';
import type { PublicUserProfileResponse } from '../../types/social';
import { SafeAreaView } from 'react-native-safe-area-context';

export type ConnectionType = 'followers' | 'following';

interface ConnectionsModalProps {
  visible: boolean;
  type: ConnectionType;
  username?: string; // If provided, fetches for that user; else fetches for self
  onClose: () => void;
  onUserSelect?: (username: string) => void;
}

export function ConnectionsModal({ visible, type, username, onClose, onUserSelect }: ConnectionsModalProps) {
  const [users, setUsers] = useState<PublicUserProfileResponse[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (visible) {
      fetchConnections();
    } else {
      // Reset state if closed
      setUsers([]);
      setError(null);
    }
  }, [visible, type, username]);

  const fetchConnections = async () => {
    setLoading(true);
    setError(null);
    try {
      let data: PublicUserProfileResponse[] = [];
      if (username) {
        data = type === 'followers'
          ? await profileApi.getPublicFollowers(username)
          : await profileApi.getPublicFollowing(username);
      } else {
        data = type === 'followers'
          ? await profileApi.getFollowers()
          : await profileApi.getFollowing();
      }
      setUsers(data);
    } catch (err: any) {
      setError(err.message || 'Kullanıcılar yüklenemedi.');
    } finally {
      setLoading(false);
    }
  };

  const handleFollowToggle = async (targetId: string, isCurrentlyFollowing: boolean) => {
    try {
      if (isCurrentlyFollowing) {
        await profileApi.unfollow(targetId);
      } else {
        await profileApi.follow(targetId);
      }
      setUsers(prev => prev.map(u => 
        u.id.toString() === targetId ? { ...u, isFollowing: !isCurrentlyFollowing } : u
      ));
    } catch (err) {
      console.log('Follow toggle failed', err);
    }
  };

  const renderItem = ({ item }: { item: PublicUserProfileResponse }) => {
    const avatarUrl = resolveMediaUrl(item.profileImageUrl);
    return (
      <TouchableOpacity 
        style={styles.userRow} 
        onPress={() => {
           if (onUserSelect && item.username) onUserSelect(item.username);
        }}>
        {avatarUrl ? (
          <Image source={{ uri: avatarUrl }} style={styles.avatar} />
        ) : (
          <View style={styles.avatarPlaceholder}>
            <Ionicons name="person" size={20} color="#FFF" />
          </View>
        )}
        <View style={styles.userInfo}>
          <Text style={styles.fullName}>{item.fullName || item.username || 'Kullanıcı'}</Text>
          <Text style={styles.usernameText}>@{item.username || 'kullanici'}</Text>
        </View>
        <TouchableOpacity 
          style={[styles.followBtn, item.isFollowing && styles.followingBtn]}
          onPress={() => handleFollowToggle(item.id.toString(), !!item.isFollowing)}
        >
          <Text style={[styles.followBtnText, item.isFollowing && styles.followingBtnText]}>
            {item.isFollowing ? 'Takip Ediliyor' : 'Takip Et'}
          </Text>
        </TouchableOpacity>
      </TouchableOpacity>
    );
  };

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet" onRequestClose={onClose}>
      <SafeAreaView style={styles.container}>
        <View style={styles.header}>
          <Text style={styles.headerTitle}>
            {type === 'followers' ? 'Takipçiler' : 'Takip Edilenler'}
          </Text>
          <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
            <Text style={styles.closeBtnText}>Kapat</Text>
          </TouchableOpacity>
        </View>

        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={Colors.primary} />
          </View>
        ) : error ? (
          <View style={styles.center}>
            <Text style={styles.errorText}>{error}</Text>
            <TouchableOpacity style={styles.retryBtn} onPress={fetchConnections}>
              <Text style={styles.retryText}>Tekrar Dene</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <FlatList
            data={users}
            keyExtractor={item => item.id.toString()}
            renderItem={renderItem}
            contentContainerStyle={styles.listContent}
            ListEmptyComponent={
              <View style={styles.center}>
                <Ionicons name="people-outline" size={48} color="#D1D5DB" />
                <Text style={styles.emptyText}>Gösterilecek kullanıcı bulunamadı.</Text>
              </View>
            }
          />
        )}
      </SafeAreaView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  header: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E5E7EB',
  },
  headerTitle: { fontSize: 18, fontWeight: 'bold', color: Colors.dark },
  closeBtn: { position: 'absolute', right: 16 },
  closeBtnText: { fontSize: 16, color: Colors.primary, fontWeight: '600' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  listContent: { paddingVertical: 8 },
  userRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#F3F4F6',
  },
  avatar: { width: 50, height: 50, borderRadius: 25, backgroundColor: '#F3F4F6' },
  avatarPlaceholder: {
    width: 50, height: 50, borderRadius: 25, backgroundColor: Colors.primary,
    justifyContent: 'center', alignItems: 'center'
  },
  userInfo: { flex: 1, marginLeft: 12 },
  fullName: { fontSize: 16, fontWeight: 'bold', color: '#111827', marginBottom: 2 },
  usernameText: { fontSize: 14, color: '#6B7280' },
  followBtn: { backgroundColor: Colors.primary, paddingHorizontal: 16, paddingVertical: 8, borderRadius: 20 },
  followingBtn: { backgroundColor: '#F3F4F6', borderWidth: 1, borderColor: '#D1D5DB' },
  followBtnText: { color: '#fff', fontSize: 14, fontWeight: 'bold' },
  followingBtnText: { color: '#374151' },
  errorText: { color: '#EF4444', marginBottom: 12 },
  retryBtn: { padding: 8, backgroundColor: '#F3F4F6', borderRadius: 8 },
  retryText: { color: '#374151', fontWeight: 'bold' },
  emptyText: { marginTop: 12, color: '#9CA3AF', fontSize: 16 }
});
