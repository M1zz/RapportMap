//
//  MacSharedDocumentsTab.swift
//  mac
//
//  공유 문서 탭 - iCloud Numbers 등 임베드
//

import SwiftUI
import SwiftData
import WebKit

struct MacSharedDocumentsTab: View {
    @Environment(\.modelContext) private var context
    let person: Person
    
    @State private var selectedDocument: SharedDocument?
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var editingDocument: SharedDocument?
    
    var body: some View {
        HSplitView {
            // 왼쪽: 문서 목록
            documentList
                .frame(minWidth: 200, maxWidth: 280)
            
            // 오른쪽: 문서 뷰어
            documentViewer
        }
    }
    
    // MARK: - Document List
    
    private var documentList: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("공유 문서")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if person.sharedDocuments.isEmpty {
                // 빈 상태
                VStack(spacing: 12) {
                    Spacer()
                    
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    
                    Text("공유 문서가 없습니다")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button("문서 추가") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // 문서 목록
                List(selection: $selectedDocument) {
                    ForEach(person.sharedDocuments) { doc in
                        documentRow(doc)
                            .tag(doc)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSharedDocumentSheet(person: person)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let doc = editingDocument {
                EditSharedDocumentSheet(person: person, document: doc)
            }
        }
    }
    
    private func documentRow(_ doc: SharedDocument) -> some View {
        HStack(spacing: 10) {
            Image(systemName: doc.type.icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(doc.type.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                editingDocument = doc
                showingEditSheet = true
            } label: {
                Label("편집", systemImage: "pencil")
            }
            
            Button {
                if let url = URL(string: doc.url) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("브라우저에서 열기", systemImage: "safari")
            }
            
            Divider()
            
            Button(role: .destructive) {
                person.removeSharedDocument(id: doc.id)
                try? context.save()
                if selectedDocument?.id == doc.id {
                    selectedDocument = nil
                }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Document Viewer
    
    private var documentViewer: some View {
        Group {
            if let doc = selectedDocument {
                VStack(spacing: 0) {
                    // 문서 헤더
                    HStack {
                        Image(systemName: doc.type.icon)
                            .foregroundStyle(.blue)
                        
                        Text(doc.title)
                            .font(.headline)
                        
                        Spacer()
                        
                        Button {
                            if let url = URL(string: doc.url) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("브라우저에서 열기", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            // 새로고침
                            let current = selectedDocument
                            selectedDocument = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                selectedDocument = current
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // WebView
                    WebViewWrapper(url: doc.url)
                        .onAppear {
                            person.markDocumentAccessed(id: doc.id)
                            try? context.save()
                        }
                }
            } else {
                // 선택된 문서 없음
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("문서를 선택하세요")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("왼쪽 목록에서 문서를 선택하면\n여기에 표시됩니다")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }
}

// MARK: - WebView Wrapper

struct WebViewWrapper: NSViewRepresentable {
    let url: String
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        
        // JavaScript 허용
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // 사용자 에이전트 설정 (데스크탑 버전으로)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: url) else { return }
        
        // 이미 같은 URL이 로드되어 있으면 스킵
        if webView.url == url { return }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🌐 WebView 로딩 시작: \(webView.url?.absoluteString ?? "")")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView 로딩 완료: \(webView.url?.absoluteString ?? "")")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView 로딩 실패: \(error.localizedDescription)")
        }
        
        // 외부 링크는 기본 브라우저에서 열기
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    // iCloud 도메인 내부 링크는 WebView에서 처리
                    if url.host?.contains("icloud.com") == true ||
                       url.host?.contains("apple.com") == true {
                        decisionHandler(.allow)
                    } else {
                        // 외부 링크는 브라우저에서 열기
                        NSWorkspace.shared.open(url)
                        decisionHandler(.cancel)
                    }
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - Add Document Sheet

struct AddSharedDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let person: Person
    
    @State private var title = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var detectedType: SharedDocumentType = .other
    
    var body: some View {
        VStack(spacing: 20) {
            Text("공유 문서 추가")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                TextField("제목", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                TextField("URL", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: url) { _, newValue in
                        detectedType = SharedDocumentType.detect(from: newValue)
                        
                        // 제목 자동 추출 시도
                        if title.isEmpty && !newValue.isEmpty {
                            title = extractTitleFromURL(newValue)
                        }
                    }
                
                if !url.isEmpty {
                    HStack {
                        Image(systemName: detectedType.icon)
                            .foregroundStyle(.blue)
                        Text("감지된 타입: \(detectedType.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                TextField("메모 (선택)", text: $notes)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            
            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("추가") {
                    person.addSharedDocument(title: title, url: url, notes: notes.isEmpty ? nil : notes)
                    try? context.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty || url.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 300)
        .padding()
    }
    
    private func extractTitleFromURL(_ url: String) -> String {
        // URL에서 제목 추출 시도
        if url.contains("icloud.com") {
            return "Numbers 시트"
        } else if url.contains("docs.google.com") {
            return "Google 문서"
        } else if url.contains("notion") {
            return "Notion 페이지"
        }
        return ""
    }
}

// MARK: - Edit Document Sheet

struct EditSharedDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let person: Person
    let document: SharedDocument
    
    @State private var title: String
    @State private var url: String
    @State private var notes: String
    
    init(person: Person, document: SharedDocument) {
        self.person = person
        self.document = document
        _title = State(initialValue: document.title)
        _url = State(initialValue: document.url)
        _notes = State(initialValue: document.notes ?? "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("문서 편집")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                TextField("제목", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                TextField("URL", text: $url)
                    .textFieldStyle(.roundedBorder)
                
                TextField("메모", text: $notes)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            
            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("저장") {
                    var updated = document
                    updated.title = title
                    updated.url = url
                    updated.notes = notes.isEmpty ? nil : notes
                    person.updateSharedDocument(updated)
                    try? context.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty || url.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 280)
        .padding()
    }
}

#Preview {
    MacSharedDocumentsTab(person: Person(name: "홍길동"))
        .frame(width: 900, height: 600)
}
