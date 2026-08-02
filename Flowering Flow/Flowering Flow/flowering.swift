//
//  flowering.swift
//  Flowering Flow
//
//  Created by Elliot Williams on 2025-07-12.
//

import SwiftUI
import MediaPlayer
import AVFoundation
import CoreImage.CIFilterBuiltins
import Combine
import Accelerate
import MetalKit
import Metal
import os.log
import OSLog

struct MusicVisualizerRing: View {
    @Binding var isPlaying: Bool
    @Binding var isVisible: Bool
    @State private var gradientRotation: Double = 0
    @State private var glowIntensity: CGFloat = 0.0
    @State private var colors: [Color] = []
    @State private var bounceScale: CGFloat = 1.0
    @State private var cornerPulse: [Bool] = [false, false, false, false]
    @State private var edgePulse: [Bool] = [false, false, false, false, false, false, false, false] // 8 edge positions
    @State private var displayLink: CADisplayLink?
    @State private var lastUpdate: Date = Date()
    @State private var colorIndex: Int = 0
    
    // Cached values for performance
    @State private var cachedGradientStart: UnitPoint = UnitPoint(x: 0, y: 0.5)
    @State private var cachedGradientEnd: UnitPoint = UnitPoint(x: 1, y: 0.5)
    
    // Performance optimizations
    @State private var isAnimating = false
    @State private var frameSkipCounter = 0
    private let frameSkipRate = 2 // Skip every 2nd frame for better performance
    
    // Expanded color palette with more vibrant colors
    private let baseColors: [Color] = [
        Color(red: 1.0, green: 0.2, blue: 0.8),    // Hot pink
        Color(red: 0.2, green: 0.8, blue: 1.0),    // Cyan
        Color(red: 0.8, green: 0.2, blue: 1.0),    // Magenta
        Color(red: 0.2, green: 1.0, blue: 0.4),    // Neon green
        Color(red: 1.0, green: 0.6, blue: 0.2),    // Orange
        Color(red: 0.6, green: 0.2, blue: 1.0),    // Purple
        Color(red: 0.2, green: 0.6, blue: 1.0),    // Sky blue
        Color(red: 1.0, green: 0.8, blue: 0.2),    // Yellow
        Color(red: 0.8, green: 1.0, blue: 0.2),    // Lime
        Color(red: 1.0, green: 0.2, blue: 0.4),    // Red-pink
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let borderWidth: CGFloat = 6
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            ZStack {
                // Main border that wraps around entire screen edges
                Rectangle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: colors),
                            startPoint: cachedGradientStart,
                            endPoint: cachedGradientEnd
                        ),
                        lineWidth: borderWidth
                    )
                    .shadow(color: colors.first?.opacity(0.6) ?? .blue, radius: 8 * glowIntensity)
                    .overlay(
                        Rectangle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .white.opacity(0.4 * glowIntensity),
                                        .clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: borderWidth / 2
                            )
                    )
                    .scaleEffect(bounceScale)
                    .animation(.interpolatingSpring(stiffness: 300, damping: 10), value: bounceScale)
                    .animation(.linear(duration: 0.8), value: colors)
                    .frame(width: screenWidth, height: screenHeight)
                
                // Corner effects for all four corners
                if glowIntensity > 0.1 {
                    ForEach(0..<4, id: \.self) { index in
                        if cornerPulse[index] {
                            cornerGlow(at: cornerPosition(index: index, size: CGSize(width: screenWidth, height: screenHeight), radius: 0))
                        }
                    }
                }
                
                // Additional edge effects for better wrapping
                if glowIntensity > 0.1 {
                    ForEach(0..<8, id: \.self) { index in
                        if edgePulse[index] {
                            edgeGlow(at: edgePosition(index: index, size: CGSize(width: screenWidth, height: screenHeight)))
                        }
                    }
                }
            }
            .frame(width: screenWidth, height: screenHeight)
            .clipped()
            .drawingGroup(opaque: false) // Enable GPU acceleration
        }
        .onAppear {
            colors = baseColors
            if isPlaying {
                startAnimations()
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startAnimations()
            } else {
                stopAnimations()
            }
        }
    }
    
    // Helper to get corner positions
    private func cornerPosition(index: Int, size: CGSize, radius: CGFloat) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: radius, y: radius)
        case 1: return CGPoint(x: size.width - radius, y: radius)
        case 2: return CGPoint(x: size.width - radius, y: size.height - radius)
        default: return CGPoint(x: radius, y: size.height - radius)
        }
    }
    
    // Helper to get edge positions (8 positions: 4 edges, each with 2 points)
    private func edgePosition(index: Int, size: CGSize) -> CGPoint {
        let margin: CGFloat = 40
        switch index {
        case 0: return CGPoint(x: size.width * 0.25, y: margin) // Top left
        case 1: return CGPoint(x: size.width * 0.75, y: margin) // Top right
        case 2: return CGPoint(x: size.width - margin, y: size.height * 0.25) // Right top
        case 3: return CGPoint(x: size.width - margin, y: size.height * 0.75) // Right bottom
        case 4: return CGPoint(x: size.width * 0.75, y: size.height - margin) // Bottom right
        case 5: return CGPoint(x: size.width * 0.25, y: size.height - margin) // Bottom left
        case 6: return CGPoint(x: margin, y: size.height * 0.75) // Left bottom
        default: return CGPoint(x: margin, y: size.height * 0.25) // Left top
        }
    }
    
    // Optimized corner glow with reduced effects
    private func cornerGlow(at position: CGPoint) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        colors[colorIndex % colors.count].opacity(0.6),
                        .clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 40
                )
            )
            .frame(width: 80, height: 80)
            .position(position)
            .scaleEffect(1.2)
            .opacity(glowIntensity * 0.8)
            .animation(.easeOut(duration: 0.15), value: glowIntensity)
    }
    
    // Edge glow effects for better screen wrapping
    private func edgeGlow(at position: CGPoint) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        colors[(colorIndex + 1) % colors.count].opacity(0.5),
                        .clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 35
                )
            )
            .frame(width: 70, height: 70)
            .position(position)
            .scaleEffect(1.1)
            .opacity(glowIntensity * 0.7)
            .animation(.easeOut(duration: 0.12), value: glowIntensity)
    }
    
    private func startAnimations() {
        stopAnimations()
        displayLink = CADisplayLink(target: DisplayLinkProxy { updateFrame() }, selector: #selector(DisplayLinkProxy.tick))
        displayLink?.add(to: .main, forMode: .common)
        
        // Glow intensity animation
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
    }
    
    private func stopAnimations() {
        displayLink?.invalidate()
        displayLink = nil
        
        withAnimation(.easeOut(duration: 0.5)) {
            glowIntensity = 0.0
            bounceScale = 1.0
        }
        
        // Reset to base colors
        colors = baseColors
        cornerPulse = [false, false, false, false]
        edgePulse = [false, false, false, false, false, false, false, false]
        colorIndex = 0
        
        // Reset gradient points
        cachedGradientStart = UnitPoint(x: 0, y: 0.5)
        cachedGradientEnd = UnitPoint(x: 1, y: 0.5)
    }
    
    private func updateFrame() {
        let now = Date()
        if now.timeIntervalSince(lastUpdate) > 0.25 {
            lastUpdate = now
            updateColors()
            triggerBounceEffects()
        }
    }
    
    private func updateGradientPoints() {
        // Cycle through different gradient directions
        let angles: [Double] = [0, .pi/4, .pi/2, 3 * .pi/4, .pi, 5 * .pi/4, 3 * .pi/2, 7 * .pi/4]
        let angle = angles[Int(gradientRotation * 4) % angles.count]
        
        cachedGradientStart = UnitPoint(
            x: 0.5 - cos(angle) * 0.5,
            y: 0.5 - sin(angle) * 0.5
        )
        cachedGradientEnd = UnitPoint(
            x: 0.5 + cos(angle) * 0.5,
            y: 0.5 + sin(angle) * 0.5
        )
        
        gradientRotation += 0.1
        if gradientRotation >= 2 {
            gradientRotation = 0
        }
    }
    
    private func updateColors() {
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastUpdate)
        
        // Less frequent color updates for better performance
        if timeDiff > 0.5 {
            lastUpdate = now
            
            // Simplified color cycling
            colorIndex = (colorIndex + 1) % baseColors.count
            
            // Create new color array with rotation
            var newColors = baseColors
            let rotationAmount = Int.random(in: 1...2)
            
            for _ in 0..<rotationAmount {
                if let first = newColors.first {
                    newColors.removeFirst()
                    newColors.append(first)
                }
            }
            
            // Occasionally add variation
            if Double.random(in: 0...1) > 0.8 {
                let randomHue = Double.random(in: 0...1)
                let randomIndex = Int.random(in: 0..<newColors.count)
                newColors[randomIndex] = Color(hue: randomHue, saturation: 0.8, brightness: 1.0)
            }
            
            withAnimation(.easeInOut(duration: 0.8)) {
                colors = newColors
            }
        }
    }
    
    private func triggerBounceEffects() {
        // Reduced bounce frequency for better performance
        if Double.random(in: 0...1) > 0.9 {
            // Main border bounce
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
                bounceScale = 1.015
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
                    bounceScale = 1.0
                }
            }
            
            // Corner pulse with reduced frequency
            if Double.random(in: 0...1) > 0.7 {
                let randomCorner = Int.random(in: 0..<4)
                cornerPulse[randomCorner] = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.cornerPulse[randomCorner] = false
                }
            }
            
            // Edge pulse effects for better wrapping
            if Double.random(in: 0...1) > 0.6 {
                let randomEdge = Int.random(in: 0..<8)
                edgePulse[randomEdge] = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self.edgePulse[randomEdge] = false
                }
            }
        }
    }
}

// Helper class for CADisplayLink selector
final class DisplayLinkProxy {
    let onTick: () -> Void
    init(onTick: @escaping () -> Void) { self.onTick = onTick }
    @objc func tick() { onTick() }
}

// MARK: - Smart Text Component

struct SmartText: View {
    let text: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let maxWidth: CGFloat
    let alignment: Alignment
    
    @State private var textWidth: CGFloat = 0
    @State private var isScrollable = false
    @State private var offset: CGFloat = 0
    @State private var timer: Timer?
    @State private var hasCalculatedWidth = false
    @State private var isViewActive = true
    @State private var isCleanedUp = false
    
    var body: some View {
        ZStack {
            // Measurement view - always measure unbounded width
            Text(text)
                .font(.system(size: fontSize, weight: fontWeight))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            DispatchQueue.main.async {
                                updateTextWidth(geo.size.width)
                            }
                        }
                        .onChange(of: text) { _ in
                            DispatchQueue.main.async {
                                updateTextWidth(geo.size.width)
                            }
                        }
                        .onChange(of: maxWidth) { _ in
                            DispatchQueue.main.async {
                                updateTextWidth(geo.size.width)
                            }
                        }
                })
                .opacity(0)
            
            // Display view - only show after width calculation
            if hasCalculatedWidth {
                if isScrollable {
                    // Scrollable text
                    HStack {
                        Text(text)
                            .font(.system(size: fontSize, weight: fontWeight))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .offset(x: offset)
                            .onAppear {
                                startScrollingIfNeeded()
                            }
                        Spacer(minLength: 0)
                    }
                    .frame(width: maxWidth, alignment: .leading)
                    .clipped()
                } else {
                    // Static text - use specified alignment
                    Text(text)
                        .font(.system(size: fontSize, weight: fontWeight))
                        .lineLimit(1)
                        .frame(width: maxWidth, alignment: alignment)
                }
            }
    }
    .frame(width: maxWidth, height: fontSize * 1.3)
    .onDisappear {
        isViewActive = false
        isCleanedUp = true
        resetTimer()
    }
    .onChange(of: isViewActive) { active in
        if !active {
            resetTimer()
        }
    }
    }
    
    private func updateTextWidth(_ width: CGFloat) {
        textWidth = width
        // Add small buffer to prevent edge cases where text is just barely fitting
        isScrollable = width > (maxWidth - 5)
        hasCalculatedWidth = true
        resetTimer()
        
        if isScrollable {
            startScrollingIfNeeded()
        }
    }
    
    private func startScrollingIfNeeded() {
        guard isScrollable && isViewActive else { return }
        
        // Clear any existing timer first
        resetTimer()
        
        // Wait 3 seconds before starting scroll
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            guard self.isViewActive else { return }
            
            withAnimation(.linear(duration: 5.0)) {
                self.offset = self.maxWidth - self.textWidth
            }
            
            // Reset after scroll completes
            self.timer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { _ in
                guard self.isViewActive else { return }
                
                withAnimation(.easeOut(duration: 0.3)) {
                    self.offset = 0
                }
                
                // Restart cycle after pause
                self.timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                    guard self.isViewActive else { return }
                    self.startScrollingIfNeeded()
                }
            }
        }
    }
    
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        offset = 0
    }
}

// MARK: - Performance Optimizations with Cached Calculations

// Cached geometry calculations for flower spinner
class GeometryCache {
    static let shared = GeometryCache()
    
    private var petalOffsetCache: [String: CGSize] = [:]
    private var angleCache: [String: Double] = [:]
    private var rotationCache: [String: Double] = [:]
    
    private init() {}
    
    func petalOffset(for index: Int, radius: CGFloat, petalsInView: Int) -> CGSize {
        let key = "\(index)_\(radius)_\(petalsInView)"
        if let cached = petalOffsetCache[key] {
            return cached
        }
        
        let anglePerPetal = 360.0 / Double(petalsInView)
        let angle = Double(index) * anglePerPetal * Double.pi / 180
        let x = radius * CGFloat(cos(angle))
        let y = radius * CGFloat(sin(angle))
        let offset = CGSize(width: x, height: y)
        
        petalOffsetCache[key] = offset
        return offset
    }
    
    func anglePerPetal(for petalsInView: Int) -> Double {
        let key = "\(petalsInView)"
        if let cached = angleCache[key] {
            return cached
        }
        
        let angle = 360.0 / Double(petalsInView)
        angleCache[key] = angle
        return angle
    }
    
    func rotationForOffset(_ offset: Double, petalsInView: Int) -> Double {
        let key = "\(offset)_\(petalsInView)"
        if let cached = rotationCache[key] {
            return cached
        }
        
        let anglePerPetal = self.anglePerPetal(for: petalsInView)
        let rotation = offset * anglePerPetal
        rotationCache[key] = rotation
        return rotation
    }
    
    func clearCache() {
        petalOffsetCache.removeAll()
        angleCache.removeAll()
        rotationCache.removeAll()
    }
}

// Efficient color extraction using Accelerate framework
class ColorExtractionOptimizer {
    static let shared = ColorExtractionOptimizer()
    
    private var colorCache: [String: [Color]] = [:]
    private let cacheQueue = DispatchQueue(label: "ColorCacheQueue", qos: .utility)
    
    private init() {}
    
    func extractDominantColors(from image: UIImage, cacheKey: String) -> [Color] {
        // Check cache first
        if let cached = colorCache[cacheKey] {
            return cached
        }
        
        let colors = performColorExtraction(from: image)
        
        // Cache the result
        cacheQueue.async {
            self.colorCache[cacheKey] = colors
        }
        
        return colors
    }
    
    private func performColorExtraction(from image: UIImage) -> [Color] {
        guard let cgImage = image.cgImage else { return [.gray, .black] }
        
        // Optimized size for faster processing
        let processSize = CGSize(width: 32, height: 32)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(processSize.width),
            height: Int(processSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return [.gray, .black]
        }
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: processSize))
        
        guard let data = context.data else { return [.gray, .black] }
        let buffer = data.bindMemory(to: UInt8.self, capacity: Int(processSize.width * processSize.height * 4))
        
        // Use Accelerate framework for efficient color quantization
        var colorCounts: [UInt32: Int] = [:]
        let pixelCount = Int(processSize.width * processSize.height)
        
        for i in 0..<pixelCount {
            let pixelIndex = i * 4
            let r = buffer[pixelIndex]
            let g = buffer[pixelIndex + 1]
            let b = buffer[pixelIndex + 2]
            let a = buffer[pixelIndex + 3]
            
            // Skip transparent pixels
            if a < 128 { continue }
            
            // Quantize colors using bit shifting for performance
            let quantizedR = (r >> 5) << 5
            let quantizedG = (g >> 5) << 5
            let quantizedB = (b >> 5) << 5
            
            let colorKey = (UInt32(quantizedR) << 16) | (UInt32(quantizedG) << 8) | UInt32(quantizedB)
            colorCounts[colorKey] = (colorCounts[colorKey] ?? 0) + 1
        }
        
        // Get most common colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        
        var dominantColors: [Color] = []
        for (colorKey, _) in sortedColors.prefix(4) {
            let r = UInt8((colorKey >> 16) & 0xFF)
            let g = UInt8((colorKey >> 8) & 0xFF)
            let b = UInt8(colorKey & 0xFF)
            
            let color = Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
            dominantColors.append(color)
        }
        
        // Ensure we have at least 2 colors
        while dominantColors.count < 2 {
            dominantColors.append(.gray)
        }
        
        return dominantColors
    }
    
    func clearCache() {
        cacheQueue.async {
            self.colorCache.removeAll()
        }
    }
}

// Efficient rendering manager
class RenderingOptimizer {
    static let shared = RenderingOptimizer()
    
    private var viewCache: [String: AnyView] = [:]
    private var gradientCache: [String: LinearGradient] = [:]
    private let renderQueue = DispatchQueue(label: "RenderQueue", qos: .userInteractive)
    
    private init() {}
    
    func cachedGradient(for colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        let key = "\(colors.map { $0.description }.joined())_\(startPoint)_\(endPoint)"
        
        if let cached = gradientCache[key] {
            return cached
        }
        
        let gradient = LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: startPoint,
            endPoint: endPoint
        )
        
        gradientCache[key] = gradient
        return gradient
    }
    
    func clearCache() {
        viewCache.removeAll()
        gradientCache.removeAll()
    }
}

// Efficient text measurement cache
class TextMeasurementCache {
    static let shared = TextMeasurementCache()
    
    private var sizeCache: [String: CGSize] = [:]
    private let cacheQueue = DispatchQueue(label: "TextMeasurementQueue", qos: .utility)
    
    private init() {}
    
    func measureText(_ text: String, font: UIFont, maxWidth: CGFloat) -> CGSize {
        let key = "\(text)_\(font.fontName)_\(font.pointSize)_\(maxWidth)"
        
        if let cached = sizeCache[key] {
            return cached
        }
        
        let size = text.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).size
        
        cacheQueue.async {
            self.sizeCache[key] = size
        }
        
        return size
    }
    
    func clearCache() {
        cacheQueue.async {
            self.sizeCache.removeAll()
        }
    }
}

// Performance monitoring
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private var frameRateMonitor: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount = 0
    private let frameRateUpdateInterval = 60 // Update every 60 frames
    private let logger = Logger(subsystem: "com.flowering.flow", category: "Performance")
    
    private init() {}
    
    func startMonitoring() {
        frameRateMonitor = CADisplayLink(target: self, selector: #selector(frameUpdate))
        frameRateMonitor?.add(to: .main, forMode: .default)
    }
    
    func stopMonitoring() {
        frameRateMonitor?.invalidate()
        frameRateMonitor = nil
    }
    
    @objc private func frameUpdate(displayLink: CADisplayLink) {
        frameCount += 1
        
        if frameCount % frameRateUpdateInterval == 0 {
            let currentTime = displayLink.timestamp
            let deltaTime = currentTime - lastFrameTime
            let fps = Double(frameRateUpdateInterval) / deltaTime
            
            // Log performance metrics
            logger.debug("FPS: \(fps, privacy: .public)")
            
            // If FPS drops below 45, clear caches to free memory
            if fps < 45 {
                optimizePerformance()
            }
            
            lastFrameTime = currentTime
        }
    }
    
    private func optimizePerformance() {
        logger.info("Performance optimization triggered")
        DispatchQueue.global(qos: .utility).async {
            GeometryCache.shared.clearCache()
            ColorExtractionOptimizer.shared.clearCache()
            RenderingOptimizer.shared.clearCache()
            TextMeasurementCache.shared.clearCache()
            
            // Force garbage collection
            DispatchQueue.main.async {
                ImageCacheManager.shared.clearMemoryCache()
            }
        }
    }
}

// MARK: - Metal-Accelerated Image Processing

@available(iOS 13.0, *)
class MetalImageProcessor {
    static let shared = MetalImageProcessor()
    
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var textureLoader: MTKTextureLoader?
    private var ciContext: CIContext?
    
    private init() {
        setupMetal()
    }
    
    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        
        if let device = device {
            textureLoader = MTKTextureLoader(device: device)
            ciContext = CIContext(mtlDevice: device)
        }
    }
    
    func processImage(_ image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let _ = device,
              let _ = commandQueue,
              let ciContext = ciContext else {
            completion(image)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let ciImage = CIImage(image: image) else {
                completion(image)
                return
            }
            
            // Apply Metal-accelerated filters
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.saturation = 1.2
            filter.contrast = 1.1
            
            guard let outputImage = filter.outputImage,
                  let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
                completion(image)
                return
            }
            
            let processedImage = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                completion(processedImage)
            }
        }
    }
}

// MARK: - Adaptive Quality Manager

class AdaptiveQualityManager {
    static let shared = AdaptiveQualityManager()
    
    private var currentQualityLevel: QualityLevel = .high
    private var performanceMetrics: [Double] = []
    private let maxMetricsCount = 30
    
    enum QualityLevel: Int, CaseIterable {
        case low = 0
        case medium = 1
        case high = 2
        
        var imageSize: CGSize {
            switch self {
            case .low: return CGSize(width: 100, height: 100)
            case .medium: return CGSize(width: 150, height: 150)
            case .high: return CGSize(width: 200, height: 200)
            }
        }
        
        var compressionQuality: CGFloat {
            switch self {
            case .low: return 0.6
            case .medium: return 0.75
            case .high: return 0.85
            }
        }
        
        var animationDuration: TimeInterval {
            switch self {
            case .low: return 0.2
            case .medium: return 0.3
            case .high: return 0.5
            }
        }
    }
    
    private init() {}
    
    func updatePerformanceMetric(_ fps: Double) {
        performanceMetrics.append(fps)
        
        if performanceMetrics.count > maxMetricsCount {
            performanceMetrics.removeFirst()
        }
        
        adjustQualityLevel()
    }
    
    private func adjustQualityLevel() {
        guard performanceMetrics.count >= 10 else { return }
        
        let averageFPS = performanceMetrics.suffix(10).reduce(0, +) / 10.0
        
        if averageFPS < 30 && currentQualityLevel.rawValue > 0 {
            // Reduce quality
            currentQualityLevel = QualityLevel(rawValue: currentQualityLevel.rawValue - 1) ?? .low
        } else if averageFPS > 55 && currentQualityLevel.rawValue < 2 {
            // Increase quality
            currentQualityLevel = QualityLevel(rawValue: currentQualityLevel.rawValue + 1) ?? .high
        }
    }
    
    func getCurrentQuality() -> QualityLevel {
        return currentQualityLevel
    }
}

// MARK: - Predictive Loading Manager

class PredictiveLoadingManager {
    static let shared = PredictiveLoadingManager()
    
    private var userInteractionHistory: [String] = []
    private var predictionCache: [String: Double] = [:]
    private let maxHistorySize = 50
    
    private init() {}
    
    func recordInteraction(albumId: String) {
        userInteractionHistory.append(albumId)
        
        if userInteractionHistory.count > maxHistorySize {
            userInteractionHistory.removeFirst()
        }
        
        updatePredictions()
    }
    
    private func updatePredictions() {
        guard userInteractionHistory.count >= 3 else { return }
        
        let recentInteractions = userInteractionHistory.suffix(10)
        var frequency: [String: Int] = [:]
        
        for albumId in recentInteractions {
            frequency[albumId] = (frequency[albumId] ?? 0) + 1
        }
        
        // Calculate prediction scores
        let totalInteractions = recentInteractions.count
        for (albumId, count) in frequency {
            predictionCache[albumId] = Double(count) / Double(totalInteractions)
        }
    }
    
    func getPredictedAlbums() -> [String] {
        return predictionCache.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }
}

// MARK: - GPU-Accelerated Gradient Cache

class GPUGradientCache {
    static let shared = GPUGradientCache()
    
    private var gradientTextures: [String: MTLTexture] = [:]
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    
    private init() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
    }
    
    func getCachedGradient(for colors: [Color], size: CGSize) -> LinearGradient? {
        let key = "\(colors.map { $0.description }.joined())_\(size.width)x\(size.height)"
        
        if gradientTextures[key] != nil {
            // Return cached gradient
            return LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        // Generate and cache new gradient
        generateGradientTexture(for: colors, size: size, key: key)
        
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func generateGradientTexture(for colors: [Color], size: CGSize, key: String) {
        guard let device = device,
              let _ = commandQueue else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Create texture descriptor
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: Int(size.width),
                height: Int(size.height),
                mipmapped: false
            )
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return }
            
            // Store texture
            DispatchQueue.main.async {
                self.gradientTextures[key] = texture
            }
        }
    }
    
    func clearCache() {
        gradientTextures.removeAll()
    }
}

// MARK: - Lazy Loading Container

struct LazyLoadingContainer<Content: View>: View {
    let content: () -> Content
    @State private var isLoaded = false
    @State private var isVisible = false
    
    var body: some View {
        Group {
            if isLoaded {
                content()
            } else {
                Color.clear
                    .onAppear {
                        if isVisible {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isLoaded = true
                            }
                        }
                    }
            }
        }
        .onAppear {
            isVisible = true
            if !isLoaded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isLoaded = true
                    }
                }
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}

// MARK: - ViewBuilder Performance Optimizer

struct PerformantViewBuilder {
    static func buildView<T: View>(@ViewBuilder content: @escaping () -> T) -> some View {
        return LazyLoadingContainer {
            content()
        }
    }
}

// MARK: - Animation Performance Manager

class AnimationPerformanceManager {
    static let shared = AnimationPerformanceManager()
    
    private var activeAnimations: Set<String> = []
    private let maxConcurrentAnimations = 3
    
    private init() {}
    
    func requestAnimation(id: String, priority: TaskPriority = .userInitiated) -> Bool {
        if activeAnimations.count >= maxConcurrentAnimations {
            return false
        }
        
        activeAnimations.insert(id)
        return true
    }
    
    func completeAnimation(id: String) {
        activeAnimations.remove(id)
    }
    
    func getOptimizedAnimation(duration: TimeInterval) -> Animation {
        let qualityLevel = AdaptiveQualityManager.shared.getCurrentQuality()
        let optimizedDuration = duration * qualityLevel.animationDuration / 0.5
        
        return .easeInOut(duration: optimizedDuration)
    }
}

// MARK: - Memory Pool Manager

// Custom hashable wrapper for CGSize to support iOS versions before 18.0
struct CGSizeWrapper: Hashable {
    let size: CGSize
    
    init(_ size: CGSize) {
        self.size = size
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(size.width)
        hasher.combine(size.height)
    }
    
    static func == (lhs: CGSizeWrapper, rhs: CGSizeWrapper) -> Bool {
        return lhs.size.width == rhs.size.width && lhs.size.height == rhs.size.height
    }
}

class MemoryPoolManager {
    static let shared = MemoryPoolManager()
    
    private var imagePool: [CGSizeWrapper: [UIImage]] = [:]
    private var colorArrayPool: [[Color]] = []
    private let maxPoolSize = 20
    
    private init() {}
    
    func borrowImage(size: CGSize) -> UIImage? {
        let sizeWrapper = CGSizeWrapper(size)
        guard var pool = imagePool[sizeWrapper], !pool.isEmpty else { return nil }
        
        let image = pool.removeLast()
        imagePool[sizeWrapper] = pool
        return image
    }
    
    func returnImage(_ image: UIImage) {
        let sizeWrapper = CGSizeWrapper(image.size)
        var pool = imagePool[sizeWrapper] ?? []
        
        if pool.count < maxPoolSize {
            pool.append(image)
            imagePool[sizeWrapper] = pool
        }
    }
    
    func borrowColorArray() -> [Color]? {
        guard !colorArrayPool.isEmpty else { return nil }
        return colorArrayPool.removeLast()
    }
    
    func returnColorArray(_ colors: [Color]) {
        if colorArrayPool.count < maxPoolSize {
            colorArrayPool.append(colors)
        }
    }
    
    func clearPools() {
        imagePool.removeAll()
        colorArrayPool.removeAll()
    }
}

// MARK: - Advanced Image Cache Manager

class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let maxMemoryCacheSize: Int = 50 * 1024 * 1024 // Reduced to 50MB
    private let maxDiskCacheSize: Int = 200 * 1024 * 1024 // Reduced to 200MB
    private let cacheQueue = DispatchQueue(label: "ImageCacheQueue", qos: .utility)
    
    // Batch write optimization
    private var pendingWrites: [String: UIImage] = [:]
    private var batchWriteTimer: Timer?
    private let batchWriteInterval: TimeInterval = 2.0 // Batch writes every 2 seconds
    
    private init() {
        // Setup disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("FloweringFlowImageCache")
        
        // Create cache directory if it doesn't exist
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 100 // Max 100 images in memory
        
        // Clean up old cache on init
        Task {
            await cleanupOldCache()
        }
        
        // Start batch write timer
        startBatchWriteTimer()
        
        // Set up memory pressure monitoring
        setupMemoryPressureMonitoring()
    }
    
    private func startBatchWriteTimer() {
        batchWriteTimer = Timer.scheduledTimer(withTimeInterval: batchWriteInterval, repeats: true) { [weak self] _ in
            self?.performBatchWrites()
        }
    }
    
    private func performBatchWrites() {
        cacheQueue.async {
            for (albumId, image) in self.pendingWrites {
                let diskURL = self.diskCacheURL.appendingPathComponent("\(albumId).jpg")
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    try? imageData.write(to: diskURL)
                }
            }
            self.pendingWrites.removeAll()
        }
    }
    
    func getImage(for albumId: String) -> UIImage? {
        let key = NSString(string: albumId)
        
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: key) {
            return cachedImage
        }
        
        // Check disk cache
        let diskURL = diskCacheURL.appendingPathComponent("\(albumId).jpg")
        if let diskImage = UIImage(contentsOfFile: diskURL.path) {
            // Store back in memory cache
            let cost = Int(diskImage.size.width * diskImage.size.height * 4) // Approximate memory cost
            memoryCache.setObject(diskImage, forKey: key, cost: cost)
            return diskImage
        }
        
        return nil
    }
    
    func setImage(_ image: UIImage, for albumId: String) {
        let key = NSString(string: albumId)
        let cost = Int(image.size.width * image.size.height * 4)
        
        // Store in memory cache
        memoryCache.setObject(image, forKey: key, cost: cost)
        
        // Queue up for batch write to disk
        DispatchQueue.main.async {
            self.pendingWrites[albumId] = image
        }
    }
    
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    private func cleanupOldCache() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // Clean up old disk cache files (older than 7 days)
                let fileManager = FileManager.default
                let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
                
                if let files = try? fileManager.contentsOfDirectory(at: self.diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey]) {
                    for file in files {
                        if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                           let modificationDate = attributes[.modificationDate] as? Date,
                           modificationDate < cutoffDate {
                            try? fileManager.removeItem(at: file)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryPressureMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryPressure()
        }
    }
    
    private func handleMemoryPressure() {
        // Reduce cache limits during memory pressure
        memoryCache.countLimit = 30 // Reduce to 30 images
        memoryCache.totalCostLimit = 25 * 1024 * 1024 // Reduce to 25MB
        
        // Force evict some items
        memoryCache.removeAllObjects()
        
        // Restore normal limits after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.restoreNormalLimits()
        }
    }
    
    private func restoreNormalLimits() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = maxMemoryCacheSize
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Model

struct MusicAlbum: Identifiable {
    let id: String
    let title: String
    let artist: String
    private var _artwork: UIImage?
    var colors: [Color] = []
    let songs: [MPMediaItem]
    
    // Lazy loading properties with optimized caching
    var artwork: UIImage? {
        get {
            if let cachedArtwork = _artwork {
                return cachedArtwork
            }
            return ImageCacheManager.shared.getImage(for: id)
        }
        set {
            _artwork = newValue
            if let artwork = newValue {
                ImageCacheManager.shared.setImage(artwork, for: id)
            }
        }
    }
    
    var hasLoadedArtwork: Bool { artwork != nil }
    var hasLoadedColors: Bool { colors.count > 2 || (colors.count == 2 && colors != [.gray, .black]) }
    
    // Optimized initializer
    init(id: String, title: String, artist: String, artwork: UIImage? = nil, colors: [Color] = [.gray, .black], songs: [MPMediaItem]) {
        self.id = id
        self.title = title
        self.artist = artist
        self._artwork = artwork
        self.colors = colors
        self.songs = songs
    }
}

// MARK: - Audio Player Manager

class AudioPlayerManager: ObservableObject {
    @Published var pulseIntensity: Double = 0.0
    @Published var isPlaying = false
    @Published var currentTrack: MPMediaItem?
    @Published var playbackProgress: Double = 0.0
    @Published var currentTrackIndex = 0
    var currentAlbumId: String = ""
    
    // Use MPMusicPlayerController for proper music library playback
    private let musicPlayer = MPMusicPlayerController.applicationQueuePlayer
    private var progressTimer: Timer?
    
    private var timer: Timer?
    
    func startVisualizer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Simulate audio levels with random values
            self.pulseIntensity = Double.random(in: 0.5...1.0)
        }
    }

    func stopVisualizer() {
        timer?.invalidate()
        timer = nil
        pulseIntensity = 0.0
    }
    
    init() {
        setupMusicPlayerObservers()
    }
    
    deinit {
        cleanup()
    }
    
    private func cleanup() {
        // Stop visualizer timer first
        stopVisualizer()
        
        // Stop music player notifications
        musicPlayer.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
        
        // Clean up progress timer
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func setupMusicPlayerObservers() {
        musicPlayer.beginGeneratingPlaybackNotifications()
        
        // Playback state observer
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = self?.musicPlayer.playbackState == .playing
        }
        
        // Now playing item observer
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.currentTrack = self?.musicPlayer.nowPlayingItem
            self?.updateCurrentTrackInfo()
        }
        
        // Start progress timer
        startProgressTimer()
    }
    
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let currentItem = self.musicPlayer.nowPlayingItem else { return }
            
            let currentTime = self.musicPlayer.currentPlaybackTime
            let duration = currentItem.playbackDuration
            
            if duration > 0 {
                self.playbackProgress = currentTime / duration
            }
        }
    }
    
    private func updateCurrentTrackInfo() {
        // This can be implemented to update album context if needed
        // For now, just update the current track
        currentTrack = musicPlayer.nowPlayingItem
    }
    
    func playTrack(_ track: MPMediaItem) {
        let collection = MPMediaItemCollection(items: [track])
        let descriptor = MPMusicPlayerMediaItemQueueDescriptor(itemCollection: collection)
        
        musicPlayer.setQueue(with: descriptor)
        musicPlayer.nowPlayingItem = track
        musicPlayer.play()
        
        currentTrack = track
        isPlaying = true
        playbackProgress = 0.0
        
        print("Playing track: \(track.title ?? "Unknown") by \(track.artist ?? "Unknown")")
    }
    
    func playAlbum(_ songs: [MPMediaItem], startingAt index: Int = 0) {
        guard !songs.isEmpty, index >= 0, index < songs.count else { return }
        
        let collection = MPMediaItemCollection(items: songs)
        let descriptor = MPMusicPlayerMediaItemQueueDescriptor(itemCollection: collection)
        
        musicPlayer.setQueue(with: descriptor)
        musicPlayer.nowPlayingItem = songs[index]
        musicPlayer.play()
        
        currentTrack = songs[index]
        currentTrackIndex = index
        isPlaying = true
        playbackProgress = 0.0
        
        print("Playing album starting with: \(songs[index].title ?? "Unknown")")
    }
    
    func pause() {
        musicPlayer.pause()
        isPlaying = false
    }
    
    func resume() {
        musicPlayer.play()
        isPlaying = true
    }
    
    func stop() {
        musicPlayer.stop()
        currentTrack = nil
        isPlaying = false
        playbackProgress = 0.0
        currentTrackIndex = 0
    }
    
    func skipToNext() {
        musicPlayer.skipToNextItem()
    }
    
    func skipToPrevious() {
        musicPlayer.skipToPreviousItem()
    }
    
    func seekTo(progress: Double) {
        guard let currentItem = musicPlayer.nowPlayingItem else { return }
        
        let duration = currentItem.playbackDuration
        let targetTime = duration * progress
        
        musicPlayer.currentPlaybackTime = targetTime
        playbackProgress = progress
    }
}

// MARK: - ViewModel

@MainActor
class MusicViewModel: ObservableObject {
    @Published var albums: [MusicAlbum] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showPermissionAlert = false
    
    private var colorCache: [String: [Color]] = [:]
    private let imageCache = ImageCacheManager.shared
    private let artworkLoadingQueue = DispatchQueue(label: "ArtworkLoading", qos: .userInitiated, attributes: .concurrent)
    var loadingTasks: [String: Task<Void, Never>] = [:]
    private var failedArtworkLoads: Set<String> = []
    private var artworkLoadAttempts: [String: Int] = [:]
    
    // Concurrency management
    private let maxConcurrentTasks = 5
    private var activeTasks: Set<String> = []
    private let taskQueue = DispatchQueue(label: "TaskQueue", qos: .userInitiated)
    private let taskSemaphore = DispatchSemaphore(value: 5)
    
    func fetchAlbums() async {
        guard !isLoading else { return }
        isLoading = true
        
        // Request authorization for local music library
        await requestAuthorization()
    }
    
    private func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus)
            }
        }
        
        await MainActor.run {
            switch status {
            case .authorized:
                Task {
                    await self.loadAlbums()
                }
            case .denied, .restricted:
                self.error = NSError(domain: "Music", code: 403, userInfo: [
                    NSLocalizedDescriptionKey: "Music library access denied. Please enable access in Settings."
                ])
                self.showPermissionAlert = true
                self.isLoading = false
            case .notDetermined:
                self.error = NSError(domain: "Music", code: 401, userInfo: [
                    NSLocalizedDescriptionKey: "Music library access not determined."
                ])
                self.isLoading = false
            @unknown default:
                self.error = NSError(domain: "Music", code: 401, userInfo: [
                    NSLocalizedDescriptionKey: "Unknown authorization status."
                ])
                self.isLoading = false
            }
        }
    }
    
    private func loadAlbums() async {
        let query = MPMediaQuery.albums()
        let collections = query.collections ?? []
        
        // Quick initial load without artwork or colors
        let albums = collections.compactMap { collection -> MusicAlbum? in
            guard let representativeItem = collection.representativeItem else { return nil }
            
            let albumId = String(representativeItem.albumPersistentID)
            let title = representativeItem.albumTitle ?? "Unknown Album"
            let artist = representativeItem.albumArtist ?? "Unknown Artist"
            
            return MusicAlbum(
                id: albumId,
                title: title,
                artist: artist,
                artwork: nil, // Load artwork lazily
                colors: [.gray, .black], // Default colors
                songs: collection.items
            )
        }
        
        // Update UI immediately with basic album info
        await MainActor.run {
            self.albums = albums.sorted { $0.title < $1.title }
            self.isLoading = false
            
            // Handle empty library case
            if self.albums.isEmpty {
                self.error = NSError(domain: "Music", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "No albums found in your music library."
                ])
            }
        }
    }
    
    private func loadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
        }
        return image
    }
    
    func loadArtworkAndColors(for albumId: String, priority: TaskPriority = .userInitiated, retryCount: Int = 0, forceReload: Bool = false) async -> (UIImage?, [Color]) {
        // Cancel any existing loading task for this album
        loadingTasks[albumId]?.cancel()
        
        // Check if we already have cached data and not forcing reload
        if !forceReload, let cachedArtwork = imageCache.getImage(for: albumId),
           let cachedColors = colorCache[albumId] {
            return (cachedArtwork, cachedColors)
        }
        
        // Skip if this album has failed too many times, unless forcing reload
        if !forceReload, failedArtworkLoads.contains(albumId) {
            return (nil, [.gray, .black])
        }
        
        // Concurrency control: Check if we're already at the limit
        await withCheckedContinuation { continuation in
            taskQueue.async {
                self.taskSemaphore.wait()
                continuation.resume()
            }
        }
        
        // Track active tasks
        _ = await MainActor.run {
            self.activeTasks.insert(albumId)
        }
        
        // Track loading attempts
        artworkLoadAttempts[albumId] = (artworkLoadAttempts[albumId] ?? 0) + 1
        
        // Create a new loading task with retry mechanism
        let task = Task(priority: priority) { [weak self] in
            guard let self = self else {
                self?.taskSemaphore.signal()
                return (nil as UIImage?, [Color.gray, Color.black])
            }
            
            defer {
                // Release semaphore and cleanup when task completes
                self.taskSemaphore.signal()
                Task { @MainActor in
                    self.activeTasks.remove(albumId)
                }
            }
            let maxRetries = 3
            var currentRetry = retryCount
            
            while currentRetry < maxRetries {
                await withTaskGroup(of: Bool.self) { group in
                    group.addTask {
                        // Load artwork on background thread
                        let query = MPMediaQuery.albums()
                        guard let collection = query.collections?.first(where: {
                            String($0.representativeItem?.albumPersistentID ?? 0) == albumId
                        }),
                              let representativeItem = collection.representativeItem else {
                            print("[Error] Could not find collection for album ID: \(albumId)")
                            return false
                        }
                        
                        // Use single optimal size for performance
                        let optimalSize = CGSize(width: 200, height: 200)
                        let artwork = representativeItem.artwork?.image(at: optimalSize)
                        
                        if let artwork = artwork {
                            // Cache the artwork
                            await MainActor.run {
                                self.imageCache.setImage(artwork, for: albumId)
                            }
                            
                            // Extract colors on background thread
                            let colors = await self.extractColorsSync(from: artwork)
                            
                            await MainActor.run {
                                self.colorCache[albumId] = colors
                            }
                            
                            print("Successfully loaded artwork for album: \(representativeItem.albumTitle ?? "Unknown")")
                            return true
                        } else {
                            let attempts = await MainActor.run { self.artworkLoadAttempts[albumId] ?? 0 }
                            print("[Error] No artwork available for album: \(representativeItem.albumTitle ?? "Unknown") (Attempt \(attempts))")
                            return false
                        }
                    }
                }
                
                // Check if successful
                if imageCache.getImage(for: albumId) != nil {
                    break
                }
                
                currentRetry += 1
                if currentRetry < maxRetries {
                    print("[Retry] Artwork load for album ID \(albumId), attempt \(currentRetry + 1)")
                    // Brief delay before retry
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                } else {
                    // Mark as failed after all retries
                    _ = await MainActor.run {
                        self.failedArtworkLoads.insert(albumId)
                    }
                    print("[Failed] Artwork load for album ID \(albumId) after \(maxRetries) attempts")
                }
            }
            
            // Return the final result
            return (self.imageCache.getImage(for: albumId), self.colorCache[albumId] ?? [Color.gray, Color.black])
        }
        
        loadingTasks[albumId] = Task {
            _ = await task.value
        }
        let result = await task.value
        loadingTasks.removeValue(forKey: albumId)
        
        return result
    }
    
    func forceReloadArtwork(for albumId: String) async -> (UIImage?, [Color]) {
        // Remove from failed set and reset attempts
        failedArtworkLoads.remove(albumId)
        artworkLoadAttempts[albumId] = 0
        
        // Clear cached data
        imageCache.clearMemoryCache()
        colorCache.removeValue(forKey: albumId)
        
        // Force reload
        return await loadArtworkAndColors(for: albumId, priority: .high, forceReload: true)
    }
    
    private func extractColors(from image: UIImage?) async -> [Color] {
        return await extractColorsSync(from: image)
    }
    
    private func extractColorsSync(from image: UIImage?) async -> [Color] {
        guard let image = image else { return [.gray, .black] }
        let cacheKey = "\(image.size.width)x\(image.size.height)\(image.hashValue)"
        if let cached = colorCache[cacheKey] {
            return cached
        }
        
        let extracted = extractDominantColors(from: image)
        colorCache[cacheKey] = extracted
        return extracted
    }
    
    private func extractDominantColors(from image: UIImage) -> [Color] {
        let cacheKey = "\(image.size.width)x\(image.size.height)\(image.hashValue)"
        return ColorExtractionOptimizer.shared.extractDominantColors(from: image, cacheKey: cacheKey)
    }
}

// Integrate Search Functionality
extension String {
    func fuzzyMatch(_ query: String) -> Bool {
        let normalizedSelf = self.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if normalizedSelf == normalizedQuery {
            return true
        }
        if normalizedSelf.contains(normalizedQuery) {
            return true
        }
        var queryIndex = normalizedQuery.startIndex
        for char in normalizedSelf {
            if queryIndex < normalizedQuery.endIndex && char == normalizedQuery[queryIndex] {
                queryIndex = normalizedQuery.index(after: queryIndex)
            }
        }
        let missingChars = normalizedQuery.distance(from: queryIndex, to: normalizedQuery.endIndex)
        if missingChars <= 2 && normalizedQuery.count <= 5 {
            return true
        }
        return queryIndex == normalizedQuery.endIndex
    }
}

// MARK: - Search History Manager
class SearchHistoryManager: ObservableObject {
    static let shared = SearchHistoryManager()
    
    @Published private(set) var searchHistory: [String] = []
    private let maxHistoryItems = 20
    private let userDefaults = UserDefaults.standard
    private let historyKey = "searchHistory"
    
    init() {
        loadSearchHistory()
    }
    
    func addSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // Remove if already exists
        searchHistory.removeAll { $0.lowercased() == trimmedQuery.lowercased() }
        
        // Add to beginning
        searchHistory.insert(trimmedQuery, at: 0)
        
        // Limit to max items
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }
        
        saveSearchHistory()
    }
    
    func removeSearch(_ query: String) {
        searchHistory.removeAll { $0 == query }
        saveSearchHistory()
    }
    
    func clearHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    private func loadSearchHistory() {
        searchHistory = userDefaults.stringArray(forKey: historyKey) ?? []
    }
    
    private func saveSearchHistory() {
        userDefaults.set(searchHistory, forKey: historyKey)
    }
}

// MARK: - Search Cache
class SearchCache {
    static let shared = SearchCache()
    
    private var cache = [String: SearchResults]()
    private let maxCacheSize = 50
    
    class SearchResults {
        let albums: [MusicAlbum]
        let songs: [MPMediaItem]
        let playlists: [MPMediaPlaylist]
        
        init(albums: [MusicAlbum], songs: [MPMediaItem], playlists: [MPMediaPlaylist]) {
            self.albums = albums
            self.songs = songs
            self.playlists = playlists
        }
    }
    
    func get(for query: String) -> SearchResults? {
        return cache[query.lowercased()]
    }
    
    func set(_ results: SearchResults, for query: String) {
        let key = query.lowercased()
        
        // Manage cache size
        if cache.count >= maxCacheSize {
            // Remove oldest entry
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
            }
        }
        
        cache[key] = results
    }
    
    func clear() {
        cache.removeAll()
    }
}

enum SearchCategory: String, CaseIterable {
    case albums = "Albums"
    case songs = "Songs"
    case playlists = "Playlists"
}

// MARK: - Search View
struct SearchView: View {
    @Binding var isPresented: Bool
    let albums: [MusicAlbum]
    let onAlbumSelected: (MusicAlbum) -> Void
    
    @State private var searchText = ""
    @State private var searchResults: [MusicAlbum] = []
    @State private var songResults: [MPMediaItem] = []
    @State private var playlistResults: [MPMediaPlaylist] = []
    @State private var showSearchHistory = false
    @State private var searchCategory: SearchCategory = .albums
    @State private var isSearchInProgress = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchDebounceTimer: Timer?
    
    @StateObject private var searchHistoryManager = SearchHistoryManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search your music...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                performSearch(for: searchText)
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                clearSearchResults()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                
                // Category picker
                if !searchText.isEmpty {
                    Picker("Search Category", selection: $searchCategory) {
                        ForEach(SearchCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
                // Search history or results
                if searchText.isEmpty {
                    searchHistoryView
                } else {
                    searchResultsView
                }
            }
            .background(Color.gray.opacity(0.7))
            .navigationBarHidden(true)
        }
        .onChange(of: searchText) { newValue in
            searchTask?.cancel()
            searchDebounceTimer?.invalidate()
            
            if newValue.isEmpty {
                clearSearchResults()
            } else {
                isSearchInProgress = true
                searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    performSearch(for: newValue)
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
            searchDebounceTimer?.invalidate()
        }
    }
    
    private var searchHistoryView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !searchHistoryManager.searchHistory.isEmpty {
                HStack {
                    Text("Recent Searches")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        searchHistoryManager.clearHistory()
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchHistoryManager.searchHistory, id: \.self) { historyItem in
                            HStack {
                                Button(action: {
                                    searchText = historyItem
                                    performSearch(for: historyItem)
                                }) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(.gray)
                                        
                                        Text(historyItem)
                                            .foregroundColor(.primary)
                                            .font(.body)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    withAnimation {
                                        searchHistoryManager.removeSearch(historyItem)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .padding(.trailing)
                            }
                            
                            if historyItem != searchHistoryManager.searchHistory.last {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Search your music library")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding(.top)
                    Spacer()
                }
            }
        }
    }
    
    private var searchResultsView: some View {
        Group {
            if isSearchInProgress {
                VStack {
                    ProgressView()
                    Text("Searching...")
                        .foregroundColor(.gray)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch searchCategory {
                case .albums:
                    albumResultsView
                case .songs:
                    songResultsView
                case .playlists:
                    playlistResultsView
                }
            }
        }
    }
    
    private var albumResultsView: some View {
        Group {
            if searchResults.isEmpty {
                VStack {
                    Spacer()
                    Text("No albums found for \"\(searchText)\"")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                List(searchResults) { album in
                    Button(action: {
                        searchHistoryManager.addSearch(searchText)
                        onAlbumSelected(album)
                        isPresented = false
                    }) {
                        HStack {
                            if let artwork = album.artwork {
                                Image(uiImage: artwork)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(album.artist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("\(album.songs.count) songs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var songResultsView: some View {
        Group {
            if songResults.isEmpty {
                VStack {
                    Spacer()
                    Text("No songs found for \"\(searchText)\"")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                List(songResults, id: \.persistentID) { song in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title ?? "Unknown")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(song.artist ?? "Unknown Artist")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(song.albumTitle ?? "Unknown Album")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(formatDuration(song.playbackDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var playlistResultsView: some View {
        Group {
            if playlistResults.isEmpty {
                VStack {
                    Spacer()
                    Text("No playlists found for \"\(searchText)\"")
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                List(playlistResults, id: \.persistentID) { playlist in
                    HStack {
                        Image(systemName: "music.note.list")
                            .foregroundColor(.blue)
                            .frame(width: 50, height: 50)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name ?? "Unknown Playlist")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(playlist.count) songs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func performSearch(for query: String) {
        guard !query.isEmpty else { return }
        
        searchTask = Task {
            // Check cache first
            if let cachedResults = SearchCache.shared.get(for: query) {
                await MainActor.run {
                    searchResults = cachedResults.albums
                    songResults = cachedResults.songs
                    playlistResults = cachedResults.playlists
                    isSearchInProgress = false
                }
                return
            }
            
            // Search albums
            let albumResults = albums.filter { album in
                album.title.fuzzyMatch(query) || album.artist.fuzzyMatch(query)
            }
            
            // Search songs
            let allSongs = albums.flatMap { $0.songs }
            let songSearchResults = allSongs.filter { song in
                (song.title?.fuzzyMatch(query) ?? false) ||
                (song.artist?.fuzzyMatch(query) ?? false) ||
                (song.albumTitle?.fuzzyMatch(query) ?? false)
            }
            
            // Search playlists
            let playlistQuery = MPMediaQuery.playlists()
            let playlistSearchResults = playlistQuery.collections?.compactMap { $0 as? MPMediaPlaylist }.filter { playlist in
                playlist.name?.fuzzyMatch(query) ?? false
            } ?? []
            
            let results = SearchCache.SearchResults(
                albums: albumResults,
                songs: Array(songSearchResults.prefix(100)), // Limit to 100 songs
                playlists: playlistSearchResults
            )
            
            // Cache results
            SearchCache.shared.set(results, for: query)
            
            await MainActor.run {
                searchResults = results.albums
                songResults = results.songs
                playlistResults = results.playlists
                isSearchInProgress = false
            }
        }
    }
    
    private func clearSearchResults() {
        searchResults = []
        songResults = []
        playlistResults = []
        isSearchInProgress = false
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Main View

struct MusicPalettePlayer: View {
    @AppStorage("showVisualizer") private var showVisualizer = false
    @StateObject private var viewModel = MusicViewModel()
    @State private var selectedAlbum: MusicAlbum?
    @State private var focusedPetal: Int? = nil
    
    // Music player controls state
    @State private var isPlaying = false
    @State private var playbackProgress: CGFloat = 0.4
    @State private var isShuffle = false
    @State private var isRepeat = false
    @State private var currentlyPlayingAlbum: MusicAlbum?
    @State private var currentTrackIndex = 0
    
    // Track listing card state
    @State private var showTrackListing = false
    @State private var trackListingAlbum: MusicAlbum?
    
    // Shimmer state
    @State private var shimmeringAlbums: Set<String> = []
    
    // Audio player
    @StateObject private var audioPlayer = AudioPlayerManager()
    
    // Visualizer state
    @State private var isVisualizerVisible = true
    
    // App Lifecycle State
    @State private var isAppActive = true
    @State private var isAppInBackground = false
    
    // Keep UI state in sync with player
    private func syncPlayerState() {
        isPlaying = audioPlayer.isPlaying
        playbackProgress = CGFloat(audioPlayer.playbackProgress)
    }
    
    // Music control functions
    private func playSelectedAlbum() {
        guard let album = selectedAlbum else { return }
        
        currentlyPlayingAlbum = album
        currentTrackIndex = 0
        isPlaying = true
        playbackProgress = 0.0
        
        // Play the album starting from the first track
        audioPlayer.playAlbum(album.songs, startingAt: 0)
        
        // Add haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func togglePlayPause() {
        if isPlaying {
            audioPlayer.pause()
            isPlaying = false
            audioPlayer.stopVisualizer()
        } else {
            if currentlyPlayingAlbum?.id == selectedAlbum?.id {
                // Resume current track
                audioPlayer.resume()
                isPlaying = true
                audioPlayer.startVisualizer()
            } else {
                // Play selected album
                playSelectedAlbum()
                audioPlayer.startVisualizer()
            }
        }
        
        // Add haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func skipToNext() {
        guard let album = currentlyPlayingAlbum else {
            playSelectedAlbum()
            return
        }
        
        if isShuffle {
            // Random next track
            currentTrackIndex = Int.random(in: 0..<album.songs.count)
        } else {
            // Sequential next track
            currentTrackIndex += 1
            if currentTrackIndex >= album.songs.count {
                if isRepeat {
                    currentTrackIndex = 0
                } else {
                    isPlaying = false
                    return
                }
            }
        }
        
        let nextSong = album.songs[currentTrackIndex]
        audioPlayer.playTrack(nextSong)
        playbackProgress = 0.0
        
        // Add haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func skipToPrevious() {
        guard let album = currentlyPlayingAlbum else {
            playSelectedAlbum()
            return
        }
        
        if isShuffle {
            // Random previous track
            currentTrackIndex = Int.random(in: 0..<album.songs.count)
        } else {
            // Sequential previous track
            currentTrackIndex -= 1
            if currentTrackIndex < 0 {
                if isRepeat {
                    currentTrackIndex = album.songs.count - 1
                } else {
                    currentTrackIndex = 0
                }
            }
        }
        
        let prevSong = album.songs[currentTrackIndex]
        audioPlayer.playTrack(prevSong)
        playbackProgress = 0.0
        
        // Add haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func toggleShuffle() {
        isShuffle.toggle()
        // Add haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func toggleRepeat() {
        isRepeat.toggle()
        // Add haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // Function to play a specific track from an album
    private func playTrack(_ track: MPMediaItem, fromAlbum album: MusicAlbum) {
        currentlyPlayingAlbum = album
        if let trackIndex = album.songs.firstIndex(of: track) {
            currentTrackIndex = trackIndex
        }
        
        audioPlayer.playTrack(track)
        isPlaying = true
        playbackProgress = 0.0
        
        // Close track listing
        showTrackListing = false
        
        // Add haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    // Function to show track listing for an album
    private func showTrackListingFor(_ album: MusicAlbum) {
        trackListingAlbum = album
        showTrackListing = true
        
        // Add haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func loadArtworkForAlbum(_ album: MusicAlbum, priority: TaskPriority = .userInitiated) async {
        // Skip if already loaded to avoid redundant work
        guard !album.hasLoadedArtwork || !album.hasLoadedColors else { return }
        
        // Start shimmer effect for this album
        _ = await MainActor.run {
            shimmeringAlbums.insert(album.id)
        }
        
        // Load artwork and colors with specified priority
        let (artwork, colors) = await viewModel.loadArtworkAndColors(for: album.id, priority: priority, forceReload: false)
        
        // Update the album in the array with the loaded artwork
        if let index = viewModel.albums.firstIndex(where: { $0.id == album.id }) {
            // Create updated album with persistent artwork
            let updatedAlbum = MusicAlbum(
                id: album.id,
                title: album.title,
                artist: album.artist,
                artwork: artwork ?? album.artwork, // Keep existing artwork if new one fails
                colors: colors.isEmpty ? album.colors : colors,
                songs: album.songs
            )
            
            // Update in main array
            await MainActor.run {
                viewModel.albums[index] = updatedAlbum
                
                // Update selected album if it's the same one
                if selectedAlbum?.id == album.id {
                    selectedAlbum = updatedAlbum
                }
                
                // Update track listing album if it's the same one
                if trackListingAlbum?.id == album.id {
                    trackListingAlbum = updatedAlbum
                }
                
                // Stop shimmer effect after a brief delay
                Task {
                    try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                    shimmeringAlbums.remove(album.id)
                }
            }
        }
    }
    
    // MARK: - App Lifecycle Setup
    private func setupAppLifecycleObservers() {
        // App will resign active
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            isAppActive = false
        }
        
        // App entered background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            isAppInBackground = true
            handleAppBackgrounded()
        }
        
        // App will enter foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            isAppInBackground = false
            handleAppWillEnterForeground()
        }
        
        // App became active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            isAppActive = true
            handleAppResumed()
        }
    }
    
    private func removeAppLifecycleObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    // MARK: - App Lifecycle Handlers
    private func handleAppBackgrounded() {
        // Perform cleanup operations safely on main thread
            
            // Stop visualizer animations to save battery
            self.audioPlayer.stopVisualizer()
            
            // Reset shimmer state to prevent animation crashes
            self.shimmeringAlbums.removeAll()
            
            // Cancel any ongoing loading tasks safely
            for task in self.viewModel.loadingTasks.values {
                task.cancel()
            }
            self.viewModel.loadingTasks.removeAll()
        
        // Background operations that are safe to run off main thread
        DispatchQueue.global(qos: .utility).async {
            // Clear some caches to free memory
            ImageCacheManager.shared.clearMemoryCache()
            
            // Clear memory pools to save resources
            MemoryPoolManager.shared.clearPools()
            
            // Trim any caches
            GeometryCache.shared.clearCache()
            ColorExtractionOptimizer.shared.clearCache()
        }
    }
    
    private func handleAppWillEnterForeground() {
        // Prepare for app resume
        isAppInBackground = false
        
        // Clear any stale state
        shimmeringAlbums.removeAll()
        
        // Reset focus state
        focusedPetal = nil
    }
    
    private func handleAppResumed() {
        // App is now active and in foreground
        isAppActive = true
        
        // Restart visualizer if music is playing
        if isPlaying {
            audioPlayer.startVisualizer()
        }
        
        // Update player state
        syncPlayerState()
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                if viewModel.albums.isEmpty {
                if viewModel.isLoading {
                    ProgressView("Loading albums…")
                        .padding()
                } else if let error = viewModel.error {
                    VStack {
                        Text("Error loading music")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.subheadline)
                        Button("Try Again") {
                            Task {
                                await viewModel.fetchAlbums()
                            }
                        }
                        .padding(.top, 8)
                        
                        if viewModel.showPermissionAlert {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                } else {
                    Text("No albums found.")
                        .padding()
                }
            } else {
                FlowerSpinnerView(
                    albums: viewModel.albums,
                    selectedAlbum: $selectedAlbum,
                    focusedPetal: $focusedPetal,
                    shimmeringAlbums: $shimmeringAlbums,
                    loadArtworkForAlbum: loadArtworkForAlbum,
                    showTrackListingFor: showTrackListingFor
                )
                .frame(height: 400)
                .padding(.vertical)
                
                if focusedPetal == nil, let album = selectedAlbum {
                    AlbumDetailView(album: album)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut(duration: 0.3), value: selectedAlbum?.id)
                }
            }
            Spacer()
            
            // Current playing song display
            if let currentAlbum = currentlyPlayingAlbum,
               currentTrackIndex < currentAlbum.songs.count {
                let currentSong = currentAlbum.songs[currentTrackIndex]
                CurrentTrackView(
                    track: currentSong,
                    album: currentAlbum,
                    isPlaying: isPlaying
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            
            ControlPanel(
                isPlaying: $isPlaying,
                playbackProgress: $playbackProgress,
                isShuffle: $isShuffle,
                isRepeat: $isRepeat,
                isVisualizerVisible: $isVisualizerVisible,
                skipToNext: skipToNext,
                skipToPrevious: skipToPrevious,
                toggleShuffle: toggleShuffle,
                toggleRepeat: toggleRepeat,
                togglePlayPause: togglePlayPause
            )
            .padding(.bottom, 40)
            }
        }
        .task {
            await viewModel.fetchAlbums()
            if let first = viewModel.albums.first {
                selectedAlbum = first
                // Load artwork and colors for the first album with high priority
                await loadArtworkForAlbum(first, priority: .high)
            }
        }
        .onReceive(audioPlayer.$isPlaying) { newValue in
            isPlaying = newValue
        }
        .onReceive(audioPlayer.$playbackProgress) { newValue in
            playbackProgress = CGFloat(newValue)
        }
        .onAppear {
            setupAppLifecycleObservers()
        }
        .onDisappear {
            removeAppLifecycleObservers()
        }
        .overlay(
            // Track listing card overlay
            Group {
                if showTrackListing, let album = trackListingAlbum {
                    TrackListingCard(
                        album: album,
                        playTrack: playTrack,
                        onDismiss: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showTrackListing = false
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.1).combined(with: .opacity),
                        removal: .scale(scale: 0.1).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showTrackListing)
                    .zIndex(100)
                }
            }
        )
        .background(
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: selectedAlbum?.colors ?? [.purple, .black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: selectedAlbum?.colors)
                
                // Visualizer ring overlay - above background, below content
                if showVisualizer {
                    visualizerRing
                }
            }
        )
    }
    
    private var visualizerRing: some View {
        MusicVisualizerRing(isPlaying: $audioPlayer.isPlaying, isVisible: $isVisualizerVisible)
            .opacity(isVisualizerVisible && audioPlayer.isPlaying ? 1 : 0)
            .animation(.easeInOut(duration: 0.5), value: isVisualizerVisible && audioPlayer.isPlaying)
            .allowsHitTesting(false)
            .drawingGroup(opaque: false) // Enable GPU acceleration with transparency support
            .compositingGroup() // Optimize rendering performance
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
    }
}

// MARK: - Flower Spinner

struct FlowerSpinnerView: View {
    let albums: [MusicAlbum]
    let radius: CGFloat = 140
    let petalSize: CGFloat = 90  // Increased size for bigger artwork
    let petalsInView = 30  // Number of petals visible at once to match original
    
    @Binding var selectedAlbum: MusicAlbum?
    @Binding var focusedPetal: Int?
    @Binding var shimmeringAlbums: Set<String>
    let loadArtworkForAlbum: (MusicAlbum, TaskPriority) async -> Void
    let showTrackListingFor: (MusicAlbum) -> Void
    
    @State private var currentOffset: Double = 0  // Current position in the album array
    @State private var dragVelocity: Double = 0
    @State private var lastDragValue: CGFloat = 0
    @State private var isDragging = false
    @State private var displayRotation: Double = 0
    // Focus is now external (@Binding)
    // @State private var focusedPetal: Int? = nil  // Remove local (duplicate)
    
    @State private var glowPulse = false
    @State private var shimmerPhase: CGFloat = 0
    @State private var tappedPetal: Int? = nil  // Track which petal was just tapped

    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    @State private var inertiaTask: Task<Void, Never>? = nil
    
    // Search state
    @State private var isSearchViewPresented = false
    
    // Throttling state for drag updates
    @State private var lastUpdateTime: Date = Date()
    private let updateThrottleInterval: TimeInterval = 0.016 // ~60 FPS
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background glow - simpler like original
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.purple.opacity(0.15),
                                Color.black.opacity(0.7)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: radius + petalSize * 1.8
                        )
                    )
                    .frame(width: (radius + petalSize * 2) * 2, height: (radius + petalSize * 2) * 2)
                    .shadow(color: Color.purple.opacity(0.3), radius: 30, x: 0, y: 20)
                    .blur(radius: 8)
                    .offset(y: 15)
                
                ZStack {
                    // Render visible petals based on current offset
                    ForEach(visiblePetalIndices, id: \.self) { virtualIndex in
                        let albumIndex = (Int(currentOffset) + virtualIndex) % albums.count
                        let album = albums[albumIndex]
                        let petalPosition = virtualIndex
                        
                        petalView(for: album, isFocused: focusedPetal == petalPosition, isTapped: tappedPetal == petalPosition)
                            .frame(width: petalSize, height: petalSize)
                            .offset(petalOffset(at: petalPosition))
                            .rotationEffect(.degrees(displayRotation))
                            .scaleEffect(focusedPetal == petalPosition ? 1.5 : (selectedAlbum?.id == album.id ? 1.25 : 1))
                            .shadow(
                                color: neonGlowColor(for: album).opacity(selectedAlbum?.id == album.id ? 0.8 : 0.3),
                                radius: selectedAlbum?.id == album.id ? 15 : 8,
                                x: 0,
                                y: selectedAlbum?.id == album.id ? 10 : 5
                            )
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentOffset)
                            .highPriorityGesture(
                                TapGesture()
                                    .onEnded {
                                        if focusedPetal == petalPosition {
                                            // Tap again to unfocus if already focused
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                focusedPetal = nil
                                            }
                                        } else {
                                            hapticImpact.impactOccurred()
                                            // Update selection immediately for responsive background
                                            selectedAlbum = album
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                focusedPetal = petalPosition
                                                snapToPosition(petalPosition)
                                            }
                                            Task {
                                                await loadArtworkForAlbum(album, .high)
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { _ in
                                        if focusedPetal == petalPosition {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                focusedPetal = nil
                                            }
                                        }
                                    }
                            )
                            .onAppear {
                                if selectedAlbum?.id == album.id {
                                    glowPulse = true
                                }
                                // Load artwork with priority based on selection
                                Task {
                                    let priority: TaskPriority = selectedAlbum?.id == album.id ? .high : .userInitiated
                                    await loadArtworkForAlbum(album, priority)
                                }
                            }
                            .onDisappear {
                                glowPulse = false
                            }
                            .onTapGesture {
                                hapticImpact.impactOccurred()
                                // Update selection immediately for responsive background
                                selectedAlbum = album
                                // Focus this petal (shows expanded info)
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    focusedPetal = petalPosition
                                    snapToPosition(petalPosition)
                                }
                                // Update album colors as soon as tapped
                                Task {
                                    await loadArtworkForAlbum(album, .high)
                                }
                            }
                            .onLongPressGesture {
                                hapticImpact.impactOccurred()
                                
                                // Show track listing card on long press
                                showTrackListingFor(album)
                            }
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            inertiaTask?.cancel()
                            isDragging = true
                            let dragDelta = value.translation.width - lastDragValue
                            lastDragValue = value.translation.width
                            
                            // Throttle updates to reduce UI overhead
                            let now = Date()
                            if now.timeIntervalSince(lastUpdateTime) >= updateThrottleInterval {
                                lastUpdateTime = now
                                
                                // Improved drag sensitivity - more responsive to drag distance
                                let sensitivity: Double = 0.015  // Increased sensitivity
                                let deltaOffset = -Double(dragDelta) * sensitivity
                                currentOffset = fmod(currentOffset + deltaOffset + Double(albums.count), Double(albums.count))
                                
                                // Calculate velocity for inertia with better scaling
                                let velocityScale: Double = 0.008
                                dragVelocity = -Double(value.predictedEndTranslation.width - value.translation.width) * velocityScale
                                
                                updateDisplayRotation()
                                updateSelectedAlbum()
                            }
                        }
                        .onEnded { _ in
                            lastDragValue = 0
                            isDragging = false
                            startInertia()
                        }
                )
                
                // Search icon at the center - moved outside of ForEach
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.black)
                    )
                    .onTapGesture {
                        isSearchViewPresented = true
                    }
                    .sheet(isPresented: $isSearchViewPresented) {
                        SearchView(
                            isPresented: $isSearchViewPresented,
                            albums: albums,
                            onAlbumSelected: { album in
                                // Update selection and focus
                                selectedAlbum = album
                                if let albumIndex = albums.firstIndex(where: { $0.id == album.id }) {
                                    // Update the flower spinner position to show the selected album
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                        currentOffset = Double(albumIndex)
                                        updateDisplayRotation()
                                        updateSelectedAlbum()
                                    }
                                }
                                // Load artwork for the selected album
                                Task {
                                    await loadArtworkForAlbum(album, .high)
                                }
                            }
                        )
                    }
                
                // Background tap gesture to unfocus
                if focusedPetal != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                focusedPetal = nil
                            }
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                currentOffset = 0
                displayRotation = 0
                updateSelectedAlbum()
                startContinuousRotation()
                
                // Initialize shimmer phase but don't start continuous animation
                shimmerPhase = 0.0
                
                // Preload artwork for initial visible petals with staggered loading
                Task {
                    await withTaskGroup(of: Void.self) { group in
                        for (priority, i) in visiblePetalIndices.enumerated() {
                            let albumIndex = i % albums.count
                            let album = albums[albumIndex]
                            
                            group.addTask {
                                // Load center petals first, then outer ones
                                let taskPriority: TaskPriority = priority < 3 ? .userInitiated : .background
                                await loadArtworkForAlbum(album, taskPriority)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 2 * (radius + petalSize))
    }
    
    // Computed properties for the circular arrangement
    var visiblePetalIndices: Range<Int> {
        return 0..<petalsInView
    }
    
    var anglePerPetal: Double {
        360.0 / Double(petalsInView)
    }
    
    func petalOffset(at index: Int) -> CGSize {
        return GeometryCache.shared.petalOffset(for: index, radius: radius, petalsInView: petalsInView)
    }
    
    func isSelectedPetal(_ petalIndex: Int) -> Bool {
        // The "selected" petal is always the top one (index 0)
        return petalIndex == 0
    }
    
    func neonGlowColor(for album: MusicAlbum) -> Color {
        if selectedAlbum?.id == album.id {
            // Use the album's primary color for glow if available
            return album.hasLoadedColors && album.colors.count > 1 ? album.colors[1] : Color.purple
        } else {
            return album.hasLoadedColors && !album.colors.isEmpty ? album.colors[0].opacity(0.5) : selectedAlbum?.colors.first?.opacity(0.5) ?? Color.purple.opacity(0.5)
        }
    }
    
    func updateDisplayRotation() {
        // Smooth rotation animation based on current position
        let rotationPerAlbum = anglePerPetal
        displayRotation = currentOffset * rotationPerAlbum
    }
    
    func updateSelectedAlbum() {
        guard !albums.isEmpty else { return }
        let selectedIndex = Int(currentOffset.rounded()) % albums.count
        let selectedAlbumCandidate = albums[selectedIndex]
        
        if selectedAlbum?.id != selectedAlbumCandidate.id {
            selectedAlbum = selectedAlbumCandidate
            hapticImpact.impactOccurred()
            
            // Load artwork for the new selection and surrounding albums with proper prioritization
            Task {
                // Load selected album with high priority
                await loadArtworkForAlbum(selectedAlbumCandidate, .high)
                
                // Preload artwork for visible albums with lower priority
                await withTaskGroup(of: Void.self) { group in
                    for i in visiblePetalIndices {
                        let preloadIndex = (Int(currentOffset) + i) % albums.count
                        let preloadAlbum = albums[preloadIndex]
                        
                        group.addTask {
                            await loadArtworkForAlbum(preloadAlbum, .background)
                        }
                    }
                }
            }
        }
    }
    
    func startContinuousRotation() {
        // Only gentle idle rotation when not interacting
        inertiaTask?.cancel()
        inertiaTask = Task {
            while !Task.isCancelled {
                if !isDragging && abs(dragVelocity) < 0.01 {
                    // Very slow idle rotation - slightly slower for more elegant feel
                    currentOffset = fmod(currentOffset + 0.001, Double(albums.count))
                    updateDisplayRotation()
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000 / 60)
            }
        }
    }
    
    func startInertia() {
        inertiaTask?.cancel()
        inertiaTask = Task {
            var velocity = dragVelocity
            while abs(velocity) > 0.001 && !Task.isCancelled {
                currentOffset = fmod(currentOffset + velocity + Double(albums.count), Double(albums.count))
                updateDisplayRotation()
                updateSelectedAlbum()
                velocity *= 0.92  // Slightly less deceleration for more natural feel
                try? await Task.sleep(nanoseconds: 1_000_000_000 / 60)
            }
            
            // Snap to nearest album
            await MainActor.run {
                snapToNearestAlbum()
            }
            startContinuousRotation()
        }
    }
    
    func snapToNearestAlbum() {
        let targetOffset = currentOffset.rounded()
        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
            currentOffset = targetOffset
            updateDisplayRotation()
            updateSelectedAlbum()
        }
    }
    
    func snapToPosition(_ position: Int) {
        let targetOffset = Double(Int(currentOffset) + position)
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.7)) {
            currentOffset = fmod(targetOffset, Double(albums.count))
            updateDisplayRotation()
            updateSelectedAlbum()
        }
    }
    
    @ViewBuilder
    func petalView(for album: MusicAlbum, isFocused: Bool = false, isTapped: Bool = false) -> some View {
        ZStack {
            // Focus overlay for expanded detail view
            if isFocused {
                VStack(spacing: 8) {
                    // Enlarged album artwork - square with rounded corners
                    if let artwork = album.artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: petalSize * 1.3, height: petalSize * 1.3)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 3)
                            )
                    }
                    
                    // Album details
                    VStack(spacing: 4) {
                        Text(album.title)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        Text(album.artist)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        
                        Text("\(album.songs.count) songs")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.7))
                            .blur(radius: 2)
                    )
                }
                .frame(width: petalSize * 1.8, height: petalSize * 2.2)
                .zIndex(1)
            } else {
                // Show normal petal view only when not focused
                ZStack {
                    // Square album artwork with rounded corners
                    if let artwork = album.artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: petalSize * 0.85, height: petalSize * 0.85)  // Bigger size
                            .clipShape(RoundedRectangle(cornerRadius: 8))  // Square with rounded corners
                            .shadow(color: neonGlowColor(for: album).opacity(0.8), radius: 8, x: 0, y: 0)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: petalSize * 0.85, height: petalSize * 0.85)  // Bigger size
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.7))
                            )
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                }
                .overlay(
                    // Only show shimmer effect when this album is loading
                    Group {
                        if shimmeringAlbums.contains(album.id) {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0),
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .rotationEffect(.degrees(30))
                                .offset(x: shimmerPhase * petalSize * 2 - petalSize)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onAppear {
                                    // Start shimmer animation when album starts loading
                                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                        shimmerPhase = 1.0
                                    }
                                }
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Album Detail View

struct AlbumDetailView: View {
    let album: MusicAlbum
    
    var body: some View {
        VStack(spacing: 8) {
            Text(album.title)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
                .shadow(radius: 2)
                .multilineTextAlignment(.center)
            
            Text(album.artist)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .shadow(radius: 1)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.25))
                .blur(radius: 10)
        )
    }
}

// MARK: - Track Listing Card

struct TrackListingCard: View {
    let album: MusicAlbum
    let playTrack: (MPMediaItem, MusicAlbum) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with album info and close button
                HStack {
                    // Album artwork
                    if let artwork = album.artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Text(album.artist)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                        
                        Text("\(album.songs.count) tracks")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: album.hasLoadedColors && album.colors.count > 1 ? [album.colors[0], album.colors[1]] : [.gray, .black]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                
                // Track list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(album.songs.enumerated()), id: \.element.persistentID) { index, track in
                            TrackRow(
                                track: track,
                                trackNumber: index + 1,
                                onTap: {
                                    playTrack(track, album)
                                }
                            )
                            
                            if index < album.songs.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .background(Color.black.opacity(0.8))
            }
            .frame(width: min(geometry.size.width * 0.85, 350), height: min(geometry.size.height * 0.7, 500))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .background(
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
        )
    }
}

struct TrackRow: View {
    let track: MPMediaItem
    let trackNumber: Int
    let onTap: () -> Void
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Track number
                Text("\(trackNumber)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24, alignment: .trailing)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title ?? "Unknown Track")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let artist = track.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Duration
                Text(formatDuration(track.playbackDuration))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Color.white.opacity(0.05)
                .opacity(0) // Start transparent
        )
        .onHover { isHovered in
            // Add hover effect if needed
        }
    }
}

// MARK: - Current Track View

struct CurrentTrackView: View {
    let track: MPMediaItem
    let album: MusicAlbum
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork
            if let artwork = album.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown Track")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.artist ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Playing indicator
            if isPlaying {
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: 3, height: 12)
                            .scaleEffect(y: 0.3)
                            .animation(
                                Animation.easeInOut(duration: 0.4)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.1),
                                value: isPlaying
                            )
                            .scaleEffect(y: isPlaying ? 1.0 : 0.3)
                    }
                }
                .frame(width: 15, height: 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .blur(radius: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Controls

struct ControlPanel: View {
    @Binding var isPlaying: Bool
    @Binding var playbackProgress: CGFloat
    @Binding var isShuffle: Bool
    @Binding var isRepeat: Bool
    @Binding var isVisualizerVisible: Bool
    var skipToNext: () -> Void
    var skipToPrevious: () -> Void
    var toggleShuffle: () -> Void
    var toggleRepeat: () -> Void
    var togglePlayPause: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .foregroundColor(.white.opacity(0.2))
                    
                    Capsule()
                        .foregroundColor(.white)
                        .frame(width: geometry.size.width * playbackProgress)
                        .shadow(color: .white.opacity(0.8), radius: 3)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 30)
            
            HStack(spacing: 18) {
                Button(action: toggleShuffle) {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .foregroundColor(isShuffle ? .blue : .white)
                        .frame(width: 32, height: 32)
                }
                
                Button(action: skipToPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .frame(width: 40, height: 40)
                }
                
                Button(action: togglePlayPause) {
                    ZStack {
                        Circle()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.black)
                    }
                }
                
                Button(action: skipToNext) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .frame(width: 40, height: 40)
                }
                
                Button(action: toggleRepeat) {
                    Image(systemName: "repeat")
                        .font(.title3)
                        .foregroundColor(isRepeat ? .green : .white)
                        .frame(width: 32, height: 32)
                }
            }
            .foregroundColor(.white)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal, 40)
    }
}

// MARK: - Preview

struct MusicPalettePlayer_Previews: PreviewProvider {
    static var previews: some View {
        MusicPalettePlayer()
    }
}

@main
struct Flowering_FlowApp: App {
    var body: some Scene {
        WindowGroup {
            MusicPalettePlayer()
        }
    }
}
