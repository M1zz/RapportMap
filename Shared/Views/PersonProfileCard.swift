//
//  PersonProfileCard.swift
//  RapportMap
//
//  프로필 카드 — 아바타 + 이름 + 탐험 진행률
//

import SwiftUI
import SwiftData
#if os(iOS)
import PhotosUI
#else
import UniformTypeIdentifiers
#endif

// MARK: - PersonProfileCard

struct PersonProfileCard: View {
    @Bindable var person: Person

    @State private var showingFullScreenPhoto = false

    #if os(iOS)
    @State private var selectedPhoto: PhotosPickerItem?
    #endif

    private var totalTerritories: Int { Territory.allCases.count }
    private var exploredCount: Int { person.exploredTerritories.count }

    var body: some View {
        HStack(spacing: 14) {
            avatarSection

            VStack(alignment: .leading, spacing: 5) {
                Text(person.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                HStack(spacing: 6) {
                    Text(person.depth.icon)
                    Text(person.depth.title)
                        .font(.body)
                        .foregroundStyle(person.depth.color)
                }

                HStack(spacing: 8) {
                    ProgressView(value: person.totalExplorationProgress)
                        .tint(person.depth.color)
                        .frame(width: 100)
                    Text("\(exploredCount)/\(totalTerritories) 탐험")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondaryBackground)
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
        .padding(.top, 8)
        .sheet(isPresented: $showingFullScreenPhoto) {
            FullScreenPhotoView(
                imageData: person.profileImageData,
                isPresented: $showingFullScreenPhoto
            )
        }
        #if os(iOS)
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    person.profileImageData = data
                }
            }
        }
        #endif
    }

    // MARK: - 아바타 섹션

    private var avatarSection: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarImage
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(Circle().stroke(person.depth.color.opacity(0.4), lineWidth: 2))
                .onTapGesture {
                    if person.profileImageData != nil {
                        showingFullScreenPhoto = true
                    }
                }

            photoBadge
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let data = person.profileImageData {
            #if os(iOS)
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                defaultAvatar
            }
            #else
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                defaultAvatar
            }
            #endif
        } else {
            defaultAvatar
        }
    }

    private var defaultAvatar: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "d4a82a"), Color(hex: "8a6010")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(person.progressMoonPhase)
                .font(.system(size: 26))
        }
    }

    @ViewBuilder
    private var photoBadge: some View {
        #if os(iOS)
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            badgeCircle
        }
        .buttonStyle(.plain)
        #else
        Button { pickPhotoMac() } label: {
            badgeCircle
        }
        .buttonStyle(.plain)
        #endif
    }

    private var badgeCircle: some View {
        Circle()
            .fill(person.depth.color)
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    #if os(macOS)
    private func pickPhotoMac() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? Data(contentsOf: url) {
            person.profileImageData = data
        }
    }
    #endif
}

// MARK: - 풀스크린 사진 뷰

struct FullScreenPhotoView: View {
    let imageData: Data?
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            Group {
                if let data = imageData {
                    #if os(iOS)
                    if let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(Circle())
                            .padding(40)
                    }
                    #else
                    if let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(Circle())
                            .padding(40)
                    }
                    #endif
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer()
                Text("탭하면 닫힙니다")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 40)
            }
        }
        #if os(macOS)
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, Discovery.self, configurations: config)
    let person = Person(name: "김철수", depth: .personal)
    container.mainContext.insert(person)
    person.addDiscovery(territory: .nickname, content: "달빛")
    person.addDiscovery(territory: .hobby, content: "등산")
    return VStack {
        PersonProfileCard(person: person)
        Spacer()
    }
    .modelContainer(container)
}
