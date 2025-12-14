//
//  ContentView.swift
//  InteriorAI
//
//  Main SwiftUI view for the InteriorAI application
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = InteriorAIViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("InteriorAI")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("LiDAR-Powered Interior Design Assistant")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // Main action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        viewModel.startNewProject()
                    }) {
                        Label("Start New Project", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        viewModel.scanRoom()
                    }) {
                        Label("Scan Room", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!LiDARScanningService.shared.isLiDARSupported())

                    Button(action: {
                        viewModel.detectFurniture()
                    }) {
                        Label("Detect Furniture", systemImage: "chair.lounge")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        viewModel.getRecommendations()
                    }) {
                        Label("Get AI Recommendations", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Status information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Compatibility:")
                        .font(.headline)

                    HStack {
                        Image(systemName: LiDARScanningService.shared.isLiDARSupported() ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(LiDARScanningService.shared.isLiDARSupported() ? .green : .red)
                        Text("LiDAR Scanner")
                    }

                    HStack {
                        Image(systemName: FurnitureDetectionService.shared.areModelsAvailable() ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(FurnitureDetectionService.shared.areModelsAvailable() ? .green : .yellow)
                        Text("AI Models")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

class InteriorAIViewModel: ObservableObject {
    @Published var currentProjectId: UUID?
    @Published var isScanning = false
    @Published var scanProgress: ScanProgress?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    func startNewProject() {
        do {
            let projectId = UUID()
            try ProjectContextManager.shared.startProject(projectId: projectId, initialGoal: "Create a functional and aesthetically pleasing room layout")
            currentProjectId = projectId
            Logger.shared.info("Started new project: \(projectId)")
        } catch {
            Logger.shared.error("Failed to start new project", error: error, category: .general)
        }
    }

    func scanRoom() {
        guard !isScanning else { return }

        isScanning = true
        let scanId = UUID()

        // Subscribe to scan progress
        LiDARScanningService.shared.scanProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.scanProgress = progress
            }
            .store(in: &cancellables)

        // Subscribe to scan completion
        LiDARScanningService.shared.scanCompleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.isScanning = false
                switch result {
                case .success(let pointCloud):
                    self?.handleScanCompletion(pointCloud)
                case .failure(let error):
                    Logger.shared.error("Scan failed", error: error, category: .lidar)
                }
            }
            .store(in: &cancellables)

        // Start scanning
        do {
            try LiDARScanningService.shared.startScan(scanId: scanId)
        } catch {
            Logger.shared.error("Failed to start scan", error: error, category: .lidar)
            isScanning = false
        }
    }

    func detectFurniture() {
        // Placeholder - would integrate with camera picker
        Logger.shared.info("Furniture detection requested - camera integration needed")
    }

    func getRecommendations() {
        guard let projectId = currentProjectId else {
            Logger.shared.warning("No active project for recommendations")
            return
        }

        // Placeholder - would create DesignRecommendationRequest and call DesignAIService
        Logger.shared.info("AI recommendations requested for project: \(projectId)")
    }

    private func handleScanCompletion(_ pointCloud: PointCloud) {
        guard let projectId = currentProjectId else { return }

        do {
            try ProjectContextManager.shared.logScanContext(pointCloud)
            Logger.shared.info("Scan context logged for project: \(projectId)")
        } catch {
            Logger.shared.error("Failed to log scan context", error: error, category: .general)
        }
    }

    private func setupBindings() {
        // Setup any additional reactive bindings here
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
