//
//  BatteryView.swift
//  AirBattery
//
//  Created by apple on 2024/2/23.
//

import SwiftUI

struct BatteryView: View {
    var item: Device
    var body: some View {
        let width = round(max(1, min(19, Double(item.batteryLevel)/100*19)))
        ZStack{
            ZStack(alignment: .leading) {
                Image("batt_outline_bold")
                Group{
                    Rectangle()
                        .fill(Color(getPowerColor(item)))
                        .frame(width: width, height: 8, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
                }.offset(x:2)
            }
            //.frame(width: 25.5, height: 12, alignment: .leading)
            if item.deviceID == "@MacInternalBattery" {
                if item.acPowered {
                    Image("batt_" + ((item.isCharging != 0 || item.isCharged) ? "bolt" : "plug") + "_mask")
                        .blendMode(.destinationOut)
                        .offset(x:-1.5)
                    Image("batt_" + ((item.isCharging != 0 || item.isCharged) ? "bolt" : "plug"))
                        .offset(x:-1.5)
                        .foregroundColor(.blackWhite)
                }
            }else{
                if item.isCharging != 0 {
                    Image("batt_" + ((item.isCharging == 5) ? "plug" : "bolt") + "_mask")
                        .blendMode(.destinationOut)
                        .offset(x:-1.5)
                    Image("batt_" + ((item.isCharging == 5) ? "plug" : "bolt"))
                        .offset(x:-1.5)
                        .foregroundColor(.blackWhite)
                }
            }
        }.compositingGroup()
    }
}

struct mainBatteryView: View {
    @State var item: iBattery = InternalBattery.status
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("intBattOnStatusBar") var intBattOnStatusBar = true
    @AppStorage("colorfulBattery") var colorfulBattery = false
    @AppStorage("iosBatteryStyle") var iosBatteryStyle = false
    @AppStorage("batteryPercent") var batteryPercent = "outside"
    @AppStorage("batteryTimeLeft") var batteryTimeLeft = false
    @AppStorage("batteryTimeToFull") var batteryTimeToFull = false
    @AppStorage("batteryTimePosition") var batteryTimePosition = "right"
    @AppStorage("batteryTimeFormat") var batteryTimeFormat = "compact"
    @AppStorage("internalLevel") var internalLevel = false
    @AppStorage("hideLevel") var hideLevel = 90
    
    @AppStorage("test_debug") var test_debug = false
    @AppStorage("test_hasib") var test_hasib = false
    @AppStorage("test_acpower") var test_ac = false
    @AppStorage("test_full") var test_full = false
    @AppStorage("test_iblevel") var test_iblevel = 100
    
    @State var factor = 0.0

    var showTime: Bool {
        (item.acPowered ? batteryTimeToFull : batteryTimeLeft) && item.hasBattery && intBattOnStatusBar
            && !item.timeLeft.isEmpty && item.timeLeft != "…" && item.timeLeft != "∞"
    }

    var timeText: String {
        let parts = item.timeLeft.split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else {
            return item.timeLeft
        }
        if batteryTimeFormat == "long" {
            var components: [String] = []
            if hours > 0 { components.append("\(hours) hour\(hours == 1 ? "" : "s")") }
            if minutes > 0 { components.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
            return components.isEmpty ? "0 minutes" : components.joined(separator: " ")
        }
        if hours > 0 && minutes > 0 { return "\(hours)h\(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }

    func timeWidth(_ size: CGFloat) -> Double {
        (timeText as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium)]).width
    }

    func timeLabel(_ size: CGFloat) -> some View {
        Text(timeText)
            .font(.system(size: size, weight: .medium))
            .monospacedDigit()
    }

    @ViewBuilder
    var batteryContent: some View {
        if item.hasBattery && intBattOnStatusBar {
            if batteryPercent == "only" {
                Text("\(item.batteryLevel)%").font(.system(size: 11))
            } else {
                if batteryPercent == "outside" && !(item.batteryLevel > hideLevel) {
                    Text("\(item.batteryLevel)%").font(.system(size: 11))
                }
                if !iosBatteryStyle {
                    let width = round(max(2, min(19, Double(item.batteryLevel)/100*19)))
                    ZStack(alignment: .leading){
                        if colorfulBattery || batteryPercent == "inside" {
                            Image("batt_outline_bold")
                        } else {
                            Image("batt_outline")
                        }
                        if batteryPercent == "inside" && !(item.batteryLevel > hideLevel) {
                            BatteryLevelView(item: item)
                                .scaleEffect(0.9)
                                .foregroundColor(colorfulBattery ? Color(getPowerColor(ib2ab(item))) : .primary)
                                .offset(x: item.batteryLevel < 100 ? -1 : -0.5)
                        } else {
                            Rectangle()
                                .fill(colorfulBattery ? Color(getPowerColor(ib2ab(item))) : (item.batteryLevel <= 10 ? .red : .primary))
                                .frame(width: width, height: 8, alignment: .leading)
                                .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
                                .offset(x:2)
                            if item.acPowered {
                                Image("batt_" + ((item.isCharging || item.isCharged) ? "bolt" : "plug") + "_mask")
                                    .blendMode(.destinationOut)
                                    .offset(x:6)
                                Image("batt_" + ((item.isCharging || item.isCharged) ? "bolt" : "plug"))
                                    .offset(x:6)
                                    .foregroundColor(.blackWhite)
                            }
                        }
                    
                    }.compositingGroup()
                } else {
                    ZStack(alignment: .leading) {
                        Image("battery.100percent")
                            .resizable().scaledToFit()
                            .frame(width: 27)
                            .opacity(0.4)
                            .mask (
                                HStack {
                                    Spacer().frame(minWidth: 0)
                                    Rectangle().frame(width: min(25, CGFloat(100 - item.batteryLevel) / 100 * 27))
                                }
                            )
                        Image("battery.100percent")
                            .resizable().scaledToFit()
                            .foregroundColor(colorfulBattery ? Color(getPowerColor(ib2ab(item)) + "2") : (item.batteryLevel <= 10 ? .red : .primary))
                            .frame(width: 27)
                            .mask (
                                HStack {
                                    Rectangle().frame(width: max(2, CGFloat(item.batteryLevel) / 100 * 27))
                                    Spacer().frame(minWidth: 0)
                                }
                            )
                        if batteryPercent == "inside" && !(item.batteryLevel > hideLevel) {
                            if colorfulBattery {
                                BatteryLevelView(item: item)
                                    .foregroundColor(.white)
                            } else {
                                BatteryLevelView(item: item)
                                    .foregroundColor(.white)
                                    .blendMode(.destinationOut)
                            }
                        } else {
                            if item.acPowered {
                                Image("batt_" + ((item.isCharging || item.isCharged) ? "bolt" : "plug") + "_mask")
                                    .blendMode(.destinationOut)
                                    .offset(x:6.5)
                                Image("batt_" + ((item.isCharging || item.isCharged) ? "bolt" : "plug"))
                                    .offset(x:6.5)
                                    .foregroundColor(.blackWhite)
                            }
                        }
                    }.compositingGroup()
                }
            }
        } else {
            Image("bolt.square.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        }
    }

    func targetWidth() -> Double {
        if !(item.hasBattery && intBattOnStatusBar) { return 36 }
        var width: Double = 42
        if batteryPercent == "outside" && !(item.batteryLevel > hideLevel) { width = 76 }
        if showTime {
            let horizontal = batteryTimePosition == "left" || batteryTimePosition == "right"
            width = horizontal ? width + timeWidth(9) + 6 : max(width, timeWidth(8) + 4)
        }
        return width
    }

    var body: some View {
        Group {
            if showTime {
                switch batteryTimePosition {
                case "left":
                    HStack(alignment: .center, spacing: 3) { timeLabel(9); batteryContent }
                case "top":
                    VStack(spacing: 1) { timeLabel(8); batteryContent }
                case "bottom":
                    VStack(spacing: 1) { batteryContent; timeLabel(8) }
                default:
                    HStack(alignment: .center, spacing: 3) { batteryContent; timeLabel(9) }
                }
            } else {
                HStack(alignment: .center, spacing: 4) { batteryContent }
            }
        }
        .onReceive(dockTimer) { t in refeshPinnedBar() }
        .onReceive(mainTimer) { t in
            if item.hasBattery {
                InternalBattery.status = getPowerState()
                let width = statusBarItem.button?.frame.size.width
                if intBattOnStatusBar {
                    if test_debug {
                        InternalBattery.status = iBattery(hasBattery: test_hasib, isCharging: !test_full, isCharged: false, acPowered: test_ac, timeLeft: "", batteryLevel: test_iblevel)
                    } else {
                        InternalBattery.status = getPowerState()
                    }
                    item = InternalBattery.status
                    let target = targetWidth()
                    if width != target { setStatusBar(width: target) }
                } else {
                    if width != 36 { setStatusBar(width: 36) }
                }
            } else {
                if test_debug {
                    let width = statusBarItem.button?.frame.size.width
                    if width != 36 { setStatusBar(width: 36) }
                    InternalBattery.status = iBattery(hasBattery: test_hasib, isCharging: !test_full, isCharged: false, acPowered: test_ac, timeLeft: "", batteryLevel: test_iblevel)
                    item = InternalBattery.status
                }
            }
        }
    }
}

struct BatteryLevelView: View {
    var item: iBattery
    
    var body: some View {
        Group {
            if item.acPowered {
                HStack(spacing: -1) {
                    Text("\(item.batteryLevel)")
                        .font(.system(size: item.batteryLevel > 99 ? 10 : 11, weight: .medium))
                        .tracking(item.batteryLevel > 99 ? -0.3 : 0)
                        .offset(y: item.batteryLevel > 99 ? 0.4 : 0.5)
                    Image((item.isCharging || item.isCharged) ? "bolt.fill" : "powerplug.portrait.fill")
                        .resizable().scaledToFit()
                        .frame(width: 5)
                        .padding(.leading, 1)
                        .offset(y:item.batteryLevel < 100 ? 0.5 : 0)
                }
                .offset(x: item.batteryLevel < 100 ? 0.5 : -0.5)
                .offset(y: (item.acPowered && item.batteryLevel < 100) ? -0.5 : 0)
            } else {
                Text("\(item.batteryLevel)")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .frame(maxHeight: 12, alignment: .center)
        .frame(maxWidth: 24, alignment: .center)
    }
}

func setStatusBar(width: Double) {
    let iconView = NSHostingView(rootView: mainBatteryView())
    iconView.frame = NSRect(x: 0, y: 0, width: width, height: 21.5)
    statusBarItem.button?.subviews.removeAll()
    statusBarItem.button?.addSubview(iconView)
    statusBarItem.button?.frame = iconView.frame
}
