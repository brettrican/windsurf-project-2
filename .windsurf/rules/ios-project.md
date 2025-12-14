The purpose of this document is to establish the foundational rules and context management protocols for generating a production-ready iOS application. 

You are an expert iOS developer tasked with creating a production-ready application. 
IMPORTANT: You will create and maintain project contexts as you generate code to ensure 
consistency and alignment with the original goals throughout the entire process.

================================================================================
CONTEXT MANAGEMENT INSTRUCTIONS FOR THIS LLM SESSION
================================================================================

CRITICAL INSTRUCTION: As you generate code, you MUST actively maintain the following:

1. PROJECT CONTEXT VECTOR DATABASE
   - After generating each major component, create a brief context entry
   - Format each context as: [COMPONENT_NAME]: [Key decisions], [Dependencies], [Goals]
   - Store these contexts in memory and reference them before generating new code
   - Before writing any new module, RETRIEVE and review all related contexts

2. DESIGN DECISION LOG
   - Document every architectural decision you make
   - Include: Why the decision was made, What alternatives were considered, What dependencies it creates
   - Reference this log when making conflicting decisions
   - Flag any decisions that contradict previous ones

3. REQUIREMENT VERIFICATION CHECKLIST
   - Before generating each major feature, verify it aligns with:
     * Original app goals (LiDAR scanning + AI design recommendations)
     * Technical requirements (ARKit, CoreML, SwiftUI)
     * Security requirements (encryption, Keychain, validation)
     * Error handling strategy (custom Error enums, Result types)
   - If any generated code conflicts with requirements, pause and reconcile

4. DEPENDENCY MAPPING
   - Create a mental map of all module dependencies
   - Before generating a module, verify all dependencies exist
   - Flag circular dependencies
   - Ensure dependency injection is properly implemented

5. CODE COHERENCE CHECKS
   - After generating 5 files, create a brief coherence summary:
     * Files generated: [list]
     * Architecture maintained: [yes/no]
     * Error handling pattern consistent: [yes/no]
     * Security practices applied: [yes/no]
   - Identify any inconsistencies and self-correct

================================================================================
VECTOR DATABASE SCHEMA FOR THIS PROJECT
================================================================================

For each major component, create a context vector with these fields:

{
  "component_name": "string",
  "module_path": "string", 
  "purpose": "string",
  "dependencies": ["array of dependent modules"],
  "provides_to": ["array of modules that depend on this"],
  "key_protocols": ["array of protocols used"],
  "error_types": ["custom errors this module defines"],
  "security_measures": ["security practices implemented"],
  "threading_model": "main/background/async-await",
  "testing_requirements": "array of test cases needed",
  "generated_timestamp": "when created",
  "alignment_score": "1-10 score of how well it meets requirements"
}

BUILD THIS VECTOR DATABASE CONTINUOUSLY AS YOU WORK.

================================================================================
REFERENCE CONTEXTS BEFORE EACH MODULE
================================================================================

Before generating ANY new code file, follow this checklist:

CONTEXT RETRIEVAL PHASE:
1. What have I already generated? (Review mental vector DB)
2. What are the dependencies for this new module? (Check dependency map)
3. What error types have been defined? (Cross-reference error modules)
4. What security patterns have been applied? (Ensure consistency)
5. What protocols are being used? (Verify consistent naming and patterns)

ALIGNMENT CHECK PHASE:
6. Does this module align with the app's core mission?
   → Mission: "LiDAR scanning + AI design recommendations"
7. Does this use the required frameworks (ARKit, CoreML, SwiftUI)?
8. Does this follow the architecture (MVVM + Clean Architecture)?
9. Does this implement required error handling (Result types, custom Errors)?
10. Does this implement required security (encryption, validation, Keychain)?

CONFLICT DETECTION PHASE:
11. Would this module contradict previously made decisions?
12. Would this create circular dependencies?
13. Does this duplicate logic already generated elsewhere?
14. Would this violate the threading model established?

If any check fails, PAUSE and explain the conflict before proceeding.

================================================================================
CONTEXT LOGGING FORMAT
================================================================================

At the end of EACH major component generated, output:

---
[CONTEXT LOG - {COMPONENT_NAME}]
Generated: {Brief description of what was created}
Dependencies: {What this depends on}
Dependents: {What depends on this}
Error Types: {New error types defined}
Security: {Security measures implemented}
Threading: {Main/Background/Async}
Alignment: {1-10 score vs requirements}
Next Required: {What should be generated next}
Potential Conflicts: {Any identified issues}
---

This allows you to maintain coherence and allows the user to track progress.

================================================================================
CONTINUOUS GOAL TRACKING
================================================================================

App's Core Goals (reference before EVERY module):
1. ✓ LiDAR room scanning with point cloud visualization
2. ✓ Furniture detection using Core ML
3. ✓ AI-powered design recommendations
4. ✓ AR furniture visualization and placement
5. ✓ Design trend analysis
6. ✓ Export and sharing functionality
7. ✓ Production-ready security
8. ✓ Comprehensive error handling
9. ✓ Context management for design tracking
10. ✓ Vector database for goal alignment

DO NOT generate code that doesn't contribute to ONE of these goals.

================================================================================
CRITICAL PROJECT SPECIFICATIONS
================================================================================

APP NAME: InteriorAI (LiDAR-Powered Interior Design Assistant)
TARGET PLATFORM: iOS 16.0+
TARGET DEVICE: iPhone 15 Pro Max (primary), iPhone 12 Pro+ and newer
DEVELOPMENT LANGUAGE: Swift 5.9+
UI FRAMEWORK: SwiftUI
ARCHITECTURE PATTERN: MVVM + Clean Architecture

================================================================================
REQUIRED FRAMEWORKS (DO NOT FORGET)
================================================================================

- ARKit 5+ (LiDAR access and AR visualization)
- RealityKit (3D scene rendering)
- Core ML (on-device furniture detection)
- Vision Framework (image analysis)
- SwiftUI (user interface)
- Combine (reactive programming)
- CryptoKit (secure data handling)
- CoreData (persistent storage + vector database)

================================================================================
NON-NEGOTIABLE REQUIREMENTS
================================================================================

ARCHITECTURE:
- MVVM pattern with Clear Separation of Concerns
- Dependency Injection for all services
- Repository Pattern for data access
- Protocol-oriented design

ERROR HANDLING (REQUIRED IN ALL CODE):
- Custom Error enums for each module (LiDARError, DetectionError, NetworkError, etc.)
- Result<Success, Failure> types throughout
- ZERO force unwrapping (use guard/if-let instead)
- Proper error propagation with logging
- User-friendly error messages

SECURITY (REQUIRED IN ALL CODE):
- Keychain storage for sensitive data
- AES-256-GCM encryption for scans
- Certificate pinning for API calls
- Jailbreak detection
- Input validation on all data
- No PII in logs
- HTTPS only

TESTING (REQUIRED FOR ALL CODE):
- Unit tests for all ViewModels and Services
- Mock objects for dependencies
- Target 80%+ code coverage
- Integration tests for critical paths

================================================================================
FOLDER STRUCTURE TO MAINTAIN
================================================================================

APP/
├── App.swift
├── Features/
│   ├── LiDARScanning/
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   ├── Services/
│   │   ├── Models/
│   │   └── Errors/
│   ├── FurnitureDetection/
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   ├── Services/
│   │   ├── Models/
│   │   └── Errors/
│   ├── DesignRecommendations/
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   ├── Services/
│   │   ├── Models/
│   │   └── Errors/
│   ├── ARPreview/
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   ├── Services/
│   │   └── Models/
│   └── ProjectContext/
│       ├── ViewModels/
│       ├── Views/
│       ├── Services/
│       ├── Models/
│       └── Errors/
├── Core/
│   ├── Networking/
│   ├── Storage/
│   ├── Logging/
│   ├── Security/
│   ├── VectorDatabase/
│   └── Utilities/
└── Tests/

MAINTAIN THIS STRUCTURE CONSISTENTLY.

================================================================================
CODE QUALITY STANDARDS (NON-NEGOTIABLE)
================================================================================

- Swift API Design Guidelines compliance
- Meaningful variable names (no abbreviations)
- Triple-slash (///) documentation for all public APIs
- SOLID principles throughout
- Max cyclomatic complexity: 10 per function
- Max function length: 50 lines
- Proper access control (private/fileprivate/public)
- No force unwrapping, no try!, no default values for errors

================================================================================
VECTOR DATABASE IMPLEMENTATION REQUIREMENTS
================================================================================

Your code must include a VectorDatabase service that:

1. STORES PROJECT CONTEXTS:
   - Each design scan = one context vector
   - Each design recommendation = one context vector
   - Each furniture detection = one context vector
   - Each AR placement = one context vector

2. ENABLES SIMILARITY SEARCH:
   - Find similar past designs
   - Compare current state to original goals
   - Track design evolution

3. VALIDATES ALIGNMENT:
   - Query: "Is current design aligned with project goals?"
   - Query: "What was the original design intention?"
   - Query: "How does this furniture match detected preferences?"

4. SUPPORTS PERSISTENCE:
   - Save contexts locally with encryption
   - Retrieve contexts across app sessions
   - Archive old contexts

================================================================================
GENERATION SEQUENCE (FOLLOW THIS ORDER)
================================================================================

PHASE 1: FOUNDATIONS (Do not skip)
1. Constants.swift - Define all app constants
2. Error enums (LiDARError.swift, DetectionError.swift, etc.)
3. Core data models (PointCloud.swift, DetectedFurniture.swift, etc.)

PHASE 2: CORE INFRASTRUCTURE
4. SecurityValidator.swift - Security checks
5. KeychainManager.swift - Secure storage
6. Logger.swift - Logging infrastructure
7. APIClient.swift - Network layer
8. VectorDatabase.swift - Context management

PHASE 3: FEATURE SERVICES
9. LiDARScanningService.swift
10. FurnitureDetectionService.swift
11. DesignAIService.swift
12. ProjectContextManager.swift

PHASE 4: VIEW MODELS & VIEWS
13. ViewModels (LiDARScanningViewModel, etc.)
14. Views (SwiftUI)

PHASE 5: INTEGRATION & TESTS
15. All unit tests
16. All integration tests
17. Mock objects

FOLLOW THIS SEQUENCE EXACTLY.

================================================================================
SELF-CORRECTION MECHANISM
================================================================================

If you catch yourself about to do any of the following, STOP and correct:

🚫 STOP if you're about to:
- Use force unwrapping (!)
- Use try! without error handling
- Store sensitive data in UserDefaults
- Use HTTP instead of HTTPS
- Create a ViewController (use SwiftUI only)
- Forget to implement error handling
- Skip security validation
- Use global variables for state
- Create circular dependencies
- Ignore the MVVM pattern
- Generate code that doesn't align with core goals

✅ Instead:
- Use guard/if-let for optionals
- Use Result<Success, Failure> types
- Use Keychain for sensitive data
- Always use HTTPS
- Use SwiftUI only
- Implement Result types and proper error propagation
- Always validate and encrypt
- Use @StateObject/@ObservedObject for state
- Check dependency map before creating modules
- Follow MVVM strictly
- Verify alignment with core goals

================================================================================
PROGRESS TRACKING
================================================================================

After each major component, report:

PROGRESS CHECKPOINT:
- Files Generated: [count]
- Lines of Code: [estimate]
- Core Goals Addressed: [count/10]
- Security Measures: [count implemented]
- Error Handling: [coverage percentage]
- Test Coverage: [estimated percentage]
- Architecture Integrity: [score 1-10]
- Potential Issues: [list any concerns]
- Next Steps: [what should be generated next]

================================================================================
CUSTOM VECTOR DATABASE REQUIREMENTS FOR THIS PROJECT
================================================================================

Implement ProjectContextManager that maintains:

1. DESIGN GOAL VECTORS:
   - Store original user intent
   - Store design preferences
   - Store furniture style preferences
   - Enable periodic reconciliation

2. SCAN CONTEXT VECTORS:
   - Room dimensions
   - Detected furniture
   - Room lighting conditions
   - Available space

3. RECOMMENDATION VECTORS:
   - Generated suggestions
   - Trend alignment scores
   - User acceptance/rejection
   - Pattern matching for future scans

4. ALIGNMENT QUERIES:
   - isCurrentDesignAlignedWithGoals() -> Bool
   - getSimilarPastDesigns() -> [DesignContext]
   - getDesignEvolution() -> [DesignContext]
   - validateNewFurnitureAgainstGoals() -> Result

================================================================================
FINAL CHECKLIST BEFORE STARTING GENERATION
================================================================================

Before you write the first line of code, confirm:

☑ I understand the app is: LiDAR scanning + AI design recommendations
☑ I understand the target device: iPhone 15 Pro Max
☑ I understand the architecture: MVVM + Clean Architecture
☑ I understand error handling is non-negotiable
☑ I understand security is non-negotiable
☑ I understand I must maintain context throughout generation
☑ I understand I must verify alignment with goals before each module
☑ I understand I must log contexts after each major component
☑ I understand I must follow the generation sequence exactly
☑ I understand I must implement vector database for project tracking
☑ I am ready to generate production-ready code
☑ I will self-correct if I violate any non-negotiable requirement

================================================================================
BEGIN CODE GENERATION
================================================================================

Now generate the complete, production-ready iOS application following ALL 
specifications above. 

REMEMBER:
1. Create context vectors as you work
2. Reference contexts before each new module
3. Verify alignment with core goals continuously
4. Log progress after each major component
5. Implement vector database for design tracking
6. Never violate non-negotiable requirements
7. Self-correct immediately if you drift from goals

Start with Phase 1 (Constants and Error Enums).
Output context logs after each component.
Maintain the folder structure exactly as specified.

Generate comprehensive, production-ready code for immediate iOS deployment.