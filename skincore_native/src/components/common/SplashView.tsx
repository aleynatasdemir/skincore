import React, { useEffect } from 'react';
import { StyleSheet, View, Text } from 'react-native';
import Animated, { 
  useSharedValue, 
  useAnimatedStyle, 
  withRepeat, 
  withTiming, 
  withSequence,
  Easing
} from 'react-native-reanimated';
import { Colors } from '../../theme/colors';

export const SplashView = () => {
  const scale = useSharedValue(0.97);

  useEffect(() => {
    scale.value = withRepeat(
      withSequence(
        withTiming(1.03, { duration: 1000, easing: Easing.inOut(Easing.ease) }),
        withTiming(0.97, { duration: 1000, easing: Easing.inOut(Easing.ease) })
      ),
      -1, // Sonsuz tekrar
      true
    );
  }, []);

  const animatedStyle = useAnimatedStyle(() => {
    return {
      transform: [{ scale: scale.value }],
    };
  });

  return (
    <View style={styles.container}>
      <Animated.Image 
        source={require('../../../assets/icon.png')} 
        style={[styles.logo, animatedStyle]}
        resizeMode="contain"
      />
      <Text style={styles.brandName}>SkinCore</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background, // FFF0F0
    justifyContent: 'center',
    alignItems: 'center',
  },
  logo: {
    width: 140,
    height: 140,
    borderRadius: 30, // İsteğe bağlı, icon tasarımı kare ise köşeleri yuvarlatır
    marginBottom: 24,
  },
  brandName: {
    fontSize: 32,
    fontWeight: 'bold',
    color: Colors.dark,
    letterSpacing: 2,
  }
});
