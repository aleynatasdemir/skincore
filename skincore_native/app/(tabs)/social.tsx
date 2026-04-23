import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, FlatList, TextInput, TouchableOpacity, SafeAreaView, ActivityIndicator, Modal } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useSocialStore } from '../../src/store/socialStore';
import { RoutineFeedCard, PersonRow, RoutineDetailSheet } from '../../src/components/social/SocialComponents';
import type { RoutineFeedItem, PublicUserProfileResponse } from '../../src/types/social';

export default function SocialScreen() {
  const store = useSocialStore();
  const [selectedRoutine, setSelectedRoutine] = useState<RoutineFeedItem | null>(null);

  useEffect(() => {
    store.fetchData();
  }, []); // Initial load

  const renderHeader = () => (
    <View style={styles.header}>
      <Text style={styles.headerTitle}>Topluluk</Text>
      <TouchableOpacity style={styles.createButton}>
        <Ionicons name="add" size={24} color="#FFF" />
      </TouchableOpacity>
    </View>
  );

  const renderSearchBar = () => (
    <View style={styles.searchContainer}>
      <Ionicons name="search" size={18} color="#9CA3AF" />
      <TextInput
        style={styles.searchInput}
        placeholder={store.activeTab === 'ROUTINES' ? "Rutinlerde ara..." : "Kişilerde ara..."}
        placeholderTextColor="#9CA3AF"
        value={store.searchQuery}
        onChangeText={store.setSearchQuery}
      />
      {store.searchQuery.length > 0 && (
        <TouchableOpacity onPress={() => store.setSearchQuery('')}>
          <Ionicons name="close-circle" size={16} color="#9CA3AF" />
        </TouchableOpacity>
      )}
    </View>
  );

  const renderTabs = () => (
    <View style={styles.tabContainer}>
      <TouchableOpacity 
        style={[styles.tabButton, store.activeTab === 'ROUTINES' && styles.activeTabButton]}
        onPress={() => store.setActiveTab('ROUTINES')}
      >
        <Text style={[styles.tabText, store.activeTab === 'ROUTINES' && styles.activeTabText]}>RUTİNLER</Text>
      </TouchableOpacity>
      <TouchableOpacity 
        style={[styles.tabButton, store.activeTab === 'PEOPLE' && styles.activeTabButton]}
        onPress={() => store.setActiveTab('PEOPLE')}
      >
        <Text style={[styles.tabText, store.activeTab === 'PEOPLE' && styles.activeTabText]}>KİŞİLER</Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <SafeAreaView style={styles.safeArea}>
      {renderHeader()}
      {renderTabs()}
      
      <View style={styles.searchWrapper}>
        {renderSearchBar()}
      </View>

      {store.isLoading && store.routines.length === 0 && store.users.length === 0 ? (
        <View style={styles.centerContainer}>
          <ActivityIndicator size="large" color="#D4728C" />
        </View>
      ) : store.activeTab === 'ROUTINES' ? (
        <FlatList
          data={store.routines}
          keyExtractor={item => item.id}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          renderItem={({ item }) => (
            <RoutineFeedCard 
              item={item} 
              onPress={() => setSelectedRoutine(item)} 
            />
          )}
          ListEmptyComponent={
            <View style={styles.centerContainer}>
              <Ionicons name="images-outline" size={48} color="#D1D5DB" />
              <Text style={styles.emptyText}>Henüz bir rutin bulunamadı.</Text>
            </View>
          }
        />
      ) : (
        <FlatList
          data={store.users}
          keyExtractor={item => item.id}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          renderItem={({ item }) => <PersonRow user={item} />}
          ListEmptyComponent={
            <View style={styles.centerContainer}>
              <Ionicons name="people-outline" size={48} color="#D1D5DB" />
              <Text style={styles.emptyText}>Kimse bulunamadı.</Text>
            </View>
          }
        />
      )}

      {/* Routine Detail Modal */}
      <Modal
        visible={!!selectedRoutine}
        animationType="slide"
        transparent={true}
        onRequestClose={() => setSelectedRoutine(null)}
      >
        <TouchableOpacity style={styles.modalOverlay} activeOpacity={1} onPress={() => setSelectedRoutine(null)}>
          {selectedRoutine && (
            <TouchableOpacity activeOpacity={1} style={styles.modalContentTouchable}>
              <RoutineDetailSheet 
                routine={selectedRoutine} 
                onClose={() => setSelectedRoutine(null)} 
              />
            </TouchableOpacity>
          )}
        </TouchableOpacity>
      </Modal>

    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#FBF3F3',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 10,
    paddingBottom: 20,
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: '800',
    color: '#1A1A2E',
  },
  createButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#D4728C',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#D4728C',
    shadowOpacity: 0.3,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 4 },
  },
  tabContainer: {
    flexDirection: 'row',
    marginHorizontal: 16,
    backgroundColor: '#F3F4F6',
    borderRadius: 12,
    padding: 4,
    marginBottom: 16,
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
  searchWrapper: {
    paddingHorizontal: 16,
    marginBottom: 16,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF',
    borderRadius: 14,
    paddingHorizontal: 12,
    paddingVertical: 10,
    shadowColor: '#000',
    shadowOpacity: 0.03,
    shadowRadius: 5,
    elevation: 1,
  },
  searchInput: {
    flex: 1,
    marginLeft: 8,
    fontSize: 15,
    color: '#1A1A2E',
    paddingVertical: 0,
  },
  listContent: {
    paddingBottom: 80,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: 60,
  },
  emptyText: {
    marginTop: 12,
    color: '#6B7280',
    fontSize: 15,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  modalContentTouchable: {
    width: '100%',
  }
});
