//
//  MentoringProfileView.swift
//  RapportMap
//
//  멘토링 기본 정보 확인 및 수정 뷰
//

import SwiftUI

struct MentoringProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var profile: MentoringProfile
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 철학 메시지
                    philosophySection

                    // 프로필 내용
                    if isEditing {
                        editingView
                    } else {
                        readOnlyView
                    }

                    // 작성 날짜 정보
                    metadataSection
                }
                .padding()
            }
            .navigationTitle("멘토링 기본 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("완료") {
                            saveAndClose()
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button {
                            isEditing = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("수정")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 철학 섹션

    private var philosophySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("멘토링 철학")
                    .font(.headline)
            }

            Text(MentoringPhilosophy.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 읽기 전용 뷰

    private var readOnlyView: some View {
        VStack(spacing: 16) {
            profileField(
                title: "멘토가 알았으면 하는 나의 배경",
                content: profile.background,
                icon: "person.text.rectangle"
            )

            profileField(
                title: "아카데미에 나갈 때의 목표",
                content: profile.academyGoal,
                icon: "target"
            )

            profileField(
                title: "아카데미에서 배우고 싶은 것들",
                content: profile.learningPlan,
                icon: "book"
            )

            profileField(
                title: "목표 달성을 위해 지금 하고 있는 노력들",
                content: profile.currentEfforts,
                icon: "flame"
            )
        }
    }

    private func profileField(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            if content.isEmpty {
                Text("작성되지 않음")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - 수정 뷰

    private var editingView: some View {
        VStack(spacing: 16) {
            editableField(
                title: "멘토가 알았으면 하는 나의 배경",
                text: $profile.background,
                icon: "person.text.rectangle",
                placeholder: "예: 나는 디자인에 관심이 많고, 이전에 작은 프로젝트 경험이 있습니다..."
            )

            editableField(
                title: "아카데미에 나갈 때의 목표",
                text: $profile.academyGoal,
                icon: "target",
                placeholder: "예: iOS 개발자로 취업하여 사용자에게 가치있는 앱을 만들고 싶습니다..."
            )

            editableField(
                title: "아카데미에서 배우고 싶은 것들",
                text: $profile.learningPlan,
                icon: "book",
                placeholder: "예: SwiftUI, 디자인 패턴, 팀 협업 방법..."
            )

            editableField(
                title: "목표 달성을 위해 지금 하고 있는 노력들",
                text: $profile.currentEfforts,
                icon: "flame",
                placeholder: "예: 매일 1시간씩 코딩 연습, 주 3회 알고리즘 문제 풀이..."
            )
        }
    }

    private func editableField(
        title: String,
        text: Binding<String>,
        icon: String,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)

            TextEditor(text: text)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - 메타데이터

    private var metadataSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("최초 작성")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(profile.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if profile.updatedAt != profile.createdAt {
                HStack {
                    Text("마지막 수정")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(profile.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - 액션

    private func saveAndClose() {
        profile.updatedAt = Date()
        isEditing = false
    }
}

// MARK: - Preview

struct MentoringProfileView_Previews: PreviewProvider {
    static var previews: some View {
        MentoringProfileView(profile: .constant(MentoringProfile(
            background: "저는 디자인에 관심이 많고, 작은 프로젝트를 해본 경험이 있습니다.",
            academyGoal: "iOS 개발자로 취업하여 사용자에게 가치있는 앱을 만들고 싶습니다.",
            learningPlan: "SwiftUI, 디자인 패턴, 팀 협업 방법을 배우고 싶습니다.",
            currentEfforts: "매일 1시간씩 코딩 연습을 하고 있고, 주 3회 알고리즘 문제를 풀고 있습니다."
        )))
    }
}
