# Loop Commander

System-level macOS scheduler for Claude Code tasks with a native SwiftUI dashboard.

## Architecture

7-crate Cargo workspace + native Swift macOS app:
- `lc-core`: Domain types, errors, IPC messages, validation
- `lc-config`: YAML config read/write for global config + per-task files
- `lc-scheduler`: launchd plist generation, launchctl bootstrap/bootout
- `lc-runner`: Standalone binary invoked by launchd to execute claude commands
- `lc-logger`: SQLite persistence for execution logs
- `lc-daemon`: Long-running Unix socket server, health checks, task lifecycle
- `lc-cli`: Command line interface communicating with daemon via JSON-RPC
- `macos-app/`: Native SwiftUI app communicating with daemon via JSON-RPC

All data lives in ~/.loop-commander/

## Key constraints

- macOS only (launchd, ~/Library/LaunchAgents)
- Tasks persist across reboots (launchd user agents)
- SQLite in WAL mode (concurrent readers)
- JSON-RPC 2.0 over Unix domain socket for IPC
- Daemon is the SOLE API server — both CLI and Swift app communicate through it
- lc-runner is a separate binary for process isolation
- No FFI between Swift and Rust — pure JSON-RPC over socket
- All YAML writes are atomic (temp file + fsync + rename)
- Socket at ~/.loop-commander/daemon.sock (not /tmp/)
- launchctl bootstrap/bootout (modern API, not deprecated load/unload)

## Testing

Run `cargo test --workspace` from root. Every crate has unit tests.
Run `swift build` from `macos-app/` for the Swift app.
Integration tests may need launchd access (skip in CI with `#[cfg(not(ci))]`).

## File locations

- ~/.loop-commander/config.yaml — global settings
- ~/.loop-commander/tasks/*.yaml — one file per task
- ~/.loop-commander/plists/*.plist — generated launchd plists
- ~/.loop-commander/output/*.log — stdout/stderr from runs
- ~/.loop-commander/logs.db — SQLite execution log
- ~/.loop-commander/daemon.pid — daemon PID
- ~/.loop-commander/daemon.sock — daemon Unix socket
- ~/Library/LaunchAgents/com.loopcommander.task.*.plist — symlinks

## Build

```bash
# Rust
cargo build --release
# Binaries: target/release/loop-commander, target/release/lc-runner, target/release/lc

# Swift
cd macos-app && swift build
```
