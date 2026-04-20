import Foundation
import CoreImage

enum PairingImportSource: String, Equatable, Sendable {
    case manualPaste
    case qrCode
    case sharedLink
    case sharedFile

    var displayName: String {
        switch self {
        case .manualPaste:
            return "Pasted payload"
        case .qrCode:
            return "QR code"
        case .sharedLink:
            return "Pairing link"
        case .sharedFile:
            return "Shared file"
        }
    }

    var successMessage: String {
        switch self {
        case .manualPaste:
            return "Pairing applied from pasted payload."
        case .qrCode:
            return "Pairing applied from QR code."
        case .sharedLink:
            return "Pairing applied from shared link."
        case .sharedFile:
            return "Pairing applied from shared file."
        }
    }
}

struct TardiPairingPayload: Codable, Equatable, Sendable {
    let endpoint: String
    let bearerToken: String
    let certSHA256: String

    enum CodingKeys: String, CodingKey {
        case endpoint
        case bearerToken = "bearer_token"
        case certSHA256 = "cert_sha256"
    }
}

enum TardiPairingError: Error, Equatable {
    case invalidFormat
    case invalidJSON
    case invalidEndpoint
    case invalidToken
    case invalidFingerprint
    case invalidQRCode
    case unsupportedImportURL
    case unreadableImportFile
}

extension TardiPairingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The pairing payload format was not recognized."
        case .invalidJSON:
            return "The pairing payload was not valid JSON."
        case .invalidEndpoint:
            return "The pairing payload must point to an HTTPS gateway."
        case .invalidToken:
            return "The pairing payload did not include a bearer token."
        case .invalidFingerprint:
            return "The pairing payload did not include a valid cert fingerprint."
        case .invalidQRCode:
            return "No BearClaw pairing QR code was found in that image."
        case .unsupportedImportURL:
            return "That shared item is not a supported BearClaw pairing payload."
        case .unreadableImportFile:
            return "The shared pairing file could not be read."
        }
    }
}

func parseTardiPairingPayload(_ input: String) throws -> TardiPairingPayload {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw TardiPairingError.invalidFormat }

    let jsonData: Data
    if trimmed.hasPrefix("tardi1:") {
        let encoded = String(trimmed.dropFirst("tardi1:".count))
        guard let decoded = decodeBase64URL(encoded) else {
            throw TardiPairingError.invalidFormat
        }
        jsonData = decoded
    } else {
        guard let data = trimmed.data(using: .utf8) else {
            throw TardiPairingError.invalidFormat
        }
        jsonData = data
    }

    guard let payload = try? JSONDecoder().decode(TardiPairingPayload.self, from: jsonData) else {
        throw TardiPairingError.invalidJSON
    }

    guard let url = URL(string: payload.endpoint), url.scheme?.lowercased() == "https" else {
        throw TardiPairingError.invalidEndpoint
    }

    let token = payload.bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else { throw TardiPairingError.invalidToken }

    let normalizedFingerprint = normalizeFingerprint(payload.certSHA256)
    guard normalizedFingerprint.count == 64 else { throw TardiPairingError.invalidFingerprint }

    return TardiPairingPayload(
        endpoint: payload.endpoint,
        bearerToken: token,
        certSHA256: normalizedFingerprint
    )
}

func parseTardiPairingPayload(from url: URL) throws -> TardiPairingPayload {
    if let scheme = url.scheme?.lowercased(), scheme == "tardi1" {
        return try parseTardiPairingPayload(url.absoluteString)
    }

    guard url.isFileURL else {
        throw TardiPairingError.unsupportedImportURL
    }

    let accessed = url.startAccessingSecurityScopedResource()
    defer {
        if accessed {
            url.stopAccessingSecurityScopedResource()
        }
    }

    let data: Data
    do {
        data = try Data(contentsOf: url)
    } catch {
        throw TardiPairingError.unreadableImportFile
    }

    if let text = String(data: data, encoding: .utf8) {
        return try parseTardiPairingPayload(text)
    }

    throw TardiPairingError.unreadableImportFile
}

func parseTardiPairingPayloadFromQRCodeImageData(_ data: Data) throws -> TardiPairingPayload {
    guard let ciImage = CIImage(data: data) else {
        throw TardiPairingError.invalidQRCode
    }

    let detector = CIDetector(
        ofType: CIDetectorTypeQRCode,
        context: nil,
        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
    )
    let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] ?? []
    guard let payloadText = features.first?.messageString, !payloadText.isEmpty else {
        throw TardiPairingError.invalidQRCode
    }

    return try parseTardiPairingPayload(payloadText)
}

func normalizeFingerprint(_ raw: String) -> String {
    let cleaned = raw
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: ":", with: "")
        .lowercased()

    guard cleaned.count == 64 else { return "" }
    guard cleaned.allSatisfy({ $0.isHexDigit }) else { return "" }
    return cleaned
}

private func decodeBase64URL(_ text: String) -> Data? {
    var base64 = text
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    let padding = 4 - (base64.count % 4)
    if padding < 4 {
        base64 += String(repeating: "=", count: padding)
    }
    return Data(base64Encoded: base64)
}
