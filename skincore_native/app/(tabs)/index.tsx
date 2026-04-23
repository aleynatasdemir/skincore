import React, { useEffect, useState, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, ActivityIndicator, Keyboard } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { Colors } from '../../src/theme/colors';
import { useHomeStore } from '../../src/store/homeStore';
import {
  HeroCard,
  PopularProductCard,
  QuickActionCard,
  SearchProductRow,
  HistoryRow
} from '../../src/components/home/HomeComponents';

export default function HomeScreen() {
  const router = useRouter();
  const [searchText, setSearchText] = useState('');
  
  const {
    searchResults,
    isSearching,
    popularProducts,
    isLoadingPopular,
    searchHistory,
    isLoadingHistory,
    searchProducts,
    clearSearchResults,
    fetchPopularProducts,
    fetchSearchHistory,
    addSearchHistory,
    deleteHistoryItem,
    clearHistory
  } = useHomeStore();

  // Initial fetch
  useEffect(() => {
    fetchPopularProducts();
    fetchSearchHistory();
  }, []);

  // Debounce logic for search
  useEffect(() => {
    const timer = setTimeout(() => {
      searchProducts(searchText);
    }, 350);
    return () => clearTimeout(timer);
  }, [searchText]);

  const handleProductTap = async (productId: string, productName?: string, firstImageUrl?: string, brand?: string) => {
    // Add to history
    await addSearchHistory(searchText || productName || 'Ürün', productId, productName, brand, firstImageUrl);
    router.push(`/product/${productId}`);
  };

  const renderContent = () => {
    if (searchText.trim().length > 0) {
      return (
        <View style={styles.resultsContainer}>
          <Text style={styles.resultsStatus}>
            {isSearching ? 'Aranıyor...' : (searchResults.length === 0 ? 'Sonuç bulunamadı' : `${searchResults.length} ürün bulundu`)}
          </Text>
          {isSearching && <ActivityIndicator size="small" color="#D4728C" style={{ marginTop: 20 }} />}
          
          {!isSearching && searchResults.map(product => (
            <SearchProductRow 
              key={product.id} 
              product={product} 
              onPress={() => handleProductTap(product.id, product.name, product.firstImageUrl, product.brand)} 
            />
          ))}
        </View>
      );
    }

    return (
      <View style={styles.homeContent}>
        <HeroCard onPress={() => router.push('/(tabs)/scan')} />

        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>En Çok Arananlar</Text>
          {isLoadingPopular && <ActivityIndicator size="small" color="#D4728C" />}
        </View>
        
        {popularProducts.length === 0 && !isLoadingPopular ? (
           <Text style={styles.emptyText}>Henüz veri yok.</Text>
        ) : (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.popularScroll}>
            {popularProducts.map(item => (
              <PopularProductCard 
                key={item.productId} 
                item={item} 
                onPress={() => handleProductTap(item.productId, item.productName, item.resolvedImageUrl)} 
              />
            ))}
          </ScrollView>
        )}

        <Text style={[styles.sectionTitle, { marginHorizontal: 16, marginTop: 12, marginBottom: 12 }]}>
          Keşfet
        </Text>
        <View style={styles.quickActionsRow}>
          <QuickActionCard
            title="Cilt Tipi Testi"
            subtitle="Cildini tanıyarak sana en uygun rutini keşfet"
            imageSource={require('../../assets/images/quiz_card_background.png')}
            onPress={() => console.log('Quiz triggered')}
          />
          <View style={{ width: 12 }} />
          <QuickActionCard
            title="Rutin Oluştur"
            subtitle="Ürünlerini ekle, günlük cilt bakım rutinini planla"
            imageSource={require('../../assets/images/routine_card_background.png')}
            onPress={() => console.log('Routine triggered')}
          />
        </View>

        {(searchHistory.length > 0 || isLoadingHistory) && (
          <View style={styles.historySection}>
            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>Son Aramalar</Text>
              {isLoadingHistory ? (
                <ActivityIndicator size="small" color="#D4728C" />
              ) : (
                <TouchableOpacity onPress={clearHistory}>
                  <Text style={styles.clearText}>Tümünü Sil</Text>
                </TouchableOpacity>
              )}
            </View>
            <View style={styles.historyList}>
               {searchHistory.map((item, index) => (
                 <HistoryRow 
                   key={item.id || index.toString()} 
                   item={item} 
                   onDelete={() => deleteHistoryItem(item.id)}
                   onPress={() => {
                     if (item.productId) {
                       handleProductTap(item.productId, item.productName, item.imageUrl, item.category);
                     } else {
                       setSearchText(item.query);
                     }
                   }} 
                 />
               ))}
            </View>
          </View>
        )}
      </View>
    );
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <Text style={styles.brandTitle}>skincore.</Text>
      </View>

      <View style={styles.searchBarContainer}>
        <Ionicons name={isSearching ? "sync-circle-outline" : "search"} size={20} color="#9CA3AF" />
        <TextInput
          style={styles.searchInput}
          placeholder="Ürün, marka veya içerik ara..."
          placeholderTextColor="#9CA3AF"
          value={searchText}
          onChangeText={setSearchText}
          autoCorrect={false}
          autoCapitalize="none"
        />
        {searchText.length > 0 && (
          <TouchableOpacity onPress={() => { setSearchText(''); Keyboard.dismiss(); }}>
            <Ionicons name="close-circle" size={20} color="#9CA3AF" />
          </TouchableOpacity>
        )}
      </View>

      <ScrollView 
        contentContainerStyle={styles.scrollContent} 
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        onScrollBeginDrag={() => Keyboard.dismiss()}
      >
        {renderContent()}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFF0F0',
  },
  header: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  brandTitle: {
    fontSize: 26,
    fontWeight: '300',
    color: '#D4728C',
  },
  searchBarContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF',
    marginHorizontal: 16,
    paddingHorizontal: 12,
    height: 46,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#E5E7EB',
    marginBottom: 16,
  },
  searchInput: {
    flex: 1,
    height: '100%',
    marginLeft: 8,
    color: '#1A1A2E',
    fontSize: 15,
  },
  scrollContent: {
    paddingBottom: 80,
  },
  resultsContainer: {
    paddingHorizontal: 16,
  },
  resultsStatus: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#9CA3AF',
    marginBottom: 12,
  },
  homeContent: {
    paddingTop: 8,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1A1A2E',
  },
  emptyText: {
    fontSize: 12,
    color: '#9CA3AF',
    paddingHorizontal: 16,
  },
  popularScroll: {
    paddingHorizontal: 16,
    paddingBottom: 4,
  },
  quickActionsRow: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    marginBottom: 24,
  },
  historySection: {
    marginTop: 8,
  },
  clearText: {
    fontSize: 13,
    fontWeight: '500',
    color: '#EF4444',
  },
  historyList: {
    paddingHorizontal: 16,
  }
});
