//
//  RetroTimerView.swift
//  WakTrainerFeatureWorkout
//
//  Created by COMATOKI on 2026-08-02.
//

import SwiftUI

struct RetroTimerView: View {
    // 실제 타이머 로직을 위한 상태 변수들
    @State private var hours = 12
    @State private var minutes = 0
    @State private var seconds = 59
    @State private var timerActive = false
    
    // 1초마다 신호를 주는 타이머 퍼블리셔
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 30) {
            // MARK: - 타이머 본체 (흰색 베젤)
            VStack {
                // 상단 로고 영역 (이미지의 2EUS 로고 위치)
                HStack {
                    Text("SwiftUI")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Text("T-100")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding([.horizontal, .top], 20)

                // MARK: - LCD 디스플레이 화면
                ZStack {
                    // LCD 배경색 (약간 초록빛이 도는 회색)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.8, green: 0.82, blue: 0.8))
                        .frame(height: 150)
                        .overlay(
                            // LCD 화면 안쪽 그림자 효과 (오목해 보이게)
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                                .blur(radius: 1)
                                .offset(x: 1, y: 1)
                                .mask(RoundedRectangle(cornerRadius: 10).fill(LinearGradient(gradient: Gradient(colors: [Color.black, Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing)))
                        )

                    // 디지털 시간 표시 (고정폭 폰트로 숫자가 움직이지 않게 함)
                    HStack(alignment: .bottom, spacing: 2) {
                        // 시:분
                        Text(String(format: "%02d:%02d", hours, minutes))
                            .font(.system(size: 80, weight: .black, design: .monospaced))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1)) // 아주 진한 회색 (숫자색)
                        
                        // 초 (이미지처럼 약간 작게 표시)
                        Text(String(format: "%02d", seconds))
                            .font(.system(size: 45, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .padding(.bottom, 10) // 아래쪽 정렬 맞춤
                    }
                }
                .padding(.horizontal, 15)

                // MARK: - 하단 버튼 영역
                HStack(spacing: 20) {
                    // 원형 버튼 3개 (이미지의 M, S, 모델명 버튼 위치)
                    Group {
                        CircleButton(text: "H") // Hour 설정용 가정
                        CircleButton(text: "M") // Minute 설정용 가정
                        CircleButton(text: "CLR") // Clear용 가정
                    }

                    Spacer()

                    // 타원형 START/STOP 버튼
                    Button(action: {
                        timerActive.toggle()
                    }) {
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 120, height: 50)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                            .overlay(
                                Text(timerActive ? "STOP" : "START")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(timerActive ? .red : .blue)
                            )
                            // 버튼 입체감 효과
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 2, y: 2)
                    }
                }
                .padding([.horizontal, .bottom], 25)
                .padding(.top, 10)

            }
            .background(Color.white)
            .cornerRadius(30) // 전체 외관의 크고 둥근 모서리
            // 전체 본체 그림자 및 입체감 효과
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 5, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .frame(width: 380) // 타이머 전체 너비 고정

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97)) // 앱 배경색 (약간 밝은 회색)
        // 타이머 로직 처리
        .onReceive(timer) { _ in
            if timerActive {
                performTimerTick()
            }
        }
    }
    
    // MARK: - 타이머 로직 함수
    private func performTimerTick() {
        if seconds > 0 {
            seconds -= 1
        } else {
            if minutes > 0 {
                minutes -= 1
                seconds = 59
            } else {
                if hours > 0 {
                    hours -= 1
                    minutes = 59
                    seconds = 59
                } else {
                    // 타이머 종료
                    timerActive = false
                    // 여기에 알람음 추가 가능
                }
            }
        }
    }
}

// MARK: - 공통 원형 버튼 컴포넌트
struct CircleButton: View {
    var text: String
    
    var body: some View {
        Button(action: {}) {
            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .overlay(
                    Text(text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                )
                // 버튼 입체감 효과
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 1, y: 1)
        }
    }
}

// MARK: - 미리보기
struct RetroTimerView_Previews: PreviewProvider {
    static var previews: some View {
        RetroTimerView()
    }
}
