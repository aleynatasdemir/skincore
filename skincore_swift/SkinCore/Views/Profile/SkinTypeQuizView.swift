import SwiftUI

// MARK: - Quiz Data

private struct QuizQuestion {
    let id: Int
    let question: String
    let answers: [QuizAnswer]
}

private struct QuizAnswer {
    let text: String
    let scores: [String: Int]
}

private let quizQuestions: [QuizQuestion] = [
    QuizQuestion(id: 1,
        question: "quiz_q1",
        answers: [
            QuizAnswer(text: "quiz_q1_a1", scores: ["Yağlı": 2, "Akneye Meyilli": 1]),
            QuizAnswer(text: "quiz_q1_a2", scores: ["Karma": 2]),
            QuizAnswer(text: "quiz_q1_a3", scores: ["Kuru": 2]),
            QuizAnswer(text: "quiz_q1_a4", scores: ["Normal": 2])
        ]),
    QuizQuestion(id: 2,
        question: "quiz_q2",
        answers: [
            QuizAnswer(text: "quiz_q2_a1", scores: ["Kuru": 2]),
            QuizAnswer(text: "quiz_q2_a2", scores: ["Yağlı": 2]),
            QuizAnswer(text: "quiz_q2_a3", scores: ["Karma": 2]),
            QuizAnswer(text: "quiz_q2_a4", scores: ["Normal": 2])
        ]),
    QuizQuestion(id: 3,
        question: "quiz_q3",
        answers: [
            QuizAnswer(text: "quiz_q3_a1", scores: ["Yağlı": 2, "Akneye Meyilli": 1]),
            QuizAnswer(text: "quiz_q3_a2", scores: ["Karma": 2]),
            QuizAnswer(text: "quiz_q3_a3", scores: ["Kuru": 1, "Normal": 1]),
            QuizAnswer(text: "quiz_q3_a4", scores: ["Normal": 2])
        ]),
    QuizQuestion(id: 4,
        question: "quiz_q4",
        answers: [
            QuizAnswer(text: "quiz_q4_a1", scores: ["Akneye Meyilli": 3, "Yağlı": 1]),
            QuizAnswer(text: "quiz_q4_a2", scores: ["Karma": 1]),
            QuizAnswer(text: "quiz_q4_a3", scores: ["Normal": 1]),
            QuizAnswer(text: "quiz_q4_a4", scores: ["Kuru": 1])
        ]),
    QuizQuestion(id: 5,
        question: "quiz_q5",
        answers: [
            QuizAnswer(text: "quiz_q5_a1", scores: ["Hassas": 3]),
            QuizAnswer(text: "quiz_q5_a2", scores: ["Hassas": 1]),
            QuizAnswer(text: "quiz_q5_a3", scores: ["Normal": 1]),
            QuizAnswer(text: "quiz_q5_a4", scores: [:])
        ]),
    QuizQuestion(id: 6,
        question: "quiz_q6",
        answers: [
            QuizAnswer(text: "quiz_q6_a1", scores: ["Olgun": 3]),
            QuizAnswer(text: "quiz_q6_a2", scores: ["Olgun": 2]),
            QuizAnswer(text: "quiz_q6_a3", scores: ["Olgun": 1]),
            QuizAnswer(text: "quiz_q6_a4", scores: [:])
        ]),
    QuizQuestion(id: 7,
        question: "quiz_q7",
        answers: [
            QuizAnswer(text: "quiz_q7_a1", scores: ["Yağlı": 2]),
            QuizAnswer(text: "quiz_q7_a2", scores: ["Karma": 2]),
            QuizAnswer(text: "quiz_q7_a3", scores: ["Kuru": 2]),
            QuizAnswer(text: "quiz_q7_a4", scores: ["Normal": 2])
        ])
]

// MARK: - Hesaplama

private func calculateSkinType(answers: [Int: Int]) -> String {
    var scores: [String: Int] = [
        "Yağlı": 0, "Kuru": 0, "Karma": 0,
        "Normal": 0, "Hassas": 0, "Akneye Meyilli": 0, "Olgun": 0
    ]

    for question in quizQuestions {
        guard let selectedIndex = answers[question.id],
              selectedIndex < question.answers.count else { continue }
        let answer = question.answers[selectedIndex]
        for (skinType, value) in answer.scores {
            scores[skinType, default: 0] += value
        }
    }

    let maxScore = scores.values.max() ?? 0
    let candidates = scores.filter { $0.value == maxScore }.map { $0.key }

    let priority = ["Akneye Meyilli", "Hassas", "Yağlı", "Kuru", "Karma", "Normal", "Olgun"]
    for p in priority {
        if candidates.contains(p) { return p }
    }
    return "Normal"
}

// MARK: - Main View

struct SkinTypeQuizView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss

    /// When set, "Save" returns the result via this callback instead of saving to backend.
    var onQuizComplete: ((String) -> Void)? = nil

    @State private var currentIndex: Int = 0
    @State private var answers: [Int: Int] = [:]
    @State private var selectedAnswer: Int? = nil
    @State private var showResult = false
    @State private var resultSkinType: String = ""
    @State private var isSaving = false

    private var currentQuestion: QuizQuestion { quizQuestions[currentIndex] }
    private var progress: CGFloat { CGFloat(currentIndex + 1) / CGFloat(quizQuestions.count) }
    private var isFirst: Bool { currentIndex == 0 }
    private var isLast: Bool { currentIndex == quizQuestions.count - 1 }

    var body: some View {
        ZStack {
            Color(hex: "FFF8F7").ignoresSafeArea()

            if showResult {
                QuizResultView(
                    skinType: resultSkinType,
                    isSaving: isSaving,
                    onSave: { Task { await saveAndDismiss() } },
                    onRetake: { resetQuiz() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            } else {
                questionView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentIndex)
        .animation(.easeInOut(duration: 0.35), value: showResult)
    }

    // MARK: - Soru Ekranı

    private var questionView: some View {
        VStack(spacing: 0) {
            // TopBar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.6))
                        .frame(width: 40, height: 40)
                        .background(Color(hex: "D4728C").opacity(0.06))
                        .clipShape(Circle())
                }
                Spacer()
                Text(lang.s(.quizNavTitle))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "D4728C").opacity(0.5))
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // İçerik
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Adım + Soru
                    VStack(spacing: 20) {
                        Text(String(format: lang.s(.quizStep), currentIndex + 1, quizQuestions.count))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(3)
                            .foregroundColor(Color(hex: "D4728C").opacity(0.4))
                            .textCase(.uppercase)

                        Text(lang.s(quizKey(currentQuestion.question)))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 24)

                    // Cevaplar
                    VStack(spacing: 12) {
                        ForEach(Array(currentQuestion.answers.enumerated()), id: \.offset) { idx, answer in
                            AnswerButton(
                                text: lang.s(quizKey(answer.text)),
                                isSelected: selectedAnswer == idx,
                                action: { selectedAnswer = idx }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 36)
                    .padding(.bottom, 140)
                }
            }

            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) { bottomBar }
    }

    // MARK: - Alt Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Progress
            VStack(spacing: 8) {
                HStack {
                    Text(lang.s(.quizProgress))
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                    Spacer()
                    Text("\(String(format: "%02d", currentIndex + 1)) / \(String(format: "%02d", quizQuestions.count))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.5))
                }
                .padding(.horizontal, 4)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: "D4728C").opacity(0.08))
                            .frame(height: 2)
                        Capsule()
                            .fill(Color(hex: "D4728C").opacity(0.35))
                            .frame(width: geo.size.width * progress, height: 2)
                            .animation(.easeInOut(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 2)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)

            // Butonlar
            HStack {
                // Geri
                Button {
                    goBack()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isFirst ? Color(hex: "D4728C").opacity(0.2) : Color(hex: "D4728C").opacity(0.5))
                        .frame(width: 48, height: 48)
                        .background(Color(hex: "D4728C").opacity(isFirst ? 0.03 : 0.06))
                        .clipShape(Circle())
                }
                .disabled(isFirst)

                Spacer()

                // İleri / Bitir
                Button {
                    goNext()
                } label: {
                    HStack(spacing: 10) {
                        Text(isLast ? lang.s(.quizFinish) : lang.s(.quizNext))
                            .font(.system(size: 14, weight: .bold))
                            .tracking(0.5)
                        Image(systemName: isLast ? "checkmark" : "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .frame(height: 52)
                    .background(
                        selectedAnswer != nil
                            ? Color(hex: "D4728C")
                            : Color(hex: "D4728C").opacity(0.3)
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "D4728C").opacity(selectedAnswer != nil ? 0.25 : 0),
                            radius: 12, x: 0, y: 4)
                }
                .disabled(selectedAnswer == nil)
                .animation(.easeInOut(duration: 0.2), value: selectedAnswer != nil)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(
            Color(hex: "FFF8F7").opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Navigasyon

    private func goNext() {
        guard let selected = selectedAnswer else { return }
        answers[currentQuestion.id] = selected

        if isLast {
            resultSkinType = calculateSkinType(answers: answers)
            showResult = true
        } else {
            currentIndex += 1
            selectedAnswer = answers[quizQuestions[currentIndex].id]
        }
    }

    private func goBack() {
        guard !isFirst else { return }
        answers[currentQuestion.id] = selectedAnswer
        currentIndex -= 1
        selectedAnswer = answers[quizQuestions[currentIndex].id]
    }

    private func resetQuiz() {
        answers = [:]
        selectedAnswer = nil
        currentIndex = 0
        showResult = false
    }

    private func saveAndDismiss() async {
        if let callback = onQuizComplete {
            callback(resultSkinType)
            return
        }
        isSaving = true
        do {
            _ = try await APIClient.shared.updateProfile(skinType: resultSkinType)
            let updated = try await APIClient.shared.getMe()
            await MainActor.run { authViewModel.currentUser = updated }
        } catch {}
        isSaving = false
        dismiss()
    }

    // Quiz key helper
    private func quizKey(_ raw: String) -> L10nKey {
        switch raw {
        case "quiz_q1": return .quizQ1
        case "quiz_q2": return .quizQ2
        case "quiz_q3": return .quizQ3
        case "quiz_q4": return .quizQ4
        case "quiz_q5": return .quizQ5
        case "quiz_q6": return .quizQ6
        case "quiz_q7": return .quizQ7
        case "quiz_q1_a1": return .quizQ1A1
        case "quiz_q1_a2": return .quizQ1A2
        case "quiz_q1_a3": return .quizQ1A3
        case "quiz_q1_a4": return .quizQ1A4
        case "quiz_q2_a1": return .quizQ2A1
        case "quiz_q2_a2": return .quizQ2A2
        case "quiz_q2_a3": return .quizQ2A3
        case "quiz_q2_a4": return .quizQ2A4
        case "quiz_q3_a1": return .quizQ3A1
        case "quiz_q3_a2": return .quizQ3A2
        case "quiz_q3_a3": return .quizQ3A3
        case "quiz_q3_a4": return .quizQ3A4
        case "quiz_q4_a1": return .quizQ4A1
        case "quiz_q4_a2": return .quizQ4A2
        case "quiz_q4_a3": return .quizQ4A3
        case "quiz_q4_a4": return .quizQ4A4
        case "quiz_q5_a1": return .quizQ5A1
        case "quiz_q5_a2": return .quizQ5A2
        case "quiz_q5_a3": return .quizQ5A3
        case "quiz_q5_a4": return .quizQ5A4
        case "quiz_q6_a1": return .quizQ6A1
        case "quiz_q6_a2": return .quizQ6A2
        case "quiz_q6_a3": return .quizQ6A3
        case "quiz_q6_a4": return .quizQ6A4
        case "quiz_q7_a1": return .quizQ7A1
        case "quiz_q7_a2": return .quizQ7A2
        case "quiz_q7_a3": return .quizQ7A3
        case "quiz_q7_a4": return .quizQ7A4
        default: return .appName
        }
    }
}

// MARK: - Answer Button

private struct AnswerButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(text)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "D4728C") : Color(hex: "1A1A2E").opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color(hex: "D4728C") : Color(hex: "D4728C").opacity(0.2))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                isSelected
                    ? Color.white
                    : Color.white.opacity(0.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color(hex: "D4728C").opacity(0.25) : Color(hex: "D4728C").opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? Color(hex: "D4728C").opacity(0.08) : Color.black.opacity(0.01),
                radius: isSelected ? 12 : 4,
                x: 0, y: isSelected ? 4 : 1
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Result View

struct QuizResultView: View {
    let skinType: String
    let isSaving: Bool
    let onSave: () -> Void
    let onRetake: () -> Void
    @EnvironmentObject var lang: LanguageManager

    private var skinTypeIcon: String {
        switch skinType {
        case "Yağlı": return "drop.fill"
        case "Kuru": return "sun.max.fill"
        case "Karma": return "circle.lefthalf.filled"
        case "Hassas": return "leaf.fill"
        case "Akneye Meyilli": return "exclamationmark.circle.fill"
        case "Olgun": return "sparkles"
        default: return "face.smiling"
        }
    }

    private var localizedSkinType: String {
        SkinTypeTranslation.localized(skinType, lang: lang)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // İkon
                ZStack {
                    Circle()
                        .fill(Color(hex: "D4728C").opacity(0.06))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(Color(hex: "D4728C").opacity(0.1))
                        .frame(width: 90, height: 90)
                    Image(systemName: skinTypeIcon)
                        .font(.system(size: 36))
                        .foregroundColor(Color(hex: "D4728C"))
                }

                // Sonuç metni
                VStack(spacing: 12) {
                    Text(lang.s(.quizResultTitle))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(Color(hex: "D4728C").opacity(0.5))
                        .textCase(.uppercase)

                    Text(localizedSkinType)
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(Color(hex: "1A1A2E"))

                    Text(lang.s(.quizResultDesc))
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "6B7280"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            // Butonlar
            VStack(spacing: 12) {
                Button(action: onSave) {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text(lang.s(.quizSave))
                                .font(.system(size: 15, weight: .bold))
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "D4728C"))
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "D4728C").opacity(0.25), radius: 12, x: 0, y: 4)
                }
                .disabled(isSaving)

                Button(action: onRetake) {
                    Text(lang.s(.quizRetake))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.6))
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }
}
