import SwiftUI

struct StatusPill: View {
    let status: String

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    var label: String {
        switch status {
        case "to-read": return "To Read"
        case "to-try": return "To Try"
        case "to-share": return "To Share"
        case "done": return "Done"
        default: return status
        }
    }

    var color: Color {
        switch status {
        case "to-read": return .blue
        case "to-try": return .orange
        case "to-share": return .pink
        case "done": return .green
        default: return .secondary
        }
    }
}

extension String {
    /// Color for a status string value
    var statusColor: Color {
        StatusPill(status: self).color
    }
}

/// Domain-specific gradient colors matching the web app's sourceLogos palette
func domainGradient(for domain: String?) -> [Color] {
    let d = domain?.lowercased() ?? ""
    if d.contains("github") { return [Color(hex: "24292e"), Color(hex: "57606a")] }
    if d.contains("reddit") { return [Color(hex: "FF4500"), Color(hex: "FF6534")] }
    if d.contains("youtube") { return [Color(hex: "FF0000"), Color(hex: "CC0000")] }
    if d.contains("medium") { return [Color(hex: "00ab6c"), Color(hex: "028a57")] }
    if d.contains("substack") { return [Color(hex: "FF6719"), Color(hex: "e55b0f")] }
    if d.contains("linkedin") { return [Color(hex: "0A66C2"), Color(hex: "0077B5")] }
    if d.contains("hackernews") || d.contains("ycombinator") { return [Color(hex: "FF6600"), Color(hex: "e55c00")] }
    if d.contains("twitter") || d.contains("x.com") { return [Color(hex: "1DA1F2"), Color(hex: "0d8ddb")] }
    // Deterministic color from domain hash
    let hash = d.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
    let hue = Double(abs(hash) % 360) / 360.0
    return [
        Color(hue: hue, saturation: 0.55, brightness: 0.45),
        Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.5, brightness: 0.38)
    ]
}
