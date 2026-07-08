import Foundation

protocol Vault {
    func sow(_ sprout: Sprout)
    func dig() -> Sprout
    func markRoute(url: String, mode: String)
    func raiseFlag()
}

final class SoilVault: Vault {

    private let shared: UserDefaults
    private let plain = UserDefaults.standard

    init() {
        shared = UserDefaults(suiteName: Seed.suiteBed) ?? .standard
    }

    private var url: URL {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Seed.bedVault, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(Seed.logFile)
    }

    func sow(_ sprout: Sprout) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .millisecondsSince1970
        if let json = try? enc.encode(sprout) {
            try? wrap(json).write(to: url, options: .atomic)
        }
        [shared, plain].forEach {
            $0.set(sprout.pollenGranted, forKey: SeedKey.pollenGranted)
            $0.set(sprout.pollenBarred, forKey: SeedKey.pollenBarred)
            if let when = sprout.pollenAt { $0.set(when.timeIntervalSince1970, forKey: SeedKey.pollenAt) }
        }
    }

    func dig() -> Sprout {
        if let raw = try? Data(contentsOf: url) {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .millisecondsSince1970
            if let sprout = try? dec.decode(Sprout.self, from: unwrap(raw)) {
                return sprout
            }
        }
        var sprout = Sprout()
        sprout.routeURL = plain.string(forKey: SeedKey.routeURL)
        sprout.routeMode = shared.string(forKey: SeedKey.routeMode)
        sprout.seed = shared.bool(forKey: SeedKey.primed) == false
        sprout.pollenGranted = shared.bool(forKey: SeedKey.pollenGranted) || plain.bool(forKey: SeedKey.pollenGranted)
        sprout.pollenBarred = shared.bool(forKey: SeedKey.pollenBarred) || plain.bool(forKey: SeedKey.pollenBarred)
        let ts = shared.double(forKey: SeedKey.pollenAt)
        sprout.pollenAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        return sprout
    }

    func markRoute(url: String, mode: String) {
        plain.set(url, forKey: SeedKey.routeURL)
        shared.set(url, forKey: SeedKey.routeURL)
        shared.set(mode, forKey: SeedKey.routeMode)
    }

    func raiseFlag() {
        shared.set(true, forKey: SeedKey.primed)
        plain.set(true, forKey: SeedKey.primed)
    }

    private func wrap(_ data: Data) -> Data {
        let key = Seed.cipher
        var out = ""
        out.reserveCapacity(data.count * 2)
        for (index, byte) in data.enumerated() {
            let mixed = byte ^ key[index % key.count]
            out += String(format: "%02x", mixed)
        }
        return Data(out.utf8)
    }

    private func unwrap(_ data: Data) -> Data {
        let hex = String(decoding: data, as: UTF8.self)
        let key = Seed.cipher
        var bytes = [UInt8]()
        var cursor = hex.startIndex
        var index = 0
        while cursor < hex.endIndex {
            guard let next = hex.index(cursor, offsetBy: 2, limitedBy: hex.endIndex) else { break }
            if let value = UInt8(hex[cursor..<next], radix: 16) {
                bytes.append(value ^ key[index % key.count])
            }
            cursor = next
            index += 1
        }
        return Data(bytes)
    }
}
