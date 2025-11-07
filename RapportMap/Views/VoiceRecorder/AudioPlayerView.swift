//
//  AudioPlayerView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/7/25.
//

import SwiftUI

// MARK: - AudioPlayerView
struct AudioPlayerView: View {
    let audioURL: URL
    let totalDuration: TimeInterval
    
    @StateObject private var player = AudioPlayer()
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var isDragging = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.blue)
                Text("음성 기록")
                    .font(.headline)
                Spacer()
                Text(formatTime(player.duration > 0 ? player.duration : totalDuration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 프로그레스 바
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 배경
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        // 진행률
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: progressWidth(geometry: geometry), height: 4)
                            .cornerRadius(2)
                        
                        // 드래그 핸들
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 16)
                            .offset(x: progressWidth(geometry: geometry) - 8)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        isDragging = true
                                        let progress = min(max(0, (value.location.x / geometry.size.width)), 1)
                                        let seekTime = progress * (player.duration > 0 ? player.duration : totalDuration)
                                        currentTime = seekTime
                                    }
                                    .onEnded { value in
                                        let progress = min(max(0, (value.location.x / geometry.size.width)), 1)
                                        let seekTime = progress * (player.duration > 0 ? player.duration : totalDuration)
                                        player.seek(to: seekTime)
                                        isDragging = false
                                    }
                            )
                    }
                }
                .frame(height: 16)
                
                // 시간 표시
                HStack {
                    Text(formatTime(isDragging ? currentTime : player.currentTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                    
                    Spacer()
                    
                    Text(formatTime(player.duration > 0 ? player.duration : totalDuration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            
            // 컨트롤 버튼들
            HStack {
                // 15초 뒤로
                Button {
                    player.skip(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .disabled(!player.isReady)
                
                Spacer()
                
                // 재생/일시정지
                Button {
                    if isPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                }
                .disabled(!player.isReady)
                
                Spacer()
                
                // 15초 앞으로
                Button {
                    player.skip(by: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .disabled(!player.isReady)
            }
            .padding(.horizontal)
            
            // 재생 속도 조절
            HStack {
                Text("재생 속도:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                        Button {
                            player.setPlaybackRate(Float(speed))
                        } label: {
                            Text("\(speed, specifier: "%.2g")x")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    player.playbackRate == Float(speed)
                                        ? Color.blue
                                        : Color.gray.opacity(0.2)
                                )
                                .foregroundStyle(
                                    player.playbackRate == Float(speed)
                                        ? .white
                                        : .primary
                                )
                                .cornerRadius(12)
                        }
                        .disabled(!player.isReady)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            player.loadAudio(from: audioURL)
        }
        .onDisappear {
            player.stop()
        }
        .onReceive(player.timePublisher) { time in
            if !isDragging {
                currentTime = time
            }
        }
        .onReceive(player.didFinishPlaying) {
            isPlaying = false
        }
    }
    
    private func progressWidth(geometry: GeometryProxy) -> CGFloat {
        let duration = player.duration > 0 ? player.duration : totalDuration
        guard duration > 0 else { return 0 }
        
        let time = isDragging ? currentTime : player.currentTime
        let progress = time / duration
        return geometry.size.width * progress
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
