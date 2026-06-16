//
//  MarkerPhotoScreen.swift  (12 · Marker Photo)
//  GrowRate
//

import SwiftUI

struct MarkerPhotoScreen: View {
    @EnvironmentObject var store: DataStore
    let batchId: UUID

    @State private var showPicker = false
    @State private var source: UIImagePickerController.SourceType = .photoLibrary
    @State private var pickedImage: UIImage?
    @State private var caption = ""
    @State private var showCaption = false
    @State private var viewing: PhotoMarker?

    private var batch: Batch? { store.batch(batchId) }
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        GRScreen {
            ScrollView(showsIndicators: false) {
                if let b = batch {
                    VStack(spacing: 16) {
                        Menu {
                            Button(action: { source = .camera; showPicker = true }) {
                                Label("Camera", systemImage: "camera")
                            }
                            Button(action: { source = .photoLibrary; showPicker = true }) {
                                Label("Photo Library", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                Text("Add Photo").font(.gr(16, .bold))
                            }
                            .foregroundColor(GR.onPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.orange))
                        }

                        if b.photos.isEmpty {
                            EmptyState(systemImage: "photo.on.rectangle.angled",
                                       title: "No photos",
                                       message: "Snap the birds, the scale or the batch and add notes to track progress visually.")
                        } else {
                            LazyVGrid(columns: cols, spacing: 12) {
                                ForEach(b.photos.sorted { $0.date > $1.date }) { p in
                                    photoCell(p)
                                }
                            }
                        }
                    }
                    .padding(GR.pad).padding(.bottom, 90)
                } else {
                    EmptyState(systemImage: "questionmark", title: "Batch not found", message: "")
                }
            }
        }
        .navigationTitle("Photos").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker(sourceType: source) { img in
                pickedImage = img; caption = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showCaption = true }
            }
        }
        .sheet(isPresented: $showCaption) { captionSheet }
        .fullScreenCover(item: $viewing) { p in fullView(p) }
    }

    private func photoCell(_ p: PhotoMarker) -> some View {
        Button(action: { viewing = p }) {
            VStack(alignment: .leading, spacing: 0) {
                if let img = store.loadPhoto(p.fileName) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(height: 130).clipped()
                } else {
                    Rectangle().fill(GR.bg2).frame(height: 130)
                        .overlay(Image(systemName: "photo").foregroundColor(GR.textMuted))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.caption.isEmpty ? "No caption" : p.caption)
                        .font(.gr(12, .semibold)).foregroundColor(GR.text).lineLimit(1)
                    Text(shortDate(p.date)).font(.gr(10)).foregroundColor(GR.textMuted)
                }.padding(8)
            }
            .background(RoundedRectangle(cornerRadius: GR.radiusSmall).fill(GR.card))
            .overlay(RoundedRectangle(cornerRadius: GR.radiusSmall).stroke(GR.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: GR.radiusSmall))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var captionSheet: some View {
        NavigationView {
            GRScreen {
                VStack(spacing: 16) {
                    if let img = pickedImage {
                        Image(uiImage: img).resizable().aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: GR.radius))
                    }
                    GRTextField(title: "Caption", text: $caption, placeholder: "Day 21 weigh-in…")
                    GRPrimaryButton(title: "Save photo", systemImage: "checkmark") {
                        if let img = pickedImage { store.savePhoto(img, caption: caption, to: batchId) }
                        pickedImage = nil; showCaption = false
                    }
                    Spacer()
                }.padding(GR.pad)
            }
            .navigationTitle("New Photo").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { pickedImage = nil; showCaption = false }
                    .foregroundColor(GR.textSecondary) } }
        }
    }

    private func fullView(_ p: PhotoMarker) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                if let img = store.loadPhoto(p.fileName) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fit)
                }
                Text(p.caption).font(.gr(15, .semibold)).foregroundColor(.white).padding()
                Spacer()
            }
            VStack {
                HStack {
                    Button(action: { viewing = nil }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: {
                        store.deletePhoto(p, from: batchId); viewing = nil
                    }) {
                        Image(systemName: "trash.circle.fill").font(.system(size: 28)).foregroundColor(GR.red)
                    }
                }.padding()
                Spacer()
            }
        }
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
}
