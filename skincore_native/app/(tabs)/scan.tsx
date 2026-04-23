import React, { useRef, useState, useEffect } from 'react';
import { 
  View, Text, StyleSheet, Dimensions, TouchableOpacity, 
  Image, Modal, ScrollView, ActivityIndicator, Alert 
} from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';
import Animated, { 
  useSharedValue, useAnimatedStyle, withRepeat, withTiming, Easing 
} from 'react-native-reanimated';
import { useScanStore } from '../../src/store/scanStore';
import { SearchProductRow } from '../../src/components/home/HomeComponents';
import { useRouter } from 'expo-router';

const { width, height } = Dimensions.get('window');
const FRAME_PADDING = 24;
const FRAME_WIDTH = width - (FRAME_PADDING * 2);
const FRAME_HEIGHT = height * 0.50;

// MARK: - Scan Animation Overlay
const PhotoScanAnimation = () => {
  const scanProgress = useSharedValue(0);

  useEffect(() => {
    scanProgress.value = withRepeat(
      withTiming(1, { duration: 2400, easing: Easing.inOut(Easing.ease) }),
      -1, // infinite
      true // reverse
    );
  }, []);

  const animatedStyle = useAnimatedStyle(() => {
    return {
      transform: [{ translateY: (scanProgress.value - 0.5) * (FRAME_HEIGHT - 70) }],
    };
  });

  return (
    <Animated.View style={[styles.scanLineContainer, animatedStyle]}>
      <View style={styles.scanGlow} />
      <View style={styles.scanLine} />
    </Animated.View>
  );
};

// MARK: - Pulsing Dot
const PulsingDot = () => {
  const scale = useSharedValue(1);
  const opacity = useSharedValue(1);

  useEffect(() => {
    scale.value = withRepeat(withTiming(2, { duration: 1100 }), -1, false);
    opacity.value = withRepeat(withTiming(0, { duration: 1100 }), -1, false);
  }, []);

  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  return (
    <View style={styles.dotContainer}>
      <Animated.View style={[styles.dotPulse, animStyle]} />
      <View style={styles.dotCenter} />
    </View>
  );
};

// MARK: - Main Screen
export default function ScanScreen() {
  const router = useRouter();
  const [permission, requestPermission] = useCameraPermissions();
  const cameraRef = useRef<CameraView>(null);
  const [flashOn, setFlashOn] = useState(false);

  const {
    capturedImage, isProcessing, searchResults, hasSearched,
    setCapturedImage, processImage, reset
  } = useScanStore();

  if (!permission) {
    return <View style={styles.container} />; // Loading
  }

  if (!permission.granted) {
    return (
      <View style={styles.permissionContainer}>
         <View style={styles.permissionIconCircle}>
            <Ionicons name="camera" size={40} color="#D4728C" />
         </View>
         <Text style={styles.permissionTitle}>Ürünlerinizi Tarayın</Text>
         <Text style={styles.permissionDesc}>
           Cilt bakım ürünlerinizi analiz etmek ve rutininize uymayan maddeleri görmek için kameranıza erişim izni vermeniz gerekiyor.
         </Text>
         <TouchableOpacity style={styles.permissionButton} onPress={requestPermission}>
            <Text style={styles.permissionButtonText}>Kamerayı Aç</Text>
         </TouchableOpacity>
      </View>
    );
  }

  const takePicture = async () => {
    if (cameraRef.current && !isProcessing) {
      const photo = await cameraRef.current.takePictureAsync({
        quality: 0.7,
        base64: false,
      });
      if (photo) {
        processImage(photo.uri);
      }
    }
  };

  const pickImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      quality: 0.7,
    });
    if (!result.canceled) {
      processImage(result.assets[0].uri);
    }
  };

  return (
    <View style={styles.container}>
      {/* ── 1. BACKGROUND LAYER: Camera or Blurred Image ── */}
      {capturedImage ? (
         <View style={StyleSheet.absoluteFill}>
           <Image source={{ uri: capturedImage }} style={[StyleSheet.absoluteFill, styles.blurredBackground]} blurRadius={28} />
           <View style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(255,240,240,0.55)' }]} />
         </View>
      ) : (
         <CameraView 
           ref={cameraRef} 
           style={StyleSheet.absoluteFill} 
           facing="back"
           enableTorch={flashOn}
         />
      )}

      {/* ── 2. TOP BAR ── */}
      <View style={styles.topBar}>
        <TouchableOpacity style={styles.iconButton} onPress={() => router.back()}>
          <Ionicons name="chevron-back" size={20} color="#FFF" />
        </TouchableOpacity>
        <Text style={styles.brandTitle}>skincore.</Text>
        <TouchableOpacity style={styles.iconButton} onPress={() => setFlashOn(!flashOn)}>
          <Ionicons name={flashOn ? "flash" : "flash-off"} size={20} color={flashOn ? "#EAB308" : "#FFF"} />
        </TouchableOpacity>
      </View>

      {/* ── 3. CENTER OVERLAY (Frame / Active Image) ── */}
      <View style={styles.centerContainer}>
        {capturedImage ? (
           // Image frozen in frame
           <View style={styles.frameContainer}>
             <Image source={{ uri: capturedImage }} style={styles.frameImage} />
             {isProcessing && <PhotoScanAnimation />}
             <ScanBrackets />
           </View>
        ) : (
           // Empty frame for viewfinder
           <View style={styles.frameContainerActive}>
             <ScanBrackets />
           </View>
        )}

        {/* Status Chip */}
        {isProcessing ? (
          <View style={styles.processingChip}>
            <PulsingDot />
            <Text style={styles.processingText}>Analiz Ediliyor...</Text>
          </View>
        ) : (
          !hasSearched && (
            <View style={styles.hintChip}>
               <Ionicons name="scan-outline" size={16} color="#FFF" />
               <Text style={styles.hintText}>Ürünü çerçeveye hizalayın</Text>
            </View>
          )
        )}
      </View>

      {/* ── 4. BOTTOM BAR (Controls) ── */}
      {!capturedImage && (
        <View style={styles.bottomBar}>
          <TouchableOpacity style={styles.galleryButton} onPress={pickImage}>
            <Ionicons name="images-outline" size={24} color="#FFF" />
            <Text style={styles.galleryText}>GALERİ</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.captureOuter} onPress={takePicture}>
            <View style={styles.captureInner}>
              <Ionicons name="camera" size={32} color="#FFF" />
            </View>
          </TouchableOpacity>
          
          <View style={{ width: 60 }} />
        </View>
      )}

      {/* ── 5. RESULTS SHEET (Modal) ── */}
      <Modal visible={hasSearched} animationType="slide" transparent={true}>
         <View style={styles.sheetOverlay}>
            <View style={styles.sheetContent}>
              <View style={styles.sheetHandle} />
              
              <View style={styles.sheetHeader}>
                 <Text style={styles.sheetTitle}>Tarama Sonucu</Text>
                 <TouchableOpacity onPress={reset}>
                    <Ionicons name="close-circle" size={24} color="#9CA3AF" />
                 </TouchableOpacity>
              </View>

              <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ padding: 16 }}>
                {searchResults.length === 0 ? (
                  <View style={styles.emptyContainer}>
                    <Ionicons name="alert-circle-outline" size={48} color="#D4728C" style={{ opacity: 0.5, marginBottom: 12 }} />
                    <Text style={styles.emptyTitle}>Ürün Bulunamadı</Text>
                    <Text style={styles.emptyDesc}>Görselinizdeki ürünü veritabanımızda eşleştiremedik. Daha net bir fotoğrafla tekrar deneyin.</Text>
                    <TouchableOpacity style={styles.retryButton} onPress={reset}>
                      <Text style={styles.retryButtonText}>Tekrar Dene</Text>
                    </TouchableOpacity>
                  </View>
                ) : (
                  <>
                    <Text style={styles.resultsCountText}>En iyi {searchResults.length} eşleşme</Text>
                    {searchResults.map((product) => (
                      <SearchProductRow 
                        key={product.id} 
                        product={product} 
                        onPress={() => console.log('Navigate to product detail:', product.id)}
                      />
                    ))}
                  </>
                )}
              </ScrollView>
            </View>
         </View>
      </Modal>
    </View>
  );
}

// Corner Brackets
const ScanBrackets = () => (
  <View style={StyleSheet.absoluteFill}>
    {/* Top Left */}
    <View style={[styles.bracket, { top: 14, left: 14, borderRightWidth: 0, borderBottomWidth: 0 }]} />
    {/* Top Right */}
    <View style={[styles.bracket, { top: 14, right: 14, borderLeftWidth: 0, borderBottomWidth: 0 }]} />
    {/* Bottom Left */}
    <View style={[styles.bracket, { bottom: 14, left: 14, borderRightWidth: 0, borderTopWidth: 0 }]} />
    {/* Bottom Right */}
    <View style={[styles.bracket, { bottom: 14, right: 14, borderLeftWidth: 0, borderTopWidth: 0 }]} />
  </View>
);

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  permissionContainer: {
    flex: 1,
    backgroundColor: '#FFF0F0',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  permissionIconCircle: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#FED9E2',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 24,
  },
  permissionTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#1A1A2E',
    marginBottom: 12,
  },
  permissionDesc: {
    fontSize: 14,
    color: '#9CA3AF',
    textAlign: 'center',
    marginBottom: 32,
    lineHeight: 20,
  },
  permissionButton: {
    backgroundColor: '#D4728C',
    paddingHorizontal: 28,
    paddingVertical: 14,
    borderRadius: 24,
  },
  permissionButtonText: {
    color: '#FFF',
    fontWeight: 'bold',
    fontSize: 16,
  },
  blurredBackground: {
    opacity: 0.45,
    transform: [{ scale: 1.1 }],
  },
  topBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: 60,
    paddingHorizontal: 24,
    zIndex: 10,
  },
  iconButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(255,255,255,0.2)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  brandTitle: {
    color: '#FFF',
    fontSize: 18,
    fontWeight: '600',
    fontFamily: 'System',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  frameContainer: {
    width: FRAME_WIDTH,
    height: FRAME_HEIGHT,
    borderRadius: 20,
    overflow: 'hidden',
    backgroundColor: '#000',
    position: 'relative',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.18,
    shadowRadius: 24,
    elevation: 10,
  },
  frameContainerActive: {
    width: FRAME_WIDTH,
    height: FRAME_HEIGHT,
    borderRadius: 20,
    position: 'relative',
    borderWidth: 1,
    borderColor: 'rgba(212, 114, 140, 0.4)',
    backgroundColor: 'rgba(0,0,0,0.1)',
  },
  frameImage: {
    width: '100%',
    height: '100%',
  },
  bracket: {
    position: 'absolute',
    width: 22,
    height: 22,
    borderColor: 'rgba(212, 114, 140, 0.8)',
    borderWidth: 3,
    borderRadius: 4,
  },
  scanLineContainer: {
    position: 'absolute',
    width: '100%',
    height: 70,
    top: 0, left: 0, right: 0,
    justifyContent: 'flex-start',
  },
  scanGlow: {
    width: '100%',
    height: '100%',
    backgroundColor: 'rgba(212, 114, 140, 0.3)',
  },
  scanLine: {
    position: 'absolute',
    top: 0,
    width: '100%',
    height: 3,
    backgroundColor: '#fff',
    shadowColor: '#D4728C',
    shadowOpacity: 1,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 0 },
    elevation: 5,
  },
  processingChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(254, 217, 226, 0.85)',
    paddingHorizontal: 22,
    paddingVertical: 13,
    borderRadius: 30,
    marginTop: 32,
    gap: 10,
  },
  processingText: {
    color: '#73585F',
    fontWeight: 'bold',
    fontSize: 15,
  },
  hintChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.5)',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 30,
    marginTop: 32,
    gap: 8,
  },
  hintText: {
    color: '#FFF',
    fontSize: 14,
    fontWeight: '500',
  },
  dotContainer: {
    width: 14,
    height: 14,
    justifyContent: 'center',
    alignItems: 'center',
  },
  dotPulse: {
    position: 'absolute',
    width: 14,
    height: 14,
    borderRadius: 7,
    backgroundColor: 'rgba(212, 114, 140, 0.35)',
  },
  dotCenter: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#D4728C',
  },
  bottomBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 48,
    paddingBottom: 50,
  },
  galleryButton: {
    alignItems: 'center',
    width: 60,
    gap: 6,
  },
  galleryText: {
    color: '#FFF',
    fontSize: 10,
    fontWeight: 'bold',
    letterSpacing: 0.8,
  },
  captureOuter: {
    width: 86,
    height: 86,
    borderRadius: 43,
    backgroundColor: 'rgba(212, 114, 140, 0.3)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  captureInner: {
    width: 68,
    height: 68,
    borderRadius: 34,
    backgroundColor: '#D4728C',
    justifyContent: 'center',
    alignItems: 'center',
  },
  sheetOverlay: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0,0,0,0.4)',
  },
  sheetContent: {
    backgroundColor: '#FFF0F0',
    borderTopLeftRadius: 32,
    borderTopRightRadius: 32,
    height: '70%',
    paddingBottom: 40,
  },
  sheetHandle: {
    width: 40,
    height: 5,
    backgroundColor: '#D1D5DB',
    borderRadius: 3,
    alignSelf: 'center',
    marginTop: 12,
    marginBottom: 8,
  },
  sheetHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingVertical: 12,
  },
  sheetTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1A1A2E',
  },
  resultsCountText: {
    fontSize: 13,
    color: '#9CA3AF',
    marginBottom: 12,
    marginLeft: 4,
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingTop: 40,
    paddingHorizontal: 20,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1A1A2E',
    marginBottom: 8,
  },
  emptyDesc: {
    fontSize: 14,
    color: '#9CA3AF',
    textAlign: 'center',
    lineHeight: 20,
    marginBottom: 24,
  },
  retryButton: {
    backgroundColor: '#FFF',
    borderWidth: 1,
    borderColor: '#E5E7EB',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 20,
  },
  retryButtonText: {
    color: '#1A1A2E',
    fontWeight: '600',
  }
});
