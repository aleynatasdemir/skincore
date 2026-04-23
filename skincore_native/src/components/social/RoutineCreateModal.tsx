import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  TouchableOpacity,
  TextInput,
  ScrollView,
  SafeAreaView,
  ActivityIndicator,
  Alert,
  Image,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import { Colors } from '../../theme/colors';
import { routinesApi } from '../../api/apiClient';

interface RoutineCreateModalProps {
  visible: boolean;
  onClose: () => void;
  onSuccess?: () => void;
}

export function RoutineCreateModal({ visible, onClose, onSuccess }: RoutineCreateModalProps) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [type, setType] = useState<'MORNING' | 'EVENING'>('MORNING');
  const [coverImage, setCoverImage] = useState<string | null>(null);
  
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Todo: Ürün seçme kısmı eklenebilir, şimdilik manuel ya da opsiyonel eklenecek
  // const [selectedProducts, setSelectedProducts] = useState<any[]>([]);

  const pickImage = async () => {
    let result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [4, 3],
      quality: 0.7,
    });

    if (!result.canceled && result.assets && result.assets.length > 0) {
      setCoverImage(result.assets[0].uri);
    }
  };

  const handleCreate = async () => {
    if (!title.trim()) {
      Alert.alert('Hata', 'Lütfen rutininize bir başlık girin.');
      return;
    }

    setIsSubmitting(true);
    let imageUrl = '';

    try {
      // 1. Önce görseli yükle (varsa)
      if (coverImage) {
        const formData = new FormData();
        formData.append('file', {
          uri: coverImage,
          name: 'routine_cover.jpg',
          type: 'image/jpeg',
        } as any);

        imageUrl = await routinesApi.uploadImage(formData);
      }

      // 2. Rutini oluştur
      await routinesApi.create({
        title,
        description,
        type,
        coverImageUrl: imageUrl,
        productIds: [] // Şimdilik boş gönderiyoruz
      });

      setTitle('');
      setDescription('');
      setType('MORNING');
      setCoverImage(null);

      if (onSuccess) onSuccess();
      onClose();
    } catch (error: any) {
       Alert.alert('Hata', error.message || 'Rutin oluşturulamadı.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <SafeAreaView style={styles.overlay}>
        <View style={styles.header}>
          <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
            <Text style={styles.closeBtnText}>İptal</Text>
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Yeni Rutin</Text>
          <TouchableOpacity 
            onPress={handleCreate} 
            disabled={isSubmitting || !title.trim()} 
            style={[styles.saveBtn, (!title.trim() || isSubmitting) && styles.disabledBtn]}
          >
            {isSubmitting ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <Text style={styles.saveBtnText}>Paylaş</Text>
            )}
          </TouchableOpacity>
        </View>

        <ScrollView contentContainerStyle={styles.scrollContent}>
          {/* Type Selector */}
          <View style={styles.typeSelector}>
            <TouchableOpacity 
               style={[styles.typeBtn, type === 'MORNING' && styles.typeBtnActiveMorning]}
               onPress={() => setType('MORNING')}
            >
               <Ionicons name="sunny" size={20} color={type === 'MORNING' ? '#F59E0B' : '#9CA3AF'} />
               <Text style={[styles.typeBtnText, type === 'MORNING' && styles.typeBtnTextActive]}>SABAH</Text>
            </TouchableOpacity>

            <TouchableOpacity 
               style={[styles.typeBtn, type === 'EVENING' && styles.typeBtnActiveEvening]}
               onPress={() => setType('EVENING')}
            >
               <Ionicons name="moon" size={20} color={type === 'EVENING' ? '#6366F1' : '#9CA3AF'} />
               <Text style={[styles.typeBtnText, type === 'EVENING' && styles.typeBtnTextActive]}>AKŞAM</Text>
            </TouchableOpacity>
          </View>

          {/* Cover Image */}
          <TouchableOpacity style={styles.imagePicker} onPress={pickImage}>
            {coverImage ? (
              <Image source={{ uri: coverImage }} style={styles.coverImage} />
            ) : (
              <View style={styles.imagePlaceholder}>
                <Ionicons name="camera-outline" size={32} color="#9ca3af" />
                <Text style={styles.imagePlaceholderText}>Kapak Fotoğrafı Ekle</Text>
              </View>
            )}
          </TouchableOpacity>

          {/* Inputs */}
          <View style={styles.inputGroup}>
             <Text style={styles.label}>Başlık <Text style={{color: '#EF4444'}}>*</Text></Text>
             <TextInput
               style={styles.input}
               placeholder="Örn: Günlük Nemlendirici Rutinim"
               value={title}
               onChangeText={setTitle}
               placeholderTextColor="#9ca3af"
             />
          </View>

          <View style={styles.inputGroup}>
             <Text style={styles.label}>Açıklama</Text>
             <TextInput
               style={[styles.input, styles.textArea]}
               placeholder="Rutininden bahset..."
               value={description}
               onChangeText={setDescription}
               multiline
               numberOfLines={4}
               textAlignVertical="top"
               placeholderTextColor="#9ca3af"
             />
          </View>
          
          <View style={styles.productsSection}>
             <Text style={styles.label}>Ürünler</Text>
             <TouchableOpacity style={styles.addProductBtn}>
                <Ionicons name="add-circle-outline" size={24} color={Colors.primary} />
                <Text style={styles.addProductText}>Ürün Ekle (Yakında)</Text>
             </TouchableOpacity>
          </View>

        </ScrollView>
      </SafeAreaView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: '#fff',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E5E7EB',
  },
  closeBtn: {
    padding: 4,
  },
  closeBtnText: {
    fontSize: 16,
    color: '#6B7280',
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: 'bold',
    color: '#111827',
  },
  saveBtn: {
    backgroundColor: Colors.primary,
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    minWidth: 70,
    alignItems: 'center',
  },
  disabledBtn: {
    opacity: 0.5,
  },
  saveBtnText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 14,
  },
  scrollContent: {
    padding: 20,
    paddingBottom: 60,
  },
  typeSelector: {
    flexDirection: 'row',
    backgroundColor: '#F3F4F6',
    borderRadius: 12,
    padding: 4,
    marginBottom: 24,
  },
  typeBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    borderRadius: 8,
    gap: 8,
  },
  typeBtnActiveMorning: {
    backgroundColor: '#fff',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  typeBtnActiveEvening: {
    backgroundColor: '#fff',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  typeBtnText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#9CA3AF',
  },
  typeBtnTextActive: {
    color: '#111827',
  },
  imagePicker: {
    width: '100%',
    aspectRatio: 4/3,
    backgroundColor: '#F9FAFB',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#E5E7EB',
    borderStyle: 'dashed',
    overflow: 'hidden',
    marginBottom: 24,
  },
  coverImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  imagePlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  imagePlaceholderText: {
    marginTop: 8,
    color: '#9CA3AF',
    fontSize: 14,
    fontWeight: '500',
  },
  inputGroup: {
    marginBottom: 20,
  },
  label: {
    fontSize: 15,
    fontWeight: '600',
    color: '#374151',
    marginBottom: 8,
  },
  input: {
    backgroundColor: '#F9FAFB',
    borderWidth: 1,
    borderColor: '#E5E7EB',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    fontSize: 15,
    color: '#111827',
  },
  textArea: {
    minHeight: 100,
  },
  productsSection: {
    marginTop: 10,
  },
  addProductBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    paddingHorizontal: 16,
    backgroundColor: '#FDF2F5', // ultra soft pink
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#F9D6D6', // soft pink
    borderStyle: 'dashed',
  },
  addProductText: {
    marginLeft: 12,
    fontSize: 15,
    fontWeight: '600',
    color: Colors.primary,
  }
});