import React, { useState } from 'react';
import { View, Text, StyleSheet, TextInput, ScrollView, FlatList, TouchableOpacity, ActivityIndicator, KeyboardAvoidingView, Platform, Dimensions, Modal } from 'react-native';
import { Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useIngredientsStore, INGREDIENT_CATEGORIES } from '../../src/store/ingredientsStore';
import { CategoryRowView, IngredientCard, IngredientDetailSheet } from '../../src/components/ingredients/IngredientComponents';
import type { MatchedIngredient } from '../../src/types/product';

const { height } = Dimensions.get('window');

export default function IngredientsScreen() {
  const store = useIngredientsStore();
  const [selectedIngredient, setSelectedIngredient] = useState<MatchedIngredient | null>(null);

  // MARK: - Handlers
  const handleLoadMore = () => {
    if (!store.isLoading && store.hasMore && (store.searchQuery.trim().length >= 2 || store.selectedCategory)) {
      store.fetchIngredients();
    }
  };

  const isListView = store.selectedCategory !== null || store.searchQuery.trim().length >= 2;

  // MARK: - Renderers
  const renderHeader = () => {
    if (store.selectedCategory) {
      return (
        <View style={styles.listHeaderContainer}>
          <TouchableOpacity onPress={() => store.selectCategory(null)} style={styles.backButton}>
            <Ionicons name="chevron-back" size={24} color="#1A1A2E" />
          </TouchableOpacity>
          <View style={styles.listHeaderTitleBox}>
            <Text style={styles.listHeaderTitle}>{store.selectedCategory.title}</Text>
            <Text style={styles.listHeaderSubtitle}>İçerik Analiz Sonucu</Text>
          </View>
        </View>
      );
    }
    return null;
  };

  const renderCategoryScreen = () => {
    return (
      <ScrollView style={styles.container} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
        {/* Hero Banner */}
        <View style={styles.heroContainer}>
          <View style={styles.heroCard}>
            <View style={styles.heroContent}>
              <Text style={styles.heroTitle}>Kozmetik içeriklerin ne anlama geldiğini keşfedin.</Text>
              
              <View style={styles.searchContainer}>
                <Ionicons name="search" size={18} color="#9CA3AF" />
                <TextInput
                  style={styles.searchInput}
                  placeholder="İçerik Ara (örn: Salisilik Asit)"
                  placeholderTextColor="#9CA3AF"
                  value={store.searchQuery}
                  onChangeText={store.setSearchQuery}
                  autoCapitalize="none"
                  returnKeyType="search"
                />
                {store.searchQuery.length > 0 && (
                  <TouchableOpacity onPress={() => store.setSearchQuery('')}>
                    <Ionicons name="close-circle" size={16} color="#9CA3AF" />
                  </TouchableOpacity>
                )}
              </View>
            </View>
          </View>
        </View>

        {/* Category List */}
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Güvenlik Kategorileri</Text>
          <Text style={styles.sectionSubtitle}>EWG verilerine dayanarak sınıflandırılmıştır.</Text>
        </View>
        
        <View style={styles.categoriesContainer}>
          {INGREDIENT_CATEGORIES.map(cat => (
            <CategoryRowView
              key={cat.id}
              category={cat}
              onPress={() => store.selectCategory(cat)}
            />
          ))}
        </View>
        <View style={{ height: 40 }} />
      </ScrollView>
    );
  };

  const renderListScreen = () => {
    const defaultCategory = INGREDIENT_CATEGORIES[2]; // Fallback to acceptable visually
    const currentCategory = store.selectedCategory || defaultCategory;

    return (
      <View style={styles.container}>
        {renderHeader()}
        
        {store.searchQuery.trim().length >= 2 && !store.selectedCategory && (
          <View style={styles.searchActiveHeader}>
             <View style={styles.searchActiveStickyBar}>
                <Ionicons name="search" size={18} color="#9CA3AF" />
                <TextInput
                  style={styles.searchInput}
                  placeholder="İçerik Ara..."
                  value={store.searchQuery}
                  onChangeText={store.setSearchQuery}
                  autoFocus
                />
                <TouchableOpacity onPress={() => store.setSearchQuery('')}>
                  <Text style={styles.searchCancelText}>İptal</Text>
                </TouchableOpacity>
             </View>
             <Text style={styles.searchResultText}>Arama Sonuçları</Text>
          </View>
        )}

        {store.selectedCategory && (
          <View style={styles.categorySummaryCard}>
             <View style={[styles.summaryIconBox, { backgroundColor: currentCategory.backgroundColor }]}>
                <Ionicons name={currentCategory.icon as any} size={24} color={currentCategory.color} />
             </View>
             <View style={styles.summaryTextBox}>
                {store.isLoading && store.ingredients.length === 0 ? (
                   <Text style={styles.summaryTitle}>Yükleniyor...</Text>
                ) : (
                   <Text style={styles.summaryTitle}>{store.ingredients.length} içerik bulundu</Text>
                )}
                <Text style={styles.summarySubtitle}>Seçilen kategori standartlarında</Text>
             </View>
          </View>
        )}

        <FlatList
          data={store.ingredients}
          keyExtractor={(item) => item.id || Math.random().toString()}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          onEndReached={handleLoadMore}
          onEndReachedThreshold={0.3}
          renderItem={({ item }) => (
            <IngredientCard
              ingredient={item}
              category={currentCategory}
              onPress={() => setSelectedIngredient(item)}
            />
          )}
          ListEmptyComponent={
            store.isLoading ? null : (
              <View style={styles.emptyContainer}>
                <Ionicons name="flask-outline" size={48} color="#D1D5DB" />
                <Text style={styles.emptyText}>Bu kriterlere uygun içerik bulunamadı.</Text>
              </View>
            )
          }
          ListFooterComponent={
            store.isLoading ? <ActivityIndicator size="small" color="#D4728C" style={{ margin: 20 }} /> : <View style={{height: 40}} />
          }
        />
      </View>
    );
  };

  return (
    <KeyboardAvoidingView 
      style={{ flex: 1, backgroundColor: '#FBF3F3' }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <Stack.Screen options={{ title: 'İçerik Sözlüğü', headerShown: !isListView }} />
      
      {isListView ? renderListScreen() : renderCategoryScreen()}

      <Modal
        visible={!!selectedIngredient}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setSelectedIngredient(null)}
      >
        <TouchableOpacity style={styles.modalOverlay} activeOpacity={1} onPress={() => setSelectedIngredient(null)}>
          {selectedIngredient && (
            <TouchableOpacity activeOpacity={1} style={styles.modalContentTouchable}>
                <IngredientDetailSheet 
                  ingredient={selectedIngredient} 
                  onClose={() => setSelectedIngredient(null)} 
                />
            </TouchableOpacity>
          )}
        </TouchableOpacity>
      </Modal>

    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'flex-end',
  },
  modalContentTouchable: {
    width: '100%',
  },
  container: {
    flex: 1,
    backgroundColor: '#FBF3F3',
  },
  heroContainer: {
    padding: 16,
    paddingTop: 8,
  },
  heroCard: {
    backgroundColor: '#FDE8E8',
    borderRadius: 20,
    overflow: 'hidden',
  },
  heroContent: {
    padding: 20,
  },
  heroTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1A1A2E',
    marginBottom: 16,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.8)',
    borderRadius: 14,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  searchInput: {
    flex: 1,
    marginLeft: 8,
    fontSize: 15,
    color: '#1A1A2E',
    paddingVertical: 0,
  },
  sectionHeader: {
    paddingHorizontal: 20,
    marginTop: 16,
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1A1A2E',
  },
  sectionSubtitle: {
    fontSize: 13,
    color: '#6B7280',
    marginTop: 4,
  },
  categoriesContainer: {
    paddingHorizontal: 16,
  },
  // List View Styles
  listHeaderContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingTop: Platform.OS === 'ios' ? 60 : 20, // rough safe area
    paddingHorizontal: 16,
    paddingBottom: 16,
    backgroundColor: '#FBF3F3',
  },
  backButton: {
    padding: 4,
  },
  listHeaderTitleBox: {
    flex: 1,
    alignItems: 'center',
    marginRight: 28, // balance back button
  },
  listHeaderTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1A1A2E',
  },
  listHeaderSubtitle: {
    fontSize: 11,
    fontWeight: '600',
    color: '#D4728C',
    letterSpacing: 0.5,
  },
  searchActiveHeader: {
    paddingHorizontal: 16,
    paddingTop: Platform.OS === 'ios' ? 50 : 16,
  },
  searchActiveStickyBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF',
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  searchCancelText: {
    color: '#D4728C',
    fontWeight: '600',
    fontSize: 14,
    marginLeft: 8,
  },
  searchResultText: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1A1A2E',
    marginBottom: 12,
  },
  categorySummaryCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF',
    marginHorizontal: 16,
    marginBottom: 16,
    padding: 16,
    borderRadius: 16,
    shadowColor: '#000',
    shadowOpacity: 0.04,
    shadowRadius: 8,
    elevation: 2,
  },
  summaryIconBox: {
    width: 52,
    height: 52,
    borderRadius: 26,
    justifyContent: 'center',
    alignItems: 'center',
  },
  summaryTextBox: {
    marginLeft: 16,
  },
  summaryTitle: {
    fontSize: 17,
    fontWeight: 'bold',
    color: '#1A1A2E',
  },
  summarySubtitle: {
    fontSize: 13,
    color: '#6B7280',
    marginTop: 2,
  },
  listContent: {
    paddingHorizontal: 16,
    paddingBottom: 20,
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingTop: 80,
  },
  emptyText: {
    marginTop: 16,
    color: '#6B7280',
    fontSize: 15,
  },
  modal: {
    justifyContent: 'flex-end',
    margin: 0,
  }
});
