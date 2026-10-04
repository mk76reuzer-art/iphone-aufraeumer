import AVFoundation
import CoreGraphics
import CoreVideo
import Darwin
import Foundation
import ImageIO

let ziel = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/aufraeumer-medien"
let dateien = FileManager.default
do {
    try dateien.createDirectory(atPath: ziel, withIntermediateDirectories: true)
} catch {
    fputs("Hinweis: Ordner fehlt\n", stderr)
    exit(1)
}

func hinweis(_ text: String) -> Never {
    fputs("Hinweis: \(text)\n", stderr)
    exit(1)
}

func schreibeJpeg(name: String, saat: UInt8) {
    let breite = 320
    let hoehe = 240
    var pixel = [UInt8](repeating: 0, count: breite * hoehe * 4)
    for i in 0..<(breite * hoehe) {
        let o = i * 4
        pixel[o] = saat
        pixel[o + 1] = UInt8((i + Int(saat) * 3) % 251)
        pixel[o + 2] = UInt8((200 + Int(saat)) % 255)
        pixel[o + 3] = 255
    }
    let url = URL(fileURLWithPath: ziel).appendingPathComponent(name)
    let fertig = pixel.withUnsafeMutableBytes { raw -> Bool in
        guard let basis = raw.baseAddress else { return false }
        guard let ctx = CGContext(
            data: basis,
            width: breite,
            height: hoehe,
            bitsPerComponent: 8,
            bytesPerRow: breite * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let bild = ctx.makeImage() else { return false }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
            return false
        }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.85,
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2020:01:15 10:00:00"
            ]
        ]
        CGImageDestinationAddImage(dest, bild, props as CFDictionary)
        return CGImageDestinationFinalize(dest)
    }
    if !fertig { hinweis("Bild \(name) nicht geschrieben") }
}

schreibeJpeg(name: "Bildschirmfoto-test.jpg", saat: 40)
schreibeJpeg(name: "gleich-a.jpg", saat: 180)
do {
    try dateien.copyItem(
        atPath: ziel + "/gleich-a.jpg",
        toPath: ziel + "/gleich-b.jpg"
    )
} catch {
    hinweis("Kopie des gleichen Bildes fehlgeschlagen")
}

let videoURL = URL(fileURLWithPath: ziel).appendingPathComponent("grosses-video.mp4")
try? dateien.removeItem(at: videoURL)

let breite = 960
let hoehe = 540
let fps: Int32 = 10
let bilder = 200
let writer: AVAssetWriter
do {
    writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
} catch {
    hinweis("Videoobjekt fehlt")
}
let einstellungen: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.jpeg,
    AVVideoWidthKey: breite,
    AVVideoHeightKey: hoehe,
    AVVideoCompressionPropertiesKey: [AVVideoQualityKey: 0.92]
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: einstellungen)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferWidthKey as String: breite,
        kCVPixelBufferHeightKey as String: hoehe
    ]
)
writer.add(input)
if !writer.startWriting() { hinweis("Video konnte nicht gestartet werden") }
writer.startSession(atSourceTime: .zero)

for index in 0..<bilder {
    var warten = 0
    while !input.isReadyForMoreMediaData && warten < 400 {
        Thread.sleep(forTimeInterval: 0.02)
        warten += 1
    }
    if !input.isReadyForMoreMediaData { hinweis("Video nimmt keine Bilder mehr an") }
    var puffer: CVPixelBuffer?
    let code = CVPixelBufferCreate(
        kCFAllocatorDefault, breite, hoehe, kCVPixelFormatType_32BGRA, nil, &puffer
    )
    guard code == kCVReturnSuccess, let puffer else { hinweis("Bildpuffer fehlt") }
    CVPixelBufferLockBaseAddress(puffer, [])
    if let basis = CVPixelBufferGetBaseAddress(puffer) {
        let bytes = CVPixelBufferGetBytesPerRow(puffer) * hoehe
        arc4random_buf(basis, bytes)
    }
    CVPixelBufferUnlockBaseAddress(puffer, [])
    let zeit = CMTime(value: CMTimeValue(index), timescale: fps)
    if !adaptor.append(puffer, withPresentationTime: zeit) {
        hinweis("Einzelbild abgelehnt")
    }
}

input.markAsFinished()
let fertig = DispatchSemaphore(value: 0)
writer.finishWriting { fertig.signal() }
fertig.wait()
if writer.status != .completed { hinweis("Video nicht abgeschlossen") }

func byteZahl(_ url: URL) -> Int64 {
    let werte = try? dateien.attributesOfItem(atPath: url.path)
    return (werte?[.size] as? NSNumber)?.int64Value ?? 0
}

let schwelle: Int64 = 52_000_000
var groesse = byteZahl(videoURL)
print("Video-Bytes vor Auffuellen: \(groesse)")
if groesse < schwelle {
    let fehlt = schwelle - groesse + 1_048_576
    var kopf = [UInt8](repeating: 0, count: 8)
    let gesamt = fehlt + 8
    kopf[0] = UInt8((gesamt >> 24) & 0xff)
    kopf[1] = UInt8((gesamt >> 16) & 0xff)
    kopf[2] = UInt8((gesamt >> 8) & 0xff)
    kopf[3] = UInt8(gesamt & 0xff)
    kopf[4] = UInt8(ascii: "f")
    kopf[5] = UInt8(ascii: "r")
    kopf[6] = UInt8(ascii: "e")
    kopf[7] = UInt8(ascii: "e")
    do {
        let handle = try FileHandle(forWritingTo: videoURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(kopf))
        let block = Data(count: 1_048_576)
        var rest = Int(fehlt)
        while rest > 0 {
            let n = min(rest, block.count)
            try handle.write(contentsOf: block.prefix(n))
            rest -= n
        }
        try handle.close()
    } catch {
        hinweis("Auffuellen fehlgeschlagen")
    }
    groesse = byteZahl(videoURL)
}
print("Video-Bytes: \(groesse)")
if groesse < 50_000_000 { hinweis("Video unter der Schwelle") }
