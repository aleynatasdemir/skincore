import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Dimensions } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import type { MatchedIngredient } from '../../types/product';
import { ingredientDisplayName } from '../../types/product';
import type { IngredientCategory } from '../../store/ingredientsStore';

// MARK: - Category Row
interface CategoryRowProps {
  category: IngredientCategory;
  onPress: () => void;
}
export const CategoryRowView: React.FC<CategoryRowProps> = ({ category, onPress }) => (
  <TouchableOpacity style={styles.categoryRow} onPress={onPress} activeOpacity={0.7}>
    <View style={[styles.categoryIconBox, { backgroundColor: category.backgroundColor }]}>
      <Ionicons name={category.icon as any} size={22} color={category.color} />
    </View>
    <View style={styles.categoryTextContainer}>
      <Text style={styles.categoryTitle}>{category.title}</Text>
      <Text style={styles.categoryDesc} numberOfLines={2}>
        {category.description}
      </Text>
    </View>
    <Ionicons name="chevron-forward" size={16} color="#D1D5DB" />
  </TouchableOpacity>
);

// MARK: - Ingredient Card
interface IngredientCardProps {
  ingredient: MatchedIngredient;
  category: IngredientCategory;
  onPress: () => void;
}
export const IngredientCard: React.FC<IngredientCardProps> = ({ ingredient, category, onPress }) => {
  const functionLabel = ingredient.functions?.[0]
    ? (typeof ingredient.functions[0] === 'string' ? ingredient.functions[0] : ingredient.functions[0].name)?.toUpperCase()
    : null;

  return (
    <TouchableOpacity style={styles.cardContainer} onPress={onPress} activeOpacity={0.8}>
      <View style={styles.cardHeader}>
        <View style={[styles.cardIconBox, { backgroundColor: category.backgroundColor }]}>
          <Ionicons name={category.icon as any} size={18} color={category.color} />
        </View>
        <View style={styles.cardTitleContainer}>
          <Text style={styles.cardTitle}>{ingredientDisplayName(ingredient)}</Text>
          {functionLabel && <Text style={styles.cardFunction}>{functionLabel}</Text>}
        </View>
      </View>
      {ingredient.description ? (
        <Text style={styles.cardDesc} numberOfLines={3}>
          {ingredient.description}
        </Text>
      ) : null}
    </TouchableOpacity>
  );
};

// MARK: - Chip
const ChipView = ({ text, color, bgColor }: { text: string; color: string; bgColor: string }) => (
  <View style={[styles.chip, { backgroundColor: bgColor }]}>
    <Text style={[styles.chipText, { color }]}>{text}</Text>
  </View>
);

const FlowLayout = ({ items, color, bgColor }: { items: string[]; color: string; bgColor: string }) => (
  <View style={styles.flowContainer}>
    {items.map((item, index) => (
      <ChipView key={index} text={item} color={color} bgColor={bgColor} />
    ))}
  </View>
);

// MARK: - Detail Sheet Component
interface DetailSheetProps {
  ingredient: MatchedIngredient;
  onClose: () => void;
}
export const IngredientDetailSheet: React.FC<DetailSheetProps> = ({ ingredient, onClose }) => {
  const ewgScoreInt = ingredient.ewg_score ? parseInt(ingredient.ewg_score.charAt(0), 10) : null;
  const ewgScoreLabel = ewgScoreInt !== null
    ? ewgScoreInt <= 2 ? 'Düşük Risk' : ewgScoreInt <= 6 ? 'Orta Risk' : 'Yüksek Risk'
    : 'N/A';

  const ewgColor = ewgScoreInt === null ? '#22C55E' : ewgScoreInt <= 4 ? '#22C55E' : ewgScoreInt <= 6 ? '#EAB308' : '#EF4444';

  const goodFor = ingredient.skin_compatibility?.good_for || [];
  const badFor = ingredient.skin_compatibility?.bad_for || [];

  return (
    <View style={styles.sheetContainer}>
      <View style={styles.sheetHeader}>
        <TouchableOpacity style={styles.closeButton} onPress={onClose}>
          <Ionicons name="close" size={18} color="#9CA3AF" />
        </TouchableOpacity>
      </View>
      
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.sheetContent}>
        <Text style={styles.sheetTitle}>{ingredientDisplayName(ingredient)}</Text>
        {ingredient.description && (
          <Text style={styles.sheetDesc}>{ingredient.description}</Text>
        )}

        {goodFor.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>BU CİLTLERE İYİ GELİR</Text>
            <FlowLayout items={goodFor} color="#D4728C" bgColor="#FDF2F8" />
          </View>
        )}

        {badFor.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>BU CİLTLERE İYİ GELMEYEBİLİR</Text>
            <FlowLayout items={badFor} color="#EF4444" bgColor="#FEE2E2" />
          </View>
        )}

        {ingredient.ewg_score && (
          <>
            <View style={styles.divider} />
            <View style={styles.ewgRow}>
              <View>
                <Text style={styles.sectionTitle}>EWG SKORU</Text>
                <Text style={styles.ewgLabel}>{ingredient.ewg_score} ({ewgScoreLabel})</Text>
              </View>
              <View style={[styles.ewgCircleOuter, { borderColor: ewgColor }]}>
                <Text style={[styles.ewgCircleText, { color: ewgColor }]}>
                  {ingredient.ewg_score.substring(0,2)}
                </Text>
              </View>
            </View>
          </>
        )}
      </ScrollView>
    </View>
  );
};

// MARK: - Styles
const styles = StyleSheet.create({
  categoryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF',
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: '#F3F4F6',
  },
  categoryIconBox: {
    width: 52,
    height: 52,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
  },
  categoryTextContainer: {
    flex: 1,
    marginLeft: 14,
  },
  categoryTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1A1A2E',
    marginBottom: 3,
  },
  categoryDesc: {
    fontSize: 12,
    color: '#6B7280',
    lineHeight: 16,
  },
  cardContainer: {
    backgroundColor: '#FFF',
    borderRadius: 16,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 6,
    elevation: 2,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 10,
  },
  cardIconBox: {
    width: 44,
    height: 44,
    borderRadius: 22,
    justifyContent: 'center',
    alignItems: 'center',
  },
  cardTitleContainer: {
    marginLeft: 12,
    flex: 1,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1A1A2E',
  },
  cardFunction: {
    fontSize: 11,
    fontWeight: '600',
    color: '#D4728C',
    letterSpacing: 0.3,
    marginTop: 2,
  },
  cardDesc: {
    fontSize: 13,
    color: '#4B5563',
    lineHeight: 20,
  },
  sheetContainer: {
    backgroundColor: '#FFF',
    borderRadius: 28,
    paddingVertical: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.15,
    shadowRadius: 20,
    elevation: 24,
    maxHeight: Dimensions.get('window').height * 0.7,
  },
  sheetHeader: {
    alignItems: 'flex-end',
    paddingHorizontal: 24,
  },
  closeButton: {
    padding: 8,
    backgroundColor: '#F3F4F6',
    borderRadius: 20,
  },
  sheetContent: {
    paddingHorizontal: 24,
    paddingBottom: 30,
  },
  sheetTitle: {
    fontSize: 26,
    fontWeight: 'bold',
    color: '#1A1A2E',
  },
  sheetDesc: {
    fontSize: 15,
    color: '#4B5563',
    lineHeight: 22,
    marginTop: 10,
    marginBottom: 20,
  },
  section: {
    marginTop: 20,
  },
  sectionTitle: {
    fontSize: 11,
    fontWeight: 'bold',
    color: '#9CA3AF',
    letterSpacing: 1,
    marginBottom: 10,
  },
  flowContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  chip: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 20,
  },
  chipText: {
    fontSize: 13,
    fontWeight: '500',
  },
  divider: {
    height: 1,
    backgroundColor: '#F3F4F6',
    marginVertical: 20,
  },
  ewgRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  ewgLabel: {
    fontSize: 15,
    fontWeight: '600',
    color: '#1A1A2E',
  },
  ewgCircleOuter: {
    width: 44,
    height: 44,
    borderRadius: 22,
    borderWidth: 2,
    justifyContent: 'center',
    alignItems: 'center',
  },
  ewgCircleText: {
    fontSize: 18,
    fontWeight: 'bold',
  }
});
