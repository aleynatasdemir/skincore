import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Image, ImageProps } from 'expo-image';

export function CachedImage({ style, ...props }: ImageProps) {
  return (
    <Image
      style={[styles.image, style]}
      contentFit="cover"
      transition={200}
      cachePolicy="memory-disk"
      {...props}
    />
  );
}

const styles = StyleSheet.create({
  image: {
    width: '100%',
    height: '100%',
  },
});
