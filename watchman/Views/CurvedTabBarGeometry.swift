import SwiftUI

@available(iOS 26.0, *)
struct CurvedTabBarGeometry {
    /// Generates a path for a floating, curved tab bar.
    /// - Parameter rect: The bounding rectangle for the tab bar.
    /// - Returns: A path describing the shape of the tab bar.
    /// - Parameter extraCurve: Additional height to add to the arch (default 0).
    ///   Use positive values to make the curve sharper/steeper.
    static func pathForCurvedTabBar(in rect: CGRect) -> Path {
        var path = Path()
        
        // We inset by 32 (half of the 64 stroke width) to ensure the 
        // round caps fit inside the rect.
        let inset: CGFloat = 32
        
        // Curve parameters
        // We revert to the Quadratic Curve for stability.
        // We use an offset of 20. 
        // This is higher than original (14) to avoid "flat top",
        // but lower than the spikey version (28) to avoid "arrow head".
        let startPoint = CGPoint(x: rect.minX + inset, y: rect.midY + 12) 
        let endPoint = CGPoint(x: rect.maxX - inset, y: rect.midY + 12)
        let controlPoint = CGPoint(x: rect.midX, y: rect.midY - 20)
        
        path.move(to: startPoint)
        path.addQuadCurve(to: endPoint, control: controlPoint)
        
        return path
    }
}
