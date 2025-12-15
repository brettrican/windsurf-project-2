//
//  LiDARScanningService.swift
//  InteriorAI
//
//  Service for LiDAR scanning operations with ARKit integration
//

import Foundation
import ARKit
import AVFoundation
import Combine
import simd

/// Scanning state
public enum ScanningState {
    case idle
    case preparing
    case scanning
    case processing
    case completed
    case failed(LiDARError)
}

/// Scan quality metrics
public struct ScanQualityMetrics {
    public let averageConfidence: Float
    public let pointCount: Int
    public let coverageArea: Float // in square meters
    public let scanDuration: TimeInterval
    public let qualityScore: Float // 0.0 to 1.0

    public var isHighQuality: Bool {
        return qualityScore >= ARConstants.confidenceThreshold && pointCount >= 10000
    }
}

/// Scan progress information
public struct ScanProgress {
    public let state: ScanningState
    public let progress: Float // 0.0 to 1.0
    public let currentPoints: Int
    public let estimatedTimeRemaining: TimeInterval?
    public let qualityMetrics: ScanQualityMetrics?

    public init(state: ScanningState,
                progress: Float = 0.0,
                currentPoints: Int = 0,
                estimatedTimeRemaining: TimeInterval? = nil,
                qualityMetrics: ScanQualityMetrics? = nil) {
        self.state = state
        self.progress = progress
        self.currentPoints = currentPoints
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.qualityMetrics = qualityMetrics
    }
}

/// LiDAR scanning service with ARKit integration
public final class LiDARScanningService: NSObject {
    // MARK: - Singleton
    public static let shared = LiDARScanningService()

    // MARK: - Properties
    private var arSession: ARSession?
    private var configuration: ARWorldTrackingConfiguration?

    private let processingQueue = DispatchQueue(label: "com.interiorai.lidar.processing", qos: .userInitiated)
    private let sessionQueue = DispatchQueue(label: "com.interiorai.lidar.session", qos: .userInitiated)

    // Scanning state
    private var currentScanId: UUID?
    private var scanStartTime: Date?
    private var accumulatedFrames: [ARFrame] = []
    private var pointCloudBuilder = PointCloudBuilder()

    // Publishers
    public let scanProgress = PassthroughSubject<ScanProgress, Never>()
    public let scanCompleted = PassthroughSubject<Result<PointCloud, LiDARError>, Never>()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private override init() {
        super.init()
        setupARKit()
    }

    deinit {
        cleanup()
    }

    // MARK: - Public Interface

    /// Checks if LiDAR scanning is supported on this device
    public func isLiDARSupported() -> Bool {
        guard let deviceModel = getDeviceModel() else { return false }
        return ARConstants.minimumLiDARDevices.contains(deviceModel)
    }

    /// Checks if camera access is authorized
    public func isCameraAuthorized() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .authorized
    }

    /// Requests camera access permission
    public func requestCameraAccess() async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if !granted {
            throw LiDARError.cameraAccessDenied
        }
    }

    /// Starts a new LiDAR scan
    /// - Parameter scanId: Optional scan identifier
    /// - Throws: LiDARError if scanning cannot be started
    public func startScan(scanId: UUID? = nil) throws {
        Logger.shared.lidar("Starting LiDAR scan")

        // Validate device support
        guard isLiDARSupported() else {
            throw LiDARError.deviceNotSupported(getDeviceModel() ?? "Unknown")
        }

        // Validate camera access
        guard isCameraAuthorized() else {
            throw LiDARError.cameraAccessDenied
        }

        // Check if already scanning
        guard currentScanId == nil else {
            throw LiDARError.scanInitializationFailed("Scan already in progress")
        }

        // Initialize scan
        currentScanId = scanId ?? UUID()
        scanStartTime = Date()
        accumulatedFrames.removeAll()
        pointCloudBuilder.reset()

        // Update progress
        let progress = ScanProgress(state: .preparing, progress: 0.0)
        scanProgress.send(progress)

        // Start AR session
        sessionQueue.async { [weak self] in
            self?.startARSession()
        }
    }

    /// Stops the current scan
    /// - Throws: LiDARError if stopping fails
    public func stopScan() throws {
        Logger.shared.lidar("Stopping LiDAR scan")

        guard let _ = currentScanId else {
            throw LiDARError.scanInitializationFailed("No active scan to stop")
        }

        // Update progress
        let progress = ScanProgress(state: .processing, progress: 0.9)
        scanProgress.send(progress)

        // Stop AR session
        sessionQueue.async { [weak self] in
            self?.stopARSession()
        }

        // Process accumulated data
        processingQueue.async { [weak self] in
            self?.processScanData(scanId: self!.currentScanId!)
        }
    }

    /// Cancels the current scan
    public func cancelScan() {
        Logger.shared.lidar("Cancelling LiDAR scan")

        cleanup()
        let progress = ScanProgress(state: .idle, progress: 0.0)
        scanProgress.send(progress)
    }

    /// Gets the current scan progress
    public func getCurrentProgress() -> ScanProgress? {
        guard currentScanId != nil else { return nil }

        let currentPoints = pointCloudBuilder.currentPointCount
        let elapsedTime = scanStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let progress = min(Float(elapsedTime) / Float(ARConstants.maxScanDuration), 1.0)

        let qualityMetrics = calculateQualityMetrics()

        return ScanProgress(
            state: .scanning,
            progress: progress,
            currentPoints: currentPoints,
            estimatedTimeRemaining: ARConstants.maxScanDuration - elapsedTime,
            qualityMetrics: qualityMetrics
        )
    }

    // MARK: - Private Implementation

    private func setupARKit() {
        // Initialize AR session
        arSession = ARSession()
        arSession?.delegate = self

        // Configure for LiDAR scanning
        configuration = ARWorldTrackingConfiguration()
        configuration?.sceneReconstruction = .meshWithClassification
        configuration?.frameSemantics = [.sceneDepth, .smoothedSceneDepth]

        // Enable plane detection for better tracking
        configuration?.planeDetection = [.horizontal, .vertical]

        Logger.shared.lidar("ARKit setup completed")
    }

    private func startARSession() {
        guard let configuration = configuration else {
            let error = LiDARError.sessionConfigurationInvalid("AR configuration not available")
            handleScanError(error)
            return
        }

        do {
            arSession?.run(configuration)
            Logger.shared.lidar("AR session started successfully")
        } catch {
            let lidarError = LiDARError.arSessionFailed(error.localizedDescription)
            handleScanError(lidarError)
        }
    }

    private func stopARSession() {
        arSession?.pause()
        Logger.shared.lidar("AR session stopped")
    }

    private func processScanData(scanId: UUID) {
        Logger.shared.lidar("Processing scan data for \(scanId)")

        do {
            // Process accumulated frames into point cloud
            let pointCloud = try pointCloudBuilder.buildPointCloud(
                frames: accumulatedFrames,
                deviceModel: getDeviceModel() ?? "Unknown",
                scanDuration: scanStartTime.map { Date().timeIntervalSince($0) } ?? 0
            )

            // Validate scan quality
            try validateScanQuality(pointCloud)

            // Update progress to completed
            let qualityMetrics = calculateQualityMetrics()
            let progress = ScanProgress(
                state: .completed,
                progress: 1.0,
                currentPoints: pointCloud.pointCount,
                qualityMetrics: qualityMetrics
            )
            scanProgress.send(progress)

            // Send completion result
            scanCompleted.send(.success(pointCloud))

            Logger.shared.lidar("Scan processing completed successfully with \(pointCloud.pointCount) points")

        } catch let error as LiDARError {
            handleScanError(error)
        } catch {
            let lidarError = LiDARError.pointCloudGenerationFailed(error.localizedDescription)
            handleScanError(lidarError)
        }

        // Cleanup
        cleanup()
    }

    private func validateScanQuality(_ pointCloud: PointCloud) throws {
        // Check minimum point count
        guard pointCloud.pointCount >= 1000 else {
            throw LiDARError.insufficientDataPoints(pointCloud.pointCount)
        }

        // Check scan duration
        if let duration = scanStartTime.map({ Date().timeIntervalSince($0) }) {
            guard duration >= 5.0 else { // Minimum 5 seconds
                throw LiDARError.scanTimeoutExceeded(duration)
            }
        }

        // Check quality score
        guard pointCloud.metadata.qualityScore >= ARConstants.confidenceThreshold else {
            throw LiDARError.scanQualityTooLow(pointCloud.metadata.qualityScore)
        }

        Logger.shared.lidar("Scan quality validation passed")
    }

    private func calculateQualityMetrics() -> ScanQualityMetrics {
        let metrics = pointCloudBuilder.getQualityMetrics()
        let elapsedTime = scanStartTime.map { Date().timeIntervalSince($0) } ?? 0

        return ScanQualityMetrics(
            averageConfidence: metrics.averageConfidence,
            pointCount: metrics.pointCount,
            coverageArea: estimateCoverageArea(),
            scanDuration: elapsedTime,
            qualityScore: metrics.qualityScore
        )
    }

    private func estimateCoverageArea() -> Float {
        // Simple estimation based on bounding box
        let bounds = pointCloudBuilder.getCurrentBounds()
        let size = bounds.size
        return size.x * size.z * 0.8 // Rough estimate with 80% coverage factor
    }

    private func handleScanError(_ error: LiDARError) {
        Logger.shared.error("Scan failed", error: error, category: .lidar)

        let progress = ScanProgress(state: .failed(error), progress: 0.0)
        scanProgress.send(progress)

        scanCompleted.send(.failure(error))

        cleanup()
    }

    private func cleanup() {
        currentScanId = nil
        scanStartTime = nil
        accumulatedFrames.removeAll()
        pointCloudBuilder.reset()

        // Stop AR session if running
        arSession?.pause()
    }

    private func getDeviceModel() -> String? {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - ARSessionDelegate

extension LiDARScanningService: ARSessionDelegate {
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard currentScanId != nil else { return }

        // Accumulate frames for processing
        accumulatedFrames.append(frame)

        // Limit accumulated frames to prevent memory issues
        if accumulatedFrames.count > 300 { // ~10 seconds at 30fps
            accumulatedFrames.removeFirst(accumulatedFrames.count - 300)
        }

        // Process frame for real-time point cloud building
        processingQueue.async { [weak self] in
            self?.pointCloudBuilder.addFrame(frame)
        }

        // Update progress periodically
        if accumulatedFrames.count % 30 == 0 { // Every second at 30fps
            if let progress = getCurrentProgress() {
                scanProgress.send(progress)
            }
        }
    }

    public func session(_ session: ARSession, didFailWithError error: Error) {
        Logger.shared.error("AR session failed", error: error, category: .lidar)
        let lidarError = LiDARError.arSessionFailed(error.localizedDescription)
        handleScanError(lidarError)
    }

    public func sessionWasInterrupted(_ session: ARSession) {
        Logger.shared.warning("AR session was interrupted", category: .lidar)
        let progress = ScanProgress(state: .idle, progress: 0.0)
        scanProgress.send(progress)
    }

    public func sessionInterruptionEnded(_ session: ARSession) {
        Logger.shared.info("AR session interruption ended, resuming", category: .lidar)
        // Attempt to resume scanning
        if currentScanId != nil {
            startARSession()
        }
    }
}

// MARK: - Point Cloud Builder

private class PointCloudBuilder {
    private var points: [PointCloudPoint] = []
    private var bounds: BoundingBox?

    func reset() {
        points.removeAll()
        bounds = nil
    }

    func addFrame(_ frame: ARFrame) {
        guard let sceneDepth = frame.sceneDepth else { return }

        // Convert depth data to point cloud
        let depthData = sceneDepth.depthMap
        let confidenceData = sceneDepth.confidenceMap

        // Camera intrinsics for 3D projection
        let intrinsics = frame.camera.intrinsics
        let cameraTransform = frame.camera.transform

        // Process depth pixels (simplified implementation)
        // In a real implementation, this would process all pixels
        let width = CVPixelBufferGetWidth(depthData)
        let height = CVPixelBufferGetHeight(depthData)

        // Sample pixels at reduced resolution for performance
        let step = 4 // Process every 4th pixel
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                // Get depth value
                let depthValue = getDepthValue(at: x, y: y, from: depthData)
                guard let confidenceBuffer = confidenceData else { continue }
                let confidenceValue = getConfidenceValue(at: x, y: y, from: confidenceBuffer)

                // Skip invalid depths
                guard depthValue > 0 && confidenceValue > 0 else { continue }

                // Project to 3D space
                let normalizedX = (Float(x) - intrinsics[2][0]) / intrinsics[0][0]
                let normalizedY = (Float(y) - intrinsics[2][1]) / intrinsics[1][1]

                let cameraPoint = SIMD3<Float>(normalizedX * depthValue, normalizedY * depthValue, -depthValue)
                let worldPoint4 = matrix_multiply(cameraTransform, SIMD4<Float>(cameraPoint, 1))
                let worldPoint = SIMD3<Float>(worldPoint4.x, worldPoint4.y, worldPoint4.z)

                // Create point with color if available
                let color = getColorFromFrame(frame, at: x, y: y)
                let point = PointCloudPoint(
                    position: worldPoint,
                    confidence: Float(confidenceValue) / 2.0, // Normalize confidence 0-2 to 0-1
                    color: color
                )

                points.append(point)
            }
        }
    }

    func buildPointCloud(frames: [ARFrame], deviceModel: String, scanDuration: TimeInterval) throws -> PointCloud {
        guard !points.isEmpty else {
            throw LiDARError.insufficientDataPoints(0)
        }

        // Calculate bounds
        let positions = points.map { $0.position }
        bounds = BoundingBox(points: positions)

        guard let bounds = bounds else {
            throw LiDARError.pointCloudGenerationFailed("Failed to calculate bounds")
        }

        // Calculate quality metrics
        let averageConfidence = points.reduce(0) { $0 + $1.confidence } / Float(points.count)
        let qualityScore = calculateQualityScore()

        let metadata = PointCloudMetadata(
            pointCount: points.count,
            bounds: bounds,
            averageConfidence: averageConfidence,
            deviceModel: deviceModel,
            scanDuration: scanDuration,
            qualityScore: qualityScore
        )

        return PointCloud(
            points: points,
            metadata: metadata,
            name: "LiDAR Scan \(Date().formatted(date: .abbreviated, time: .shortened))"
        )
    }

    func getCurrentBounds() -> BoundingBox {
        if let bounds = bounds {
            return bounds
        }

        let positions = points.map { $0.position }
        return BoundingBox(points: positions) ?? BoundingBox(min: .zero, max: .zero)
    }

    var currentPointCount: Int { points.count }

    func getQualityMetrics() -> ScanQualityMetrics {
        let averageConfidence = points.isEmpty ? 0 : points.reduce(0) { $0 + $1.confidence } / Float(points.count)
        let qualityScore = calculateQualityScore()
        let coverageArea = estimateCoverageArea()

        return ScanQualityMetrics(
            averageConfidence: averageConfidence,
            pointCount: points.count,
            coverageArea: coverageArea,
            scanDuration: 0, // Will be set by caller
            qualityScore: qualityScore
        )
    }

    private func calculateQualityScore() -> Float {
        guard !points.isEmpty else { return 0.0 }

        let avgConfidence = points.reduce(0) { $0 + $1.confidence } / Float(points.count)
        let pointDensity = Float(points.count) / max(getCurrentBounds().volume, 1.0)
        let densityScore = min(pointDensity / 1000.0, 1.0) // Normalize density

        return (avgConfidence + densityScore) / 2.0
    }

    private func estimateCoverageArea() -> Float {
        let bounds = getCurrentBounds()
        return bounds.size.x * bounds.size.z
    }

    private func getDepthValue(at x: Int, y: Int, from pixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0 }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let index = y * width + x
        let floatPtr = baseAddress.assumingMemoryBound(to: Float.self)
        return floatPtr[index]
    }

    private func getConfidenceValue(at x: Int, y: Int, from pixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0 }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let index = y * width + x

        // Confidence is stored as UInt8
        let uint8Ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        return Float(uint8Ptr[index])
    }

    private func getColorFromFrame(_ frame: ARFrame, at x: Int, y: Int) -> SIMD3<UInt8>? {
        // capturedImage is non-optional CVPixelBuffer
        let capturedImage = frame.capturedImage

        CVPixelBufferLockBaseAddress(capturedImage, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(capturedImage, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(capturedImage) else { return nil }

        let width = CVPixelBufferGetWidth(capturedImage)
        let height = CVPixelBufferGetHeight(capturedImage)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(capturedImage)

        // Safely unwrap sceneDepth before using it
        guard let sceneDepth = frame.sceneDepth else { return nil }
        let depthWidth = CVPixelBufferGetWidth(sceneDepth.depthMap)
        let depthHeight = CVPixelBufferGetHeight(sceneDepth.depthMap)

        // Convert coordinates (depth map may have different resolution than camera image)
        let scaleX = Float(width) / Float(depthWidth)
        let scaleY = Float(height) / Float(depthHeight)

        let imageX = min(Int(Float(x) * scaleX), width - 1)
        let imageY = min(Int(Float(y) * scaleY), height - 1)

        let pixelPtr = baseAddress
            .advanced(by: imageY * bytesPerRow + imageX * 4)
            .assumingMemoryBound(to: UInt8.self)

        // BGRA format
        let blue = pixelPtr[0]
        let green = pixelPtr[1]
        let red = pixelPtr[2]

        return SIMD3<UInt8>(red, green, blue)
    }
}

