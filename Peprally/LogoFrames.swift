import UIKit

/// The peprally mark animation as a bundled frame sequence — decoded once,
/// shared by every view that plays it.
enum LogoFrames {
    static let all: [UIImage] = {
        var images: [UIImage] = []
        var i = 1
        while let url = Bundle.main.url(forResource: String(format: "frame_%03d", i),
                                        withExtension: "png",
                                        subdirectory: "logo-frames"),
              let image = UIImage(contentsOfFile: url.path) {
            images.append(image)
            i += 1
        }
        return images
    }()

    static let fps: Double = 15

    static func frame(at t: TimeInterval) -> UIImage? {
        guard !all.isEmpty else { return nil }
        return all[Int(t * fps) % all.count]
    }
}
