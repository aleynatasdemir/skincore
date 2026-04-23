import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  TouchableOpacity,
  Dimensions,
  Platform,
  Alert
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../src/theme/colors';
import { productsApi, favoritesApi } from '../../src/api/apiClient';
import type { ProductWithEnrichedIngredients, IngredientMatchResult } from '../../src/types/product';
import { resolveImageUrl } from '../../src/types/product';
import { CachedImage } from '../../src/components/common/CachedImage';
import { IngredientRow } from '../../src/components/product/IngredientRow';
import { SafeAreaView } from 'react-native-safe-area-context';

const { width } = Dimensions.get('window');

function analyzeSafety(ingredients?: IngredientMatchResult[]) {
  if (!ingredients || ingredients.length === 0) {
    return { score: 100, label: 'Bilinmiyor', color: '#9CA3AF' };
  }

  let validCount = 0;
  let totalScore = 0;

  ingredients.forEach((item) => {
    if (item.matchedIngredient && item.matchedIngredient.safety_level !== undefined) {
      totalScore += item.matchedIngredient.safety_level;
      validCount++;
    }
  });

  if (validCount === 0) return { score: 100, label: 'Bilinmiyor', color: '#9CA3AF' };

  const maxPossible = validCount * 4;
  const ratio = (maxPossible - totalScore) / maxPossible;
  const score100 = Math.round(ratio * 100);

  let label = 'Güvenli (Temiz)';
  let color = '#10B981';
  
  if (score100 < 40) {
    label = 'Yüksek Riskli';
    color = '#EF4444';
  } else if (score100 < 75) {
    label = 'Orta Riskli';
    color = '#F59E0B';
  }

  return { score: score100, label, color };
}

export default function ProductDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();

  const [product, setProduct] = useState<ProductWithEnrichedIngredients | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  const [isFavorite, setIsFavorite] = useState(false);
  const [favoriteLoading, setFavoriteLoading] = useState(false);

  useEffect(() => {
    if (id) {
      fetchProduct();
      checkFavorite();
    }
  }, [id]);

  const fetchProduct = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await productsApi.getDetails(id!);
      setProduct(data);
    } catch (err: any) {
      setError(err.message || 'Ürün yüklenirken hata oluştu.');
    } finally {
      setLoading(false);
    }
  };

  const checkFavorite = async () => {
    try {
      const res = await favoritesApi.check(id!);
      setIsFavorite(res.isFavorite);
    } catch (err) {
      // Sessizce hatayı yoksay
      console.log('Favorite check failed:', err);
    }
  };

  const toggleFavorite = async () => {
    if (!product || favoriteLoading) return;
    setFavoriteLoading(true);
    // Optimistic toggle
    const prev = isFavorite;
    setIsFavorite(!prev);

    try {
      const imgUrl = product.image_urls && product.image_urls.length > 0 
                     ? resolveImageUrl(product.image_urls[0]) || '' 
                     : '';
      
      const req = {
        productId: product.id || id!,
        productName: product.name || 'İsimsiz Ürün',
        productBrand: product.brand,
        productImageURL: imgUrl
      };

      const res = await favoritesApi.toggle(req);
      // Backend true source of truth
      setIsFavorite(res.isFavorite);
    } catch (err) {
      setIsFavorite(prev);
      Alert.alert('Hata', 'Favori işlemi başarısız oldu.');
    } finally {
      setFavoriteLoading(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color={Colors.primary} />
      </View>
    );
  }

  if (error || !product) {
    return (
      <SafeAreaView style={styles.errorContainer}>
        <Ionicons name="alert-circle-outline" size={60} color="#EF4444" />
        <Text style={styles.errorText}>{error || 'Ürün bulunamadı.'}</Text>
        <TouchableOpacity style={styles.backBtnError} onPress={() => router.back()}>
          <Text style={styles.backBtnTextError}>Geri Dön</Text>
        </TouchableOpacity>
      </SafeAreaView>
    );
  }

  const { score, label, color } = analyzeSafety(product.enrichedIngredients);
  const images = product.image_urls || [];
  
  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={[styles.header, { paddingTop: Platform.OS === 'ios' ? 50 : 20 }]}>
        <TouchableOpacity style={styles.headerBtn} onPress={() => router.back()}>
          <Ionicons name="arrow-back" size={24} color="#111827" />
        </TouchableOpacity>
        <Text style={styles.headerTitle} numberOfLines={1}>Ürün Detayı</Text>
        <TouchableOpacity style={styles.headerBtn} onPress={toggleFavorite} disabled={favoriteLoading}>
          <Ionicons 
             name={isFavorite ? "heart" : "heart-outline"} 
             size={26} 
             color={isFavorite ? Colors.primary : "#111827"} 
          />
        </TouchableOpacity>
      </View>

      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Images */}
        <View style={styles.imageCarousel}>
          {images.length > 0 ? (
            <ScrollView horizontal pagingEnabled showsHorizontalScrollIndicator={false}>
              {images.map((img, index) => {
                const uri = resolveImageUrl(img);
                return uri ? (
                  <CachedImage
                    key={index}
                    source={{ uri }}
                    style={styles.productImage}
                  />
                ) : null;
              })}
            </ScrollView>
          ) : (
            <View style={styles.noImage}>
              <Ionicons name="image-outline" size={64} color="#D1D5DB" />
              <Text style={styles.noImageText}>Görsel Yok</Text>
            </View>
          )}
        </View>

        {/* Info */}
        <View style={styles.infoSection}>
          {product.brand ? <Text style={styles.brand}>{product.brand}</Text> : null}
          <Text style={styles.name}>{product.name || 'Bilinmeyen Ürün'}</Text>

          <View style={styles.safetyCard}>
            <View style={[styles.scoreCircle, { borderColor: color }]}>
              <Text style={[styles.scoreText, { color }]}>{score}</Text>
              <Text style={styles.scoreSub}>/ 100</Text>
            </View>
            <View style={styles.safetyTextWrapper}>
              <Text style={styles.safetyTitle}>Güvenlik Skoru</Text>
              <View style={[styles.safetyBadge, { backgroundColor: color + '20' }]}>
                 <Text style={[styles.safetyLabel, { color }]}>{label}</Text>
              </View>
            </View>
          </View>
        </View>

        {/* Ingredients */}
        <View style={styles.ingredientsSection}>
           <Text style={styles.sectionTitle}>
             İçerik Analizi ({product.enrichedIngredients?.length || 0})
           </Text>
           {product.enrichedIngredients && product.enrichedIngredients.length > 0 ? (
             <View style={styles.ingredientsList}>
                {(() => {
                   const risky: IngredientMatchResult[] = [];
                   const moderate: IngredientMatchResult[] = [];
                   const safe: IngredientMatchResult[] = [];
                   const unknown: IngredientMatchResult[] = [];

                   product.enrichedIngredients.forEach(item => {
                     if (!item.matchedIngredient || item.matchedIngredient.safety_level === undefined) {
                       unknown.push(item);
                     } else {
                       const level = item.matchedIngredient.safety_level;
                       if (level >= 3) risky.push(item);
                       else if (level === 2) moderate.push(item);
                       else safe.push(item);
                     }
                   });

                   return (
                     <View>
                        {/* Tablo/Özet Banner */}
                        <View style={styles.analysisSummaryBox}>
                           <View style={styles.summaryCol}>
                              <Text style={styles.summaryNumber}>{safe.length}</Text>
                              <Text style={styles.summaryLabel}>Güvenli</Text>
                              <View style={[styles.summaryDot, { backgroundColor: '#10B981' }]} />
                           </View>
                           <View style={styles.summaryCol}>
                              <Text style={styles.summaryNumber}>{moderate.length}</Text>
                              <Text style={styles.summaryLabel}>Orta Risk</Text>
                              <View style={[styles.summaryDot, { backgroundColor: '#F59E0B' }]} />
                           </View>
                           <View style={styles.summaryCol}>
                              <Text style={styles.summaryNumber}>{risky.length}</Text>
                              <Text style={styles.summaryLabel}>Riskli</Text>
                              <View style={[styles.summaryDot, { backgroundColor: '#EF4444' }]} />
                           </View>
                           <View style={styles.summaryCol}>
                              <Text style={styles.summaryNumber}>{unknown.length}</Text>
                              <Text style={styles.summaryLabel}>Bilinmiyor</Text>
                              <View style={[styles.summaryDot, { backgroundColor: '#9CA3AF' }]} />
                           </View>
                        </View>

                        {risky.length > 0 && (
                          <>
                            <View style={styles.groupHeader}><Text style={[styles.groupTitle, { color: '#EF4444' }]}>Riskli İçerikler</Text></View>
                            {risky.map((item, idx) => <IngredientRow key={`risk-${idx}`} item={item} />)}
                          </>
                        )}
                        {moderate.length > 0 && (
                          <>
                            <View style={styles.groupHeader}><Text style={[styles.groupTitle, { color: '#F59E0B' }]}>Orta Riskli İçerikler</Text></View>
                            {moderate.map((item, idx) => <IngredientRow key={`mod-${idx}`} item={item} />)}
                          </>
                        )}
                        {safe.length > 0 && (
                          <>
                            <View style={styles.groupHeader}><Text style={[styles.groupTitle, { color: '#10B981' }]}>Güvenli İçerikler</Text></View>
                            {safe.map((item, idx) => <IngredientRow key={`safe-${idx}`} item={item} />)}
                          </>
                        )}
                        {unknown.length > 0 && (
                          <>
                            <View style={styles.groupHeader}><Text style={[styles.groupTitle, { color: '#6B7280' }]}>Analiz Edilemeyenler</Text></View>
                            {unknown.map((item, idx) => <IngredientRow key={`unk-${idx}`} item={item} />)}
                          </>
                        )}
                     </View>
                   );
                })()}
             </View>
           ) : (
             <Text style={styles.emptyText}>Bu ürünün içerik detayı henüz analiz edilemedi veya içerik bilgisi eksik.</Text>
           )}
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FAFAFA'
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff'
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
    padding: 20
  },
  errorText: {
    fontSize: 16,
    color: '#374151',
    marginTop: 16,
    textAlign: 'center',
    marginBottom: 24,
  },
  backBtnError: {
    backgroundColor: Colors.primary,
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  backBtnTextError: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 16,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingBottom: 12,
    backgroundColor: '#fff',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E5E7EB',
  },
  headerBtn: {
    padding: 4,
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#111827',
    maxWidth: width - 100,
  },
  scrollContent: {
    paddingBottom: 40,
  },
  imageCarousel: {
    width: width,
    height: width,
    backgroundColor: '#fff',
  },
  productImage: {
    width: width,
    height: width,
    resizeMode: 'contain',
  },
  noImage: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F3F4F6'
  },
  noImageText: {
    marginTop: 12,
    color: '#9CA3AF',
    fontSize: 16,
    fontWeight: '500'
  },
  infoSection: {
    padding: 20,
    backgroundColor: '#fff',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E5E7EB',
  },
  brand: {
    fontSize: 14,
    color: '#6B7280',
    fontWeight: '600',
    textTransform: 'uppercase',
    marginBottom: 4,
  },
  name: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#111827',
    marginBottom: 20,
  },
  safetyCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F9FAFB',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: '#F3F4F6',
  },
  scoreCircle: {
    width: 60,
    height: 60,
    borderRadius: 30,
    borderWidth: 4,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
    backgroundColor: '#fff',
  },
  scoreText: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  scoreSub: {
    fontSize: 10,
    color: '#6B7280',
    marginTop: -2,
  },
  safetyTextWrapper: {
    flex: 1,
    alignItems: 'flex-start',
  },
  safetyTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: '#374151',
    marginBottom: 6,
  },
  safetyBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
  },
  safetyLabel: {
    fontSize: 13,
    fontWeight: 'bold',
  },
  ingredientsSection: {
    paddingTop: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#111827',
    paddingHorizontal: 20,
    marginBottom: 12,
  },
  ingredientsList: {
    backgroundColor: '#fff',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#E5E7EB',
  },
  analysisSummaryBox: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingVertical: 20,
    backgroundColor: '#F9FAFB',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E5E7EB',
  },
  summaryCol: {
    alignItems: 'center',
  },
  summaryNumber: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#111827',
  },
  summaryLabel: {
    fontSize: 12,
    color: '#6B7280',
    marginTop: 4,
    marginBottom: 6,
  },
  summaryDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  groupHeader: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#FFF',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#F3F4F6',
  },
  groupTitle: {
    fontSize: 14,
    fontWeight: 'bold',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  emptyText: {
    paddingHorizontal: 20,
    color: '#6B7280',
    fontSize: 15,
    marginTop: 8,
  }
});