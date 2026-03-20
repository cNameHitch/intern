import SwiftUI

struct ScheduleBuilderView: View {
    @ObservedObject var vm: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            presetPicker
            subPicker
            cronReadout
        }
    }

    // MARK: - Preset Picker

    private var presetPicker: some View {
        LCFormField(label: "Preset") {
            Picker("Schedule", selection: $vm.schedulePreset) {
                ForEach(SchedulePreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: vm.schedulePreset) { _ in
                vm.syncCronFromPreset()
            }
        }
    }

    // MARK: - Sub Picker

    @ViewBuilder
    private var subPicker: some View {
        if vm.schedulePreset.requiresTimePicker {
            timeSubPicker
                .transition(.lcFadeSlide)
        }
        if vm.schedulePreset.requiresDayOfWeekPicker {
            dayOfWeekSubPicker
                .transition(.lcFadeSlide)
        }
        if vm.schedulePreset.requiresDayOfMonthPicker {
            dayOfMonthSubPicker
                .transition(.lcFadeSlide)
        }
        if vm.schedulePreset.isCustom {
            customCronField
                .transition(.lcFadeSlide)
        }
    }

    // MARK: - Time Sub Picker

    private var timeSubPicker: some View {
        LCFormField(label: "Time") {
            HStack(spacing: 4) {
                Picker("Hour", selection: $vm.selectedHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 70)
                .onChange(of: vm.selectedHour) { _ in vm.syncCronFromPreset() }

                Text(":")
                    .font(.lcBodyMedium)
                    .foregroundColor(.lcTextMuted)

                Picker("Minute", selection: $vm.selectedMinute) {
                    ForEach(stride(from: 0, to: 60, by: 5).map { $0 }, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 70)
                .onChange(of: vm.selectedMinute) { _ in vm.syncCronFromPreset() }
            }
        }
    }

    // MARK: - Day of Week Sub Picker

    private var dayOfWeekSubPicker: some View {
        LCFormField(label: "Day of Week") {
            HStack(spacing: 4) {
                ForEach(
                    Array(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].enumerated()),
                    id: \.offset
                ) { index, name in
                    DayChip(
                        label: name,
                        isSelected: vm.selectedWeekdays.contains(index)
                    ) {
                        vm.toggleWeekday(index)
                    }
                }
            }
        }
    }

    // MARK: - Day of Month Sub Picker

    private var dayOfMonthSubPicker: some View {
        LCFormField(label: "Day of Month") {
            VStack(alignment: .leading, spacing: 4) {
                Picker("Day", selection: $vm.selectedDayOfMonth) {
                    ForEach(1...28, id: \.self) { d in
                        Text("\(d)").tag(d)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: vm.selectedDayOfMonth) { _ in vm.syncCronFromPreset() }

                Text("Days 29-31 omitted for reliability across all months.")
                    .font(.lcCaption)
                    .foregroundColor(.lcTextSubtle)
            }
        }
    }

    // MARK: - Custom Cron Field

    private var customCronField: some View {
        LCFormField(label: "Cron Expression") {
            LCTextField(text: $vm.draft.schedule, placeholder: "*/15 * * * *")
        }
    }

    // MARK: - Cron Readout

    private var cronReadout: some View {
        let isInvalid = vm.schedulePreset.isCustom &&
                        vm.draft.schedule.split(separator: " ").count != 5
        return VStack(alignment: .leading, spacing: 3) {
            if isInvalid {
                Text("Invalid cron expression")
                    .font(.lcCaption)
                    .foregroundColor(.lcRed)
            } else {
                Text(vm.draft.schedule.isEmpty ? "—" : vm.draft.schedule)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.lcAccentLight)
                Text(vm.draft.scheduleHuman.isEmpty ? "—" : vm.draft.scheduleHuman)
                    .font(.lcCaption)
                    .foregroundColor(.lcTextSecondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isInvalid ? Color.lcRedBg : Color.lcCodeBackground)
        .overlay(
            RoundedRectangle(cornerRadius: LCRadius.button)
                .stroke(
                    isInvalid ? Color.lcRedBorder : Color.lcBorder,
                    lineWidth: 1
                )
        )
        .cornerRadius(LCRadius.button)
        .textSelection(.enabled)
        .accessibilityLabel("Cron expression: \(vm.draft.schedule). Meaning: \(vm.draft.scheduleHuman)")
    }
}

// MARK: - DayChip

private struct DayChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? .lcAccentLight : .lcTextMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? Color.lcAccentBgSubtle : Color.lcSurfaceContainer)
                .overlay(
                    RoundedRectangle(cornerRadius: LCRadius.badge)
                        .stroke(
                            isSelected ? Color.lcAccent : Color.lcBorderInput,
                            lineWidth: 1
                        )
                )
                .cornerRadius(LCRadius.badge)
        }
        .buttonStyle(.plain)
    }
}
