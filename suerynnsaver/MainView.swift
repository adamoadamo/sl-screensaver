import ScreenSaver
import AppKit

@objc(SuerynnSaverView)
class MainView: ScreenSaverView {
    private class ImageCacheManager {
        static let shared = ImageCacheManager()
        private var imageCache: [String: NSImage] = [:]
        private let bundle: Bundle

        private init() {
            let mainBundle = Bundle(for: MainView.self)
            NSLog("Main bundle path: \(mainBundle.bundlePath)")

            // Try to find the installed screensaver bundle
            if let saverPath = mainBundle.bundlePath.components(separatedBy: "Contents/MacOS").first {
                NSLog("Saver path: \(saverPath)")
                if let saverBundle = Bundle(path: saverPath) {
                    self.bundle = saverBundle
                    NSLog("Using saver bundle")
                } else {
                    self.bundle = mainBundle
                    NSLog("Falling back to main bundle")
                }
            } else {
                self.bundle = mainBundle
                NSLog("Using main bundle directly")
            }

            NSLog("Final bundle path: \(bundle.bundlePath)")
            verifyBundleContents()
        }

        private func verifyBundleContents() {
            NSLog("🔍 Bundle verification:")
            NSLog("🔍 Bundle path: \(bundle.bundlePath)")

            if let resourcePath = bundle.resourcePath {
                NSLog("🔍 Resource path: \(resourcePath)")
                do {
                    let resources = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    NSLog("🔍 Found \(resources.count) resources:")
                    for resource in resources {
                        NSLog("🔍 - \(resource)")
                    }
                } catch {
                    NSLog("❌ Error listing resources: \(error)")
                }
            } else {
                NSLog("❌ No resource path found")
            }
        }

        func loadImage(named name: String) -> NSImage? {
            if let cachedImage = imageCache[name] {
                return cachedImage
            }

            // Try loading directly from bundle resources as PNG
            if let imagePath = bundle.path(forResource: name, ofType: "png") {
                NSLog("Found image at path: \(imagePath)")
                if let image = NSImage(contentsOfFile: imagePath) {
                    NSLog("Successfully loaded image: \(name)")
                    imageCache[name] = image
                    return image
                }
            }

            NSLog("Failed to load image: \(name)")
            return nil
        }
    }

    private let imageCache = ImageCacheManager.shared
    private struct Character {
        var position: CGPoint
        var edge: Int       // 0 = bottom, 1 = right, 2 = top, 3 = left
        var angle: CGFloat
        var images: [NSImage]
        var currentFrame: Int = 0
        var frameDelayCounter: Int = 0
        var state: MovementState = .movingAlongEdge
        var opacity: CGFloat = 1.0
        var isActive: Bool = true
        var characterType: String  // Store which character this is
    }
    
    private enum MovementState {
        case movingAlongEdge
        case movingAlongCorner(arcCenter: CGPoint, endAngle: CGFloat, currentAngle: CGFloat, angleIncrement: CGFloat)
    }

    private var characters: [Character] = []
    private var charactersInitialized = false
    private var displayLink: CVDisplayLink?
    private var lastFrameTime: TimeInterval = 0
    private let targetFrameInterval: TimeInterval = 1.0 / 30.0  // Match original animation interval

    // Define percentages as constants
    private struct ScreenPercentages {
        static let characterSize: CGFloat = 0.275     // 15.5% of smaller screen dimension
        static let cornerRadius: CGFloat = 0.225       // 12.5% of smaller screen dimension
        static let edgeOffset: CGFloat = -0.0045       // -0.45% of smaller screen dimension
        static let minDistance: CGFloat = 0.45          // Increased from 0.45 to 0.65
        static let edgeSpeed: CGFloat = 0.0015        // 0.2% of smaller screen dimension per frame
        static let cornerSpeedMultiplier: CGFloat = 5.5  // Multiplier for corner speed relative to edge speed
        static let frameDelay: Int = 7                 // Number of frames to wait before advancing animation
    }

    // Computed properties based on screen size
    private var smallerScreenDimension: CGFloat {
        return min(bounds.width, bounds.height)
    }

    private var squareSize: CGFloat {
        return smallerScreenDimension * ScreenPercentages.characterSize
    }

    private var imageSize: CGFloat {
        return squareSize * 1.05  // Slightly larger than square size
    }

    private var cornerRadius: CGFloat {
        return smallerScreenDimension * ScreenPercentages.cornerRadius
    }

    private var edgeOffset: CGFloat {
        return smallerScreenDimension * ScreenPercentages.edgeOffset
    }

    private var minDistance: CGFloat {
        return smallerScreenDimension * ScreenPercentages.minDistance
    }

    private var edgeSpeed: CGFloat {
        return smallerScreenDimension * ScreenPercentages.edgeSpeed
    }

    private var cornerSpeed: CGFloat {
        return edgeSpeed * ScreenPercentages.cornerSpeedMultiplier
    }

    // Add frameDelay as a computed property
    private var frameDelay: Int {
        return ScreenPercentages.frameDelay
    }

    // Rename from 'animations' to 'characterAnimations'
    private let characterAnimations: [String: [String]] = [
        "Apple": ["Apple_Walk-1", "Apple_Walk-2", "Apple_Walk-3"],
        "Butterfly": ["Butterfly_Walk-1", "Butterfly_Walk-2", "Butterfly_Walk-3", "Butterfly_Walk-4", "Butterfly_Walk-5", "Butterfly_Walk-6", "Butterfly_Walk-7", "Butterfly_Walk-8"],
        "Man": ["Man_Walk-1", "Man_Walk-2", "Man_Walk-3"],
        "Paper": ["Paper_Walk-1", "Paper_Walk-2", "Paper_Walk-3"],
        "Peanut": ["Peanut_Walk-1", "Peanut_Walk-2", "Peanut_Walk-3"],
        "Can": ["Can_Walk-1", "Can_Walk-2", "Can_Walk-3"],
        "Lip": ["Lip_Walk-1", "Lip_Walk-2", "Lip_Walk-3"],
        "Bird": ["Bird_Walk-1", "Bird_Walk-2", "Bird_Walk-3", "Bird_Walk-4", "Bird_Walk-5", "Bird_Walk-6", "Bird_Walk-7"],
        "Pea": ["Pea_Walk-1", "Pea_Walk-2", "Pea_Walk-3"],
        "Cry": ["Cry_Walk-1", "Cry_Walk-2", "Cry_Walk-3"],
        "Elephant": ["Elephant_Walk-1", "Elephant_Walk-2", "Elephant_Walk-3"],
        "Goo": ["Goo_Walk-1", "Goo_Walk-2", "Goo_Walk-3"],
        "Balloon": ["Balloon_Walk-1", "Balloon_Walk-2", "Balloon_Walk-3"],
        "Pant": ["Pant_Walk-1", "Pant_Walk-2", "Pant_Walk-3"],
        "Bat": ["Bat_Walk-1", "Bat_Walk-2", "Bat_Walk-3", "Bat_Walk-4", "Bat_Walk-5", "Bat_Walk-6"],
        "Horse": ["Horse_Walk-1", "Horse_Walk-2", "Horse_Walk-3"],
        "Umbrella": ["Umbrella_Walk-1", "Umbrella_Walk-2", "Umbrella_Walk-3"],
        "Roll": ["Roll_Walk-1", "Roll_Walk-2", "Roll_Walk-3"],
        "Paint": ["Paint_Walk-1", "Paint_Walk-2", "Paint_Walk-3", "Paint_Walk-4"],
    ]

    private var hasInitializedPositions = false
    private let maxActiveCharacters = 7
    private var availableCharacterTypes: Set<String> = []
    private var activeCharacterTypes: Set<String> = []
    private var fadeTimer: Timer?
    private let fadeInterval: TimeInterval = 20  // Average between 5-10 seconds

    @objc override init?(frame: NSRect, isPreview: Bool) {
        NSLog("🟢 MainView init starting")
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
        setupDisplayLink()
    }

    @objc required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        NSLog("🟢 Starting commonInit")
        loadImages()
        NSLog("🟢 Finished commonInit")
    }

    private func loadImages() {
        NSLog("🟢 Starting loadImages")
        characters = []
        availableCharacterTypes = Set(characterAnimations.keys)
        activeCharacterTypes = Set()

        // Randomly select initial characters
        let initialCharacters = Array(characterAnimations.keys).shuffled().prefix(maxActiveCharacters)

        for characterName in initialCharacters {
            if let frames = characterAnimations[characterName] {
                var images: [NSImage] = []

                for frameName in frames {
                    if let image = imageCache.loadImage(named: frameName) {
                        images.append(image)
                    }
                }

                if !images.isEmpty {
                    characters.append(Character(
                        position: .zero,  // Position will be set by initializeCharacterPositions
                        edge: 0,
                        angle: 0,
                        images: images,
                        opacity: 0.0,  // Start fully transparent
                        isActive: true,
                        characterType: characterName
                    ))
                    activeCharacterTypes.insert(characterName)
                    availableCharacterTypes.remove(characterName)
                    NSLog("✅ Loaded character \(characterName) with \(images.count) frames")
                }
            }
        }

        NSLog("🟢 Finished loadImages with \(characters.count) active characters")
        setupFadeTimer()
    }

    private func setupFadeTimer() {
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { [weak self] _ in
            self?.rotateRandomCharacter()
        }
    }

    private func rotateRandomCharacter() {
        // Don't select characters that are currently fading
        guard let characterToRemove = characters.filter({ $0.isActive && $0.opacity == 1.0 }).randomElement(),
              !availableCharacterTypes.isEmpty else {
            return
        }

        // Get list of available characters excluding the one being removed
        let validNewTypes = availableCharacterTypes.filter { $0 != characterToRemove.characterType }
        guard let newCharacterType = validNewTypes.randomElement() else {
            return
        }

        NSLog("🔄 Rotating: removing \(characterToRemove.characterType), will add \(newCharacterType)")
        
        startFadeAnimation(for: characterToRemove.characterType, fadingIn: false) { [weak self] in
            guard let self = self else { return }
            
            // Remove the character from the array after fade out
            if let index = self.characters.firstIndex(where: { $0.characterType == characterToRemove.characterType }) {
                self.characters.remove(at: index)
            }
            
            self.activeCharacterTypes.remove(characterToRemove.characterType)
            self.availableCharacterTypes.insert(characterToRemove.characterType)

            let delay = TimeInterval.random(in: 2...4)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.addNewCharacter(ofType: newCharacterType)
            }
        }
    }

    private func startFadeAnimation(for characterType: String, fadingIn: Bool, completion: (() -> Void)? = nil) {
        let duration: TimeInterval = 0.5
        let steps = 30
        let stepDuration = duration / Double(steps)
        var currentStep = 0

        NSLog("🎭 Starting fade \(fadingIn ? "in" : "out") animation for \(characterType)")

        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            
            if let index = self.characters.firstIndex(where: { $0.characterType == characterType }) {
                let newOpacity: CGFloat
                if fadingIn {
                    newOpacity = min(CGFloat(currentStep) / CGFloat(steps), 1.0)
                } else {
                    newOpacity = max(1.0 - (CGFloat(currentStep) / CGFloat(steps)), 0.0)
                }
                
                self.characters[index].opacity = newOpacity
                NSLog("👻 \(characterType) opacity now: \(newOpacity)")
                
                DispatchQueue.main.async {
                    self.needsDisplay = true
                }
            } else {
                NSLog("⚠️ Character not found for fade animation: \(characterType)")
                timer.invalidate()
                return
            }

            if currentStep >= steps {
                NSLog("✅ Fade \(fadingIn ? "in" : "out") complete for \(characterType)")
                timer.invalidate()
                completion?()
            }
        }
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)

        // Initialize positions if we haven't yet and have valid dimensions
        if !hasInitializedPositions && bounds.width > 0 && bounds.height > 0 {
            NSLog("📏 Initializing positions with dimensions: \(bounds.width) x \(bounds.height)")
            initializeCharacterPositions()
            hasInitializedPositions = true
        }

        // Draw characters
        for (index, character) in characters.enumerated() {
            NSLog("🎨 Drawing character \(index) at position: \(character.position)")
            drawCharacter(character)
        }
    }

    private func drawCharacter(_ character: Character) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        // Move to position and rotate
        context.translateBy(x: character.position.x, y: character.position.y)
        context.rotate(by: character.angle)

        if character.images.indices.contains(character.currentFrame) {
            let image = character.images[character.currentFrame]
            let rect = CGRect(x: -imageSize / 2, y: 0, width: imageSize, height: imageSize)
            
            // Create a new graphics context with the opacity
            NSGraphicsContext.saveGraphicsState()
            context.setAlpha(character.opacity)
            
            // Draw the image with the current opacity
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: character.opacity)
            
            NSGraphicsContext.restoreGraphicsState()
        }
        
        context.restoreGState()
    }

    override func animateOneFrame() {
        if !charactersInitialized && bounds.width > 0 && bounds.height > 0 {
            NSLog("🟢 Setting up characters...")
            setupCharacters()
        }

        if charactersInitialized {
            for i in 0..<characters.count {
                animateCharacter(&characters[i])
                moveCharacter(&characters[i])
            }
            needsDisplay = true
        } else {
            NSLog("❌ Characters not initialized")
        }
    }

    private func animateCharacter(_ character: inout Character) {
        character.frameDelayCounter += 1
        if character.frameDelayCounter >= frameDelay {
            character.currentFrame = (character.currentFrame + 1) % character.images.count
            character.frameDelayCounter = 0
        }
    }

    private func moveCharacter(_ character: inout Character) {
        switch character.state {
        case .movingAlongEdge:
            switch character.edge {
            case 0: // Bottom edge
                character.position.x += edgeSpeed
                character.angle = 0
                if character.position.x >= bounds.width - cornerRadius - edgeOffset {
                    // Start turning along bottom-right corner
                    let arcCenter = CGPoint(
                        x: bounds.width - cornerRadius - edgeOffset,
                        y: cornerRadius + edgeOffset
                    )
                    let startAngle: CGFloat = 3 * CGFloat.pi / 2
                    let endAngle: CGFloat = 2 * CGFloat.pi
                    let angleIncrement = computeAngleIncrement(startAngle: startAngle, endAngle: endAngle, speed: cornerSpeed)
                    character.state = .movingAlongCorner(
                        arcCenter: arcCenter,
                        endAngle: endAngle,
                        currentAngle: startAngle,
                        angleIncrement: angleIncrement
                    )
                }
            case 1: // Right edge
                character.position.y += edgeSpeed
                character.angle = CGFloat.pi / 2
                if character.position.y >= bounds.height - cornerRadius - edgeOffset {
                    // Start turning along top-right corner
                    let arcCenter = CGPoint(
                        x: bounds.width - cornerRadius - edgeOffset,
                        y: bounds.height - cornerRadius - edgeOffset
                    )
                    let startAngle: CGFloat = 0
                    let endAngle: CGFloat = CGFloat.pi / 2
                    let angleIncrement = computeAngleIncrement(startAngle: startAngle, endAngle: endAngle, speed: cornerSpeed)
                    character.state = .movingAlongCorner(
                        arcCenter: arcCenter,
                        endAngle: endAngle,
                        currentAngle: startAngle,
                        angleIncrement: angleIncrement
                    )
                }
            case 2: // Top edge
                character.position.x -= edgeSpeed
                character.angle = CGFloat.pi
                if character.position.x <= cornerRadius + edgeOffset {
                    // Start turning along top-left corner
                    let arcCenter = CGPoint(
                        x: cornerRadius + edgeOffset,
                        y: bounds.height - cornerRadius - edgeOffset
                    )
                    let startAngle: CGFloat = CGFloat.pi / 2
                    let endAngle: CGFloat = CGFloat.pi
                    let angleIncrement = computeAngleIncrement(startAngle: startAngle, endAngle: endAngle, speed: cornerSpeed)
                    character.state = .movingAlongCorner(
                        arcCenter: arcCenter,
                        endAngle: endAngle,
                        currentAngle: startAngle,
                        angleIncrement: angleIncrement
                    )
                }
            case 3: // Left edge
                character.position.y -= edgeSpeed
                character.angle = 3 * CGFloat.pi / 2
                if character.position.y <= cornerRadius + edgeOffset {
                    // Start turning along bottom-left corner
                    let arcCenter = CGPoint(
                        x: cornerRadius + edgeOffset,
                        y: cornerRadius + edgeOffset
                    )
                    let startAngle: CGFloat = CGFloat.pi
                    let endAngle: CGFloat = 3 * CGFloat.pi / 2
                    let angleIncrement = computeAngleIncrement(startAngle: startAngle, endAngle: endAngle, speed: cornerSpeed)
                    character.state = .movingAlongCorner(
                        arcCenter: arcCenter,
                        endAngle: endAngle,
                        currentAngle: startAngle,
                        angleIncrement: angleIncrement
                    )
                }
            default:
                break
            }

        case .movingAlongCorner(let arcCenter, let endAngle, var currentAngle, let angleIncrement):
            // Adjust angleIncrement to prevent overshooting
            let remainingAngle = endAngle - currentAngle
            let direction: CGFloat = angleIncrement >= 0 ? 1 : -1
            let absIncrement = abs(angleIncrement)
            let absRemaining = abs(remainingAngle)
            let adjustedIncrement = absIncrement > absRemaining ? direction * absRemaining : angleIncrement
            currentAngle += adjustedIncrement

            let finishedTurning = (angleIncrement >= 0 && currentAngle >= endAngle) || (angleIncrement < 0 && currentAngle <= endAngle)

            if finishedTurning {
                currentAngle = endAngle
                character.state = .movingAlongEdge
                character.edge = (character.edge + 1) % 4
                character.angle = angleForEdge(character.edge) // Set angle based on new edge
                // Set position exactly at the end angle
                character.position.x = arcCenter.x + cornerRadius * cos(currentAngle)
                character.position.y = arcCenter.y + cornerRadius * sin(currentAngle)
            } else {
                // Update the character's state with the new currentAngle
                character.state = .movingAlongCorner(
                    arcCenter: arcCenter,
                    endAngle: endAngle,
                    currentAngle: currentAngle,
                    angleIncrement: angleIncrement
                )
                character.position.x = arcCenter.x + cornerRadius * cos(currentAngle)
                character.position.y = arcCenter.y + cornerRadius * sin(currentAngle)
                character.angle = normalizeAngle(angle: currentAngle + CGFloat.pi / 2)
            }
        }
    }

    private func computeAngleIncrement(startAngle: CGFloat, endAngle: CGFloat, speed: CGFloat) -> CGFloat {
        let angleDifference = endAngle - startAngle
        let direction: CGFloat = angleDifference >= 0 ? 1 : -1
        return direction * speed / cornerRadius
    }

    private func normalizeAngle(angle: CGFloat) -> CGFloat {
        var newAngle = angle.truncatingRemainder(dividingBy: 2 * CGFloat.pi)
        if newAngle < 0 {
            newAngle += 2 * CGFloat.pi
        }
        return newAngle
    }

    private func angleForEdge(_ edge: Int) -> CGFloat {
        switch edge {
        case 0:
            return 0.0 // Bottom edge
        case 1:
            return CGFloat.pi / 2 // Right edge
        case 2:
            return CGFloat.pi // Top edge
        case 3:
            return 3 * CGFloat.pi / 2 // Left edge
        default:
            return 0.0
        }
    }

    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else { return }

        lastFrameTime = CACurrentMediaTime()

        CVDisplayLinkSetOutputCallback(displayLink, { (displayLink, _, _, _, _, displayLinkContext) -> CVReturn in
            let view = Unmanaged<MainView>.fromOpaque(displayLinkContext!).takeUnretainedValue()

            let currentTime = CACurrentMediaTime()
            let elapsed = currentTime - view.lastFrameTime

            // Only animate if enough time has passed
            if elapsed >= view.targetFrameInterval {
                DispatchQueue.main.async {
                    view.animateOneFrame()
                }
                view.lastFrameTime = currentTime
            }

            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())

        CVDisplayLinkStart(displayLink)
    }

    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
        fadeTimer?.invalidate()
    }

    private func initializeCharacterPositions() {
        NSLog("🎯 Initializing character positions")
        let screenWidth = bounds.width
        let screenHeight = bounds.height

        NSLog("📏 Screen dimensions: \(screenWidth) x \(screenHeight)")

        let startPositions = generateNonOverlappingPositions(screenWidth: screenWidth, screenHeight: screenHeight)

        for (index, position) in startPositions.enumerated() {
            if index < characters.count {
                characters[index].position = position.position
                characters[index].edge = position.edge
                characters[index].angle = position.angle
                NSLog("📍 Positioned character \(index) at: \(position.position)")
                
                // Start fade in animation for each character with a slight delay
                let delay = Double(index) * 0.75  // Stagger the fade-ins
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.startFadeAnimation(for: self?.characters[index].characterType ?? "", fadingIn: true)
                }
            }
        }

        NSLog("✅ Finished positioning \(characters.count) characters")
    }

    private func setupCharacters() {
        // Only run if we haven't initialized and now have valid bounds
        if !charactersInitialized && bounds.width > 0 && bounds.height > 0 {
            let screenWidth = bounds.width
            let screenHeight = bounds.height
            let startPositions = generateNonOverlappingPositions(screenWidth: screenWidth, screenHeight: screenHeight)

            // Update positions for any characters that weren't properly positioned initially
            for (index, start) in startPositions.enumerated() {
                if index < characters.count {
                    characters[index].position = start.position
                    characters[index].edge = start.edge
                    characters[index].angle = start.angle
                }
            }

            charactersInitialized = true
        }
    }

    private func generateNonOverlappingPositions(screenWidth: CGFloat, screenHeight: CGFloat) -> [(position: CGPoint, edge: Int, angle: CGFloat)] {
        NSLog("🎲 Generating positions for screen: \(screenWidth) x \(screenHeight)")
        var positions: [(position: CGPoint, edge: Int, angle: CGFloat)] = []
        let numberOfCharacters = characters.count
        let offset = smallerScreenDimension * ScreenPercentages.edgeOffset  // Use the same offset calculation as movement

        for i in 0..<numberOfCharacters {
            var newPosition: CGPoint
            var angle: CGFloat
            var edge: Int
            var isValidPosition: Bool
            var attempts = 0

            repeat {
                attempts += 1
                isValidPosition = true
                edge = Int.random(in: 0...3)

                switch edge {
                case 0: // Bottom edge
                    let posAlongEdge = CGFloat.random(in: 0...screenWidth)
                    newPosition = CGPoint(x: posAlongEdge, y: offset)
                    angle = 0
                case 1: // Right edge
                    let posAlongEdge = CGFloat.random(in: 0...screenHeight)
                    newPosition = CGPoint(x: screenWidth - offset, y: posAlongEdge)
                    angle = CGFloat.pi / 2
                case 2: // Top edge
                    let posAlongEdge = CGFloat.random(in: 0...screenWidth)
                    newPosition = CGPoint(x: posAlongEdge, y: screenHeight - offset)
                    angle = CGFloat.pi
                case 3: // Left edge
                    let posAlongEdge = CGFloat.random(in: 0...screenHeight)
                    newPosition = CGPoint(x: offset, y: posAlongEdge)
                    angle = 3 * CGFloat.pi / 2
                default:
                    newPosition = .zero
                    angle = 0
                }

                // Check minimum distance from other characters
                for existingPosition in positions {
                    let distance = hypot(newPosition.x - existingPosition.position.x,
                                         newPosition.y - existingPosition.position.y)
                    if distance < minDistance {
                        isValidPosition = false
                        break
                    }
                }

                if attempts > 100 {
                    NSLog("⚠️ Too many attempts for position \(i), using last generated position")
                    isValidPosition = true
                }

            } while !isValidPosition

            NSLog("📍 Generated position \(i): x=\(newPosition.x), y=\(newPosition.y), edge=\(edge)")
            positions.append((position: newPosition, edge: edge, angle: angle))
        }
        
        return positions
    }

    private func addNewCharacter(ofType type: String) {
        guard availableCharacterTypes.contains(type),
              let frames = characterAnimations[type] else {
            NSLog("❌ Cannot add character: type not available or no frames found")
            return
        }

        NSLog("📥 Loading images for new character: \(type)")
        var images: [NSImage] = []
        for frameName in frames {
            if let image = imageCache.loadImage(named: frameName) {
                images.append(image)
            }
        }

        if images.isEmpty {
            NSLog("❌ No images loaded for character \(type)")
            return
        }

        // Generate a new position ensuring no overlap
        let screenWidth = bounds.width
        let screenHeight = bounds.height
        let offset = smallerScreenDimension * ScreenPercentages.edgeOffset

        var newPosition: CGPoint
        var angle: CGFloat
        var edge: Int
        var isValidPosition = false
        var attempts = 0
        let maxAttempts = 200  // Increased from 100 to 200

        repeat {
            attempts += 1
            edge = Int.random(in: 0...3)

            switch edge {
            case 0: // Bottom edge
                let posAlongEdge = CGFloat.random(in: 0...screenWidth)
                newPosition = CGPoint(x: posAlongEdge, y: offset)
                angle = 0
            case 1: // Right edge
                let posAlongEdge = CGFloat.random(in: 0...screenHeight)
                newPosition = CGPoint(x: screenWidth - offset, y: posAlongEdge)
                angle = CGFloat.pi / 2
            case 2: // Top edge
                let posAlongEdge = CGFloat.random(in: 0...screenWidth)
                newPosition = CGPoint(x: posAlongEdge, y: screenHeight - offset)
                angle = CGFloat.pi
            case 3: // Left edge
                let posAlongEdge = CGFloat.random(in: 0...screenHeight)
                newPosition = CGPoint(x: offset, y: posAlongEdge)
                angle = 3 * CGFloat.pi / 2
            default:
                newPosition = .zero
                angle = 0
            }

            // More thorough overlap check
            isValidPosition = true
            for existingCharacter in self.characters {
                let distance = hypot(newPosition.x - existingCharacter.position.x, 
                                     newPosition.y - existingCharacter.position.y)
                
                // Add a buffer zone around the minimum distance
                let safeDistance = self.minDistance * 1.1
                if distance < safeDistance {
                    isValidPosition = false
                    break
                }
            }

            if attempts > maxAttempts {
                NSLog("⚠️ Could not find non-overlapping position after \(maxAttempts) attempts")
                return  // Instead of using potentially overlapping position, skip adding the character
            }
        } while !isValidPosition

        // Only proceed if we found a valid position
        if isValidPosition {
            let newCharacter = Character(
                position: newPosition,
                edge: edge,
                angle: angle,
                images: images,
                opacity: 0.0,
                isActive: true,
                characterType: type
            )

            characters.append(newCharacter)
            activeCharacterTypes.insert(type)
            availableCharacterTypes.remove(type)
            
            NSLog("✨ Added new character \(type) at position: \(newPosition)")
            startFadeAnimation(for: type, fadingIn: true)
        }
    }
}
