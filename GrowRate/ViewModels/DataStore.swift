//
//  DataStore.swift
//  GrowRate
//
//  Central observable store. Persists batches as JSON in the Documents
//  directory, owns all CRUD, photo files, derived history and CSV export.
//

import SwiftUI

// MARK: - History event (derived)

struct HistoryEvent: Identifiable {
    enum Kind { case placed, weighed, feed, mortality, slaughtered, target }
    let id = UUID()
    var date: Date
    var kind: Kind
    var title: String
    var detail: String
    var batchName: String

    var icon: String {
        switch kind {
        case .placed: return "shippingbox.fill"
        case .weighed: return "scalemass.fill"
        case .feed: return "bag.fill"
        case .mortality: return "xmark.circle.fill"
        case .slaughtered: return "checkmark.seal.fill"
        case .target: return "flag.checkered"
        }
    }
    var color: Color {
        switch kind {
        case .placed: return GR.orange
        case .weighed: return GR.green
        case .feed: return GR.yellow
        case .mortality: return GR.red
        case .slaughtered: return GR.text
        case .target: return GR.green
        }
    }
}

final class DataStore: ObservableObject {
    @Published var batches: [Batch] = []

    private let fileName = "growrate_batches.json"

    init() { load() }

    // MARK: Paths

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var fileURL: URL { documentsURL.appendingPathComponent(fileName) }
    private var photosDir: URL { documentsURL.appendingPathComponent("photos", isDirectory: true) }

    // MARK: Persistence

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { batches = []; return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        batches = (try? decoder.decode([Batch].self, from: data)) ?? []
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(batches) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: Batch CRUD

    var activeBatches: [Batch] { batches.filter { !$0.isSlaughtered } }
    var finishedBatches: [Batch] { batches.filter { $0.isSlaughtered } }

    func batch(_ id: UUID) -> Batch? { batches.first(where: { $0.id == id }) }

    func addBatch(_ b: Batch) {
        batches.insert(b, at: 0)
        save()
    }

    func updateBatch(_ b: Batch) {
        guard let i = batches.firstIndex(where: { $0.id == b.id }) else { return }
        batches[i] = b
        save()
    }

    func deleteBatch(_ b: Batch) {
        for p in b.photos { deletePhotoFile(p.fileName) }
        batches.removeAll { $0.id == b.id }
        save()
    }

    private func mutate(_ id: UUID, _ block: (inout Batch) -> Void) {
        guard let i = batches.firstIndex(where: { $0.id == id }) else { return }
        block(&batches[i])
        save()
    }

    // MARK: Sub-record CRUD

    func addWeight(_ e: WeightEntry, to id: UUID) { mutate(id) { $0.weights.append(e) } }
    func deleteWeight(_ e: WeightEntry, from id: UUID) { mutate(id) { $0.weights.removeAll { $0.id == e.id } } }

    func addFeed(_ e: FeedEntry, to id: UUID) { mutate(id) { $0.feed.append(e) } }
    func deleteFeed(_ e: FeedEntry, from id: UUID) { mutate(id) { $0.feed.removeAll { $0.id == e.id } } }

    func addMortality(_ e: MortalityEntry, to id: UUID) { mutate(id) { $0.mortality.append(e) } }
    func deleteMortality(_ e: MortalityEntry, from id: UUID) { mutate(id) { $0.mortality.removeAll { $0.id == e.id } } }

    func markSlaughtered(_ id: UUID, date: Date, dressedPerBirdGrams: Double) {
        mutate(id) {
            $0.isSlaughtered = true
            $0.slaughterDate = date
            if dressedPerBirdGrams > 0 { $0.actualDressedWeightPerBirdGrams = dressedPerBirdGrams }
        }
    }
    func reopenBatch(_ id: UUID) {
        mutate(id) { $0.isSlaughtered = false; $0.slaughterDate = nil }
    }

    // MARK: Photos

    func savePhoto(_ image: UIImage, caption: String, to id: UUID) {
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: photosDir.appendingPathComponent(name))
            let marker = PhotoMarker(date: Date(), fileName: name, caption: caption)
            mutate(id) { $0.photos.append(marker) }
        }
    }
    func loadPhoto(_ fileName: String) -> UIImage? {
        UIImage(contentsOfFile: photosDir.appendingPathComponent(fileName).path)
    }
    func deletePhoto(_ marker: PhotoMarker, from id: UUID) {
        deletePhotoFile(marker.fileName)
        mutate(id) { $0.photos.removeAll { $0.id == marker.id } }
    }
    private func deletePhotoFile(_ name: String) {
        try? FileManager.default.removeItem(at: photosDir.appendingPathComponent(name))
    }

    // MARK: History

    func history(for batch: Batch) -> [HistoryEvent] {
        var events: [HistoryEvent] = []
        let df = DateFormatter(); df.dateStyle = .medium

        events.append(HistoryEvent(date: batch.placementDate, kind: .placed,
                                   title: "Batch placed",
                                   detail: "\(batch.initialCount) head · \(batch.cross.name)",
                                   batchName: batch.name))
        for w in batch.weights {
            events.append(HistoryEvent(date: w.date, kind: .weighed,
                                       title: "Weighed (day \(batch.day(for: w.date)))",
                                       detail: "Avg \(Int(w.avgWeightGrams)) g · sample \(w.sampleSize)",
                                       batchName: batch.name))
        }
        for f in batch.feed {
            events.append(HistoryEvent(date: f.date, kind: .feed,
                                       title: "\(f.phase.title) feed",
                                       detail: String(format: "%.1f kg", f.amountKg),
                                       batchName: batch.name))
        }
        for m in batch.mortality {
            events.append(HistoryEvent(date: m.date, kind: .mortality,
                                       title: "\(m.type.title) ×\(m.count)",
                                       detail: m.cause.isEmpty ? "No cause noted" : m.cause,
                                       batchName: batch.name))
        }
        if batch.isSlaughtered, let sd = batch.slaughterDate {
            events.append(HistoryEvent(date: sd, kind: .slaughtered,
                                       title: "Slaughtered",
                                       detail: "Day \(batch.day(for: sd)) · \(batch.currentCount) birds",
                                       batchName: batch.name))
        }
        return events.sorted { $0.date > $1.date }
    }

    func globalHistory() -> [HistoryEvent] {
        batches.flatMap { history(for: $0) }.sorted { $0.date > $1.date }
    }

    // MARK: CSV export

    func csv(for batch: Batch) -> String {
        let cost = CostEngine.analyze(batch)
        let fcr = FCREngine.analyze(batch)
        var lines: [String] = []
        lines.append("Grow Rate batch report")
        lines.append("Name,\(batch.name)")
        lines.append("Cross,\(batch.cross.name)")
        lines.append("Placed,\(isoDay(batch.placementDate))")
        lines.append("Head placed,\(batch.initialCount)")
        lines.append("Head current,\(batch.currentCount)")
        lines.append("Target weight (g),\(Int(batch.targetWeightGrams))")
        lines.append("")
        lines.append("Day,Date,Avg weight (g),Sample size")
        for w in batch.sortedWeights {
            lines.append("\(batch.day(for: w.date)),\(isoDay(w.date)),\(Int(w.avgWeightGrams)),\(w.sampleSize)")
        }
        lines.append("")
        lines.append("Feed date,Phase,Amount (kg)")
        for f in batch.sortedFeed {
            lines.append("\(isoDay(f.date)),\(f.phase.title),\(String(format: "%.2f", f.amountKg))")
        }
        lines.append("")
        lines.append("Summary")
        lines.append("Total feed (kg),\(String(format: "%.1f", fcr.feedKg))")
        lines.append("FCR,\(String(format: "%.2f", fcr.fcr))")
        lines.append("Total cost,\(String(format: "%.2f", cost.totalCost))")
        lines.append("Cost per kg live,\(String(format: "%.2f", cost.costPerKgLive))")
        lines.append("Cost per kg dressed,\(String(format: "%.2f", cost.costPerKgDressed))")
        return lines.joined(separator: "\n")
    }

    private func isoDay(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }
}
