import { useState, useEffect, useCallback, useRef } from "react";

// ─── Data Layer (simulated - replace with IPC to Rust backend) ───────────────
const INITIAL_TASKS = [
  {
    id: "lc-a1b2c3d4",
    name: "PR Review Sweep",
    command: "claude -p 'Review all open PRs in this repo. Check for logic errors, missing tests, and style violations. Auto-fix what you can, leave comments on what you cannot.'",
    skill: "/review-pr",
    schedule: "0 */2 * * *",
    scheduleHuman: "Every 2 hours",
    workingDir: "~/projects/hello-ai-site",
    status: "active",
    maxBudget: 5.0,
    totalSpent: 12.47,
    createdAt: "2026-03-10T09:00:00Z",
    lastRun: "2026-03-15T14:00:00Z",
    nextRun: "2026-03-15T16:00:00Z",
    runCount: 42,
    successCount: 40,
    failCount: 2,
    tags: ["code-review", "automation"],
  },
  {
    id: "lc-e5f6g7h8",
    name: "Error Log Monitor",
    command: "claude -p 'Scan error logs from the last interval. Categorize by severity. If any are P0/P1, create a GitHub issue with reproduction steps.'",
    skill: null,
    schedule: "*/15 * * * *",
    scheduleHuman: "Every 15 minutes",
    workingDir: "~/projects/ferrum",
    status: "active",
    maxBudget: 2.0,
    totalSpent: 8.93,
    createdAt: "2026-03-12T11:30:00Z",
    lastRun: "2026-03-15T14:45:00Z",
    nextRun: "2026-03-15T15:00:00Z",
    runCount: 284,
    successCount: 281,
    failCount: 3,
    tags: ["monitoring", "ferrum"],
  },
  {
    id: "lc-i9j0k1l2",
    name: "Morning Briefing",
    command: "claude -p 'Generate a morning dev briefing: overnight commits, CI status, open issues assigned to me, dependency audit deltas. Output to ~/briefings/$(date +%Y-%m-%d).md'",
    skill: null,
    schedule: "0 7 * * 1-5",
    scheduleHuman: "Weekdays at 7:00 AM",
    workingDir: "~/projects",
    status: "active",
    maxBudget: 3.0,
    totalSpent: 4.21,
    createdAt: "2026-03-01T07:00:00Z",
    lastRun: "2026-03-14T07:00:00Z",
    nextRun: "2026-03-17T07:00:00Z",
    runCount: 10,
    successCount: 10,
    failCount: 0,
    tags: ["briefing", "daily"],
  },
  {
    id: "lc-m3n4o5p6",
    name: "Dependency Audit",
    command: "claude -p 'Run cargo audit and npm audit across all workspace crates and packages. Compare against yesterday\\'s snapshot. Flag new vulnerabilities with CVE details.'",
    skill: null,
    schedule: "0 6 * * *",
    scheduleHuman: "Daily at 6:00 AM",
    workingDir: "~/projects/cadence-ai",
    status: "paused",
    maxBudget: 2.0,
    totalSpent: 3.15,
    createdAt: "2026-03-05T06:00:00Z",
    lastRun: "2026-03-13T06:00:00Z",
    nextRun: null,
    runCount: 8,
    successCount: 7,
    failCount: 1,
    tags: ["security", "cadence-ai"],
  },
  {
    id: "lc-q7r8s9t0",
    name: "Test Suite Health",
    command: "claude -p 'Run the full test suite 3 times. Track flaky tests. Update .flaky-tests.json with any new entries. If flakiness rate > 5%, open an issue.'",
    skill: null,
    schedule: "0 0 * * *",
    scheduleHuman: "Daily at midnight",
    workingDir: "~/projects/gitr",
    status: "error",
    maxBudget: 4.0,
    totalSpent: 6.80,
    createdAt: "2026-03-08T00:00:00Z",
    lastRun: "2026-03-15T00:00:00Z",
    nextRun: "2026-03-16T00:00:00Z",
    runCount: 7,
    successCount: 5,
    failCount: 2,
    tags: ["testing", "gitr"],
  },
];

const INITIAL_LOGS = [
  { id: 1, taskId: "lc-a1b2c3d4", taskName: "PR Review Sweep", timestamp: "2026-03-15T14:00:12Z", duration: 47, status: "success", tokensUsed: 12450, cost: 0.31, summary: "Reviewed 3 PRs. Auto-fixed 2 lint issues on #142. Left comment on #145 re: missing error handling in auth middleware.", output: "PR #142: Fixed unused import and trailing whitespace\nPR #143: LGTM, no changes needed\nPR #145: Comment left on L47-52 about unwrap() in production path" },
  { id: 2, taskId: "lc-e5f6g7h8", taskName: "Error Log Monitor", timestamp: "2026-03-15T14:45:03Z", duration: 8, status: "success", tokensUsed: 3200, cost: 0.08, summary: "No P0/P1 errors. 2 P3 warnings logged (rate limiter threshold approaching).", output: "Scanned 147 log entries from last 15min window\nP3: Rate limiter at 82% capacity on /api/v1/quotes endpoint\nP3: Slow query detected: portfolio_positions JOIN (312ms)" },
  { id: 3, taskId: "lc-q7r8s9t0", taskName: "Test Suite Health", timestamp: "2026-03-15T00:00:45Z", duration: 312, status: "error", tokensUsed: 45000, cost: 1.12, summary: "Test run 2/3 failed: segfault in pack-objects interop test. Unable to complete flakiness analysis.", output: "Run 1: 1,187/1,200 passed (13 skipped)\nRun 2: FATAL - segfault in test_pack_objects_large_delta at line 847\nRun 3: Aborted due to Run 2 failure\n\nError: Process exited with signal 11 (SIGSEGV)" },
  { id: 4, taskId: "lc-a1b2c3d4", taskName: "PR Review Sweep", timestamp: "2026-03-15T12:00:08Z", duration: 32, status: "success", tokensUsed: 8900, cost: 0.22, summary: "Reviewed 1 PR. #144 approved with minor suggestion on naming convention.", output: "PR #144: Suggested renaming `process_data` to `transform_market_feed` for clarity\nApproved with comment" },
  { id: 5, taskId: "lc-e5f6g7h8", taskName: "Error Log Monitor", timestamp: "2026-03-15T14:30:02Z", duration: 6, status: "success", tokensUsed: 2100, cost: 0.05, summary: "Clean interval. No errors above P4.", output: "Scanned 89 log entries. All nominal." },
  { id: 6, taskId: "lc-i9j0k1l2", taskName: "Morning Briefing", timestamp: "2026-03-14T07:00:15Z", duration: 63, status: "success", tokensUsed: 18700, cost: 0.47, summary: "Briefing generated. 4 overnight commits, CI green, 2 issues assigned, no new vulnerabilities.", output: "Written to ~/briefings/2026-03-14.md\n\nHighlights:\n- 4 commits on main (2 from dependabot)\n- CI: All green across 3 repos\n- Issues: #89 (Ferrum alpha signal calibration), #12 (Cadence UI polish)\n- Deps: No new CVEs" },
  { id: 7, taskId: "lc-m3n4o5p6", taskName: "Dependency Audit", timestamp: "2026-03-13T06:00:22Z", duration: 89, status: "success", tokensUsed: 15400, cost: 0.39, summary: "1 new advisory found: tokio-rustls moderate severity. Patch available.", output: "cargo audit: 1 advisory (RUSTSEC-2026-0042 tokio-rustls)\nnpm audit: 0 vulnerabilities\n\nDelta from yesterday: +1 moderate\nRecommendation: Update tokio-rustls to 0.26.1" },
  { id: 8, taskId: "lc-e5f6g7h8", taskName: "Error Log Monitor", timestamp: "2026-03-15T14:15:02Z", duration: 7, status: "success", tokensUsed: 2800, cost: 0.07, summary: "1 P3 warning: Redis connection pool briefly saturated.", output: "Scanned 112 log entries\nP3: Redis pool hit max connections (32/32) for 1.2s at 14:11:03 UTC" },
];

// ─── Helpers ─────────────────────────────────────────────────────────────────

function cronToNext(cron) {
  // Simplified - real impl would parse cron properly
  return "in ~12 min";
}

function relativeTime(iso) {
  if (!iso) return "—";
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return `${days}d ago`;
}

function formatDuration(secs) {
  if (secs < 60) return `${secs}s`;
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return s > 0 ? `${m}m ${s}s` : `${m}m`;
}

function formatTimestamp(iso) {
  return new Date(iso).toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

const STATUS_CONFIG = {
  active: { color: "#22c55e", bg: "rgba(34,197,94,0.1)", label: "Active", icon: "●" },
  paused: { color: "#f59e0b", bg: "rgba(245,158,11,0.1)", label: "Paused", icon: "❚❚" },
  error: { color: "#ef4444", bg: "rgba(239,68,68,0.1)", label: "Error", icon: "✕" },
  success: { color: "#22c55e", bg: "rgba(34,197,94,0.08)", label: "Success", icon: "✓" },
};

// ─── Components ──────────────────────────────────────────────────────────────

function StatusBadge({ status }) {
  const cfg = STATUS_CONFIG[status] || STATUS_CONFIG.active;
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", gap: 5,
      padding: "3px 10px", borderRadius: 4,
      background: cfg.bg, color: cfg.color,
      fontSize: 11, fontWeight: 600, letterSpacing: "0.5px",
      textTransform: "uppercase", fontFamily: "'JetBrains Mono', monospace",
    }}>
      <span style={{ fontSize: 8 }}>{cfg.icon}</span> {cfg.label}
    </span>
  );
}

function MetricCard({ label, value, sub, accent }) {
  return (
    <div style={{
      padding: "18px 20px", borderRadius: 8,
      background: "rgba(255,255,255,0.02)",
      border: "1px solid rgba(255,255,255,0.06)",
      minWidth: 140,
    }}>
      <div style={{ fontSize: 11, color: "rgba(255,255,255,0.4)", fontWeight: 500, marginBottom: 6, letterSpacing: "0.5px", textTransform: "uppercase" }}>{label}</div>
      <div style={{ fontSize: 28, fontWeight: 700, color: accent || "#e2e8f0", fontFamily: "'JetBrains Mono', monospace", lineHeight: 1 }}>{value}</div>
      {sub && <div style={{ fontSize: 11, color: "rgba(255,255,255,0.35)", marginTop: 6 }}>{sub}</div>}
    </div>
  );
}

function TaskRow({ task, selected, onClick, onToggle }) {
  const successRate = task.runCount > 0 ? Math.round((task.successCount / task.runCount) * 100) : 0;
  return (
    <div
      onClick={onClick}
      style={{
        display: "grid",
        gridTemplateColumns: "1fr 160px 120px 90px 80px 70px",
        alignItems: "center",
        padding: "14px 20px",
        cursor: "pointer",
        background: selected ? "rgba(99,102,241,0.08)" : "transparent",
        borderLeft: selected ? "2px solid #818cf8" : "2px solid transparent",
        borderBottom: "1px solid rgba(255,255,255,0.04)",
        transition: "all 0.15s ease",
      }}
      onMouseEnter={(e) => { if (!selected) e.currentTarget.style.background = "rgba(255,255,255,0.02)"; }}
      onMouseLeave={(e) => { if (!selected) e.currentTarget.style.background = "transparent"; }}
    >
      <div>
        <div style={{ fontWeight: 600, fontSize: 13.5, color: "#e2e8f0", marginBottom: 3 }}>{task.name}</div>
        <div style={{ fontSize: 11, color: "rgba(255,255,255,0.35)", fontFamily: "'JetBrains Mono', monospace" }}>
          {task.workingDir}
        </div>
      </div>
      <div style={{ fontSize: 12, color: "rgba(255,255,255,0.5)", fontFamily: "'JetBrains Mono', monospace" }}>
        {task.scheduleHuman}
      </div>
      <div><StatusBadge status={task.status} /></div>
      <div style={{ fontSize: 12, color: "rgba(255,255,255,0.45)" }}>{relativeTime(task.lastRun)}</div>
      <div style={{ fontSize: 12, color: "rgba(255,255,255,0.45)", fontFamily: "'JetBrains Mono', monospace" }}>{task.runCount}</div>
      <div style={{
        fontSize: 12, fontFamily: "'JetBrains Mono', monospace",
        color: successRate >= 95 ? "#22c55e" : successRate >= 80 ? "#f59e0b" : "#ef4444",
      }}>{successRate}%</div>
    </div>
  );
}

function LogEntry({ log, expanded, onToggle }) {
  const cfg = STATUS_CONFIG[log.status];
  return (
    <div style={{
      borderBottom: "1px solid rgba(255,255,255,0.04)",
      background: expanded ? "rgba(255,255,255,0.02)" : "transparent",
    }}>
      <div
        onClick={onToggle}
        style={{
          display: "grid",
          gridTemplateColumns: "22px 1fr 140px 70px 80px 70px",
          alignItems: "center",
          padding: "10px 16px",
          cursor: "pointer",
          gap: 8,
        }}
      >
        <span style={{ color: cfg.color, fontSize: 10, textAlign: "center" }}>{cfg.icon}</span>
        <div>
          <span style={{ fontSize: 12.5, color: "#c8d0dc", fontWeight: 500 }}>{log.taskName}</span>
          <span style={{ fontSize: 11, color: "rgba(255,255,255,0.3)", marginLeft: 10 }}>{log.summary.slice(0, 80)}{log.summary.length > 80 ? "…" : ""}</span>
        </div>
        <span style={{ fontSize: 11, color: "rgba(255,255,255,0.35)", fontFamily: "'JetBrains Mono', monospace" }}>
          {formatTimestamp(log.timestamp)}
        </span>
        <span style={{ fontSize: 11, color: "rgba(255,255,255,0.35)", fontFamily: "'JetBrains Mono', monospace" }}>
          {formatDuration(log.duration)}
        </span>
        <span style={{ fontSize: 11, color: "rgba(255,255,255,0.35)", fontFamily: "'JetBrains Mono', monospace" }}>
          {log.tokensUsed.toLocaleString()} tok
        </span>
        <span style={{ fontSize: 11, color: "rgba(255,255,255,0.35)", fontFamily: "'JetBrains Mono', monospace" }}>
          ${log.cost.toFixed(2)}
        </span>
      </div>
      {expanded && (
        <div style={{
          padding: "0 16px 14px 46px",
          animation: "fadeSlide 0.2s ease",
        }}>
          <div style={{ fontSize: 11.5, color: "rgba(255,255,255,0.5)", marginBottom: 8, lineHeight: 1.5 }}>{log.summary}</div>
          <pre style={{
            fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
            color: "rgba(255,255,255,0.55)", background: "rgba(0,0,0,0.3)",
            padding: 14, borderRadius: 6, margin: 0,
            lineHeight: 1.6, whiteSpace: "pre-wrap", wordBreak: "break-word",
            border: "1px solid rgba(255,255,255,0.05)",
          }}>
            {log.output}
          </pre>
        </div>
      )}
    </div>
  );
}

function TaskEditor({ task, onSave, onCancel, isNew }) {
  const [form, setForm] = useState(task ? { ...task } : {
    id: `lc-${Math.random().toString(36).slice(2, 10)}`,
    name: "", command: "", skill: "", schedule: "", scheduleHuman: "",
    workingDir: "~/projects/", status: "active", maxBudget: 5.0,
    totalSpent: 0, createdAt: new Date().toISOString(), lastRun: null,
    nextRun: null, runCount: 0, successCount: 0, failCount: 0, tags: [],
  });
  const [tagInput, setTagInput] = useState("");

  const inputStyle = {
    width: "100%", boxSizing: "border-box",
    padding: "10px 12px", borderRadius: 6,
    background: "rgba(0,0,0,0.3)", border: "1px solid rgba(255,255,255,0.1)",
    color: "#e2e8f0", fontSize: 13, fontFamily: "'JetBrains Mono', monospace",
    outline: "none", transition: "border-color 0.15s",
  };
  const labelStyle = {
    fontSize: 11, fontWeight: 600, color: "rgba(255,255,255,0.5)",
    textTransform: "uppercase", letterSpacing: "0.5px", marginBottom: 6, display: "block",
  };

  return (
    <div style={{
      position: "fixed", inset: 0, background: "rgba(0,0,0,0.7)",
      display: "flex", alignItems: "center", justifyContent: "center",
      zIndex: 1000, backdropFilter: "blur(8px)",
    }}>
      <div style={{
        background: "#1a1d23", borderRadius: 12, padding: 32,
        width: 560, maxHeight: "85vh", overflowY: "auto",
        border: "1px solid rgba(255,255,255,0.08)",
        boxShadow: "0 24px 80px rgba(0,0,0,0.6)",
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 28 }}>
          <h2 style={{ margin: 0, fontSize: 18, fontWeight: 700, color: "#e2e8f0" }}>
            {isNew ? "New Scheduled Task" : "Edit Task"}
          </h2>
          <button onClick={onCancel} style={{
            background: "none", border: "none", color: "rgba(255,255,255,0.4)",
            fontSize: 20, cursor: "pointer", padding: "4px 8px",
          }}>✕</button>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
          <div>
            <label style={labelStyle}>Task Name</label>
            <input
              value={form.name} onChange={e => setForm({ ...form, name: e.target.value })}
              placeholder="e.g., PR Review Sweep"
              style={inputStyle}
              onFocus={e => e.target.style.borderColor = "rgba(129,140,248,0.5)"}
              onBlur={e => e.target.style.borderColor = "rgba(255,255,255,0.1)"}
            />
          </div>

          <div>
            <label style={labelStyle}>Claude Command</label>
            <textarea
              value={form.command} onChange={e => setForm({ ...form, command: e.target.value })}
              placeholder="claude -p 'Your prompt here...'"
              rows={4}
              style={{ ...inputStyle, resize: "vertical", lineHeight: 1.5 }}
              onFocus={e => e.target.style.borderColor = "rgba(129,140,248,0.5)"}
              onBlur={e => e.target.style.borderColor = "rgba(255,255,255,0.1)"}
            />
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
            <div>
              <label style={labelStyle}>Skill (optional)</label>
              <input
                value={form.skill || ""} onChange={e => setForm({ ...form, skill: e.target.value })}
                placeholder="/review-pr, /loop, etc."
                style={inputStyle}
                onFocus={e => e.target.style.borderColor = "rgba(129,140,248,0.5)"}
                onBlur={e => e.target.style.borderColor = "rgba(255,255,255,0.1)"}
              />
            </div>
            <div>
              <label style={labelStyle}>Working Directory</label>
              <input
                value={form.workingDir} onChange={e => setForm({ ...form, workingDir: e.target.value })}
                placeholder="~/projects/my-repo"
                style={inputStyle}
                onFocus={e => e.target.style.borderColor = "rgba(129,140,248,0.5)"}
                onBlur={e => e.target.style.borderColor = "rgba(255,255,255,0.1)"}
              />
            </div>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
            <div>
              <label style={labelStyle}>Cron Schedule</label>
              <input
                value={form.schedule} onChange={e => setForm({ ...form, schedule: e.target.value })}
                placeholder="*/15 * * * *"
                style={inputStyle}
                onFocus={e => e.target.style.borderColor = "rgba(129,140,248,0.5)"}
                onBlur={e => e.target.style.borderColor = "rgba(255,255,255,0.1)"}
              />
            </div>
            <div>
              <label style={labelStyle}>Human-Readable</label>
              <input
                value={form.scheduleHuman} onChange={e => setForm({ ...form, scheduleHuman: e.target.value })}
                placeholder="Every 15 minutes"
                style={inputStyle}
                onFocus={e => e.target.style.borderColor = "rgba(129,140,248,0.5)"}
                onBlur={e => e.target.style.borderColor = "rgba(255,255,255,0.1)"}
              />
            </div>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
            <div>
              <label style={labelStyle}>Max Budget per Run ($)</label>
              <input
                type="number" step="0.5" min="0.5"
                value={form.maxBudget} onChange={e => setForm({ ...form, maxBudget: parseFloat(e.target.value) || 0 })}
                style={inputStyle}
                onFocus={e => e.target.style.borderColor = "rgba(129,140,248,0.5)"}
                onBlur={e => e.target.style.borderColor = "rgba(255,255,255,0.1)"}
              />
            </div>
            <div>
              <label style={labelStyle}>Tags</label>
              <div style={{ display: "flex", gap: 6 }}>
                <input
                  value={tagInput}
                  onChange={e => setTagInput(e.target.value)}
                  onKeyDown={e => {
                    if (e.key === "Enter" && tagInput.trim()) {
                      setForm({ ...form, tags: [...(form.tags || []), tagInput.trim()] });
                      setTagInput("");
                    }
                  }}
                  placeholder="Press enter to add"
                  style={{ ...inputStyle, flex: 1 }}
                  onFocus={e => e.target.style.borderColor = "rgba(129,140,248,0.5)"}
                  onBlur={e => e.target.style.borderColor = "rgba(255,255,255,0.1)"}
                />
              </div>
              {form.tags && form.tags.length > 0 && (
                <div style={{ display: "flex", gap: 4, flexWrap: "wrap", marginTop: 8 }}>
                  {form.tags.map((t, i) => (
                    <span key={i} onClick={() => setForm({ ...form, tags: form.tags.filter((_, j) => j !== i) })} style={{
                      fontSize: 10, padding: "3px 8px", borderRadius: 4,
                      background: "rgba(129,140,248,0.15)", color: "#a5b4fc",
                      cursor: "pointer", fontFamily: "'JetBrains Mono', monospace",
                    }}>{t} ✕</span>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>

        <div style={{ display: "flex", gap: 10, marginTop: 28, justifyContent: "flex-end" }}>
          <button onClick={onCancel} style={{
            padding: "10px 20px", borderRadius: 6, border: "1px solid rgba(255,255,255,0.1)",
            background: "transparent", color: "rgba(255,255,255,0.5)", fontSize: 13,
            cursor: "pointer", fontWeight: 500,
          }}>Cancel</button>
          <button onClick={() => onSave(form)} style={{
            padding: "10px 24px", borderRadius: 6, border: "none",
            background: "#818cf8", color: "#fff", fontSize: 13,
            cursor: "pointer", fontWeight: 600,
          }}>{isNew ? "Create Task" : "Save Changes"}</button>
        </div>
      </div>
    </div>
  );
}

// ─── Main App ────────────────────────────────────────────────────────────────

export default function LoopCommander() {
  const [tasks, setTasks] = useState(INITIAL_TASKS);
  const [logs, setLogs] = useState(INITIAL_LOGS);
  const [selectedTask, setSelectedTask] = useState(null);
  const [view, setView] = useState("tasks"); // tasks | logs | detail
  const [expandedLog, setExpandedLog] = useState(null);
  const [editor, setEditor] = useState(null); // null | { task, isNew }
  const [logFilter, setLogFilter] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [now, setNow] = useState(Date.now());

  useEffect(() => {
    const iv = setInterval(() => setNow(Date.now()), 30000);
    return () => clearInterval(iv);
  }, []);

  const activeCount = tasks.filter(t => t.status === "active").length;
  const totalRuns = tasks.reduce((a, t) => a + t.runCount, 0);
  const totalSpent = tasks.reduce((a, t) => a + t.totalSpent, 0);
  const overallSuccess = totalRuns > 0
    ? Math.round(tasks.reduce((a, t) => a + t.successCount, 0) / totalRuns * 100) : 0;

  const filteredLogs = logs
    .filter(l => logFilter === "all" || l.status === logFilter)
    .filter(l => !searchQuery || l.taskName.toLowerCase().includes(searchQuery.toLowerCase()) || l.summary.toLowerCase().includes(searchQuery.toLowerCase()))
    .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

  const detailTask = tasks.find(t => t.id === selectedTask);
  const detailLogs = logs.filter(l => l.taskId === selectedTask).sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

  const handleToggleStatus = (taskId) => {
    setTasks(prev => prev.map(t => {
      if (t.id !== taskId) return t;
      const next = t.status === "active" ? "paused" : "active";
      return { ...t, status: next };
    }));
  };

  const handleDeleteTask = (taskId) => {
    setTasks(prev => prev.filter(t => t.id !== taskId));
    setLogs(prev => prev.filter(l => l.taskId !== taskId));
    if (selectedTask === taskId) {
      setSelectedTask(null);
      setView("tasks");
    }
  };

  const handleSaveTask = (form) => {
    if (editor.isNew) {
      setTasks(prev => [...prev, form]);
    } else {
      setTasks(prev => prev.map(t => t.id === form.id ? { ...t, ...form } : t));
    }
    setEditor(null);
  };

  return (
    <div style={{
      fontFamily: "'Inter', -apple-system, system-ui, sans-serif",
      background: "#0f1117", color: "#e2e8f0", minHeight: "100vh",
      display: "flex", flexDirection: "column",
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600;700&display=swap');
        @keyframes fadeSlide { from { opacity: 0; transform: translateY(-4px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
        * { box-sizing: border-box; }
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.08); border-radius: 3px; }
        ::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.15); }
      `}</style>

      {/* ─── Header ─────────────────────────────────────────────────── */}
      <header style={{
        padding: "16px 28px", display: "flex", alignItems: "center", justifyContent: "space-between",
        borderBottom: "1px solid rgba(255,255,255,0.06)",
        background: "rgba(15,17,23,0.95)", backdropFilter: "blur(12px)",
        position: "sticky", top: 0, zIndex: 100,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <div style={{
            width: 32, height: 32, borderRadius: 8,
            background: "linear-gradient(135deg, #818cf8, #6366f1)",
            display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: 15, fontWeight: 800, color: "#fff",
          }}>⟳</div>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700, letterSpacing: "-0.3px" }}>Loop Commander</div>
            <div style={{ fontSize: 10.5, color: "rgba(255,255,255,0.3)", fontFamily: "'JetBrains Mono', monospace", letterSpacing: "0.5px" }}>
              LAUNCHD · CLAUDE CODE · {activeCount} ACTIVE
            </div>
          </div>
        </div>

        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          {["tasks", "logs"].map(v => (
            <button key={v} onClick={() => { setView(v); setSelectedTask(null); }} style={{
              padding: "7px 16px", borderRadius: 6, border: "none",
              background: view === v || (view === "detail" && v === "tasks") ? "rgba(129,140,248,0.15)" : "transparent",
              color: view === v || (view === "detail" && v === "tasks") ? "#a5b4fc" : "rgba(255,255,255,0.4)",
              fontSize: 12.5, fontWeight: 600, cursor: "pointer",
              transition: "all 0.15s",
            }}>{v === "tasks" ? "Tasks" : "Logs"}</button>
          ))}
          <div style={{ width: 1, height: 20, background: "rgba(255,255,255,0.08)", margin: "0 6px" }} />
          <button onClick={() => setEditor({ task: null, isNew: true })} style={{
            padding: "7px 16px", borderRadius: 6, border: "none",
            background: "#818cf8", color: "#fff",
            fontSize: 12.5, fontWeight: 600, cursor: "pointer",
            display: "flex", alignItems: "center", gap: 5,
          }}>+ New Task</button>
        </div>
      </header>

      {/* ─── Metrics ────────────────────────────────────────────────── */}
      <div style={{
        display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))",
        gap: 12, padding: "20px 28px",
      }}>
        <MetricCard label="Active Tasks" value={activeCount} sub={`${tasks.length} total`} accent="#818cf8" />
        <MetricCard label="Total Runs" value={totalRuns.toLocaleString()} sub="all time" />
        <MetricCard label="Success Rate" value={`${overallSuccess}%`} sub="across all tasks" accent={overallSuccess >= 95 ? "#22c55e" : "#f59e0b"} />
        <MetricCard label="Total Spend" value={`$${totalSpent.toFixed(2)}`} sub="API costs" />
        <MetricCard label="Daemon" value="UP" sub="launchd · PID 4821" accent="#22c55e" />
      </div>

      {/* ─── Content ────────────────────────────────────────────────── */}
      <div style={{ flex: 1, padding: "0 28px 28px" }}>

        {/* ─── Tasks View ─── */}
        {(view === "tasks" && !selectedTask) && (
          <div style={{
            borderRadius: 10, border: "1px solid rgba(255,255,255,0.06)",
            overflow: "hidden", background: "rgba(255,255,255,0.01)",
          }}>
            <div style={{
              display: "grid",
              gridTemplateColumns: "1fr 160px 120px 90px 80px 70px",
              padding: "10px 20px",
              fontSize: 10, fontWeight: 600, color: "rgba(255,255,255,0.3)",
              textTransform: "uppercase", letterSpacing: "0.5px",
              borderBottom: "1px solid rgba(255,255,255,0.06)",
              background: "rgba(255,255,255,0.02)",
            }}>
              <span>Task</span><span>Schedule</span><span>Status</span><span>Last Run</span><span>Runs</span><span>Health</span>
            </div>
            {tasks.map(t => (
              <TaskRow
                key={t.id} task={t}
                selected={selectedTask === t.id}
                onClick={() => { setSelectedTask(t.id); setView("detail"); }}
                onToggle={() => handleToggleStatus(t.id)}
              />
            ))}
          </div>
        )}

        {/* ─── Detail View ─── */}
        {view === "detail" && detailTask && (
          <div style={{ animation: "fadeSlide 0.2s ease" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 20 }}>
              <button onClick={() => { setView("tasks"); setSelectedTask(null); }} style={{
                background: "none", border: "none", color: "rgba(255,255,255,0.4)",
                fontSize: 13, cursor: "pointer", padding: "4px 0",
              }}>← Back</button>
              <div style={{ flex: 1 }} />
              <button onClick={() => setEditor({ task: detailTask, isNew: false })} style={{
                padding: "6px 14px", borderRadius: 6, border: "1px solid rgba(255,255,255,0.1)",
                background: "transparent", color: "rgba(255,255,255,0.6)", fontSize: 12,
                cursor: "pointer", fontWeight: 500,
              }}>Edit</button>
              <button onClick={() => handleToggleStatus(detailTask.id)} style={{
                padding: "6px 14px", borderRadius: 6, border: "1px solid rgba(255,255,255,0.1)",
                background: "transparent",
                color: detailTask.status === "active" ? "#f59e0b" : "#22c55e",
                fontSize: 12, cursor: "pointer", fontWeight: 500,
              }}>{detailTask.status === "active" ? "Pause" : "Resume"}</button>
              <button onClick={() => handleDeleteTask(detailTask.id)} style={{
                padding: "6px 14px", borderRadius: 6, border: "1px solid rgba(239,68,68,0.2)",
                background: "transparent", color: "#ef4444", fontSize: 12,
                cursor: "pointer", fontWeight: 500,
              }}>Delete</button>
            </div>

            <div style={{
              borderRadius: 10, border: "1px solid rgba(255,255,255,0.06)",
              padding: 24, marginBottom: 20, background: "rgba(255,255,255,0.01)",
            }}>
              <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16 }}>
                <h2 style={{ margin: 0, fontSize: 20, fontWeight: 700 }}>{detailTask.name}</h2>
                <StatusBadge status={detailTask.status} />
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 }}>
                <div>
                  <div style={{ fontSize: 10, color: "rgba(255,255,255,0.35)", textTransform: "uppercase", letterSpacing: "0.5px", marginBottom: 6 }}>Command</div>
                  <pre style={{
                    fontSize: 11.5, fontFamily: "'JetBrains Mono', monospace",
                    color: "#a5b4fc", background: "rgba(0,0,0,0.3)",
                    padding: 12, borderRadius: 6, margin: 0,
                    whiteSpace: "pre-wrap", wordBreak: "break-all",
                    border: "1px solid rgba(255,255,255,0.05)",
                    lineHeight: 1.6,
                  }}>{detailTask.command}</pre>
                </div>
                <div>
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                    {[
                      ["Schedule", detailTask.scheduleHuman],
                      ["Cron", detailTask.schedule],
                      ["Working Dir", detailTask.workingDir],
                      ["Skill", detailTask.skill || "—"],
                      ["Budget/Run", `$${detailTask.maxBudget.toFixed(2)}`],
                      ["Total Spent", `$${detailTask.totalSpent.toFixed(2)}`],
                      ["Created", formatTimestamp(detailTask.createdAt)],
                      ["Last Run", detailTask.lastRun ? relativeTime(detailTask.lastRun) : "—"],
                    ].map(([k, v]) => (
                      <div key={k}>
                        <div style={{ fontSize: 10, color: "rgba(255,255,255,0.3)", textTransform: "uppercase", letterSpacing: "0.5px", marginBottom: 3 }}>{k}</div>
                        <div style={{ fontSize: 12.5, color: "#c8d0dc", fontFamily: "'JetBrains Mono', monospace" }}>{v}</div>
                      </div>
                    ))}
                  </div>
                  {detailTask.tags.length > 0 && (
                    <div style={{ display: "flex", gap: 4, marginTop: 12, flexWrap: "wrap" }}>
                      {detailTask.tags.map((t, i) => (
                        <span key={i} style={{
                          fontSize: 10, padding: "3px 8px", borderRadius: 4,
                          background: "rgba(129,140,248,0.1)", color: "#818cf8",
                          fontFamily: "'JetBrains Mono', monospace",
                        }}>{t}</span>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Task-specific logs */}
            <div style={{
              borderRadius: 10, border: "1px solid rgba(255,255,255,0.06)",
              overflow: "hidden", background: "rgba(255,255,255,0.01)",
            }}>
              <div style={{
                padding: "12px 16px", borderBottom: "1px solid rgba(255,255,255,0.06)",
                display: "flex", alignItems: "center", justifyContent: "space-between",
              }}>
                <span style={{ fontSize: 12, fontWeight: 600, color: "rgba(255,255,255,0.5)" }}>
                  Execution History ({detailLogs.length} runs)
                </span>
              </div>
              {detailLogs.length === 0 ? (
                <div style={{ padding: 32, textAlign: "center", color: "rgba(255,255,255,0.25)", fontSize: 13 }}>
                  No executions yet
                </div>
              ) : detailLogs.map(l => (
                <LogEntry
                  key={l.id} log={l}
                  expanded={expandedLog === l.id}
                  onToggle={() => setExpandedLog(expandedLog === l.id ? null : l.id)}
                />
              ))}
            </div>
          </div>
        )}

        {/* ─── Logs View ─── */}
        {view === "logs" && (
          <div>
            <div style={{ display: "flex", gap: 8, marginBottom: 16, alignItems: "center" }}>
              <input
                value={searchQuery} onChange={e => setSearchQuery(e.target.value)}
                placeholder="Search logs..."
                style={{
                  padding: "8px 14px", borderRadius: 6,
                  background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)",
                  color: "#e2e8f0", fontSize: 12.5, outline: "none", width: 240,
                  fontFamily: "'JetBrains Mono', monospace",
                }}
              />
              <div style={{ flex: 1 }} />
              {["all", "success", "error"].map(f => (
                <button key={f} onClick={() => setLogFilter(f)} style={{
                  padding: "6px 12px", borderRadius: 5, border: "none",
                  background: logFilter === f ? "rgba(129,140,248,0.15)" : "transparent",
                  color: logFilter === f ? "#a5b4fc" : "rgba(255,255,255,0.35)",
                  fontSize: 11.5, fontWeight: 600, cursor: "pointer", textTransform: "capitalize",
                }}>{f}</button>
              ))}
            </div>
            <div style={{
              borderRadius: 10, border: "1px solid rgba(255,255,255,0.06)",
              overflow: "hidden", background: "rgba(255,255,255,0.01)",
            }}>
              <div style={{
                display: "grid",
                gridTemplateColumns: "22px 1fr 140px 70px 80px 70px",
                padding: "10px 16px",
                fontSize: 10, fontWeight: 600, color: "rgba(255,255,255,0.25)",
                textTransform: "uppercase", letterSpacing: "0.5px",
                borderBottom: "1px solid rgba(255,255,255,0.06)",
                background: "rgba(255,255,255,0.02)", gap: 8,
              }}>
                <span></span><span>Task / Summary</span><span>Time</span><span>Duration</span><span>Tokens</span><span>Cost</span>
              </div>
              {filteredLogs.map(l => (
                <LogEntry
                  key={l.id} log={l}
                  expanded={expandedLog === l.id}
                  onToggle={() => setExpandedLog(expandedLog === l.id ? null : l.id)}
                />
              ))}
            </div>
          </div>
        )}
      </div>

      {/* ─── Editor Modal ─── */}
      {editor && (
        <TaskEditor
          task={editor.task}
          isNew={editor.isNew}
          onSave={handleSaveTask}
          onCancel={() => setEditor(null)}
        />
      )}
    </div>
  );
}
