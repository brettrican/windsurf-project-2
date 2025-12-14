# InteriorAI

An iOS application that uses ARKit and LiDAR to scan rooms and provide interior design recommendations using AI.

## Features

- LiDAR-based room scanning
- 3D point cloud generation
- Furniture detection and recognition
- AI-powered design recommendations
- Real-time AR visualization

## Requirements

- Xcode 14.0+
- iOS 14.0+
- Device with LiDAR scanner (iPhone 12 Pro/Pro Max, iPad Pro 11-inch (2nd gen), iPad Pro 12.9-inch (4th gen) or later)
- Swift 5.5+

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/InteriorAI.git
   cd InteriorAI
   ```

2. Install dependencies using XcodeGen:
   ```bash
   brew install xcodegen
   xcodegen generate
   ```

3. Open the project:
   ```bash
   open InteriorAI.xcodeproj
   ```

4. Build and run the project (⌘R)

## Project Structure

```
InteriorAI/
├── InteriorAI/
│   ├── AppDelegate.swift          # App lifecycle
│   ├── SceneDelegate.swift        # Scene management
│   ├── ContentView.swift          # Main UI
│   │
│   ├── Core/                      # Core functionality
│   │   ├── Logging/               # Logging utilities
│   │   ├── Networking/            # API client and network layer
│   │   ├── Security/              # Security utilities
│   │   └── VectorDatabase/        # Vector database for AI features
│   │
│   └── Features/                  # Feature modules
│       ├── DesignRecommendations/ # AI design suggestions
│       ├── LiDARScanning/         # Room scanning functionality
│       └── FurnitureDetection/    # Object detection
│
├── Resources/                    # Assets, Localization, etc.
└── Tests/                        # Unit and UI tests
```

## Dependencies

- **Alamofire**: HTTP networking
- **CombineExt**: Combine extensions
- **ARKit**: Augmented Reality
- **CoreML**: Machine Learning
- **Vision**: Computer Vision

## Configuration

1. Update `project.yml` with your development team and bundle identifier.
2. Add any required API keys to `Constants.swift`.
3. For production, update the code signing settings in Xcode.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

Your Name - [@yourtwitter](https://twitter.com/yourtwitter) - email@example.com

Project Link: [https://github.com/yourusername/InteriorAI](https://github.com/yourusername/InteriorAI)
