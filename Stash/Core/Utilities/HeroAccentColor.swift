import SwiftUI
import UIKit
import CoreImage
import Nuke

// MARK: - Color Extraction

/// Utility for extracting and caching dominant accent colors from images.
/// Combines GPU-accelerated color extraction with in-memory caching and SwiftUI environment integration.
enum HeroAccentColor {
    
    // In-memory cache for extracted colors to prevent redundant processing
    private static let cache = NSCache<NSURL, UIColor>()
    
    // Reusable CIContext for GPU rendering (thread-safe, Sendable)
    private nonisolated static let ciContext = CIContext(options: [.workingColorSpace: kCFNull as Any])
    
    /// Extracts the dominant color from an image at the given URL.
    /// Results are cached in memory. CPU-intensive work runs on a background thread.
    ///
    /// - Parameter url: The image URL to extract color from.
    /// - Returns: The dominant `Color`, or nil if extraction fails.
    static func extract(from url: URL) async -> Color? {
        // 1. Check cache first (NSCache is thread-safe)
        if let cached = cache.object(forKey: url as NSURL) {
            return Color(cached)
        }
        
        do {
            // 2. Fetch image using Nuke (likely already in Nuke's cache)
            let image = try await ImagePipeline.shared.image(for: url)
            
            // 3. Extract dominant color in background to avoid blocking main thread
            let color = await Task.detached(priority: .userInitiated) {
                extractDominantColor(from: image)
            }.value
            
            if let color = color {
                // Store in cache as UIColor (since SwiftUI Color doesn't conform to NSObject)
                cache.setObject(UIColor(color), forKey: url as NSURL)
                return color
            }
            return nil
        } catch {
            return nil
        }
    }
    
    /// Extracts the dominant/average color from the center region of an image.
    /// Uses hardware-accelerated CoreImage `CIAreaAverage` filter for performance.
    /// This method is nonisolated to allow background execution.
    ///
    /// - Parameters:
    ///   - image: The source UIImage.
    ///   - centerFraction: The fraction of the image to sample from center (0.0-1.0). Default 0.4 (40%).
    /// - Returns: The dominant color as a `Color`, or nil if extraction fails.
    /// Extracts a vibrant dominant color from the image.
    /// Uses downsampling and saturation-weighted bucketing to favor vibrant colors over muddy averages.
    nonisolated static func extractDominantColor(from image: UIImage) -> Color? {
        guard let inputCGImage = image.cgImage else { return nil }
        
        // 0. Crop to center 50% to focus on clothes/subject instead of background
        let cropRect = CGRect(
            x: Double(inputCGImage.width) * 0.25,
            y: Double(inputCGImage.height) * 0.25,
            width: Double(inputCGImage.width) * 0.5,
            height: Double(inputCGImage.height) * 0.5
        )
        
        guard let croppedCGImage = inputCGImage.cropping(to: cropRect) else { return nil }
        
        // 1. Downsample to a small grid (40x40) for performance
        // This reduces processing from ~12M pixels to ~1.6k pixels, making it extremely fast.
        let width = 40
        let height = 40
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // Raw pixel buffer
        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }
        
        // Draw the image into the small context
        context.draw(croppedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 2. Iterate pixels and bucket them effectively
        // We use a simple grid quantization to cluster similar colors
        var colorBuckets: [Int: (count: Int, red: CGFloat, green: CGFloat, blue: CGFloat, saturation: CGFloat)] = [:]
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = CGFloat(rawData[offset]) / 255.0
                let g = CGFloat(rawData[offset + 1]) / 255.0
                let b = CGFloat(rawData[offset + 2]) / 255.0
                let a = CGFloat(rawData[offset + 3]) / 255.0
                
                if a < 0.1 { continue } // Ignore transparent
                
                // Convert to HSB for filtering
                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                UIColor(red: r, green: g, blue: b, alpha: 1.0).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
                
                // 3. Filter out "muddy" or uninteresting colors
                // Ignore very dark, very bright (white), or very unsaturated (gray) values
                if brightness < 0.15 || brightness > 0.95 || saturation < 0.15 {
                    continue
                }
                
                // Quantize color to create buckets (reduce precision to find clusters)
                // 5-bit precision per channel
                let qR = Int(r * 10)
                let qG = Int(g * 10)
                let qB = Int(b * 10)
                let key = (qR << 16) | (qG << 8) | qB
                
                // Add to bucket
                var bucket = colorBuckets[key] ?? (count: 0, red: 0, green: 0, blue: 0, saturation: 0)
                bucket.count += 1
                bucket.red += r
                bucket.green += g
                bucket.blue += b
                bucket.saturation += saturation
                colorBuckets[key] = bucket
            }
        }
        
        // 4. Find the best bucket
        // We score buckets by (Count * Saturation^2) to heavily favor vibrant clusters
        // even if they are smaller than a giant muddy brown cluster.
        var bestColor: Color? = nil
        var maxScore: CGFloat = -1.0
        
        for (_, bucket) in colorBuckets {
            let avgSaturation = bucket.saturation / CGFloat(bucket.count)
            
            // Score formula: balance popularity with vibrancy
            let score = CGFloat(bucket.count) * (avgSaturation * avgSaturation)
            
            if score > maxScore {
                maxScore = score
                let avgR = bucket.red / CGFloat(bucket.count)
                let avgG = bucket.green / CGFloat(bucket.count)
                let avgB = bucket.blue / CGFloat(bucket.count)
                bestColor = Color(red: avgR, green: avgG, blue: avgB)
            }
        }
        
        // Fallback: If no vibrant colors found (e.g. B&W image), fallback to simple average
        // Re-using the simple average logic just in case, but usually bestColor will be found unless image is purely B/W.
        return bestColor ?? extractAverageFallback(from: rawData, width: width, height: height)
    }
    
    /// Simple fallback that just averages all pixels (used for B&W or low contrast images)
    private nonisolated static func extractAverageFallback(from data: [UInt8], width: Int, height: Int) -> Color? {
        var rSum: CGFloat = 0
        var gSum: CGFloat = 0
        var bSum: CGFloat = 0
        var count: CGFloat = 0
        
        for i in stride(from: 0, to: data.count, by: 4) {
             rSum += CGFloat(data[i]) / 255.0
             gSum += CGFloat(data[i+1]) / 255.0
             bSum += CGFloat(data[i+2]) / 255.0
             count += 1
        }
        
        if count == 0 { return nil }
        return Color(red: rSum / count, green: gSum / count, blue: bSum / count)
    }
}

// MARK: - SwiftUI Environment Integration

private struct HeroAccentColorKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// The accent color extracted from a hero image, if available.
    var heroAccentColor: Color? {
        get { self[HeroAccentColorKey.self] }
        set { self[HeroAccentColorKey.self] = newValue }
    }
}

extension View {
    /// Sets the hero accent color for this view and its children.
    func withHeroAccentColor(_ color: Color?) -> some View {
        environment(\.heroAccentColor, color)
    }
}

// MARK: - View Modifiers

/// A background modifier that uses the hero accent color if available,
/// falling back to a default color.
struct AccentedCardBackground: ViewModifier {
    @Environment(\.heroAccentColor) private var accentColor
    var opacity: Double = 0.6
    var fallbackColor: Color = Color.stashCardBackground
    
    func body(content: Content) -> some View {
        content
            .background(
                (accentColor ?? fallbackColor).opacity(opacity)
            )
    }
}

extension View {
    /// Applies an accented card background that uses the hero accent color if available.
    func accentedCardBackground(opacity: Double = 0.6, fallback: Color = .stashCardBackground) -> some View {
        modifier(AccentedCardBackground(opacity: opacity, fallbackColor: fallback))
    }
}
