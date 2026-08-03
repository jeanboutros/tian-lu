# Advisory: BS detect_hostname_and_ip || true masks failures

| Field | Value |
|-------|-------|
| ID | psc-adv-0050-bs-detect_hostname_and_ip-||-true-masks-failures |
| Type | advisory |
| Status | accepted |
| Confidence | 80 |
| Priority | high |
| Source ticket | psc-0003 |
| Source agent | BS-challenger |
| Source file | [docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-0003/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |
| Finding ID | M-34 |

## Description
`SERVER_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{...}' || true)"` — the `|| true` suppresses ALL failures including `awk` parse failures, leaving `SERVER_IP` empty silently. The subsequent `[[ -z ]]` check catches this, but the `|| true` masks the distinction between "ip route failed" and "awk produced no output."

## Recommended Action
Replace `|| true` with a more targeted error path, or add a diagnostic when `ip route` succeeds but `awk` yields empty.

## User Decision
accepted

## Decision Rationale
User accepted this advisory finding. Implement as recommended.

## Implementation Ticket
<filled if accepted or implemented — reference to the implementation ticket>
