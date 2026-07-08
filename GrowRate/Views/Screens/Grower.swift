import Foundation
import Combine
import AppsFlyerLib

@MainActor
final class Grower {

    typealias Rung = () async -> Bloom?

    private let vault: Vault
    private let sensor: Sensor
    private let canopy: Canopy
    private let pollen: Pollen

    private var sprout = Sprout()
    private var sprouted = false
    private var picked = false
    private var growing = false

    private let blooms = PassthroughSubject<Bloom, Never>()
    var bloomFeed: AnyPublisher<Bloom, Never> { blooms.eraseToAnyPublisher() }

    init(vault: Vault, sensor: Sensor, canopy: Canopy, pollen: Pollen) {
        self.vault = vault
        self.sensor = sensor
        self.canopy = canopy
        self.pollen = pollen
    }

    func plant() {
        root()
    }

    func takeSap(_ data: [String: Any]) {
        root()
        data.forEach { sprout.sap[$0.key] = "\($0.value)" }
    }

    func takeRoots(_ data: [String: Any]) {
        root()
        data.forEach { sprout.roots[$0.key] = "\($0.value)" }
    }

    func grow() async {
        root()
        guard picked == false, growing == false else { return }
        growing = true
        defer { growing = false }

        for rung in [sniffBud, gateSap, graft, reach] as [Rung] {
            if let bloom = await rung() {
                deliver(bloom)
                return
            }
        }
    }

    func pollinate(then done: @escaping () -> Void) {
        Task { [weak self] in
            guard let self = self else { return }
            let ok = await self.pollen.dust()
            self.sprout.pollenGranted = ok
            self.sprout.pollenBarred = ok == false
            self.sprout.pollenAt = Date()
            self.vault.sow(self.sprout)
            self.blooms.send(.flower)
            done()
        }
    }

    func shrug() {
        root()
        sprout.pollenAt = Date()
        vault.sow(sprout)
        blooms.send(.flower)
    }

    func stall() -> Bool {
        root()
        return pick()
    }

    private func sniffBud() async -> Bloom? {
        guard let stash = budStash() else { return nil }
        return settle(stash)
    }

    private func gateSap() async -> Bloom? {
        sprout.hasSap ? nil : .dormant
    }

    private func graft() async -> Bloom? {
        await equalize()
        return nil
    }

    private func reach() async -> Bloom? {
        do {
            let link = try await canopy.post(load: sprout.sap.mapValues { $0 as Any })
            return settle(link)
        } catch {
            return .wilt
        }
    }

    private func deliver(_ bloom: Bloom) {
        if case .dormant = bloom {
            blooms.send(.dormant)
        } else if pick() {
            blooms.send(bloom)
        }
    }

    private func root() {
        guard sprouted == false else { return }
        sprouted = true
        sprout = vault.dig()
    }

    private func budStash() -> String? {
        let stash = UserDefaults.standard.string(forKey: SeedKey.pushURL) ?? ""
        return stash.isEmpty ? nil : stash
    }

    private func equalize() async {
        guard sprout.organicWild, sprout.seed, sprout.grafted == false else { return }

        sprout.grafted = true
        vault.sow(sprout)

        try? await Task.sleep(nanoseconds: 5_000_000_000)

        guard sprout.bloomed == false else { return }

        do {
            let fresh = try await sensor.read(deviceID: AppsFlyerLib.shared().getAppsFlyerUID())
                .mapValues { "\($0)" }
            guard fresh.isEmpty == false else { return }

            var blend = fresh
            sprout.roots.forEach { pair in
                if blend[pair.key] == nil { blend[pair.key] = pair.value }
            }
            sprout.sap = blend
            vault.sow(sprout)
        } catch {
        }
    }

    private func settle(_ url: String) -> Bloom {
        let due = sprout.pollenDue

        sprout.routeURL = url
        sprout.routeMode = "Active"
        sprout.seed = false
        sprout.bloomed = true

        vault.sow(sprout)
        vault.markRoute(url: url, mode: "Active")
        vault.raiseFlag()
        UserDefaults.standard.removeObject(forKey: SeedKey.pushURL)

        return due ? .pollinate : .flower
    }

    private func pick() -> Bool {
        guard picked == false else { return false }
        picked = true
        return true
    }
}

enum Bed {
    @MainActor static let grower: Grower = {
        Grower(
            vault: SoilVault(),
            sensor: SapSensor(),
            canopy: LeafCanopy(),
            pollen: BeePollen()
        )
    }()
}
