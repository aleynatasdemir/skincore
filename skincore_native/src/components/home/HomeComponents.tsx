import React from 'react';
import { View, Text, Image, TouchableOpacity, StyleSheet, Dimensions } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { resolvePopularImageUrl, resolveFirstImageUrl, resolveHistoryImageUrl } from '../../types/product';
import type { Product, PopularProductResponse, SearchHistoryResponse } from '../../types/product';
import { resolveMediaUrl } from '../../api/apiClient';

const { width } = Dimensions.get('window');

// MARK: - Hero Card (Scan Shelf)
interface HeroCardProps {
  onPress: () => void;
}
export const HeroCard: React.FC<HeroCardProps> = ({ onPress }) => {
  return (
    <View style={styles.heroContainer}>
      <Image
        source={require('../../../assets/images/scan_shelf_background.png')}
        style={styles.heroImage}
      />
      <View style={styles.heroGradient}>
        <View style={styles.heroBadge}>
          <Text style={styles.heroBadgeText}>YENİ</Text>
        </View>
        <Text style={styles.heroTitle}>Rafınızı Tarayın</Text>
        <Text style={styles.heroDesc}>
          Cilt bakım ürünlerinizi tek seferde tarayın ve uyumluluklarını anında öğrenin.
        </Text>
        <TouchableOpacity style={styles.heroButton} onPress={onPress}>
          <Ionicons name="scan-outline" size={16} color="#1A1A2E" />
          <Text style={styles.heroButtonText}>Hemen Tara</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

// MARK: - Popular Product Card
interface PopularProductCardProps {
  item: PopularProductResponse;
  onPress: () => void;
}
export const PopularProductCard: React.FC<PopularProductCardProps> = ({ item, onPress }) => {
  const imageUrl = resolveMediaUrl(resolvePopularImageUrl(item)) ?? 'https://via.placeholder.com/150';
  
  return (
    <TouchableOpacity style={styles.popularCard} onPress={onPress} activeOpacity={0.8}>
      <Image source={{ uri: imageUrl }} style={styles.popularImage} />
      <Text style={styles.popularTitle} numberOfLines={2}>
        {item.productName || 'isimsiz ürün'}
      </Text>
    </TouchableOpacity>
  );
};

// MARK: - Quick Action Card
interface QuickActionCardProps {
  title: string;
  subtitle: string;
  imageSource: any;
  onPress: () => void;
}
export const QuickActionCard: React.FC<QuickActionCardProps> = ({ title, subtitle, imageSource, onPress }) => {
  return (
    <TouchableOpacity style={styles.quickActionCard} onPress={onPress} activeOpacity={0.8}>
      <Image source={imageSource} style={styles.quickActionImage} />
      <View style={styles.quickActionGradient}>
        <Text style={styles.quickActionTitle} numberOfLines={2}>{title}</Text>
        <Text style={styles.quickActionSubtitle} numberOfLines={2}>{subtitle}</Text>
      </View>
    </TouchableOpacity>
  );
};

// MARK: - Search Product Row
interface SearchProductRowProps {
  product: Product;
  onPress: () => void;
}
export const SearchProductRow: React.FC<SearchProductRowProps> = ({ product, onPress }) => {
  const imageUrl = resolveMediaUrl(resolveFirstImageUrl(product.image_urls));
  const ingredientCount = product.productIngredients?.length || 0;

  return (
    <TouchableOpacity style={styles.listRow} onPress={onPress} activeOpacity={0.7}>
      <View style={styles.listImagePlaceholder}>
        {imageUrl ? (
          <Image source={{ uri: imageUrl }} style={styles.listImage} />
        ) : (
          <Ionicons name="beaker-outline" size={24} color="#9CA3AF" />
        )}
      </View>
      <View style={styles.listContent}>
        <Text style={styles.listTitle} numberOfLines={2}>{product.name}</Text>
        {product.brand && <Text style={styles.listSubtitle}>{product.brand}</Text>}
        {ingredientCount > 0 && (
          <View style={styles.listBadgeRow}>
            <Ionicons name="list-outline" size={12} color="#D4728C" />
            <Text style={styles.listBadgeText}>{ingredientCount} içerik</Text>
          </View>
        )}
      </View>
      <Ionicons name="chevron-forward" size={16} color="#CBD5E1" />
    </TouchableOpacity>
  );
};

// MARK: - History Row
interface HistoryRowProps {
  item: SearchHistoryResponse;
  onPress: () => void;
  onDelete: () => void;
}
export const HistoryRow: React.FC<HistoryRowProps> = ({ item, onPress, onDelete }) => {
  const imageUrl = resolveMediaUrl(resolveHistoryImageUrl(item));

  return (
    <TouchableOpacity style={styles.listRow} onPress={onPress} activeOpacity={0.7}>
      <View style={styles.listImagePlaceholder}>
        {imageUrl ? (
          <Image source={{ uri: imageUrl }} style={styles.listImage} />
        ) : (
          <Ionicons name="search-outline" size={20} color="#9CA3AF" />
        )}
      </View>
      <View style={styles.listContent}>
        <Text style={styles.listTitle} numberOfLines={1}>{item.query}</Text>
        {item.productName && <Text style={styles.listSubtitle} numberOfLines={1}>{item.productName}</Text>}
        {item.category && <Text style={styles.listCatText}>{item.category}</Text>}
      </View>
      <TouchableOpacity onPress={onDelete} style={{ padding: 4 }}>
        <Ionicons name="close-circle" size={20} color="#CBD5E1" />
      </TouchableOpacity>
    </TouchableOpacity>
  );
};

// MARK: - Styles
const styles = StyleSheet.create({
  heroContainer: {
    marginHorizontal: 16,
    height: 180,
    borderRadius: 20,
    overflow: 'hidden',
    backgroundColor: '#000',
    marginBottom: 24,
  },
  heroImage: {
    width: '100%',
    height: '100%',
    opacity: 0.8,
  },
  heroGradient: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.4)',
    padding: 24,
    justifyContent: 'center',
    alignItems: 'flex-start',
  },
  heroBadge: {
    backgroundColor: '#D4728C',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
    marginBottom: 8,
  },
  heroBadgeText: {
    color: '#FFF',
    fontSize: 10,
    fontWeight: 'bold',
  },
  heroTitle: {
    color: '#FFF',
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  heroDesc: {
    color: 'rgba(255,255,255,0.9)',
    fontSize: 13,
    marginBottom: 12,
    lineHeight: 18,
  },
  heroButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    gap: 6,
  },
  heroButtonText: {
    color: '#1A1A2E',
    fontSize: 14,
    fontWeight: '600',
  },
  popularCard: {
    width: 110,
    backgroundColor: '#FFF',
    borderRadius: 16,
    padding: 10,
    marginRight: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 8,
    elevation: 2,
  },
  popularImage: {
    width: 90,
    height: 90,
    borderRadius: 10,
    marginBottom: 8,
    backgroundColor: '#F3F4F6',
  },
  popularTitle: {
    fontSize: 11,
    fontWeight: '600',
    color: '#1A1A2E',
  },
  quickActionCard: {
    flex: 1,
    height: 160,
    borderRadius: 16,
    overflow: 'hidden',
    backgroundColor: '#CCC',
  },
  quickActionImage: {
    width: '100%',
    height: '100%',
  },
  quickActionGradient: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.3)',
    justifyContent: 'flex-end',
    padding: 12,
  },
  quickActionTitle: {
    color: '#FFF',
    fontSize: 14,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  quickActionSubtitle: {
    color: 'rgba(255,255,255,0.85)',
    fontSize: 11,
  },
  listRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF',
    padding: 12,
    borderRadius: 14,
    marginBottom: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 6,
    elevation: 1,
  },
  listImagePlaceholder: {
    width: 50,
    height: 50,
    borderRadius: 10,
    backgroundColor: '#F3F4F6',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
    overflow: 'hidden',
  },
  listImage: {
    width: '100%',
    height: '100%',
  },
  listContent: {
    flex: 1,
  },
  listTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1A1A2E',
    marginBottom: 2,
  },
  listSubtitle: {
    fontSize: 12,
    color: '#9CA3AF',
    marginBottom: 4,
  },
  listBadgeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  listBadgeText: {
    fontSize: 10,
    color: '#D4728C',
  },
  listCatText: {
    fontSize: 11,
    color: '#D4728C',
  },
});
