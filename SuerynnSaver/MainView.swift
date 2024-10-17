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
    }

    private var characters: [Character] = []
    private var squareSize: CGFloat = 0
    private var imageSize: CGFloat = 0
    private let speed: CGFloat = 2.0
    private let cornerRadius: CGFloat = 20.0
    private let frameDelay: Int = 4
    private var edgeOffset: CGFloat = -6.0
    private var charactersInitialized = false
    private let minDistance: CGFloat = 100.0 // Minimum distance between characters

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        loadImagesFromJSON()
        animationTimeInterval = 1.0 / 30.0
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

        for (name, frames) in animations {
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
        self.imageSize = squareSize * 1.5

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
        switch character.edge {
        case 0:
            character.position.x += speed
            if character.position.x >= bounds.width - cornerRadius - edgeOffset {
                character.angle = lerpAngle(character.angle, target: CGFloat.pi / 2, t: 0.05)
                if character.position.x >= bounds.width - edgeOffset {
                    character.edge = 1
                    character.angle = CGFloat.pi / 2
                }
            }
        case 1:
            character.position.y += speed
            if character.position.y >= bounds.height - cornerRadius - edgeOffset {
                character.angle = lerpAngle(character.angle, target: CGFloat.pi, t: 0.05)
                if character.position.y >= bounds.height - edgeOffset {
                    character.edge = 2
                    character.angle = CGFloat.pi
                }
            }
        case 2:
            character.position.x -= speed
            if character.position.x <= cornerRadius + edgeOffset {
                character.angle = lerpAngle(character.angle, target: 3 * CGFloat.pi / 2, t: 0.05)
                if character.position.x <= edgeOffset {
                    character.edge = 3
                    character.angle = 3 * CGFloat.pi / 2
                }
            }
        case 3:
            character.position.y -= speed
            if character.position.y <= cornerRadius + edgeOffset {
                character.angle = lerpAngle(character.angle, target: 0, t: 0.05)
                if character.position.y <= edgeOffset {
                    character.edge = 0
                    character.angle = 0
                }
            }
        default:
            break
        }
    }

    private func lerpAngle(_ angle: CGFloat, target: CGFloat, t: CGFloat) -> CGFloat {
        return angle + (target - angle) * t
    }
}
