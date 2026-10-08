import AppKit

let size: CGFloat = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
let tile = NSBezierPath(roundedRect: canvas.insetBy(dx: 64, dy: 64), xRadius: 212, yRadius: 212)
NSGradient(starting: NSColor(calibratedRed: 0.075, green: 0.13, blue: 0.19, alpha: 1),
           ending: NSColor(calibratedRed: 0.025, green: 0.06, blue: 0.105, alpha: 1))!
    .draw(in: tile, angle: -90)

// The top capsule is a quiet, unmistakable reference to the Mac notch.
NSColor(calibratedRed: 0, green: 0.015, blue: 0.035, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 255, y: 699, width: 514, height: 118),
             xRadius: 59, yRadius: 59).fill()
NSColor(calibratedRed: 0.18, green: 0.38, blue: 0.43, alpha: 1).setStroke()
let notchOutline = NSBezierPath(roundedRect: NSRect(x: 257, y: 701, width: 510, height: 114),
                                xRadius: 57, yRadius: 57)
notchOutline.lineWidth = 5
notchOutline.stroke()

let center = NSPoint(x: 512, y: 407)
let radius: CGFloat = 195
let track = NSBezierPath()
track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
track.lineWidth = 48
NSColor(calibratedRed: 0.17, green: 0.29, blue: 0.34, alpha: 1).setStroke()
track.stroke()

// Three quarters complete: a focus timer, not a generic clock app.
let progress = NSBezierPath()
progress.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: -180, clockwise: true)
progress.lineWidth = 48
progress.lineCapStyle = .round
NSColor(calibratedRed: 0.17, green: 0.91, blue: 0.76, alpha: 1).setStroke()
progress.stroke()

let hand = NSBezierPath()
hand.move(to: center)
hand.line(to: NSPoint(x: 512, y: 532))
hand.move(to: center)
hand.line(to: NSPoint(x: 605, y: 356))
hand.lineWidth = 31
hand.lineCapStyle = .round
hand.lineJoinStyle = .round
NSColor.white.setStroke()
hand.stroke()
NSColor.white.setFill()
NSBezierPath(ovalIn: NSRect(x: 488, y: 383, width: 48, height: 48)).fill()

NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: output, options: .atomic)
