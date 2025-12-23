import SwiftUI

struct ScoringCustomizationView: View {
    @ObservedObject var gameEngine: GameEngine
    @Environment(\.dismiss) private var dismiss

    // MARK: - State Properties
    @State private var single1Points: Int = 100
    @State private var single5Points: Int = 50
    @State private var threePairPoints: Int = 750
    @State private var straightPoints: Int = 1500
    @State private var twoTripletsPoints: Int = 2500
    @State private var three1sPoints: Int = 1000
    @State private var three2sPoints: Int = 200
    @State private var three3sPoints: Int = 300
    @State private var three4sPoints: Int = 400
    @State private var three5sPoints: Int = 500
    @State private var three6sPoints: Int = 600
    
    @State private var showingNumericInput: Bool = false
    @State private var editingTitle: String = ""
    @State private var editingValue: Binding<Int>?
    @State private var editingRange: ClosedRange<Int> = 0...1000

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Custom Scoring")
                            .farkleTitle()

                        Text("Customize point values for different dice combinations")
                            .farkleCaption()
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    // Single Dice Section
                    scoringSection(title: "Single Dice") {
                        scoringRow(title: "Single 1", value: $single1Points, range: 50...500)
                        scoringRow(title: "Single 5", value: $single5Points, range: 25...250)
                    }

                    // Three of a Kind Section
                    scoringSection(title: "Three of a Kind") {
                        scoringRow(title: "Three 1s", value: $three1sPoints, range: 500...2000)
                        scoringRow(title: "Three 2s", value: $three2sPoints, range: 100...1000)
                        scoringRow(title: "Three 3s", value: $three3sPoints, range: 150...1500)
                        scoringRow(title: "Three 4s", value: $three4sPoints, range: 200...2000)
                        scoringRow(title: "Three 5s", value: $three5sPoints, range: 250...2500)
                        scoringRow(title: "Three 6s", value: $three6sPoints, range: 300...3000)
                    }

                    // Special Combinations Section
                    scoringSection(title: "Special Combinations") {
                        scoringRow(title: "Three Pairs", value: $threePairPoints, range: 500...2000)
                        scoringRow(title: "Straight (1-2-3-4-5-6)", value: $straightPoints, range: 1000...3000)
                        scoringRow(title: "Two Triplets", value: $twoTripletsPoints, range: 2000...5000)
                    }

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: saveScoring) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Custom Scoring")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button(action: resetToDefaults) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Reset to Official Rules")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Scoring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingNumericInput) {
            if let binding = editingValue {
                NumericInputSheet(
                    title: editingTitle,
                    currentValue: binding.wrappedValue,
                    range: editingRange,
                    onSave: { newValue in
                        binding.wrappedValue = newValue
                    }
                )
            }
        }
        .onAppear {
            loadSavedScoring()
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func scoringSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        FarkleCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .farkleSection()

                VStack(spacing: 8) {
                    content()
                }
            }
        }
    }

    private func scoringRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .farkleBody()

            Spacer()

            HStack(spacing: 12) {
                Button(action: {
                    if value.wrappedValue > range.lowerBound {
                        let decrement = value.wrappedValue <= 100 ? 25 : (value.wrappedValue <= 500 ? 50 : 100)
                        value.wrappedValue = max(range.lowerBound, value.wrappedValue - decrement)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(value.wrappedValue > range.lowerBound ? .accentColor : .gray)
                        .font(.title2)
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                // Clickable value that opens SwiftUI sheet
                Button(action: {
                    editingTitle = title
                    editingValue = value
                    editingRange = range
                    showingNumericInput = true
                }) {
                    Text("\(value.wrappedValue)")
                        .farkleValueMedium()
                        .frame(minWidth: 60)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                }

                Button(action: {
                    if value.wrappedValue < range.upperBound {
                        let increment = value.wrappedValue < 100 ? 25 : (value.wrappedValue < 500 ? 50 : 100)
                        value.wrappedValue = min(range.upperBound, value.wrappedValue + increment)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(value.wrappedValue < range.upperBound ? .accentColor : .gray)
                        .font(.title2)
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }

    // MARK: - Data Management

    private func loadSavedScoring() {
        single1Points = UserDefaults.standard.object(forKey: "scoring_single1") as? Int ?? 100
        single5Points = UserDefaults.standard.object(forKey: "scoring_single5") as? Int ?? 50
        threePairPoints = UserDefaults.standard.object(forKey: "scoring_threePair") as? Int ?? 750
        straightPoints = UserDefaults.standard.object(forKey: "scoring_straight") as? Int ?? 1500
        twoTripletsPoints = UserDefaults.standard.object(forKey: "scoring_twoTriplets") as? Int ?? 2500
        three1sPoints = UserDefaults.standard.object(forKey: "scoring_three1s") as? Int ?? 1000
        three2sPoints = UserDefaults.standard.object(forKey: "scoring_three2s") as? Int ?? 200
        three3sPoints = UserDefaults.standard.object(forKey: "scoring_three3s") as? Int ?? 300
        three4sPoints = UserDefaults.standard.object(forKey: "scoring_three4s") as? Int ?? 400
        three5sPoints = UserDefaults.standard.object(forKey: "scoring_three5s") as? Int ?? 500
        three6sPoints = UserDefaults.standard.object(forKey: "scoring_three6s") as? Int ?? 600
    }

    private func saveScoring() {
        UserDefaults.standard.set(single1Points, forKey: "scoring_single1")
        UserDefaults.standard.set(single5Points, forKey: "scoring_single5")
        UserDefaults.standard.set(threePairPoints, forKey: "scoring_threePair")
        UserDefaults.standard.set(straightPoints, forKey: "scoring_straight")
        UserDefaults.standard.set(twoTripletsPoints, forKey: "scoring_twoTriplets")
        UserDefaults.standard.set(three1sPoints, forKey: "scoring_three1s")
        UserDefaults.standard.set(three2sPoints, forKey: "scoring_three2s")
        UserDefaults.standard.set(three3sPoints, forKey: "scoring_three3s")
        UserDefaults.standard.set(three4sPoints, forKey: "scoring_three4s")
        UserDefaults.standard.set(three5sPoints, forKey: "scoring_three5s")
        UserDefaults.standard.set(three6sPoints, forKey: "scoring_three6s")

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        dismiss()
    }

    private func resetToDefaults() {
        single1Points = 100
        single5Points = 50
        threePairPoints = 750
        straightPoints = 1500
        twoTripletsPoints = 2500
        three1sPoints = 1000
        three2sPoints = 200
        three3sPoints = 300
        three4sPoints = 400
        three5sPoints = 500
        three6sPoints = 600

        // Clear all saved values
        let keys = ["scoring_single1", "scoring_single5", "scoring_threePair", "scoring_straight",
                   "scoring_twoTriplets", "scoring_three1s", "scoring_three2s", "scoring_three3s",
                   "scoring_three4s", "scoring_three5s", "scoring_three6s"]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
