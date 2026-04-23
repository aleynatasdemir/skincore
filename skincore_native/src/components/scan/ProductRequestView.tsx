import React, { useState } from 'react';
import { View, Text, TextInput, StyleSheet, TouchableOpacity, ScrollView, Alert, KeyboardAvoidingView, Platform, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import { Colors } from '../../theme/colors';
import { productsApi, extractErrorMessage } from '../../api/apiClient';
import { CachedImage } from '../common/CachedImage';
import { useRouter } from 'expo-router';

// Eksik veya Hatalı Ürün Bildirimi Formu
export function ProductRequestView() {
  const router = useRouter();
  
  const [brand, setBrand] = useState('');
  const [productName, setProductName] = useState('');
  
  const [frontImage, setFrontImage] = useState<string | null>(null);
  const [ingredientImage, setIngredientImage] = useState<string | null>(null);
  
  const [isSubmitting, setIsSubmitting] = useState(false);

  const pickImage = async (type: 'front' | 'ingredient') => {
    let result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      quality: 0.7,
    });

    if (!result.canceled && result.assets && result.assets.length > 0) {
      if (type === 'front') {
        setFrontImage(result.assets[0].uri);
      } else {
        setIngredientImage(result.assets[0].uri);
      }
    }
  };

  const handleSubmit = async () => {
    if (!brand.trim() || !productName.trim()) {
      Alert.alert('Hata', 'Lütfen marka ve ürün adı alanlarını doldurunuz.');
      return;
    }
    
    if (!frontImage || !ingredientImage) {
      Alert.alert('Eksik Bilgi', 'Ürünün hem ön yüzünü hem de içerik kısmını gösteren fotoğrafları eklemeniz analiz için gereklidir.');
      return;
    }

    setIsSubmitting(true);
    try {
      const formData = new FormData();
      formData.append('brand', brand);
      formData.append('productName', productName);
      
      // FormData append for React Native
      formData.append('frontImage', {
        uri: frontImage,
        name: 'front.jpg',
        type: 'image/jpeg',
      } as any);

      formData.append('ingredientImage', {
        uri: ingredientImage,
        name: 'ingredient.jpg',
        type: 'image/jpeg',
      } as any);

      await productsApi.submitRequest(formData);
      
      Alert.alert('Başarılı', 'Ürün talebiniz başarıyla alındı. Teşekkür ederiz!', [
        { text: 'Tamam', onPress: () => router.back() }
      ]);
    } catch (error) {
      Alert.alert('Hata', extractErrorMessage(error, 'Ürün talebi gönderilemedi.'));
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <KeyboardAvoidingView 
      style={styles.container} 
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <Text style={styles.title}>Yeni Ürün Bildir / Talep Et</Text>
        <Text style={styles.subtitle}>
          Aradığınız ürünü bulamadıysanız veya detaylarında eksiklik düşünüyorsanız bize iletin.
        </Text>

        <View style={styles.formGroup}>
          <Text style={styles.label}>Marka<Text style={styles.required}>*</Text></Text>
          <TextInput
            style={styles.input}
            placeholder="Örn: The Ordinary"
            value={brand}
            onChangeText={setBrand}
            placeholderTextColor="#9ca3af"
          />
        </View>

        <View style={styles.formGroup}>
          <Text style={styles.label}>Ürün Adı<Text style={styles.required}>*</Text></Text>
          <TextInput
            style={styles.input}
            placeholder="Örn: Niacinamide 10% + Zinc 1%"
            value={productName}
            onChangeText={setProductName}
            placeholderTextColor="#9ca3af"
          />
        </View>

        <View style={styles.photoSection}>
          <Text style={styles.label}>Ürün Fotoğrafları<Text style={styles.required}>*</Text></Text>
          
          <View style={styles.photoBoxes}>
            {/* Ön Yüz */}
            <TouchableOpacity style={styles.photoBox} onPress={() => pickImage('front')}>
              {frontImage ? (
                <CachedImage source={{ uri: frontImage }} style={styles.previewImage} />
              ) : (
                <View style={styles.photoPlaceholder}>
                  <Ionicons name="camera-outline" size={32} color={Colors.primary} />
                  <Text style={styles.photoText}>Ön Yüz</Text>
                </View>
              )}
            </TouchableOpacity>

            {/* İçerik */}
            <TouchableOpacity style={styles.photoBox} onPress={() => pickImage('ingredient')}>
              {ingredientImage ? (
                <CachedImage source={{ uri: ingredientImage }} style={styles.previewImage} />
              ) : (
                <View style={styles.photoPlaceholder}>
                   <Ionicons name="list-outline" size={32} color={Colors.primary} />
                   <Text style={styles.photoText}>İçerik Listesi</Text>
                </View>
              )}
            </TouchableOpacity>
          </View>
        </View>
        
        <TouchableOpacity 
          style={[styles.submitButton, isSubmitting && styles.submitButtonDisabled]} 
          onPress={handleSubmit}
          disabled={isSubmitting}
        >
          {isSubmitting ? (
            <ActivityIndicator color="#fff" />
          ) : (
             <Text style={styles.submitButtonText}>Talebi Gönder</Text>
          )}
        </TouchableOpacity>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  scrollContent: {
    padding: 24,
    paddingBottom: 60,
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#111827',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 14,
    color: '#6b7280',
    lineHeight: 20,
    marginBottom: 30,
  },
  formGroup: {
    marginBottom: 20,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#374151',
    marginBottom: 8,
  },
  required: {
    color: '#EF4444',
  },
  input: {
    borderWidth: 1,
    borderColor: '#d1d5db',
    borderRadius: 10,
    paddingHorizontal: 16,
    paddingVertical: 14,
    fontSize: 15,
    backgroundColor: '#f9fafb',
    color: '#111827',
  },
  photoSection: {
    marginTop: 10,
    marginBottom: 30,
  },
  photoBoxes: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 16,
  },
  photoBox: {
    flex: 1,
    aspectRatio: 1,
    backgroundColor: '#fef2f2',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#fecaca',
    borderStyle: 'dashed',
    overflow: 'hidden',
  },
  photoPlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 12,
  },
  photoText: {
    marginTop: 8,
    fontSize: 13,
    color: Colors.primary,
    fontWeight: '500',
    textAlign: 'center',
  },
  previewImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  submitButton: {
    backgroundColor: Colors.primary,
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  submitButtonDisabled: {
    opacity: 0.7,
  },
  submitButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  }
});