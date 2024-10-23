import ScreenSaver
import AppKit

class ImageCacheManager {
    static let shared = ImageCacheManager()
    private var imageCache: [String: NSImage] = [:]

    func loadImage(named name: String) -> NSImage? {
        if let cachedImage = imageCache[name] {
            return cachedImage
        }
        if let image = NSImage(named: name) {
            imageCache[name] = image
            return image
        }
        return nil
    }
}

class MainView: ScreenSaverView {
    private struct Character {
        var position: CGPoint
        var edge: Int       // 0 = bottom, 1 = right, 2 = top, 3 = left
        var angle: CGFloat
        var images: [NSImage]
        var currentFrame: Int = 0
        var frameDelayCounter: Int = 0
        var state: MovementState = .movingAlongEdge
    }
    
    private enum MovementState {
        case movingAlongEdge
        case movingAlongCorner(arcCenter: CGPoint, endAngle: CGFloat, currentAngle: CGFloat, angleIncrement: CGFloat)
    }

    private var characters: [Character] = []
    private var squareSize: CGFloat = 0
    private var imageSize: CGFloat = 0
    private let edgeSpeed: CGFloat = 2.0
    private var cornerSpeed: CGFloat {
        return edgeSpeed * 4.0 // Further increase corner speed
    }
    private let cornerRadius: CGFloat = 120.0 // Updated radius to 100
    private let frameDelay: Int = 4
    private var edgeOffset: CGFloat = -5.0 // Set to 0.0 to avoid misalignment
    private var charactersInitialized = false
    private let minDistance: CGFloat = 100.0 // Minimum distance between characters

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        loadImagesFromJSON()
        animationTimeInterval = 1.0 / 30.0 // Adjust to 1/60.0 for smoother animation if needed
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func loadImagesFromJSON() {
        guard let url = Bundle.main.url(forResource: "characters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let animations = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return
        }

        for (_, frames) in animations {
            var images: [NSImage] = []
            for frameName in frames {
                if let image = ImageCacheManager.shared.loadImage(named: frameName) {
                    images.append(image)
                }
            }
            if !images.isEmpty {
                characters.append(Character(position: .zero, edge: 0, angle: 0, images: images))
            }
        }
    }

    private func setupCharacters() {
        guard !charactersInitialized else { return }
        charactersInitialized = true

        self.squareSize = bounds.height * 0.1
        self.imageSize = squareSize * 1.05

        let screenWidth = bounds.width
        let screenHeight = bounds.height
        let startPositions = generateNonOverlappingPositions(screenWidth: screenWidth, screenHeight: screenHeight)

        for (index, start) in startPositions.enumerated() {
            if index < characters.count {
                characters[index].position = start.position
                characters[index].edge = start.edge
                characters[index].angle = start.angle
            }
        }
    }

    private func generateNonOverlappingPositions(screenWidth: CGFloat, screenHeight: CGFloat) -> [(position: CGPoint, edge: Int, angle: CGFloat)] {
        var positions: [(position: CGPoint, edge: Int, angle: CGFloat)] = []

        for _ in 0..<characters.count {
            var newPosition: CGPoint
            var angle: CGFloat
            var edge: Int
            var isValidPosition: Bool

            repeat {
                isValidPosition = true
                edge = Int.random(in: 0...3)
                switch edge {
                case 0:
                    let posAlongEdge = CGFloat.random(in: edgeOffset...(screenWidth - edgeOffset))
                    newPosition = CGPoint(x: posAlongEdge, y: edgeOffset)
                    angle = 0
                case 1:
                    let posAlongEdge = CGFloat.random(in: edgeOffset...(screenHeight - edgeOffset))
                    newPosition = CGPoint(x: screenWidth - edgeOffset, y: posAlongEdge)
                    angle = CGFloat.pi / 2
                case 2:
                    let posAlongEdge = CGFloat.random(in: edgeOffset...(screenWidth - edgeOffset))
                    newPosition = CGPoint(x: posAlongEdge, y: screenHeight - edgeOffset)
                    angle = CGFloat.pi
                case 3:
                    let posAlongEdge = CGFloat.random(in: edgeOffset...(screenHeight - edgeOffset))
                    newPosition = CGPoint(x: edgeOffset, y: posAlongEdge)
                    angle = 3 * CGFloat.pi / 2
                default:
                    newPosition = CGPoint.zero
                    angle = 0
                }

                for previousPosition in positions {
                    let distance = hypot(newPosition.x - previousPosition.position.x, newPosition.y - previousPosition.position.y)
                    if distance < minDistance {
                        isValidPosition = false
                        break
                    }
                }
            } while !isValidPosition

            positions.append((position: newPosition, edge: edge, angle: angle))
        }
        return positions
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)
        NSColor.black.setFill()
        bounds.fill()

        // Removed the red stroke path
        // drawPathWithRoundedCorners()

        for character in characters {
            drawCharacter(character)
        }
    }

    private func drawCharacter(_ character: Character) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        context.translateBy(x: character.position.x, y: character.position.y)
        context.rotate(by: character.angle)

        let image = character.images[character.currentFrame]
        image.draw(in: CGRect(x: -imageSize / 2, y: 0, width: imageSize, height: imageSize))

        context.restoreGState()
    }

    override func animateOneFrame() {
        if !charactersInitialized && bounds.width > 0 && bounds.height > 0 {
            setupCharacters()
        }

        if charactersInitialized {
            for i in 0..<characters.count {
                animateCharacter(&characters[i])
                moveCharacter(&characters[i])
            }
        }

        setNeedsDisplay(bounds)
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
                    let arcCenter = CGPoint(x: bounds.width - cornerRadius - edgeOffset, y: cornerRadius + edgeOffset)
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
                    let arcCenter = CGPoint(x: bounds.width - cornerRadius - edgeOffset, y: bounds.height - cornerRadius - edgeOffset)
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
                    let arcCenter = CGPoint(x: cornerRadius + edgeOffset, y: bounds.height - cornerRadius - edgeOffset)
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
                    let arcCenter = CGPoint(x: cornerRadius + edgeOffset, y: cornerRadius + edgeOffset)
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
}
