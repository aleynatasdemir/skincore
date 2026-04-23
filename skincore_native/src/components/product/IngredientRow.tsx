import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, LayoutAnimation } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../theme/colors';
import type { IngredientMatchResult } from '../../types/product';
import { resolvedSafetyLevel, ingredientDisplayName } from '../../types/product';

interface IngredientRowProps {
  item: IngredientMatchResult;
}

export function IngredientRow({ item }: IngredientRowProps) {
  const [expanded, setExpanded] = useState(false);
  const ingredient = item.matchedIngredient;

  if (!ingredient) {
    // Eşleşmemiş (sadece ham metin)
    return (
      <View style={styles.unmatchedContainer}>
        <Ionicons name="help-circle-outline" size={20} color="#9CA3AF" style={styles.icon} />
        <Text style={styles.unmatchedText}>{item.originalString || 'Bilinmeyen İçerik'}</Text>
      </View>
    );
  }

  const safetyLevel = resolvedSafetyLevel(ingredient.safety_level);
  
  let labelColor = '#10B981'; // Green
  let limitLabelColor = '#10B981';
  let safetyText = 'Güvenli';
  
  if (safetyLevel === 0) {
    labelColor = '#9CA3AF'; // Gray
    limitLabelColor = '#9CA3AF';
    safetyText = 'Bilinmiyor';
  } else if (safetyLevel === 2) {
    labelColor = '#F59E0B'; // Yellow
    limitLabelColor = '#F59E0B';
    safetyText = 'Orta Risk';
  } else if (safetyLevel === 3) {
    labelColor = '#EF4444'; // Red
    limitLabelColor = '#EF4444';
    safetyText = 'Yüksek Risk';
  }

  const toggleExpand = () => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setExpanded(!expanded);
  };

  return (
    <TouchableOpacity style={styles.container} activeOpacity={0.7} onPress={toggleExpand}>
      <View style={styles.headerRow}>
        <View style={[styles.indicator, { backgroundColor: labelColor }]} />
        
        <View style={styles.titleContainer}>
          <Text style={styles.nameText}>{ingredientDisplayName(ingredient)}</Text>
          {ingredient.ewg_score ? (
            <Text style={styles.ewgText}>EWG: {ingredient.ewg_score}</Text>
          ) : null}
        </View>

        <Ionicons
          name={expanded ? 'chevron-up' : 'chevron-down'}
          size={20}
          color="#6B7280"
        />
      </View>

      {expanded && (
        <View style={styles.expandedContent}>
          {ingredient.description_en || ingredient.description ? (
             <Text style={styles.descText}>
               {ingredient.description_en || ingredient.description}
             </Text>
          ) : null}
          
          <View style={styles.badgesRow}>
            {ingredient.limited_eu && (
               <View style={[styles.badge, { backgroundColor: '#FEF3C7', borderColor: limitLabelColor }]}>
                  <Text style={[styles.badgeText, { color: limitLabelColor }]}>AB Kısıtlamalı</Text>
               </View>
            )}
            {ingredient.limited_us && (
               <View style={[styles.badge, { backgroundColor: '#FEF3C7', borderColor: limitLabelColor }]}>
                  <Text style={[styles.badgeText, { color: limitLabelColor }]}>ABD Kısıtlamalı</Text>
               </View>
            )}
            {ingredient.comedogenic_rating !== undefined && (
               <View style={styles.badgeNeutral}>
                  <Text style={styles.badgeTextNeutral}>Komedojenik: {ingredient.comedogenic_rating}</Text>
               </View>
            )}
          </View>
        </View>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#fff',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#f3f4f6',
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  unmatchedContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f9fafb',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#f3f4f6',
  },
  icon: {
    marginRight: 10,
  },
  unmatchedText: {
    color: '#6b7280',
    fontSize: 14,
    flex: 1,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  indicator: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: 12,
  },
  titleContainer: {
    flex: 1,
  },
  nameText: {
    fontSize: 15,
    fontWeight: '600',
    color: '#111827',
    marginBottom: 2,
  },
  ewgText: {
    fontSize: 12,
    color: '#6b7280',
  },
  expandedContent: {
    paddingLeft: 22,
    marginTop: 8,
  },
  descText: {
    fontSize: 13,
    color: '#4B5563',
    lineHeight: 18,
    marginBottom: 8,
  },
  badgesRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    borderWidth: 1,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: '600',
  },
  badgeNeutral: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    backgroundColor: '#f3f4f6',
    borderWidth: 1,
    borderColor: '#e5e7eb',
  },
  badgeTextNeutral: {
    fontSize: 11,
    color: '#374151',
    fontWeight: '500',
  }
});