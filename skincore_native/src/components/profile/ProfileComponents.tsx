import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Image, TextInput, ActivityIndicator, Alert, Modal, SafeAreaView, FlatList } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../theme/colors';
import { resolveMediaUrl } from '../../api/apiClient';
import { useProfileStore } from '../../store/profileStore';
import type { RoutineFeedItem, UserProfileResponse } from '../../types/social';
import type { FavoriteResponse } from '../../types/product';
import { CachedImage } from '../common/CachedImage';

// MARK: - Profile Stats & Header

interface ProfileHeaderProps {
  user: UserProfileResponse;
  myRoutinesCount: number;
  onEditProfile: () => void;
  onOpenSettings: () => void;
}

export function ProfileHeader({ user, myRoutinesCount, onEditProfile, onOpenSettings }: ProfileHeaderProps) {
  return (
    <View style={styles.headerContainer}>
      <View style={styles.topRow}>
        <View style={styles.avatarContainer}>
          <Image
            source={{ uri: resolveMediaUrl(user.profileImageUrl) || 'https://ui-avatars.com/api/?name=' + (user.fullName || user.username) + '&background=D4728C&color=fff' }}
            style={styles.avatar}
          />
        </View>

        <View style={styles.statsContainer}>
          <View style={styles.statBox}>
            <Text style={styles.statNumber}>{myRoutinesCount}</Text>
            <Text style={styles.statLabel}>Rutin</Text>
          </View>
          <TouchableOpacity style={styles.statBox}>
            <Text style={styles.statNumber}>{user.followerCount || 0}</Text>
            <Text style={styles.statLabel}>Takipçi</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.statBox}>
            <Text style={styles.statNumber}>{user.followingCount || 0}</Text>
            <Text style={styles.statLabel}>Takip</Text>
          </TouchableOpacity>
        </View>
      </View>

      <View style={styles.infoRow}>
        <Text style={styles.fullName}>{user.fullName}</Text>
        <Text style={styles.username}>@{user.username}</Text>
        {!!user.bio && <Text style={styles.bio}>{user.bio}</Text>}
      </View>

      <View style={styles.buttonsRow}>
        <TouchableOpacity style={styles.editButton} onPress={onEditProfile}>
          <Text style={styles.editButtonText}>Profili Düzenle</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.settingsButton} onPress={onOpenSettings}>
          <Ionicons name="settings-outline" size={20} color={Colors.dark} />
        </TouchableOpacity>
      </View>
    </View>
  );
}

// MARK: - Grid Cells

interface RoutineGridCellProps {
  item: RoutineFeedItem;
  onPress: () => void;
}

export function RoutineGridCell({ item, onPress }: RoutineGridCellProps) {
  const coverUrl = resolveMediaUrl(item.coverImageUrl);

  return (
    <TouchableOpacity style={styles.gridCell} onPress={onPress}>
      <View style={styles.imageWrapper}>
        {coverUrl ? (
          <CachedImage uri={coverUrl} style={styles.gridImage} />
        ) : (
          <View style={[styles.gridImage, styles.placeholderImage]}>
             <Ionicons name="apps-outline" size={24} color="#9CA3AF" />
          </View>
        )}
      </View>
    </TouchableOpacity>
  );
}

interface FavoriteGridCellProps {
  item: FavoriteResponse;
  onPress: () => void;
}

export function FavoriteGridCell({ item, onPress }: FavoriteGridCellProps) {
  const imageUrl = resolveMediaUrl(item?.image_urls?.[0] || item?.productImageURL);
  
  return (
    <TouchableOpacity style={styles.gridCell} onPress={onPress}>
      <View style={styles.imageWrapper}>
        <View style={styles.imageInner}>
          {imageUrl ? (
            <CachedImage uri={imageUrl} style={styles.gridImageFav} resizeMode="contain" />
          ) : (
            <View style={[styles.gridImageFav, styles.placeholderImage]}>
               <Ionicons name="flask-outline" size={24} color="#9CA3AF" />
            </View>
          )}
        </View>
        <View style={styles.favLabelContainer}>
           <Text style={styles.favLabel} numberOfLines={1}>{item.productName}</Text>
        </View>
      </View>
    </TouchableOpacity>
  );
}

// MARK: - Styles

const styles = StyleSheet.create({
  headerContainer: {
    paddingHorizontal: 20,
    paddingTop: 10,
    paddingBottom: 20,
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
    backgroundColor: '#E5E7EB',
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
    color: Colors.dark,
  },
  statLabel: {
    fontSize: 13,
    color: Colors.muted,
    marginTop: 2,
  },
  infoRow: {
    marginBottom: 16,
  },
  fullName: {
    fontSize: 16,
    fontWeight: '700',
    color: Colors.dark,
  },
  username: {
    fontSize: 14,
    color: Colors.muted,
    marginBottom: 4,
  },
  bio: {
    fontSize: 14,
    color: '#4B5563',
    lineHeight: 20,
  },
  buttonsRow: {
    flexDirection: 'row',
    gap: 12,
  },
  editButton: {
    flex: 1,
    height: 36,
    backgroundColor: '#E5E7EB',
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  editButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.dark,
  },
  settingsButton: {
    width: 36,
    height: 36,
    backgroundColor: '#E5E7EB',
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },

  gridCell: {
    flex: 1/3,
    aspectRatio: 1,
    margin: 1, // Space between grid items
  },
  imageWrapper: {
    flex: 1,
    backgroundColor: '#fff',
    overflow: 'hidden',
  },
  imageInner: {
    flex: 1,
    padding: 8,
  },
  gridImage: {
    width: '100%',
    height: '100%',
  },
  gridImageFav: {
    width: '100%',
    height: '100%',
  },
  placeholderImage: {
    backgroundColor: '#F3F4F6',
    justifyContent: 'center',
    alignItems: 'center',
  },
  favLabelContainer: {
    position: 'absolute',
    bottom: 0, left: 0, right: 0,
    backgroundColor: 'rgba(255,255,255,0.85)',
    paddingHorizontal: 4,
    paddingVertical: 2,
  },
  favLabel: {
    fontSize: 10,
    textAlign: 'center',
    color: Colors.dark,
    fontWeight: '500',
  }
});

// MARK: - Edit Profile Sheet

interface EditProfileSheetProps {
  visible: boolean;
  onClose: () => void;
  user: UserProfileResponse | null;
}

export function EditProfileSheet({ visible, onClose, user }: EditProfileSheetProps) {
  const store = useProfileStore();
  const [fullName, setFullName] = useState(user?.fullName || '');
  const [username, setUsername] = useState(user?.username || '');
  const [bio, setBio] = useState(user?.bio || '');
  const [loading, setLoading] = useState(false);

  const handleSave = async () => {
    if (!username.trim()) {
      Alert.alert('Hata', 'Kullanıcı adı boş olamaz.');
      return;
    }
    
    setLoading(true);
    const success = await store.updateProfile({
      displayName: fullName,
      username: username.toLowerCase().trim(),
      bio: bio
    });
    setLoading(false);

    if (success) {
      onClose();
    } else {
      Alert.alert('Hata', store.error || 'Profil güncellenemedi.');
      store.clearError();
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <SafeAreaView style={stylesSheet.overlay}>
        <View style={stylesSheet.container}>
          <View style={stylesSheet.header}>
            <TouchableOpacity onPress={onClose} disabled={loading}>
              <Text style={stylesSheet.cancelButton}>İptal</Text>
            </TouchableOpacity>
            <Text style={stylesSheet.title}>Profili Düzenle</Text>
            <TouchableOpacity onPress={handleSave} disabled={loading}>
              {loading ? (
                <ActivityIndicator size="small" color={Colors.primary} />
              ) : (
                <Text style={stylesSheet.saveButton}>Bitti</Text>
              )}
            </TouchableOpacity>
          </View>

          <View style={stylesSheet.avatarSection}>
              <Image
                source={{ uri: resolveMediaUrl(user?.profileImageUrl) || 'https://ui-avatars.com/api/?name=' + (user?.fullName || user?.username) + '&background=D4728C&color=fff' }}
                style={stylesSheet.editAvatar}
              />
              <TouchableOpacity>
                <Text style={stylesSheet.changePhotoText}>Fotoğrafı Değiştir</Text>
              </TouchableOpacity>
          </View>

          <View style={stylesSheet.form}>
            <View style={stylesSheet.inputGroup}>
              <Text style={stylesSheet.label}>Ad Soyad</Text>
              <TextInput
                style={stylesSheet.input}
                value={fullName}
                onChangeText={setFullName}
                placeholder="Ad Soyad"
              />
            </View>

            <View style={stylesSheet.inputGroup}>
              <Text style={stylesSheet.label}>Kullanıcı Adı</Text>
              <TextInput
                style={stylesSheet.input}
                value={username}
                onChangeText={setUsername}
                placeholder="kullaniciadi"
                autoCapitalize="none"
              />
            </View>

            <View style={stylesSheet.inputGroup}>
              <Text style={stylesSheet.label}>Hakkında</Text>
              <TextInput
                style={[stylesSheet.input, stylesSheet.bioInput]}
                value={bio}
                onChangeText={setBio}
                placeholder="Kendinden bahset..."
                multiline
                maxLength={150}
              />
            </View>
          </View>
        </View>
      </SafeAreaView>
    </Modal>
  );
}

const stylesSheet = StyleSheet.create({
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
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#f3f4f6',
  },
  cancelButton: {
    fontSize: 16,
    color: '#4b5563',
  },
  saveButton: {
    fontSize: 16,
    fontWeight: 'bold',
    color: Colors.primary,
  },
  title: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#111827',
  },
  avatarSection: {
    alignItems: 'center',
    paddingVertical: 24,
  },
  editAvatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    marginBottom: 12,
  },
  changePhotoText: {
    color: Colors.primary,
    fontWeight: '600',
    fontSize: 14,
  },
  form: {
    paddingHorizontal: 16,
  },
  inputGroup: {
    marginBottom: 16,
  },
  label: {
    fontSize: 12,
    color: '#6b7280',
    marginBottom: 4,
    textTransform: 'uppercase',
  },
  input: {
    borderBottomWidth: 1,
    borderBottomColor: '#e5e7eb',
    fontSize: 16,
    color: '#1f2937',
    paddingVertical: 8,
  },
  bioInput: {
    height: 80,
    textAlignVertical: 'top',
  }
});