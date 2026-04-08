#!/usr/bin/env swift
import AppKit

let width = 660
let height = 400
let size = NSSize(width: width, height: height)

let image = NSImage(size: size)
image.lockFocus()

// Background gradient
let gradient = NSGradient(starting: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0),
                          ending: NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))!
gradient.draw(in: NSRect(origin: .zero, size: size), angle: 270)

// Arrow
let arrowPath = NSBezierPath()
let arrowY = CGFloat(height) / 2.0 + 10
let arrowLeft: CGFloat = 250
let arrowRight: CGFloat = 410

// Shaft
arrowPath.move(to: NSPoint(x: arrowLeft, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowRight - 30, y: arrowY))
arrowPath.lineWidth = 3

NSColor(red: 0.85, green: 0.65, blue: 0.2, alpha: 0.6).setStroke()
arrowPath.stroke()

// Arrowhead
let headPath = NSBezierPath()
headPath.move(to: NSPoint(x: arrowRight - 40, y: arrowY + 15))
headPath.line(to: NSPoint(x: arrowRight - 15, y: arrowY))
headPath.line(to: NSPoint(x: arrowRight - 40, y: arrowY - 15))
headPath.lineWidth = 3
headPath.lineCapStyle = .round
headPath.lineJoinStyle = .round
headPath.stroke()

// Instruction text
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center

let textAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: NSColor(red: 0.85, green: 0.65, blue: 0.2, alpha: 0.8),
    .paragraphStyle: paragraphStyle
]
let text = "Drag Upkeep to Applications" as NSString
let textSize = text.size(withAttributes: textAttrs)
let textRect = NSRect(
    x: (CGFloat(width) - textSize.width) / 2,
    y: arrowY - 60,
    width: textSize.width,
    height: textSize.height
)
text.draw(in: textRect, withAttributes: textAttrs)

image.unlockFocus()

// Save as PNG
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to create image")
    exit(1)
}

let outputPath = "dmg-background.png"
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Created \(outputPath) (\(width)x\(height))")
