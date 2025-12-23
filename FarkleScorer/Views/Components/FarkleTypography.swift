import SwiftUI

/// Typography helpers using rounded design system
extension View {
    /// Large title style for main headings
    func farkleTitle() -> some View {
        self.font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
    }
    
    /// Section heading style
    func farkleSection() -> some View {
        self.font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)
    }
    
    /// Large numeric value (for scores)
    func farkleValueLarge() -> some View {
        self.font(.system(size: 32, weight: .heavy, design: .rounded))
            .foregroundColor(.primary)
            .monospacedDigit()
    }
    
    /// Medium numeric value
    func farkleValueMedium() -> some View {
        self.font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .monospacedDigit()
    }
    
    /// Body text with rounded design
    func farkleBody() -> some View {
        self.font(.system(size: 17, weight: .regular, design: .rounded))
            .foregroundColor(.primary)
    }
    
    /// Caption text
    func farkleCaption() -> some View {
        self.font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(.secondary)
    }
}

