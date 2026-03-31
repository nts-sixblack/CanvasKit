#if canImport(UIKit)
import CoreImage
import UIKit
import CanvasKitCore

enum CanvasFilterProcessor {
    private static let context = CIContext(options: nil)

    static var isAvailable: Bool {
        true
    }

    static func apply(_ preset: CanvasFilterPreset, to image: UIImage) -> UIImage {
        guard preset.usesImageFiltering else {
            return image
        }

        guard let cgImage = image.cgImage else {
            return image
        }

        let inputImage = CIImage(cgImage: cgImage)
        let outputImage = autoreleasepool {
            filteredImage(for: preset, inputImage: inputImage) ?? inputImage
        }

        guard let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func filteredImage(for preset: CanvasFilterPreset, inputImage: CIImage) -> CIImage? {
        switch preset {
        case .normal:
            return inputImage
        case .autoFix:
            return applyChain(
                to: inputImage,
                steps: [
                    { applyingHighlightShadow(to: $0, shadowAmount: 0.25, highlightAmount: 0.15) },
                    { applyingColorControls(to: $0, contrast: 1.08) },
                    { applyingColorControls(to: $0, saturation: 1.06) }
                ]
            )
        case .vibrant:
            return applyingVibrance(to: inputImage, amount: 0.75)
        case .punch:
            return applyChain(
                to: inputImage,
                steps: [
                    { applyingVibrance(to: $0, amount: 0.55) },
                    { applyingColorControls(to: $0, saturation: 1.12, contrast: 1.12) },
                    { applyingSharpen(to: $0, sharpness: 0.18) }
                ]
            )
        case .soft:
            return applyChain(
                to: inputImage,
                steps: [
                    { applyingBloom(to: $0, intensity: 0.35, radius: 10) },
                    { applyingColorControls(to: $0, saturation: 0.97, brightness: 0.04, contrast: 0.96) }
                ]
            )
        case .matte:
            return applyChain(
                to: inputImage,
                steps: [
                    { applyingHighlightShadow(to: $0, shadowAmount: 0.42, highlightAmount: 0.06) },
                    { applyingColorControls(to: $0, saturation: 0.95, brightness: 0.02, contrast: 0.92) },
                    { applyingVibrance(to: $0, amount: 0.18) }
                ]
            )
        case .warm:
            return applyingTemperature(to: inputImage, targetNeutral: CIVector(x: 7_500, y: 0))
        case .cool:
            return applyingTemperature(to: inputImage, targetNeutral: CIVector(x: 5_600, y: 0))
        case .brightness:
            return applyingColorControls(to: inputImage, brightness: 0.08)
        case .contrast:
            return applyingColorControls(to: inputImage, contrast: 1.18)
        case .saturation:
            return applyingColorControls(to: inputImage, saturation: 1.18)
        case .mono:
            return applyingMonochrome(
                to: inputImage,
                color: CIColor(red: 0.78, green: 0.76, blue: 0.72),
                intensity: 1
            )
        case .noir:
            return applyingPhotoEffect(named: "CIPhotoEffectNoir", to: inputImage)
        case .sepia:
            return applyingSepia(to: inputImage, intensity: 0.82)
        case .fade:
            return applyingPhotoEffect(named: "CIPhotoEffectFade", to: inputImage)
        case .chrome:
            return applyingPhotoEffect(named: "CIPhotoEffectChrome", to: inputImage)
        case .instant:
            return applyingPhotoEffect(named: "CIPhotoEffectInstant", to: inputImage)
        case .transfer:
            return applyingPhotoEffect(named: "CIPhotoEffectTransfer", to: inputImage)
        case .bloom:
            return applyChain(
                to: inputImage,
                steps: [
                    { applyingBloom(to: $0, intensity: 0.55, radius: 12) },
                    { applyingColorControls(to: $0, contrast: 1.03) }
                ]
            )
        case .sharpen:
            return applyingSharpen(to: inputImage, sharpness: 0.35)
        case .vignette:
            return applyingVignette(to: inputImage, intensity: 0.9, radius: 1.5)
        }
    }

    private static func applyChain(
        to inputImage: CIImage,
        steps: [(CIImage) -> CIImage?]
    ) -> CIImage? {
        var currentImage = inputImage

        for step in steps {
            guard let nextImage = step(currentImage) else {
                return nil
            }
            currentImage = nextImage
        }

        return currentImage
    }

    private static func applyingColorControls(
        to image: CIImage,
        saturation: CGFloat? = nil,
        brightness: CGFloat? = nil,
        contrast: CGFloat? = nil
    ) -> CIImage? {
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(image, forKey: kCIInputImageKey)
        if let saturation {
            filter?.setValue(saturation, forKey: kCIInputSaturationKey)
        }
        if let brightness {
            filter?.setValue(brightness, forKey: kCIInputBrightnessKey)
        }
        if let contrast {
            filter?.setValue(contrast, forKey: kCIInputContrastKey)
        }
        return filter?.outputImage
    }

    private static func applyingVibrance(to image: CIImage, amount: CGFloat) -> CIImage? {
        let filter = CIFilter(name: "CIVibrance")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(amount, forKey: "inputAmount")
        return filter?.outputImage
    }

    private static func applyingPhotoEffect(named filterName: String, to image: CIImage) -> CIImage? {
        let filter = CIFilter(name: filterName)
        filter?.setValue(image, forKey: kCIInputImageKey)
        return filter?.outputImage
    }

    private static func applyingHighlightShadow(
        to image: CIImage,
        shadowAmount: CGFloat,
        highlightAmount: CGFloat
    ) -> CIImage? {
        let filter = CIFilter(name: "CIHighlightShadowAdjust")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(shadowAmount, forKey: "inputShadowAmount")
        filter?.setValue(highlightAmount, forKey: "inputHighlightAmount")
        return filter?.outputImage
    }

    private static func applyingTemperature(
        to image: CIImage,
        targetNeutral: CIVector
    ) -> CIImage? {
        let filter = CIFilter(name: "CITemperatureAndTint")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(x: 6_500, y: 0), forKey: "inputNeutral")
        filter?.setValue(targetNeutral, forKey: "inputTargetNeutral")
        return filter?.outputImage
    }

    private static func applyingMonochrome(
        to image: CIImage,
        color: CIColor,
        intensity: CGFloat
    ) -> CIImage? {
        let filter = CIFilter(name: "CIColorMonochrome")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(color, forKey: kCIInputColorKey)
        filter?.setValue(intensity, forKey: kCIInputIntensityKey)
        return filter?.outputImage
    }

    private static func applyingSepia(to image: CIImage, intensity: CGFloat) -> CIImage? {
        let filter = CIFilter(name: "CISepiaTone")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(intensity, forKey: kCIInputIntensityKey)
        return filter?.outputImage
    }

    private static func applyingBloom(
        to image: CIImage,
        intensity: CGFloat,
        radius: CGFloat
    ) -> CIImage? {
        let filter = CIFilter(name: "CIBloom")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(intensity, forKey: kCIInputIntensityKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        return filter?.outputImage
    }

    private static func applyingSharpen(to image: CIImage, sharpness: CGFloat) -> CIImage? {
        let filter = CIFilter(name: "CISharpenLuminance")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(sharpness, forKey: kCIInputSharpnessKey)
        return filter?.outputImage
    }

    private static func applyingVignette(
        to image: CIImage,
        intensity: CGFloat,
        radius: CGFloat
    ) -> CIImage? {
        let filter = CIFilter(name: "CIVignette")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(intensity, forKey: kCIInputIntensityKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        return filter?.outputImage
    }
}
#endif
