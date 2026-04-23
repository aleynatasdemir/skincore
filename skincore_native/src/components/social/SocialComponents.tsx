import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Image, Dimensions, ScrollView, TextInput, ActivityIndicator, KeyboardAvoidingView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import type { RoutineFeedItem, PublicUserProfileResponse, RoutineCommentResponse, RoutineDetail } from '../../types/social';
import { resolveMediaUrl, routinesApi } from '../../api/apiClient';
import { useSocialStore } from '../../store/socialStore';

const { width, height } = Dimensions.get('window');

// MARK: - Routine Feed Card
interface RoutineFeedCardProps {
  item: RoutineFeedItem;
  onPress: () => void;
}
export const RoutineFeedCard: React.FC<RoutineFeedCardProps> = ({ item, onPress }) => {
  const store = useSocialStore();
  const coverUrl = resolveMediaUrl(item.coverImageUrl) || 'https://via.placeholder.com/400x300';
  const profileUrl = resolveMediaUrl(item.profileImageUrl);

  return (
    <TouchableOpacity style={styles.cardContainer} activeOpacity={0.9} onPress={onPress}>
      <Image source={{ uri: coverUrl }} style={styles.cardImage} />
      
      <View style={styles.cardOverlay}>
        <View style={styles.cardHeader}>
          <View style={styles.authorRow}>
            {profileUrl ? (
              <Image source={{ uri: profileUrl }} style={styles.avatar} />
            ) : (
              <View style={styles.avatarPlaceholder}>
                <Ionicons name="person" size={16} color="#FFF" />
              </View>
            )}
            <View>
              <Text style={styles.authorName}>{item.displayName || item.username || 'A. Skincore'}</Text>
              <Text style={styles.timeAgo}>{item.createdAt ? new Date(item.createdAt).toLocaleDateString() : 'Yeni'}</Text>
            </View>
          </View>
          
          <View style={styles.typeBadge}>
            <Text style={styles.typeBadgeText}>
              {item.type === 'morning' ? 'Sabah' : item.type === 'evening' ? 'Akşam' : 'Rutin'}
            </Text>
          </View>
        </View>

        <View style={styles.cardFooter}>
          <Text style={styles.cardTitle} numberOfLines={2}>{item.title}</Text>
          
          <View style={styles.interactionRow}>
            <TouchableOpacity 
              style={styles.actionButton} 
              onPress={() => store.toggleLike(item.id)}
            >
              <Ionicons 
                name={item.isLiked ? "heart" : "heart-outline"} 
                size={24} 
                color={item.isLiked ? "#EC4899" : "#FFF"} 
              />
              <Text style={styles.actionText}>{item.likeCount}</Text>
            </TouchableOpacity>

            <View style={styles.actionButton}>
              <Ionicons name="chatbubble-outline" size={22} color="#FFF" />
              <Text style={styles.actionText}>{item.commentCount}</Text>
            </View>
          </View>
        </View>
      </View>
    </TouchableOpacity>
  );
};

// MARK: - Person Row
interface PersonRowProps {
  user: PublicUserProfileResponse;
}
export const PersonRow: React.FC<PersonRowProps> = ({ user }) => {
  const profileUrl = resolveMediaUrl(user.profileImageUrl);

  return (
    <TouchableOpacity style={styles.personContainer}>
      {profileUrl ? (
        <Image source={{ uri: profileUrl }} style={styles.personAvatar} />
      ) : (
        <View style={[styles.personAvatar, { backgroundColor: '#F3F4F6', justifyContent: 'center', alignItems: 'center' }]}>
          <Ionicons name="person" size={24} color="#9CA3AF" />
        </View>
      )}
      <View style={styles.personInfo}>
        <Text style={styles.personName}>{user.fullName || user.username || 'Kullanıcı'}</Text>
        <Text style={styles.personUsername}>@{user.username}</Text>
      </View>
      <TouchableOpacity style={styles.followButton}>
        <Text style={styles.followButtonText}>
          {user.isFollowing ? 'Takipte' : 'Takip Et'}
        </Text>
      </TouchableOpacity>
    </TouchableOpacity>
  );
};

// MARK: - Routine Detail Sheet
interface RoutineDetailSheetProps {
  routine: RoutineFeedItem;
  onClose: () => void;
}
export const RoutineDetailSheet: React.FC<RoutineDetailSheetProps> = ({ routine, onClose }) => {
  const [detail, setDetail] = useState<RoutineDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [commentText, setCommentText] = useState('');
  
  const coverUrl = resolveMediaUrl(routine.coverImageUrl) || 'https://via.placeholder.com/400x300';
  const profileUrl = resolveMediaUrl(routine.profileImageUrl);

  React.useEffect(() => {
    routinesApi.getDetail(routine.id).then(res => {
      setDetail(res);
      setLoading(false);
    }).catch(e => {
      console.error(e);
      setLoading(false);
    });
  }, [routine.id]);

  const postComment = async () => {
    if (!commentText.trim()) return;
    try {
      const res = await routinesApi.addComment(routine.id, commentText);
      setDetail(prev => prev ? { ...prev, comments: [...prev.comments, res], commentCount: prev.commentCount + 1 } : prev);
      setCommentText('');
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <View style={styles.sheetContainer}>
      <View style={styles.sheetHeaderDragger} />
      
      <ScrollView bounces={false} showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 60 }}>
        <Image source={{ uri: coverUrl }} style={styles.sheetCover} />
        
        <View style={styles.sheetContent}>
          <Text style={styles.sheetTitle}>{routine.title}</Text>
          {routine.description && <Text style={styles.sheetDesc}>{routine.description}</Text>}

          <View style={styles.sheetAuthorFlex}>
            {profileUrl ? (
              <Image source={{ uri: profileUrl }} style={styles.sheetAvatar} />
            ) : (
              <View style={styles.sheetAvatarPlaceholder}>
                <Ionicons name="person" size={16} color="#FFF" />
              </View>
            )}
            <View>
               <Text style={styles.sheetAuthorName}>{routine.displayName || routine.username}</Text>
               <Text style={styles.sheetAuthorSubtitle}>Skincore Skincore</Text>
            </View>
          </View>

          <View style={styles.divider} />
          <Text style={styles.sectionHeader}>KULLANILAN ÜRÜNLER</Text>
          {routine.products?.map((p, i) => (
             <View key={i} style={styles.productBubble}>
                <Ionicons name="sparkles" size={16} color="#D4728C" />
                <Text style={styles.productBubbleText}>{p.brandName ? `${p.brandName} - ` : ''}{p.productName}</Text>
             </View>
          ))}

          <View style={styles.divider} />
          <Text style={styles.sectionHeader}>YORUMLAR</Text>
          
          {loading ? (
            <ActivityIndicator size="small" color="#D4728C" style={{ marginVertical: 20 }} />
          ) : detail?.comments?.length === 0 ? (
            <Text style={styles.noCommentsText}>Henüz yorum yok. İlk yorumu sen yap!</Text>
          ) : (
            detail?.comments?.map((c, i) => (
              <View key={i} style={styles.commentRow}>
                <Text style={styles.commentAuthor}>{c.username || 'Kullanıcı'}</Text>
                <Text style={styles.commentText}>{c.text}</Text>
              </View>
            ))
          )}
        </View>
      </ScrollView>

      {/* Write Comment Box fixed at bottom */}
      <KeyboardAvoidingView behavior="padding" style={styles.commentInputBox}>
        <TextInput 
          style={styles.commentInput} 
          placeholder="Yorum ekle..." 
          value={commentText}
          onChangeText={setCommentText}
          multiline
        />
        <TouchableOpacity style={styles.postButton} onPress={postComment}>
          <Text style={styles.postButtonText}>Paylaş</Text>
        </TouchableOpacity>
      </KeyboardAvoidingView>

      <TouchableOpacity style={styles.closeAbsolute} onPress={onClose}>
        <Ionicons name="close" size={20} color="#1A1A2E" />
      </TouchableOpacity>
    </View>
  );
};

// MARK: - Styles
const styles = StyleSheet.create({
  cardContainer: {
    marginHorizontal: 16,
    marginBottom: 20,
    borderRadius: 24,
    height: 380,
    backgroundColor: '#000',
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOpacity: 0.15,
    shadowRadius: 10,
    elevation: 8,
  },
  cardImage: {
    width: '100%',
    height: '100%',
    opacity: 0.85,
  },
  cardOverlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'space-between',
    padding: 20,
    backgroundColor: 'rgba(0,0,0,0.1)', // subtle gradient could be added via expo-linear-gradient
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  authorRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.4)',
    paddingRight: 14,
    paddingLeft: 4,
    paddingVertical: 4,
    borderRadius: 30,
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    marginRight: 8,
  },
  avatarPlaceholder: {
    width: 32,
    height: 32,
    borderRadius: 16,
    marginRight: 8,
    backgroundColor: '#9CA3AF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  authorName: {
    color: '#FFF',
    fontSize: 13,
    fontWeight: 'bold',
  },
  timeAgo: {
    color: '#D1D5DB',
    fontSize: 10,
  },
  typeBadge: {
    backgroundColor: 'rgba(255,255,255,0.2)',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 12,
  },
  typeBadgeText: {
    color: '#FFF',
    fontSize: 12,
    fontWeight: '600',
  },
  cardFooter: {
    justifyContent: 'flex-end',
  },
  cardTitle: {
    color: '#FFF',
    fontSize: 22,
    fontWeight: '800',
    marginBottom: 12,
    textShadowColor: 'rgba(0,0,0,0.5)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 4,
  },
  interactionRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 16,
    backgroundColor: 'rgba(0,0,0,0.4)',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
  },
  actionText: {
    color: '#FFF',
    fontSize: 14,
    fontWeight: 'bold',
    marginLeft: 6,
  },
  personContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F3F4F6',
  },
  personAvatar: {
    width: 50,
    height: 50,
    borderRadius: 25,
  },
  personInfo: {
    flex: 1,
    marginLeft: 12,
  },
  personName: {
    fontSize: 15,
    fontWeight: 'bold',
    color: '#1A1A2E',
  },
  personUsername: {
    fontSize: 13,
    color: '#6B7280',
    marginTop: 2,
  },
  followButton: {
    backgroundColor: '#FDE8E8',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  followButtonText: {
    color: '#D4728C',
    fontSize: 12,
    fontWeight: 'bold',
  },
  sheetContainer: {
    backgroundColor: '#FFF',
    borderTopLeftRadius: 30,
    borderTopRightRadius: 30,
    overflow: 'hidden',
    height: height * 0.85,
  },
  sheetHeaderDragger: {
    width: 40,
    height: 4,
    backgroundColor: '#D1D5DB',
    borderRadius: 2,
    alignSelf: 'center',
    marginTop: 12,
    marginBottom: 8,
  },
  sheetCover: {
    width: '100%',
    height: 300,
  },
  sheetContent: {
    padding: 24,
  },
  sheetTitle: {
    fontSize: 24,
    fontWeight: '800',
    color: '#1A1A2E',
    marginBottom: 10,
  },
  sheetDesc: {
    fontSize: 15,
    color: '#4B5563',
    lineHeight: 22,
    marginBottom: 20,
  },
  sheetAuthorFlex: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  sheetAvatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    marginRight: 12,
  },
  sheetAvatarPlaceholder: {
    width: 44,
    height: 44,
    borderRadius: 22,
    marginRight: 12,
    backgroundColor: '#D4728C',
    justifyContent: 'center',
    alignItems: 'center',
  },
  sheetAuthorName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1A1A2E',
  },
  sheetAuthorSubtitle: {
    fontSize: 12,
    color: '#6B7280',
  },
  divider: {
    height: 1,
    backgroundColor: '#F3F4F6',
    marginVertical: 24,
  },
  sectionHeader: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#9CA3AF',
    letterSpacing: 1,
    marginBottom: 16,
  },
  productBubble: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FDF2F8',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 16,
    marginBottom: 10,
  },
  productBubbleText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1A1A2E',
    marginLeft: 8,
  },
  commentRow: {
    marginBottom: 16,
  },
  commentAuthor: {
    fontSize: 13,
    fontWeight: 'bold',
    color: '#1A1A2E',
    marginBottom: 4,
  },
  commentText: {
    fontSize: 14,
    color: '#4B5563',
    lineHeight: 20,
  },
  noCommentsText: {
    color: '#9CA3AF',
    fontStyle: 'italic',
  },
  commentInputBox: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    padding: 16,
    borderTopWidth: 1,
    borderTopColor: '#F3F4F6',
    backgroundColor: '#FFF',
  },
  commentInput: {
    flex: 1,
    backgroundColor: '#F3F4F6',
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 12,
    fontSize: 14,
    maxHeight: 100,
  },
  postButton: {
    marginLeft: 12,
    paddingVertical: 10,
    paddingHorizontal: 16,
    backgroundColor: '#D4728C',
    borderRadius: 20,
  },
  postButtonText: {
    color: '#FFF',
    fontWeight: 'bold',
    fontSize: 14,
  },
  closeAbsolute: {
    position: 'absolute',
    top: 16,
    right: 16,
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(255,255,255,0.9)',
    justifyContent: 'center',
    alignItems: 'center',
  }
});
