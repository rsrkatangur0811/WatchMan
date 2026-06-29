import UIKit

extension UIImage {
  var averageColor: UIColor? {
    guard let inputImage = CIImage(image: self) else { return nil }
    let extentVector = CIVector(
      x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width,
      w: inputImage.extent.size.height)

    guard
      let filter = CIFilter(
        name: "CIAreaAverage",
        parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector])
    else { return nil }
    guard let outputImage = filter.outputImage else { return nil }

    var bitmap = [UInt8](repeating: 0, count: 4)
    let context = CIContext(options: [.workingColorSpace: kCFNull!])
    context.render(
      outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
      format: .RGBA8, colorSpace: nil)

    return UIColor(
      red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255,
      blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
  }

  /// Extracts the dominant bright/saturated color from the image.
  /// Ignores dark and dull pixels to find the "vibrant" color.
  var dominantBrightColor: UIColor? {
    // 1. Resize to small size for performance
    let size = CGSize(width: 40, height: 40)
    UIGraphicsBeginImageContextWithOptions(size, false, 1)
    draw(in: CGRect(origin: .zero, size: size))
    let resized = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    guard let cgImage = resized?.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height

    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8
    var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

    guard
      let context = CGContext(
        data: &rawData,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    else { return nil }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var rSum: CGFloat = 0
    var gSum: CGFloat = 0
    var bSum: CGFloat = 0
    var count: CGFloat = 0

    // 2. Iterate pixels
    for y in 0..<height {
      for x in 0..<width {
        let index = (y * bytesPerRow) + (x * bytesPerPixel)
        let r = CGFloat(rawData[index]) / 255.0
        let g = CGFloat(rawData[index + 1]) / 255.0
        let b = CGFloat(rawData[index + 2]) / 255.0

        // 3. Convert to HSB/HSV
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        UIColor(red: r, green: g, blue: b, alpha: 1.0).getHue(
          &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // 4. Filter for brightness and saturation
        // Minimum saturation: 0.3 (avoid grays)
        // Minimum brightness: 0.3 (avoid blacks)
        if saturation > 0.3 && brightness > 0.3 {
          rSum += r
          gSum += g
          bSum += b
          count += 1
        }
      }
    }

    // 5. Return average of qualified pixels, or fallback to standard average
    if count > 0 {
      return UIColor(red: rSum / count, green: gSum / count, blue: bSum / count, alpha: 1.0)
    } else {
      return averageColor
    }
  }

  /// Extracts multiple vibrant colors from the image, sorted by frequency.
  /// Uses pixel sampling and HSB filtering to find saturated, bright colors.
  func extractVibrantColors(count: Int = 4) -> [UIColor]? {
    // 1. Resize to 50x50 for performance
    let size = CGSize(width: 50, height: 50)
    UIGraphicsBeginImageContextWithOptions(size, false, 1)
    draw(in: CGRect(origin: .zero, size: size))
    let resized = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    guard let cgImage = resized?.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height

    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8
    var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

    guard
      let context = CGContext(
        data: &rawData,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    else { return nil }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // 2. Count colors using quantized buckets (to group similar colors)
    var colorCounts: [[CGFloat]: Int] = [:]

    for y in 0..<height {
      for x in 0..<width {
        let index = (y * bytesPerRow) + (x * bytesPerPixel)
        let r = CGFloat(rawData[index]) / 255.0
        let g = CGFloat(rawData[index + 1]) / 255.0
        let b = CGFloat(rawData[index + 2]) / 255.0

        // Convert to HSB
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        UIColor(red: r, green: g, blue: b, alpha: 1.0).getHue(
          &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Filter for vibrant colors
        if saturation > 0.3 && brightness > 0.4 {
          // Quantize to reduce unique colors (bucket by 10% increments)
          let qR = (r * 10).rounded() / 10
          let qG = (g * 10).rounded() / 10
          let qB = (b * 10).rounded() / 10
          let key = [qR, qG, qB]
          colorCounts[key, default: 0] += 1
        }
      }
    }

    // 3. Sort by frequency and return top colors
    let sortedColors = colorCounts.sorted { $0.value > $1.value }
      .prefix(count)
      .map { UIColor(red: $0.key[0], green: $0.key[1], blue: $0.key[2], alpha: 1.0) }

    return sortedColors.isEmpty ? nil : Array(sortedColors)
  }
}
