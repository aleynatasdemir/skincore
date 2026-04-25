import React, { useState } from 'react';
import { View, Text, StyleSheet, Modal, TouchableOpacity, SafeAreaView, Dimensions, ActivityIndicator, Alert } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTranslation } from 'react-i18next';
import Animated, { useAnimatedStyle, withTiming } from 'react-native-reanimated';
import { useAuthStore } from '../../store/authStore';
import api from '../../api/apiClient';

const { width } = Dimensions.get('window');

interface QuizAnswer {
  textKey: string;
  scores: Record<string, number>;
}

interface QuizQuestion {
  id: number;
  questionKey: string;
  answers: QuizAnswer[];
}

const quizQuestions: QuizQuestion[] = [
    { id: 1, questionKey: "quizQ1", answers: [ { textKey: "quizQ1A1", scores: {"Yağlı": 2, "Akneye Meyilli": 1} }, { textKey: "quizQ1A2", scores: {"Karma": 2} }, { textKey: "quizQ1A3", scores: {"Kuru": 2} }, { textKey: "quizQ1A4", scores: {"Normal": 2} } ] },
    { id: 2, questionKey: "quizQ2", answers: [ { textKey: "quizQ2A1", scores: {"Kuru": 2} }, { textKey: "quizQ2A2", scores: {"Yağlı": 2} }, { textKey: "quizQ2A3", scores: {"Karma": 2} }, { textKey: "quizQ2A4", scores: {"Normal": 2} } ] },
    { id: 3, questionKey: "quizQ3", answers: [ { textKey: "quizQ3A1", scores: {"Yağlı": 2, "Akneye Meyilli": 1} }, { textKey: "quizQ3A2", scores: {"Karma": 2} }, { textKey: "quizQ3A3", scores: {"Kuru": 1, "Normal": 1} }, { textKey: "quizQ3A4", scores: {"Normal": 2} } ] },
    { id: 4, questionKey: "quizQ4", answers: [ { textKey: "quizQ4A1", scores: {"Akneye Meyilli": 3, "Yağlı": 1} }, { textKey: "quizQ4A2", scores: {"Karma": 1} }, { textKey: "quizQ4A3", scores: {"Normal": 1} }, { textKey: "quizQ4A4", scores: {"Kuru": 1} } ] },
    { id: 5, questionKey: "quizQ5", answers: [ { textKey: "quizQ5A1", scores: {"Hassas": 3} }, { textKey: "quizQ5A2", scores: {"Hassas": 1} }, { textKey: "quizQ5A3", scores: {"Normal": 1} }, { textKey: "quizQ5A4", scores: {} } ] },
    { id: 6, questionKey: "quizQ6", answers: [ { textKey: "quizQ6A1", scores: {"Olgun": 3} }, { textKey: "quizQ6A2", scores: {"Olgun": 2} }, { textKey: "quizQ6A3", scores: {"Olgun": 1} }, { textKey: "quizQ6A4", scores: {} } ] },
    { id: 7, questionKey: "quizQ7", answers: [ { textKey: "quizQ7A1", scores: {"Yağlı": 2} }, { textKey: "quizQ7A2", scores: {"Karma": 2} }, { textKey: "quizQ7A3", scores: {"Kuru": 2} }, { textKey: "quizQ7A4", scores: {"Normal": 2} } ] }
];

function calculateSkinType(answers: Record<number, number>): string {
    let scores: Record<string, number> = { "Yağlı": 0, "Kuru": 0, "Karma": 0, "Normal": 0, "Hassas": 0, "Akneye Meyilli": 0, "Olgun": 0 };
    for (const q of quizQuestions) {
        const selectedIdx = answers[q.id];
        if (selectedIdx !== undefined && selectedIdx < q.answers.length) {
            const answer = q.answers[selectedIdx];
            for (const [type, val] of Object.entries(answer.scores)) {
                scores[type] = (scores[type] || 0) + val;
            }
        }
    }
    const maxScore = Math.max(...Object.values(scores));
    const candidates = Object.keys(scores).filter(k => scores[k] === maxScore);
    const priority = ["Akneye Meyilli", "Hassas", "Yağlı", "Kuru", "Karma", "Normal", "Olgun"];
    for (const p of priority) {
        if (candidates.includes(p)) return p;
    }
    return "Normal";
}

interface Props {
  visible: boolean;
  onClose: () => void;
  onQuizComplete?: (skinType: string) => void;
}

export const SkinTypeQuizModal: React.FC<Props> = ({ visible, onClose, onQuizComplete }) => {
  const { t } = useTranslation();
  const user = useAuthStore(state => state.currentUser);
  const checkAuth = useAuthStore(state => state.checkAuth);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<number, number>>({});
  const [selectedAnswer, setSelectedAnswer] = useState<number | null>(null);
  const [showResult, setShowResult] = useState(false);
  const [resultSkinType, setResultSkinType] = useState<string>('');
  const [isSaving, setIsSaving] = useState(false);

  const currentQ = quizQuestions[currentIndex];
  const progress = (currentIndex + 1) / quizQuestions.length;

  const progressStyle = useAnimatedStyle(() => ({
    width: withTiming(`${progress * 100}%`, { duration: 300 }),
  }));

  const handleNext = () => {
    if (selectedAnswer === null) return;
    setAnswers(prev => ({ ...prev, [currentQ.id]: selectedAnswer }));
    
    if (currentIndex < quizQuestions.length - 1) {
      setCurrentIndex(currentIndex + 1);
      setSelectedAnswer(null);
    } else {
      // Calculate
      const finalAnswers = { ...answers, [currentQ.id]: selectedAnswer };
      const res = calculateSkinType(finalAnswers);
      setResultSkinType(res);
      setShowResult(true);
    }
  };

  const handleSave = async () => {
    if (onQuizComplete) {
      onQuizComplete(resultSkinType);
      onClose();
      return;
    }
    
    setIsSaving(true);
    try {
      await api.put('/userprofile', { skinType: resultSkinType });
      await checkAuth(); // Refresh user data
      onClose();
    } catch (error) {
      Alert.alert('Hata', 'Cilt tipi kaydedilirken bir hata oluştu.');
    } finally {
      setIsSaving(false);
    }
  };

  const resetQuiz = () => {
    setCurrentIndex(0);
    setAnswers({});
    setSelectedAnswer(null);
    setShowResult(false);
    setResultSkinType('');
  };

  // Only render content if visible
  if (!visible) return null;

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet">
      <SafeAreaView style={styles.container}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
            <Ionicons name="close" size={24} color="#1A1A2E" />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>{t('quizNavTitle')}</Text>
          <View style={{ width: 24 }} />
        </View>

        {!showResult ? (
          <View style={styles.content}>
            <View style={styles.progressContainer}>
              <Text style={styles.progressText}>
                {t('quizStep', { current: currentIndex + 1, total: quizQuestions.length })}
              </Text>
              <View style={styles.progressBarBg}>
                <Animated.View style={[styles.progressBarFill, progressStyle]} />
              </View>
            </View>

            <Text style={styles.questionText}>
              {t(currentQ.questionKey)}
            </Text>

            <View style={styles.answersContainer}>
              {currentQ.answers.map((ans, idx) => {
                const isSelected = selectedAnswer === idx;
                return (
                  <TouchableOpacity
                    key={idx}
                    activeOpacity={0.7}
                    style={[styles.answerBtn, isSelected && styles.answerBtnSelected]}
                    onPress={() => setSelectedAnswer(idx)}
                  >
                    <View style={[styles.radioOuter, isSelected && styles.radioOuterSelected]}>
                      {isSelected && <View style={styles.radioInner} />}
                    </View>
                    <Text style={[styles.answerText, isSelected && styles.answerTextSelected]}>
                        {t(ans.textKey)}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>

            {selectedAnswer !== null && (
              <TouchableOpacity style={styles.nextBtn} onPress={handleNext}>
                <Text style={styles.nextBtnText}>
                  {currentIndex === quizQuestions.length - 1 ? t('quizFinish') : t('quizNext')}
                </Text>
                <Ionicons name="arrow-forward" size={20} color="#FFF" style={{ marginLeft: 8 }} />
              </TouchableOpacity>
            )}
          </View>
        ) : (
          <View style={styles.resultContent}>
            <View style={styles.resultIconBg}>
                <Ionicons name="sparkles" size={48} color="#D4728C" />
            </View>
            <Text style={styles.resultTitle}>{t('quizResultTitle')}</Text>
            <Text style={styles.resultValue}>{resultSkinType}</Text>
            <Text style={styles.resultDesc}>{t('quizResultDesc')}</Text>

            <TouchableOpacity style={styles.saveBtn} onPress={handleSave} disabled={isSaving}>
              {isSaving ? (
                <ActivityIndicator color="#FFF" />
              ) : (
                <Text style={styles.saveBtnText}>{t('quizSave')}</Text>
              )}
            </TouchableOpacity>
            
            <TouchableOpacity style={styles.retakeBtn} onPress={resetQuiz} disabled={isSaving}>
              <Text style={styles.retakeBtnText}>{t('quizRetake')}</Text>
            </TouchableOpacity>
          </View>
        )}
      </SafeAreaView>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFF',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#F3F4F6',
  },
  closeBtn: {
    padding: 4,
  },
  headerTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1A1A2E',
  },
  content: {
    flex: 1,
    padding: 24,
  },
  progressContainer: {
    marginBottom: 32,
  },
  progressText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#9CA3AF',
    marginBottom: 8,
  },
  progressBarBg: {
    height: 6,
    backgroundColor: '#F3F4F6',
    borderRadius: 3,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    backgroundColor: '#D4728C',
    borderRadius: 3,
  },
  questionText: {
    fontSize: 22,
    fontWeight: '700',
    color: '#1A1A2E',
    marginBottom: 32,
    lineHeight: 30,
  },
  answersContainer: {
    gap: 16,
  },
  answerBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderWidth: 2,
    borderColor: '#F3F4F6',
    borderRadius: 16,
    backgroundColor: '#FFF',
  },
  answerBtnSelected: {
    borderColor: '#D4728C',
    backgroundColor: '#FFF0F0',
  },
  radioOuter: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#D1D5DB',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  radioOuterSelected: {
    borderColor: '#D4728C',
  },
  radioInner: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#D4728C',
  },
  answerText: {
    flex: 1,
    fontSize: 16,
    color: '#4B5563',
    fontWeight: '500',
  },
  answerTextSelected: {
    color: '#1A1A2E',
    fontWeight: '600',
  },
  nextBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#D4728C',
    paddingVertical: 18,
    borderRadius: 30,
    marginTop: 'auto',
    marginBottom: 20,
    shadowColor: '#D4728C',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 5,
  },
  nextBtnText: {
    color: '#FFF',
    fontSize: 16,
    fontWeight: '700',
  },
  resultContent: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 32,
  },
  resultIconBg: {
    width: 100,
    height: 100,
    backgroundColor: '#FFF0F0',
    borderRadius: 50,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 24,
  },
  resultTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#9CA3AF',
    letterSpacing: 2,
    marginBottom: 8,
  },
  resultValue: {
    fontSize: 32,
    fontWeight: '800',
    color: '#1A1A2E',
    marginBottom: 16,
    textAlign: 'center',
  },
  resultDesc: {
    fontSize: 16,
    color: '#6B7280',
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: 48,
  },
  saveBtn: {
    backgroundColor: '#D4728C',
    width: '100%',
    paddingVertical: 18,
    borderRadius: 30,
    alignItems: 'center',
    marginBottom: 16,
    shadowColor: '#D4728C',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 5,
  },
  saveBtnText: {
    color: '#FFF',
    fontSize: 16,
    fontWeight: '700',
  },
  retakeBtn: {
    paddingVertical: 16,
    width: '100%',
    alignItems: 'center',
  },
  retakeBtnText: {
    color: '#9CA3AF',
    fontSize: 16,
    fontWeight: '600',
  },
});
