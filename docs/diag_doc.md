# Diagnostics Guide — motion_watchdog & diag.sh

## 1. Purpose

This tool helps you understand if the machine is behaving correctly.

The `diag.sh` script is the primary observability entrypoint for runtime diagnostics.  
It exposes the state of the `motion_watchdog`, which validates motion coherence between:

- commanded position (`pos-cmd`)
- feedback position (`pos-fb`)
- motion request state
- system readiness (CSP + OP)

---

## 2. Prerequisites

Before using `diag.sh`:

- LinuxCNC must be running
- Run commands from the repository root

Example:

```
cd linuxcnc-cia402-layer
scripts/diag.sh auto
```

---

## 3. Usage

### Run once

```
scripts/diag.sh auto
```

### Continuous observation

```
watch -n 0.2 scripts/diag.sh auto
```

### Modes

- `auto` → detects watchdog instances
- `single` → single-axis setups
- `multi` → multi-axis setups

---

## 4. First Check (What to look first)

When running `diag.sh`, check in this order:

1. `fault`
2. `fault-latched`
3. `response-timeout`
4. `stall`
5. `tracking-error`

If all are zero → system is healthy

---

## 5. Observed Fields

| Field | Description |
|------|-------------|
| pos-cmd | Commanded position |
| pos-fb | Feedback position |
| tracking-error | Difference between command and feedback |
| tracking-error-limit | Configured threshold |
| response-timeout | No response after motion request |
| stall | Motion stopped after initial response |
| fault | Current fault state |
| fault-latched | Latched fault |
| first-fault-code | First detected fault |

---

## 6. Minimal Workflow

1. Start LinuxCNC
2. Run `diag.sh`
3. Command small movement
4. Observe values in real time
5. Classify behavior

---

## 7. Diagnostic Patterns

### 7.1 System idle (expected)

```
pos-cmd ≈ pos-fb
fault = 0
stall = 0
response-timeout = 0
tracking-error ≈ 0
```

→ System is coherent

---

### 7.2 No response after motion request

```
pos-cmd changes
pos-fb does not change
response-timeout = 1
```

→ Motion requested but no response

Next step:

- verify controlword
- verify opmode
- inspect adapter signals

---

### 7.3 Motion starts then stops

```
pos-fb starts changing
then stops
stall = 1
```

→ Motion continuity lost

Next step:

- check feedback updates
- inspect backend stability

---

### 7.4 Tracking error

```
tracking-error > limit
fault = 1
```

→ Command vs feedback mismatch

Next step:

- check scaling
- check timing / sync

---

### 7.5 No feedback but no fault

```
pos-fb constant
fault = 0
```

→ System idle or feedback not initialized

---

## 8. Key Principle

The watchdog evaluates:

"Was a motion request followed by a coherent physical response?"

No assumptions about transport layer.

---

## 9. Example Output

```
===== DIAG START =====

----- WATCHDOG: (x) -----
fault = 0
stall = 0
response-timeout = 0
tracking-error = 0

===== DIAG END =====
```

---

## 10. Limitations

This tool does not directly diagnose:

- EtherCAT state (PRE-OP / OP)
- DC sync
- kernel latency

Use:

- `halcmd`
- `dmesg`

---

## 11. Summary

- run `diag.sh`
- observe key fields
- classify behavior

No guesswork — only observable behavior.
