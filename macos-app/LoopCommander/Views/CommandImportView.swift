import SwiftUI

/// A discovered Claude Code command from a .claude/commands/ directory.
struct ClaudeCommand: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let content: String
    let projectPath: String
    let projectName: String
    let filePath: String
}

/// Scans the filesystem for Claude Code custom commands and presents them for import.
struct CommandImportView: View {
    let onImport: (ClaudeCommand) -> Void
    let onDismiss: () -> Void

    @State private var commands: [ClaudeCommand] = []
    @State private var isScanning = true
    @State private var searchText = ""
    @State private var selectedCommand: ClaudeCommand?

    private var filteredCommands: [ClaudeCommand] {
        if searchText.isEmpty { return commands }
        let query = searchText.lowercased()
        return commands.filter {
            $0.name.lowercased().contains(query) ||
            $0.description.lowercased().contains(query) ||
            $0.projectName.lowercased().contains(query)
        }
    }

    /// Group commands by project
    private var groupedCommands: [(String, [ClaudeCommand])] {
        let grouped = Dictionary(grouping: filteredCommands) { $0.projectName }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Import Claude Command")
                    .font(.lcHeading)
                    .foregroundColor(.lcTextPrimary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.lcTextMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.lcTextMuted)
                TextField("Filter commands...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.lcInput)
                    .foregroundColor(.lcTextPrimary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.lcCodeBackground)
            .overlay(
                RoundedRectangle(cornerRadius: LCRadius.button)
                    .stroke(Color.lcBorderInput, lineWidth: 1)
            )
            .cornerRadius(LCRadius.button)
            .padding(.bottom, 16)

            // Content
            if isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning for Claude commands...")
                        .font(.lcBodyMedium)
                        .foregroundColor(.lcTextMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if commands.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.lcTextFaint)
                    Text("No commands found")
                        .font(.lcBodyMedium)
                        .foregroundColor(.lcTextMuted)
                    Text("Place .md files in .claude/commands/ within your projects")
                        .font(.lcCaption)
                        .foregroundColor(.lcTextSubtle)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedCommands, id: \.0) { projectName, cmds in
                            VStack(alignment: .leading, spacing: 8) {
                                // Project header
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.lcAccent)
                                    Text(projectName)
                                        .font(.lcSectionLabel)
                                        .foregroundColor(.lcTextMuted)
                                }

                                ForEach(cmds) { cmd in
                                    CommandRow(
                                        command: cmd,
                                        isSelected: selectedCommand == cmd
                                    )
                                    .onTapGesture { selectedCommand = cmd }
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 20)

            // Footer
            HStack(spacing: 10) {
                if let cmd = selectedCommand {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected: /\(cmd.name)")
                            .font(.lcCaption)
                            .foregroundColor(.lcAccentLight)
                        Text(cmd.projectName)
                            .font(.system(size: 10))
                            .foregroundColor(.lcTextSubtle)
                    }
                }
                Spacer()
                Button("Cancel", action: onDismiss)
                    .buttonStyle(LCSecondaryButtonStyle())
                Button("Import") {
                    if let cmd = selectedCommand {
                        onImport(cmd)
                        onDismiss()
                    }
                }
                .buttonStyle(LCPrimaryButtonStyle())
                .disabled(selectedCommand == nil)
            }
        }
        .padding(32)
        .frame(width: 600, height: 500)
        .background(Color.lcSurface)
        .task { await scanForCommands() }
    }

    private func scanForCommands() async {
        let found = await Task.detached {
            CommandScanner.scan()
        }.value
        commands = found
        isScanning = false
    }
}

// MARK: - Command Row

private struct CommandRow: View {
    let command: ClaudeCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("/\(command.name)")
                    .font(.lcBodyMedium)
                    .foregroundColor(isSelected ? .lcAccentLight : .lcTextPrimary)
                if !command.description.isEmpty {
                    Text(command.description)
                        .font(.lcCaption)
                        .foregroundColor(.lcTextMuted)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .lcAccent : .lcTextFaint)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.lcAccentBgSubtle : Color.lcCodeBackground)
        .overlay(
            RoundedRectangle(cornerRadius: LCRadius.button)
                .stroke(isSelected ? Color.lcAccent : Color.lcBorderInput, lineWidth: 1)
        )
        .cornerRadius(LCRadius.button)
        .contentShape(Rectangle())
    }
}

// MARK: - Filesystem Scanner

enum CommandScanner {
    /// Scan well-known locations for Claude Code commands, skills, and agents.
    static func scan() -> [ClaudeCommand] {
        var results: [ClaudeCommand] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // 1. Global user commands: ~/.claude/commands/
        let globalCmds = home.appendingPathComponent(".claude/commands")
        results.append(contentsOf: scanDirectory(globalCmds, projectName: "Global", projectPath: globalCmds.path))

        // 2. Global plugins: ~/.claude/plugins/marketplaces/**/commands/*.md and skills/*/SKILL.md
        let pluginsDir = home.appendingPathComponent(".claude/plugins/marketplaces")
        if fm.fileExists(atPath: pluginsDir.path) {
            results.append(contentsOf: scanPlugins(pluginsDir))
        }

        // 3. Scan common project roots for .claude/{commands,agents,skills}
        let searchRoots = [
            home.appendingPathComponent("Desktop/git"),
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("repos"),
            home.appendingPathComponent("src"),
            home.appendingPathComponent("Code"),
        ]

        for root in searchRoots {
            guard fm.fileExists(atPath: root.path) else { continue }
            guard let entries = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                let projectName = entry.lastPathComponent
                let claudeBase = entry.appendingPathComponent(".claude")
                guard fm.fileExists(atPath: claudeBase.path) else { continue }

                // .claude/commands/*.md
                let cmdsDir = claudeBase.appendingPathComponent("commands")
                results.append(contentsOf: scanDirectory(cmdsDir, projectName: projectName, projectPath: entry.path))

                // .claude/agents/*.md
                let agentsDir = claudeBase.appendingPathComponent("agents")
                results.append(contentsOf: scanDirectory(agentsDir, projectName: projectName, projectPath: entry.path))

                // .claude/skills/*/SKILL.md (each skill is a subdirectory)
                let skillsDir = claudeBase.appendingPathComponent("skills")
                results.append(contentsOf: scanSkillsDirectory(skillsDir, projectName: projectName, projectPath: entry.path))
            }
        }

        return results.sorted { $0.name < $1.name }
    }

    /// Parse all .md files in a single flat directory (commands/ or agents/).
    private static func scanDirectory(_ dir: URL, projectName: String, projectPath: String) -> [ClaudeCommand] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }

        return files.compactMap { url -> ClaudeCommand? in
            guard url.pathExtension == "md" else { return nil }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

            let name = parseFrontmatterField(content, field: "name")
                ?? url.deletingPathExtension().lastPathComponent
            let description = parseFrontmatterDescription(content)

            return ClaudeCommand(
                name: name,
                description: description,
                content: content,
                projectPath: projectPath,
                projectName: projectName,
                filePath: url.path
            )
        }
    }

    /// Scan .claude/skills/ where each skill is a subdirectory containing SKILL.md.
    private static func scanSkillsDirectory(_ dir: URL, projectName: String, projectPath: String) -> [ClaudeCommand] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries.compactMap { subdir -> ClaudeCommand? in
            let skillFile = subdir.appendingPathComponent("SKILL.md")
            guard let content = try? String(contentsOf: skillFile, encoding: .utf8) else { return nil }

            let name = parseFrontmatterField(content, field: "name")
                ?? subdir.lastPathComponent
            let description = parseFrontmatterDescription(content)

            return ClaudeCommand(
                name: name,
                description: description,
                content: content,
                projectPath: projectPath,
                projectName: projectName,
                filePath: skillFile.path
            )
        }
    }

    /// Recursively scan the plugins marketplace directory for commands and skills.
    private static func scanPlugins(_ dir: URL) -> [ClaudeCommand] {
        var results: [ClaudeCommand] = []
        let fm = FileManager.default
        guard let marketplaces = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for marketplace in marketplaces {
            let pluginsDir = marketplace.appendingPathComponent("plugins")
            guard let plugins = try? fm.contentsOfDirectory(
                at: pluginsDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for plugin in plugins {
                let pluginName = plugin.lastPathComponent

                // plugins/*/commands/*.md
                let cmdsDir = plugin.appendingPathComponent("commands")
                results.append(contentsOf: scanDirectory(cmdsDir, projectName: pluginName, projectPath: plugin.path))

                // plugins/*/agents/*.md
                let agentsDir = plugin.appendingPathComponent("agents")
                results.append(contentsOf: scanDirectory(agentsDir, projectName: pluginName, projectPath: plugin.path))

                // plugins/*/skills/*/SKILL.md
                let skillsDir = plugin.appendingPathComponent("skills")
                results.append(contentsOf: scanSkillsDirectory(skillsDir, projectName: pluginName, projectPath: plugin.path))
            }
        }

        return results
    }

    /// Extract the `description:` field from YAML frontmatter.
    private static func parseFrontmatterDescription(_ content: String) -> String {
        return parseFrontmatterField(content, field: "description") ?? ""
    }

    /// Extract a named field from YAML frontmatter.
    private static func parseFrontmatterField(_ content: String, field: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        let prefix = "\(field):"
        for (i, line) in lines.enumerated() {
            if i == 0 { continue }
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                let value = trimmed
                    .dropFirst(prefix.count)
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
}
