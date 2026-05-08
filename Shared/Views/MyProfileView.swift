//
//  MyProfileView.swift
//  RapportMap
//
//  내 프로필 - 사이드바 하단 표시 및 편집
//

import SwiftUI
import Combine
#if os(iOS)
import PhotosUI
#else
import UniformTypeIdentifiers
#endif

// MARK: - MyProfileManager

final class MyProfileManager: ObservableObject {
    static let shared = MyProfileManager()

    @Published var name: String {
        didSet { UserDefaults.standard.set(name, forKey: "myProfile.name") }
    }
    @Published var imageData: Data? {
        didSet { UserDefaults.standard.set(imageData, forKey: "myProfile.imageData") }
    }

    private init() {
        self.name = UserDefaults.standard.string(forKey: "myProfile.name") ?? ""
        self.imageData = UserDefaults.standard.data(forKey: "myProfile.imageData")
    }
}

// MARK: - 내 프로필 아바타 뷰 (사이드바용)

struct MyProfileSidebarRow: View {
    @ObservedObject var manager = MyProfileManager.shared
    @State private var showingProfile = false

    var body: some View {
        Button {
            showingProfile = true
        } label: {
            HStack(spacing: 10) {
                avatarImage
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 1) {
                    Text(manager.name.isEmpty ? "내 프로필" : manager.name)
                        .font(.body)
                        .fontWeight(.medium)
                    Text("나")
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingProfile) {
            MyProfileSheet()
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let data = manager.imageData {
            #if os(iOS)
            if let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else { placeholderAvatar }
            #else
            if let img = NSImage(data: data) {
                Image(nsImage: img).resizable().scaledToFill()
            } else { placeholderAvatar }
            #endif
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        ZStack {
            Color.accentColor.opacity(0.15)
            Image(systemName: "person.fill")
                .foregroundStyle(Color.accentColor)
        }
    }
}

// MARK: - 내 프로필 시트

struct MyProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager = MyProfileManager.shared

    @State private var nameInput = ""
    @State private var showingFullScreen = false

    #if os(iOS)
    @State private var selectedPhoto: PhotosPickerItem?
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 아바타
                ZStack(alignment: .bottomTrailing) {
                    avatarView
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.accentColor.opacity(0.4), lineWidth: 2))
                        .onTapGesture {
                            if manager.imageData != nil { showingFullScreen = true }
                        }

                    photoBadge
                }
                .padding(.top, 20)

                // 이름
                VStack(alignment: .leading, spacing: 6) {
                    Text("이름")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    TextField("내 이름", text: $nameInput)
                        .textFieldStyle(.roundedBorder)
                        #if os(macOS)
                        .frame(width: 260)
                        #endif
                }

                if manager.imageData != nil {
                    Button(role: .destructive) {
                        manager.imageData = nil
                    } label: {
                        Label("사진 제거", systemImage: "trash")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }

                Spacer()
            }
            .navigationTitle("내 프로필")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        manager.imageData = data
                    }
                }
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        manager.name = nameInput
                        dismiss()
                    }
                }
            }
            .onAppear { nameInput = manager.name }
            .sheet(isPresented: $showingFullScreen) {
                FullScreenPhotoView(imageData: manager.imageData, isPresented: $showingFullScreen)
            }
        }
        #if os(macOS)
        .frame(width: 340, height: 380)
        #endif
    }

    @ViewBuilder
    private var avatarView: some View {
        if let data = manager.imageData {
            #if os(iOS)
            if let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else { placeholderAvatar }
            #else
            if let img = NSImage(data: data) {
                Image(nsImage: img).resizable().scaledToFill()
            } else { placeholderAvatar }
            #endif
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        ZStack {
            Color.accentColor.opacity(0.15)
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
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
        Button { pickPhotoMac() } label: { badgeCircle }
            .buttonStyle(.plain)
        #endif
    }

    private var badgeCircle: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 28, height: 28)
            .overlay(Image(systemName: "camera.fill").font(.system(size: 12)).foregroundStyle(.white))
    }

    #if os(macOS)
    private func pickPhotoMac() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? Data(contentsOf: url) {
            manager.imageData = data
        }
    }
    #endif
}
