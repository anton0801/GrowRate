//
//  AddBatchScreen.swift  (02 · Add / Edit Batch)
//  GrowRate
//

import SwiftUI

struct AddBatchScreen: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) private var presentationMode

    var editing: Batch? = nil

    @State private var name = ""
    @State private var crossId = CrossPreset.ross308.id
    @State private var placementDate = Date()
    @State private var headCount = "100"
    @State private var initialWeight = "42"
    @State private var targetGrams: Double = 2500
    @State private var currency = "$"
    @State private var feedPrice = "0.55"
    @State private var chickPrice = "0.80"
    @State private var otherCosts = "0"
    @State private var marketLive = "0"
    @State private var saleDressed = "0"

    @State private var showError = false

    var body: some View {
        NavigationView {
            GRScreen {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        GRTextField(title: "Batch name", text: $name, placeholder: "e.g. Spring broilers")

                        crossPicker

                        GRCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("PLACEMENT DATE").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                                DatePicker("", selection: $placementDate, in: ...Date(),
                                           displayedComponents: .date)
                                    .labelsHidden().accentColor(GR.orange)
                            }
                        }

                        HStack(spacing: 12) {
                            GRTextField(title: "Head count", text: $headCount,
                                        placeholder: "100", keyboard: .numberPad)
                            GRTextField(title: "Chick weight", text: $initialWeight,
                                        placeholder: "42", keyboard: .decimalPad, suffix: "g")
                        }

                        targetSection
                        currencySection

                        SectionHeader(title: "Economics", systemImage: "dollarsign.circle.fill")
                        HStack(spacing: 12) {
                            GRTextField(title: "Feed / kg", text: $feedPrice,
                                        placeholder: "0.55", keyboard: .decimalPad, suffix: currency)
                            GRTextField(title: "Chick / head", text: $chickPrice,
                                        placeholder: "0.80", keyboard: .decimalPad, suffix: currency)
                        }
                        GRTextField(title: "Other costs (total)", text: $otherCosts,
                                    placeholder: "0", keyboard: .decimalPad, suffix: currency)
                        HStack(spacing: 12) {
                            GRTextField(title: "Live price / kg", text: $marketLive,
                                        placeholder: "0", keyboard: .decimalPad, suffix: currency)
                            GRTextField(title: "Dressed price / kg", text: $saleDressed,
                                        placeholder: "0", keyboard: .decimalPad, suffix: currency)
                        }
                        Text("Live price drives the “stop feeding” point; dressed price drives the margin.")
                            .font(.gr(11)).foregroundColor(GR.textMuted)

                        GRPrimaryButton(title: editing == nil ? "Create Batch" : "Save Changes",
                                        systemImage: "checkmark") { save() }
                            .padding(.top, 4)
                    }
                    .padding(GR.pad)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(editing == nil ? "New Batch" : "Edit Batch").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(GR.textSecondary) } }
            .alert(isPresented: $showError) {
                Alert(title: Text("Check the form"),
                      message: Text("Enter a name, a head count above zero and a target weight."),
                      dismissButton: .default(Text("OK")))
            }
        }
        .onAppear(perform: prefill)
    }

    private var crossPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CROSS / BREED").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CrossPreset.builtIns) { p in
                        GRChip(title: p.name, isSelected: crossId == p.id) {
                            withAnimation(GR.spring) { crossId = p.id }
                        }
                    }
                }
            }
        }
    }

    private var targetSection: some View {
        GRCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TARGET WEIGHT").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
                    Spacer()
                    Text(String(format: "%.2f kg", targetGrams / 1000))
                        .font(.gr(16, .heavy)).foregroundColor(GR.green)
                }
                Slider(value: $targetGrams, in: 1000...4500, step: 50).accentColor(GR.orange)
            }
        }
    }

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CURRENCY").font(.gr(11, .bold)).foregroundColor(GR.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AppState.commonCurrencies, id: \.self) { c in
                        GRChip(title: c, isSelected: currency == c) {
                            withAnimation(GR.spring) { currency = c }
                        }
                    }
                }
            }
        }
    }

    private func prefill() {
        if let b = editing {
            name = b.name; crossId = b.crossId; placementDate = b.placementDate
            headCount = "\(b.initialCount)"; initialWeight = String(format: "%.0f", b.initialAvgWeightGrams)
            targetGrams = b.targetWeightGrams; currency = b.currency
            feedPrice = trim(b.feedPricePerKg); chickPrice = trim(b.chickPricePerHead)
            otherCosts = trim(b.otherCostsTotal); marketLive = trim(b.marketPricePerKgLive)
            saleDressed = trim(b.salePricePerKgDressed)
        } else {
            crossId = appState.defaultCrossId
            targetGrams = appState.defaultTargetGrams
            currency = appState.currencyCode
            name = "Batch \(store.batches.count + 1)"
        }
    }

    private func trim(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.2f", v)
    }

    private func save() {
        let count = Int(headCount) ?? 0
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, count > 0, targetGrams > 0 else {
            showError = true; return
        }
        var b = editing ?? Batch(name: name, crossId: crossId, placementDate: placementDate,
                                 initialCount: count, targetWeightGrams: targetGrams,
                                 currency: currency, feedPricePerKg: 0)
        b.name = name; b.crossId = crossId; b.placementDate = placementDate
        b.initialCount = count
        b.initialAvgWeightGrams = Double(initialWeight) ?? 42
        b.targetWeightGrams = targetGrams
        b.currency = currency
        b.feedPricePerKg = Double(feedPrice) ?? 0
        b.chickPricePerHead = Double(chickPrice) ?? 0
        b.otherCostsTotal = Double(otherCosts) ?? 0
        b.marketPricePerKgLive = Double(marketLive) ?? 0
        b.salePricePerKgDressed = Double(saleDressed) ?? 0

        if editing == nil { store.addBatch(b) } else { store.updateBatch(b) }
        dismiss()
    }

    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}
