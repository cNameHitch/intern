import SwiftUI

struct LogsView: View {
    @StateObject private var vm = LogsViewModel()
    @EnvironmentObject var daemonMonitor: DaemonMonitor

    var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            HStack(spacing: 8) {
                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.lcTextMuted)
                    TextField("Search logs...", text: $vm.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundColor(.lcTextPrimary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: LCRadius.button)
                        .stroke(Color.lcSeparator, lineWidth: 1)
                )
                .cornerRadius(LCRadius.button)
                .frame(width: 240)

                Spacer()

                // Filter buttons
                HStack(spacing: 4) {
                    ForEach(LogFilter.allCases, id: \.self) { filter in
                        Button {
                            vm.filter = filter
                            Task { await vm.loadLogs() }
                        } label: {
                            Text(filter.displayName)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(vm.filter == filter ? .lcAccentLight : .lcTextSubtle)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(vm.filter == filter ? Color.lcAccentBg : Color.clear)
                                .cornerRadius(LCRadius.filter)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)

            // Error display
            if let error = vm.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.lcRed)
                    Text(error)
                        .font(.lcCaption)
                        .foregroundColor(.lcRed)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
            }

            // Log table
            VStack(spacing: 0) {
                LogTableHeader()

                if vm.isLoading && vm.logs.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading logs...")
                            .font(.lcBodyMedium)
                            .foregroundColor(.lcTextMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(LCSpacing.p32)
                } else if vm.logs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(.lcTextFaint)
                        Text("No logs found")
                            .font(.lcBodyMedium)
                            .foregroundColor(.lcTextMuted)
                        if vm.filter != .all || !vm.searchQuery.isEmpty {
                            Text("Try adjusting your search or filter")
                                .font(.lcCaption)
                                .foregroundColor(.lcTextSubtle)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(LCSpacing.p32)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.logs) { log in
                                LogEntryRow(
                                    log: log,
                                    isExpanded: vm.isExpanded(log.id),
                                    onToggle: { vm.toggleExpanded(log.id) }
                                )
                            }
                        }
                    }
                }
            }
            .background(Color.lcSurfaceContainer)
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.panel)
                    .stroke(Color.lcBorder, lineWidth: LCBorder.standard)
            )
            .cornerRadius(LCRadius.panel)
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
        .background(Color.lcBackground)
        .onAppear {
            vm.setClient(daemonMonitor.client)
            vm.setupSearchDebounce()
            Task { await vm.loadLogs() }
        }
        // Search debounce is handled by setupSearchDebounce()
    }
}
