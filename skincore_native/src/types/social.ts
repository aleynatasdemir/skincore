// Sosyal modeller — Swift SocialModels.swift karşılığı

// MARK: - Rutin

export type RoutineType = 'morning' | 'evening' | string;

export interface RoutineProduct {
  productId: string;
  productName?: string;
  brandName?: string;
  imageUrl?: string;
}

export interface RoutineFeedItem {
  id: string;
  userId: string;
  username?: string;
  displayName?: string;
  profileImageUrl?: string;
  title: string;
  description?: string;
  coverImageUrl?: string;
  type?: RoutineType;
  products: RoutineProduct[];
  likeCount: number;
  commentCount: number;
  isLiked: boolean;
  createdAt?: string;
}

export interface RoutineCommentResponse {
  id: string;
  userId: string;
  username?: string;
  displayName?: string;
  profileImageUrl?: string;
  text: string;
  createdAt?: string;
}

export interface RoutineDetail extends RoutineFeedItem {
  comments: RoutineCommentResponse[];
}

export interface CreateRoutineRequest {
  title: string;
  description?: string;
  type?: RoutineType;
  coverImageUrl?: string;
  productIds: string[];
}

export interface AddRoutineCommentRequest {
  text: string;
}

export interface ToggleLikeResponse {
  isLiked: boolean;
  likeCount: number;
}

// MARK: - Profil

export interface UserProfileResponse {
  id: string;
  email?: string;
  username?: string;
  fullName?: string;
  bio?: string;
  profileImageUrl?: string;
  skinType?: string;
  followerCount: number;
  followingCount: number;
  isEmailVerified?: boolean;
  notificationsEnabled?: boolean;
}

export interface PublicUserProfileResponse {
  id: string;
  username?: string;
  fullName?: string;
  bio?: string;
  profileImageUrl?: string;
  skinType?: string;
  followerCount: number;
  followingCount: number;
  isFollowing: boolean;
}

export interface UpdateProfileRequest {
  displayName?: string;
  skinType?: string;
  username?: string;
  bio?: string;
}

export interface UpdateBioRequest {
  bio?: string;
}
