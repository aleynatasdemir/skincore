import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ActivityIndicator, FlatList, Dimensions, TouchableOpacity, RefreshControl, Platform } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Colors } from '../../src/theme/colors';
import { useProfileStore, ProfileTabState } from '../../src/store/profileStore';
import { ProfileHeader, RoutineGridCell, FavoriteGridCell, EditProfileSheet } from '../../src/components/profile/ProfileComponents';
import { SettingsSheet } from '../../src/components/profile/SettingsSheet';
import type { RoutineFeedItem } from '../../src/types/social';
import type { FavoriteResponse } from '../../src/types/product';

const { width } = Dimensions.get('window');
const COLUMN_COUNT = 3;
const ITEM_WIDTH = width / COLUMN_COUNT;

export default function ProfileScreen() {
  const router = useRouter();
  const store = useProfileStore();
  const [refreshing, setRefreshing] = useState(false);

  // Modals state
  const [showSettings, setShowSettings] = useState(false);
  const [showEditProfile, setShowEditProfile] = useState(false);

  useEffect(() => {
    store.fetchProfile();
  }, []);

  const onRefresh = async () => {
    setRefreshing(true);
    await store.fetchProfile();
    setRefreshing(false);
  };

  const renderTabs = () => (
    <View style={styles.tabContainer}>
      <TouchableOpacity 
        style={[styles.tabButton, store.activeTab === 'ROUTINES' && styles.activeTabButton]}
        onPress={() => store.setActiveTab('ROUTINES')}
      >
        <Text style={[styles.tabText, store.activeTab === 'ROUTINES' && styles.activeTabText]}>RUTİNLER</Text>
      </TouchableOpacity>
      <TouchableOpacity 
        style={[styles.tabButton, store.activeTab === 'FAVORITES' && styles.activeTabButton]}
        onPress={() => store.setActiveTab('FAVORITES')}
      >
        <Text style={[styles.tabText, store.activeTab === 'FAVORITES' && styles.activeTabText]}>FAVORİLER</Text>
      </TouchableOpacity>
    </View>
  );

  const renderRoutineItem = ({ item }: { item: RoutineFeedItem }) => (
    <RoutineGridCell item={item} onPress={() => console.log('Routine tapped', item.id)} />
  );

  const renderFavoriteItem = ({ item }: { item: FavoriteResponse }) => (
    <FavoriteGridCell item={item} onPress={() => router.push(`/product/${item.productId}`)} />
  );

  if (store.isLoading && !store.myProfile && !refreshing) {
    return (
      <SafeAreaView style={[styles.container, styles.center]}>
        <ActivityIndicator size="large" color={Colors.primary} />
      </SafeAreaView>
    );
  }

  // Create a combined data array for FlatList to render Header + Tabs + Grid
  // This avoids nesting FlatList inside ScrollView
  const gridData = store.activeTab === 'ROUTINES' ? store.myRoutines : store.myFavorites;

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <FlatList
        data={gridData}
        key={store.activeTab} // Force re-render on tab switch for column num
        numColumns={COLUMN_COUNT}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.primary} />
        }
        ListHeaderComponent={
          <>
            {store.myProfile && (
              <ProfileHeader 
                user={store.myProfile} 
                myRoutinesCount={store.myRoutines?.length || 0}
                onEditProfile={() => setShowEditProfile(true)}
                onOpenSettings={() => setShowSettings(true)}
              />
            )}
            {renderTabs()}
          </>
        }
        renderItem={(props) => {
          if (store.activeTab === 'ROUTINES') {
            return renderRoutineItem({ item: props.item as RoutineFeedItem });
          } else {
            return renderFavoriteItem({ item: props.item as FavoriteResponse });
          }
        }}
        keyExtractor={(item: any) => item.id || item.productId}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyText}>
              {store.activeTab === 'ROUTINES' ? 'Henüz bir rutin oluşturmadın.' : 'Henüz favori eklemedin.'}
            </Text>
          </View>
        }
      />

      {showSettings && (
        <SettingsSheet 
          visible={showSettings} 
          onClose={() => setShowSettings(false)} 
        />
      )}

      {showEditProfile && (
        <EditProfileSheet 
          visible={showEditProfile} 
          onClose={() => setShowEditProfile(false)} 
          user={store.myProfile}
        />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FBF3F3', // Using the app's background color
  },
  center: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  listContent: {
    paddingBottom: 40,
  },
  tabContainer: {
    flexDirection: 'row',
    marginHorizontal: 16,
    backgroundColor: '#F3F4F6',
    borderRadius: 12,
    padding: 4,
    marginBottom: 8,
  },
  tabButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 10,
    borderRadius: 8,
  },
  activeTabButton: {
    backgroundColor: '#FFF',
    shadowColor: '#000',
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  tabText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#9CA3AF',
    letterSpacing: 1,
  },
  activeTabText: {
    color: '#1A1A2E',
  },
  emptyContainer: {
    height: 200,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyText: {
    color: Colors.muted,
    fontSize: 14,
  },
});
