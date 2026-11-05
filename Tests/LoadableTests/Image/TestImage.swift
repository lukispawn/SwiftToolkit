import CoreGraphics
@testable import Loadable

enum TestImage {
    static func make(width: Int, height: Int, gray: CGFloat = 0.5) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(gray: gray, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

import Foundation
import ImageIO
import Synchronization
import UniformTypeIdentifiers

extension TestImage {
    static func pngData(width: Int, height: Int) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, make(width: width, height: height)!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    static func writeTemp(_ data: Data, ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        try data.write(to: url)
        return url
    }
}

/// Serves canned responses so tests never touch the network. Register a unique URL per test.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let responses = Mutex<[URL: (status: Int, data: Data)]>([:])

    static func register(_ url: URL, status: Int, data: Data) {
        responses.withLock { $0[url] = (status, data) }
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let stub = Self.responses.withLock({ $0[url] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
