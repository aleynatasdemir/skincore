import React, { useState } from 'react';
import { View, Text, StyleSheet, Modal, TouchableOpacity, SafeAreaView, ActivityIndicator, FlatList } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../theme/colors';
import { profileApi } from '../../api/apiClient';
import type { PublicUserProfileResponse } from '../../types/social';
import { CachedImage } from '../common/CachedImage';

// Varsayımsal bileşen. Gerçek uygulamada navigasyondan tetiklenmesi gerekebilir ama şimdilik "Social" vb. sayfalardan bu modalı açabileceğiz

interface UserProfileModalProps {
  visible: boolean;
  username: string; // Fetch edilecek kullanıcının username'i (benzersiz)
  onClose: () => void;
}

export function UserProfileModal({ visible, username, onClose }: UserProfileModalProps) {
  const [profile, setProfile] = useState<PublicUserProfileResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Bu modal her açıldığında username baz alınarak public profile getirilmeli
  React.useEffect(() => {
    if (visible && username) {
      fetchUserProfile();
    }
  }, [visible, username]);

  const fetchUserProfile = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await profileApi.getPublicProfile(username);
      setProfile(data);
    } catch (err: any) {
      setError(err.message || 'Kullanıcı bulunamadı');
    } finally {
      setLoading(false);
    }
  };

  const handleToggleFollow = async () => {
    if (!profile) return;
    
    // Optimizasyon için önce UI'da değiş (optimistic update)
    const prevIsFollowing = profile.isFollowing;
    const prevFollowerCount = profile.followerCount;
    
    setProfile({ 
      ...profile, 
      isFollowing: !prevIsFollowing,
      followerCount: prevIsFollowing ? prevFollowerCount - 1 : prevFollowerCount + 1
    });

    try {
      if (prevIsFollowing) {
        await profileApi.unfollow(profile.id);
      } else {
        await profileApi.follow(profile.id);
      }
    } catch (err) {
      // Hata alırsan eski haline döndür
      setProfile({ 
        ...profile, 
        isFollowing: prevIsFollowing,
        followerCount: prevFollowerCount
      });
      console.log('Follow işlemi başarısız', err);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <SafeAreaView style={styles.overlay}>
        <View style={styles.header}>
          <TouchableOpacity onPress={onClose} style={styles.backBtn}>
            <Ionicons name="chevron-down" size={28} color="#111827" />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>{username}</Text>
          <View style={{ width: 28 }} />
        </View>

        {loading ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={Colors.primary} />
          </View>
        ) : error ? (
          <View style={styles.center}>
             <Ionicons name="person-circle-outline" size={48} color="#D1D5DB" />
             <Text style={styles.errorText}>{error}</Text>
          </View>
        ) : profile ? (
          <FlatList
            data={[]} // Şimdilik sadece profili gösteriyoruz. Sonradan kişinin rutinleri buraya çekilip maplenebilir.
            ListEmptyComponent={
              <View style={styles.emptyContainer}>
                 <Ionicons name="images-outline" size={48} color="#f3f4f6" />
                 <Text style={styles.emptyText}>Henüz bir rutin paylaşmadı.</Text>
              </View>
            }
            ListHeaderComponent={
              <View style={styles.profileInfoContainer}>
                 <View style={styles.topRow}>
                   <View style={styles.avatarContainer}>
                     <CachedImage
                       source={{ uri: profile.profileImageUrl || `https://ui-avatars.com/api/?name=${profile.fullName || profile.username}&background=D4728C&color=fff` }}
                       style={styles.avatar}
                     />
                   </View>
                   <View style={styles.statsContainer}>
                     <View style={styles.statBox}>
                       <Text style={styles.statNumber}>0</Text>
                       <Text style={styles.statLabel}>Rutin</Text>
                     </View>
                     <View style={styles.statBox}>
                       <Text style={styles.statNumber}>{profile.followerCount}</Text>
                       <Text style={styles.statLabel}>Takipçi</Text>
                     </View>
                     <View style={styles.statBox}>
                       <Text style={styles.statNumber}>{profile.followingCount}</Text>
                       <Text style={styles.statLabel}>Takip</Text>
                     </View>
                   </View>
                 </View>

                 <View style={styles.bioContainer}>
                    <Text style={styles.fullName}>{profile.fullName || profile.username}</Text>
                    {profile.bio ? <Text style={styles.bioText}>{profile.bio}</Text> : null}
                 </View>

                 <TouchableOpacity 
                    style={[styles.followButton, profile.isFollowing && styles.followingBtn]} 
                    onPress={handleToggleFollow}
                  >
                    <Text style={[styles.followBtnText, profile.isFollowing && styles.followingBtnText]}>
                      {profile.isFollowing ? 'Takip Ediliyor' : 'Takip Et'}
                    </Text>
                 </TouchableOpacity>

                 <View style={styles.tabBar}>
                    <View style={styles.activeTab}>
                       <Text style={styles.tabTextActive}>RUTİNLER</Text>
                    </View>
                 </View>
              </View>
            }
            renderItem={() => null} // Kullanıcının oluşturduğu rutinler buraya fetchlenecek.
          />
        ) : null}
      </SafeAreaView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: '#fff',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#e5e7eb'
  },
  backBtn: {
    padding: 4,
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '700',
    color: '#111827',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  errorText: {
    marginTop: 12,
    color: '#6b7280',
  },
  emptyContainer: {
    alignItems: 'center',
    marginTop: 60,
  },
  emptyText: {
    color: '#9ca3af',
    marginTop: 8,
  },
  profileInfoContainer: {
    paddingHorizontal: 20,
    paddingTop: 16,
  },
  topRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  avatarContainer: {
    marginRight: 20,
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#e5e7eb'
  },
  statsContainer: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  statBox: {
    alignItems: 'center',
  },
  statNumber: {
    fontSize: 18,
    fontWeight: '700',
    color: '#111827'
  },
  statLabel: {
    fontSize: 13,
    color: '#6b7280',
    marginTop: 2,
  },
  bioContainer: {
    marginBottom: 16,
  },
  fullName: {
    fontSize: 15,
    fontWeight: 'bold',
    color: '#111827',
    marginBottom: 4,
  },
  bioText: {
    fontSize: 14,
    color: '#374151',
    lineHeight: 20,
  },
  followButton: {
    backgroundColor: Colors.primary,
    paddingVertical: 10,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 20,
  },
  followingBtn: {
    backgroundColor: '#e5e7eb',
  },
  followBtnText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 15,
  },
  followingBtnText: {
    color: '#111827',
  },
  tabBar: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#e5e7eb',
    flexDirection: 'row',
  },
  activeTab: {
    flex: 1,
    paddingVertical: 12,
    alignItems: 'center',
    borderBottomWidth: 2,
    borderBottomColor: Colors.primary,
  },
  tabTextActive: {
    fontSize: 13,
    fontWeight: '600',
    color: '#111827',
    letterSpacing: 1,
  }
});