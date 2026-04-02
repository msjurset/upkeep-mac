#!/usr/bin/env swift

import AppKit
import CoreGraphics

/// Generates a macOS app icon with a house + wrench design in warm amber tones.
func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let inset = size * 0.05
    let roundedRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let cornerRadius = size * 0.22

    // Background: warm amber gradient
    let bgPath = CGPath(roundedRect: roundedRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(bgPath)
    context.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.80, green: 0.55, blue: 0.18, alpha: 1.0),
        CGColor(red: 0.55, green: 0.32, blue: 0.10, alpha: 1.0),
    ]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors as CFArray, locations: [0.0, 1.0]) {
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: size),
                                   end: CGPoint(x: size, y: 0),
                                   options: [])
    }

    let center = CGPoint(x: size / 2, y: size / 2)

    // House body (pentagon shape)
    let houseWidth = size * 0.48
    let houseHeight = size * 0.30
    let houseBottom = center.y - size * 0.18
    let houseLeft = center.x - houseWidth / 2
    let roofPeak = houseBottom + houseHeight + size * 0.16

    // Roof (triangle)
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    context.move(to: CGPoint(x: houseLeft - size * 0.06, y: houseBottom + houseHeight))
    context.addLine(to: CGPoint(x: center.x, y: roofPeak))
    context.addLine(to: CGPoint(x: houseLeft + houseWidth + size * 0.06, y: houseBottom + houseHeight))
    context.closePath()
    context.fillPath()

    // House walls
    let wallRect = CGRect(x: houseLeft, y: houseBottom, width: houseWidth, height: houseHeight)
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.90))
    context.fill(wallRect)

    // Door
    let doorWidth = size * 0.10
    let doorHeight = size * 0.16
    let doorLeft = center.x - doorWidth / 2
    let doorRect = CGRect(x: doorLeft, y: houseBottom, width: doorWidth, height: doorHeight)
    context.setFillColor(CGColor(red: 0.70, green: 0.45, blue: 0.18, alpha: 0.85))
    context.fill(doorRect)

    // Door knob
    let knobSize = size * 0.018
    let knobX = doorLeft + doorWidth * 0.72
    let knobY = houseBottom + doorHeight * 0.45
    context.setFillColor(CGColor(red: 0.90, green: 0.75, blue: 0.45, alpha: 1.0))
    context.fillEllipse(in: CGRect(x: knobX - knobSize / 2, y: knobY - knobSize / 2,
                                    width: knobSize, height: knobSize))

    // Window (left)
    let winSize = size * 0.08
    let winY = houseBottom + houseHeight * 0.45
    let winLeftX = houseLeft + size * 0.06
    context.setFillColor(CGColor(red: 0.55, green: 0.75, blue: 0.92, alpha: 0.8))
    context.fill(CGRect(x: winLeftX, y: winY, width: winSize, height: winSize))
    // Window panes
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
    context.setLineWidth(size * 0.008)
    context.move(to: CGPoint(x: winLeftX + winSize / 2, y: winY))
    context.addLine(to: CGPoint(x: winLeftX + winSize / 2, y: winY + winSize))
    context.move(to: CGPoint(x: winLeftX, y: winY + winSize / 2))
    context.addLine(to: CGPoint(x: winLeftX + winSize, y: winY + winSize / 2))
    context.strokePath()

    // Window (right)
    let winRightX = houseLeft + houseWidth - size * 0.06 - winSize
    context.setFillColor(CGColor(red: 0.55, green: 0.75, blue: 0.92, alpha: 0.8))
    context.fill(CGRect(x: winRightX, y: winY, width: winSize, height: winSize))
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
    context.setLineWidth(size * 0.008)
    context.move(to: CGPoint(x: winRightX + winSize / 2, y: winY))
    context.addLine(to: CGPoint(x: winRightX + winSize / 2, y: winY + winSize))
    context.move(to: CGPoint(x: winRightX, y: winY + winSize / 2))
    context.addLine(to: CGPoint(x: winRightX + winSize, y: winY + winSize / 2))
    context.strokePath()

    // Wrench overlay (bottom-right)
    let wrenchCenterX = center.x + size * 0.20
    let wrenchCenterY = houseBottom - size * 0.04
    let badgeRadius = size * 0.11

    // Badge circle
    context.setFillColor(CGColor(red: 0.25, green: 0.70, blue: 0.40, alpha: 0.95))
    context.fillEllipse(in: CGRect(x: wrenchCenterX - badgeRadius, y: wrenchCenterY - badgeRadius,
                                    width: badgeRadius * 2, height: badgeRadius * 2))

    // Wrench icon (simplified)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1.0))
    context.setLineWidth(size * 0.018)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // Wrench shaft (diagonal line)
    let shaftLen = badgeRadius * 0.55
    context.move(to: CGPoint(x: wrenchCenterX - shaftLen, y: wrenchCenterY - shaftLen))
    context.addLine(to: CGPoint(x: wrenchCenterX + shaftLen * 0.3, y: wrenchCenterY + shaftLen * 0.3))
    context.strokePath()

    // Wrench head (small arc at top-right)
    let headR = badgeRadius * 0.25
    let headCenter = CGPoint(x: wrenchCenterX + shaftLen * 0.3, y: wrenchCenterY + shaftLen * 0.3)
    context.addArc(center: headCenter, radius: headR, startAngle: .pi * 0.75, endAngle: .pi * 2.25, clockwise: false)
    context.strokePath()

    image.unlockFocus()
    return image
}

let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

let iconsetPath = "AppIcon.iconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let image = renderIcon(size: size)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(name)")
        continue
    }
    let path = "\(iconsetPath)/\(name).png"
    try! pngData.write(to: URL(fileURLWithPath: path))
    print("Generated \(path) (\(Int(size))x\(Int(size)))")
}

print("\nConverting to .icns...")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Created AppIcon.icns")
} else {
    print("iconutil failed")
}

try? fm.removeItem(atPath: iconsetPath)
