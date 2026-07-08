import Foundation
import Combine

@MainActor
final class Trellis: ObservableObject {

    @Published var toWeb = false {
        didSet { if toWeb { clock?.cancel(); locked = true } }
    }
    @Published var toMain = false {
        didSet { if toMain { clock?.cancel(); locked = true } }
    }
    @Published var prompt = false
    @Published var offline = false

    private let grower = Bed.grower
    private var pipes = Set<AnyCancellable>()
    private var clock: Task<Void, Never>?
    private var locked = false

    init() {
        grower.bloomFeed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bloom in self?.apply(bloom) }
            .store(in: &pipes)
    }

    deinit { clock?.cancel() }

    func wake() {
        grower.plant()
        clock = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard let self = self else { return }
            if self.grower.stall() { self.apply(.wilt) }
        }
    }

    func sap(_ data: [String: Any]) {
        Task {
            grower.takeSap(data)
            await grower.grow()
        }
    }

    func roots(_ data: [String: Any]) {
        grower.takeRoots(data)
    }

    func allow() {
        grower.pollinate { self.prompt = false }
    }

    func deny() {
        prompt = false
        grower.shrug()
    }

    func net(_ live: Bool) {
        if live == false { offline = true }
    }

    private func apply(_ bloom: Bloom) {
        guard locked == false else { return }
        switch bloom {
        case .dormant: return
        case .pollinate: prompt = true
        case .flower: toWeb = true
        case .wilt: toMain = true
        }
    }
}
