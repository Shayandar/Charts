//
//  Utils.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  Licensed under Apache License 2.0
//

import Foundation
import CoreGraphics

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

extension FloatingPoint {
    var DEG2RAD: Self {
        return self * .pi / 180
    }

    var RAD2DEG: Self {
        return self * 180 / .pi
    }

    /// - Note: Value must be in degrees
    /// - Returns: An angle between 0.0 < 360.0 (not less than zero, less than 360)
    var normalizedAngle: Self {
        let angle = truncatingRemainder(dividingBy: 360)
        return (sign == .minus) ? angle + 360 : angle
    }
}

extension CGSize {
    func rotatedBy(degrees: CGFloat) -> CGSize {
        return rotatedBy(radians: degrees.DEG2RAD)
    }

    func rotatedBy(radians: CGFloat) -> CGSize {
        return CGSize(
            width: abs(width * cos(radians)) + abs(height * sin(radians)),
            height: abs(width * sin(radians)) + abs(height * cos(radians))
        )
    }
}

extension Double {
    /// Rounds the number to the nearest multiple of its order of magnitude, rounding away from zero if halfway.
    func roundedToNextSignificant() -> Double {
        guard !isInfinite, !isNaN, self != 0 else { return self }
        let d = ceil(log10(abs(self)))
        let pw = 1 - Int(d)
        let magnitude = pow(10.0, Double(pw))
        let shifted = (self * magnitude).rounded()
        return shifted / magnitude
    }

    var decimalPlaces: Int {
        guard !isNaN, !isInfinite, self != 0 else { return 0 }
        let i = roundedToNextSignificant()
        guard !i.isInfinite, !i.isNaN else { return 0 }
        return Int(ceil(-log10(i))) + 2
    }
}

extension CGPoint {
    /// Calculates the position around a center point, depending on the distance from the center, and the angle of the position around the center.
    func moving(distance: CGFloat, atAngle angle: CGFloat) -> CGPoint {
        return CGPoint(
            x: x + distance * cos(angle.DEG2RAD),
            y: y + distance * sin(angle.DEG2RAD)
        )
    }
}

extension CGContext {
    public func drawImage(_ image: NSUIImage, atCenter center: CGPoint, size: CGSize) {
        var drawOffset = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        NSUIGraphicsPushContext(self)

        if image.size != size {
            let key = "resized_\(size.width)_\(size.height)"
            var scaledImage = objc_getAssociatedObject(image, key) as? NSUIImage

            if scaledImage == nil {
                NSUIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                image.draw(in: CGRect(origin: .zero, size: size))
                scaledImage = NSUIGraphicsGetImageFromCurrentImageContext()
                NSUIGraphicsEndImageContext()
                objc_setAssociatedObject(image, key, scaledImage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }

            scaledImage?.draw(in: CGRect(origin: drawOffset, size: size))
        } else {
            image.draw(in: CGRect(origin: drawOffset, size: size))
        }

        NSUIGraphicsPopContext()
    }

    public func drawText(_ text: String, at point: CGPoint, align: TextAlignment, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5), angleRadians: CGFloat = 0.0, attributes: [NSAttributedString.Key: Any]?) {
        let drawPoint = getDrawPoint(text: text, point: point, align: align, attributes: attributes)

        if angleRadians == 0.0 {
            NSUIGraphicsPushContext(self)
            (text as NSString).draw(at: drawPoint, withAttributes: attributes)
            NSUIGraphicsPopContext()
        } else {
            drawText(text, at: drawPoint, anchor: anchor, angleRadians: angleRadians, attributes: attributes)
        }
    }

    public func drawText(_ text: String, at point: CGPoint, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5), angleRadians: CGFloat, attributes: [NSAttributedString.Key: Any]?) {
        var drawOffset = CGPoint()
        NSUIGraphicsPushContext(self)

        if angleRadians != 0.0 {
            let size = text.size(withAttributes: attributes)
            drawOffset = CGPoint(x: -size.width * 0.5, y: -size.height * 0.5)
            var translate = point

            if anchor.x != 0.5 || anchor.y != 0.5 {
                let rotatedSize = size.rotatedBy(radians: angleRadians)
                translate.x -= rotatedSize.width * (anchor.x - 0.5)
                translate.y -= rotatedSize.height * (anchor.y - 0.5)
            }

            saveGState()
            translateBy(x: translate.x, y: translate.y)
            rotate(by: angleRadians)
            (text as NSString).draw(at: drawOffset, withAttributes: attributes)
            restoreGState()
        } else {
            if anchor.x != 0.0 || anchor.y != 0.0 {
                let size = text.size(withAttributes: attributes)
                drawOffset = CGPoint(x: -size.width * anchor.x, y: -size.height * anchor.y)
            }

            drawOffset.x += point.x
            drawOffset.y += point.y
            (text as NSString).draw(at: drawOffset, withAttributes: attributes)
        }

        NSUIGraphicsPopContext()
    }

    private func getDrawPoint(text: String, point: CGPoint, align: TextAlignment, attributes: [NSAttributedString.Key: Any]?) -> CGPoint {
        var point = point
        let width = text.size(withAttributes: attributes).width
        switch align {
        case .center:
            point.x -= width / 2.0
        case .right:
            point.x -= width
        default:
            break
        }
        return point
    }

    func drawMultilineText(_ text: String, at point: CGPoint, constrainedTo size: CGSize, anchor: CGPoint, knownTextSize: CGSize, angleRadians: CGFloat, attributes: [NSAttributedString.Key: Any]?) {
        var rect = CGRect(origin: .zero, size: knownTextSize)
        NSUIGraphicsPushContext(self)

        if angleRadians != 0.0 {
            rect.origin.x = -knownTextSize.width * 0.5
            rect.origin.y = -knownTextSize.height * 0.5

            var translate = point
            if anchor.x != 0.5 || anchor.y != 0.5 {
                let rotatedSize = knownTextSize.rotatedBy(radians: angleRadians)
                translate.x -= rotatedSize.width * (anchor.x - 0.5)
                translate.y -= rotatedSize.height * (anchor.y - 0.5)
            }

            saveGState()
            translateBy(x: translate.x, y: translate.y)
            rotate(by: angleRadians)
            (text as NSString).draw(with: rect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            restoreGState()
        } else {
            if anchor.x != 0.0 || anchor.y != 0.0 {
                rect.origin.x = -knownTextSize.width * anchor.x
                rect.origin.y = -knownTextSize.height * anchor.y
            }

            rect.origin.x += point.x
            rect.origin.y += point.y
            (text as NSString).draw(with: rect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        }

        NSUIGraphicsPopContext()
    }

    func drawMultilineText(_ text: String, at point: CGPoint, constrainedTo size: CGSize, anchor: CGPoint, angleRadians: CGFloat, attributes: [NSAttributedString.Key: Any]?) {
        let rect = text.boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        drawMultilineText(text, at: point, constrainedTo: size, anchor: anchor, knownTextSize: rect.size, angleRadians: angleRadians, attributes: attributes)
    }
}
