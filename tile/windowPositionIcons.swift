import SwiftUI

struct LeftHalfIcon: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.secondary, lineWidth: 1)
            .frame(width: 24, height: 16)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 11, height: 16)
            }
    }
}

struct RightHalfIcon: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.secondary, lineWidth: 1)
            .frame(width: 24, height: 16)
            .overlay(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 11, height: 16)
            }
    }
}

struct TopHalfIcon: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.secondary, lineWidth: 1)
            .frame(width: 24, height: 16)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 24, height: 8)
            }
    }
}

struct BottomHalfIcon: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.secondary, lineWidth: 1)
            .frame(width: 24, height: 16)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 24, height: 8)
            }
    }
}
