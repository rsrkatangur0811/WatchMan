import SwiftUI

@available(iOS 26.0, *)
struct CurvedTabBarGeometry {
    /// Generates a path for a floating, curved tab bar.
    /// This path is intended to be STROKED to create the tab bar width.
    static func pathForCurvedTabBar(in rect: CGRect) -> Path {
        var path = Path()
        
        // We inset by 32 (half of the 64 stroke width) to ensure the 
        // round caps fit inside the rect horizontally.
        let inset: CGFloat = 43
        
        let availableWidth = rect.width - (inset * 2)
        // Radius is half the available width
        let radius = availableWidth / 2
        
        // Center the arc so the "feet" (endpoints) are at rect.maxY
        // Arc spans 270 degrees: 135 (Bottom Left) -> 45 (Bottom Right) ccw
        // Height of "feet" from center is radius * sin(45 degrees)
        let feetOffset = radius * sin(45 * .pi / 180)
        let center = CGPoint(x: rect.midX, y: rect.maxY - feetOffset)
        
        // Draw 75% Circle Arc (270 degrees)
        // 135 degrees (Bottom Left) to 45 degrees (Bottom Right) clockwise: false (swiping over top)
        path.addArc(center: center, radius: radius, startAngle: .degrees(135), endAngle: .degrees(45), clockwise: false)
        
        return path
    }
}
