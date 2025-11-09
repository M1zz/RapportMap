//
//  CriticalActionReminderRow.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//

import SwiftUI
import SwiftData

// MARK: - ReminderStatus
enum ReminderStatus: Equatable {
    case notSet
    case overdue(days: Int)
    case today
    case soon(days: Int)
    case future
}

// MARK: - CriticalActionReminderRow
struct CriticalActionReminderRow: View {
    @Bindable var personAction: PersonAction
    @Environment(\.modelContext) private var context
    @State private var showingReminderPicker = false
    
    // 리마인더 상태 체크
    private var reminderStatus: ReminderStatus {
        guard let reminderDate = personAction.reminderDate else {
            return .notSet
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let reminder = calendar.startOfDay(for: reminderDate)
        
        let days = calendar.dateComponents([.day], from: today, to: reminder).day ?? 0
        
        if days < 0 {
            return .overdue(days: abs(days))
        } else if days == 0 {
            return .today
        } else if days <= 3 {
            return .soon(days: days)
        } else {
            return .future
        }
    }
    
    // 최근 5분 내에 추가된 항목인지 확인 (PersonAction에는 추가 시간이 없으므로 RapportAction의 ID로 추정)
    private func isRecentlyAdded() -> Bool {
        // PersonAction에는 생성 시간이 없으므로, action의 order가 999인 커스텀 액션이면서
        // 아직 완료되지 않은 상태인 경우를 최근 추가로 간주
        guard let action = personAction.action else { return false }
        
        // 커스텀 액션(order 999)이면서 아직 완료되지 않은 경우
        return action.order == 999 && !personAction.isCompleted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let action = personAction.action {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            // Critical 액션 완료 시 특별 표시
                            if personAction.isCompleted {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green) // 초록색으로 변경
                            }
                            
                            Text(action.title)
                                .font(.headline)
                                .foregroundStyle(
                                    personAction.isCompleted
                                        ? .secondary // Critical 완료 시 회색으로 변경
                                        : .primary
                                )
                                .strikethrough(personAction.isCompleted, color: .orange) // Critical 액션도 완료되면 취소선 적용
                            
                            // 새로 추가된 항목 표시
                            if isRecentlyAdded() {
                                Text("NEW")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            
                            // 긴급도 뱃지 (미완료 시에만)
                            if !personAction.isCompleted {
                                switch reminderStatus {
                                case .overdue(let days):
                                    Text("\(days)일 지남")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.red))
                                        .foregroundStyle(.white)
                                case .today:
                                    Text("오늘!")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.red))
                                        .foregroundStyle(.white)
                                case .soon(let days):
                                    Text("\(days)일 후")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.orange))
                                        .foregroundStyle(.white)
                                case .future, .notSet:
                                    EmptyView()
                                }
                            } else {
                                // 완료된 경우 완료 표시
                                Text("완료됨")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.green)) // 초록색으로 변경
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        if !action.actionDescription.isEmpty {
                            Text(action.actionDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // 완료된 액션의 결과 표시
                        if personAction.isCompleted && !personAction.context.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text(personAction.context)
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orange.gradient) // Critical 액션이므로 오렌지색 유지
                            )
                        }
                    }
                }
                
                Spacer()
                
                // 숨기기 버튼
                Button {
                    personAction.isVisibleInDetail = false
                    try? context.save()
                } label: {
                    Image(systemName: "eye.slash")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
                
                // 완료 체크박스
                Button {
                    // 완료 상태 토글 허용 (Critical 액션도 포함)
                    personAction.isCompleted.toggle()
                    if personAction.isCompleted {
                        personAction.markCompleted()
                    } else {
                        personAction.markIncomplete()
                    }
                    
                    // 관계 상태 즉시 업데이트
                    personAction.person?.updateRelationshipState()
                    
                    try? context.save()
                } label: {
                    Image(systemName: personAction.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(personAction.isCompleted ? .green : .gray) // 완료된 Critical도 초록색으로
                }
                .buttonStyle(.plain) // 버튼 스타일 추가
            }
            
            // 리마인더 설정 (미완료 시에만)
            if !personAction.isCompleted {
                HStack {
                    Button {
                        showingReminderPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: personAction.reminderDate != nil ? "bell.fill" : "bell")
                                .font(.caption)
                            
                            if let reminderDate = personAction.reminderDate {
                                Text(reminderDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                            } else {
                                Text("리마인더 설정")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(reminderStatus == .today || {
                            if case .overdue = reminderStatus { return true } else { return false }
                        }() ? Color.red : ( {
                            if case .soon = reminderStatus { return true } else { return false }
                        }() ? Color.orange : Color.blue))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill({ () -> Color in
                                if reminderStatus == .today { return Color.red.opacity(0.1) }
                                if case .overdue = reminderStatus { return Color.red.opacity(0.1) }
                                if case .soon = reminderStatus { return Color.orange.opacity(0.1) }
                                return Color.blue.opacity(0.1)
                            }())
                        )
                    }
                    .buttonStyle(.plain) // 버튼 스타일 추가
                    
                    if personAction.reminderDate != nil {
                        Button {
                            personAction.reminderDate = nil
                            personAction.isReminderActive = false
                            try? context.save()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain) // 버튼 스타일 추가
                    }
                }
            } else {
                // 완료된 액션의 완료일 표시
                if let completedDate = personAction.completedDate {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green) // 초록색으로 변경
                        Text("완료일: \(completedDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary) // 회색으로 변경
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(isRecentlyAdded() ? Color.orange.opacity(0.05) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle()) // 전체 영역을 탭 가능하게 하지만 기본 동작은 없음
        .sheet(isPresented: $showingReminderPicker) {
            ReminderPickerSheet(personAction: personAction)
        }
    }
}

// MARK: - ReminderPickerSheet
struct ReminderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var personAction: PersonAction
    
    @State private var selectedDate = Date()
    @State private var isSettingReminder = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("리마인더 일시") {
                    DatePicker("날짜와 시간", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                
                Section("미리보기") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.blue)
                            Text("알림 예정")
                                .font(.headline)
                        }
                        
                        Text(selectedDate.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if let action = personAction.action {
                            Text("\"\(action.title)\" 액션을 확인하세요")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Section {
                    Button {
                        Task {
                            await setupReminder()
                        }
                    } label: {
                        HStack {
                            if isSettingReminder {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Text("리마인더 설정")
                        }
                    }
                    .disabled(selectedDate <= Date() || isSettingReminder)
                } footer: {
                    if selectedDate <= Date() {
                        Text("미래 시간을 선택해주세요")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("리마인더 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                    .disabled(isSettingReminder)
                }
            }
            .onAppear {
                if let existingDate = personAction.reminderDate {
                    selectedDate = existingDate
                } else {
                    // 기본값: 1시간 후로 설정
                    selectedDate = Date().addingTimeInterval(3600)
                }
            }
        }
    }
    
    private func setupReminder() async {
        isSettingReminder = true
        
        // 권한 요청
        let hasPermission = await NotificationManager.shared.requestPermission()
        
        guard hasPermission else {
            isSettingReminder = false
            // TODO: 설정 앱으로 이동하도록 안내하는 얼럿 표시
            return
        }
        
        guard let action = personAction.action else {
            isSettingReminder = false
            return
        }
        
        let title = "\(action.title) 리마인더"
        let body = "\(personAction.person?.preferredName ?? personAction.person?.name ?? "")님과 관련된 중요한 액션을 확인해보세요"
        
        let success = await NotificationManager.shared.scheduleActionReminder(
            for: personAction,
            at: selectedDate,
            title: title,
            body: body
        )
        
        isSettingReminder = false
        
        if success {
            // 데이터베이스에 리마인더 정보 저장
            personAction.reminderDate = selectedDate
            personAction.isReminderActive = true
            try? context.save()
            
            // 성공 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            dismiss()
        }
        // TODO: 실패 시 에러 얼럿 표시
    }
}
