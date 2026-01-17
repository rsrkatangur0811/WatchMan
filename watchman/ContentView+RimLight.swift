
import SwiftUI

// Custom Shape for the Rim Light to handle animation correctly
struct RimLightPill: Shape {
    var trimFrom: CGFloat
    var trimTo: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(trimFrom, trimTo) }
        set {
            trimFrom = newValue.first
            trimTo = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let inset: CGFloat = 43
        let availableWidth = rect.width - (inset * 2)
        let radius = availableWidth / 2
        let feetOffset = radius * sin(45 * .pi / 180)
        let center = CGPoint(x: rect.midX, y: rect.maxY - feetOffset)
        
        // Base angles for 270 degree arc
        let startAngle: Double = 135
        let endAngle: Double = 45 // Note: 135 -> 45 CCW (actually goes 135 -> 90 -> 45? No, 135 -> 90 -> 0 -> -many? Wait)
        // In SwiftUI, 0 is Right (3 o'clock). 90 is Down. 180 is Left. 270 is Up.
        // 135 is Bottom-Left.
        // 45 is Bottom-Right.
        // To go 135 -> 45 "Over Top", we go Counter-Clockwise (Angle decreases? or increases depending on system).
        // SwiftUI default: 0 is Right, positive clockwise.
        // 135 is Down-Right? No 135 is Bottom-Right.
        // Let's stick to the code: clockwise: false.
        // If clockwise is false, we go decreased angle?
        
        // Actually, simpler logic:
        // Use the same addArc logic but computed angles.
        // Total span is 270 degrees.
        // Path direction matters for 'trim'.
        // Standard trim 0.0 is start, 1.0 is end.
        
        // We can just create the FULL path and use .trimmedPath if available.
        // Since iOS 16+, path.trimmedPath(from:to:) is available.
        // Let's try to use that for simplicity and exact match.
        
        path.addArc(center: center, radius: radius, startAngle: .degrees(135), endAngle: .degrees(45), clockwise: false)
        
        // Trim it
        // Note: trimmedPath might return a new path
        let trimmed = path.trimmedPath(from: trimFrom, to: trimTo)
        
        // Outline it
        return trimmed.strokedPath(StrokeStyle(lineWidth: 38, lineCap: .round))
    }
}
