# Gantry Architecture

This document defines the initial gantry / decouple architecture for the `linuxcnc-cia402-layer` project.

The goal is to support a **single mechanical gantry axis** driven by **two servo drives** while preserving the architectural rules already validated in V11.

---

# Scope

This stage introduces a new HAL component:

`comp/gantry_manager.comp`

The component is intentionally placed **above the CiA402 semantic layer**.

It is a **machine-level coordination layer**, not a CiA402 protocol layer.

It supervises two drive channels that act on the same mechanical structure.

Typical example:

- drive X1
- drive X2
- one mechanical axis X (gantry bridge)

---

# Architectural Position

Updated logical pipeline:

LinuxCNC motion  
        ↓  
machine_safety_gate  
        ↓  
gantry_manager  
        ↓  
cia402_pds  
        ↓  
cia402_homing  
        ↓  
cia402_cw_compose  
        ↓  
cia402_drive_adapter  
        ↓  
backend  
        ↓  
drive (Power Drive System)

This placement is deliberate.

`gantry_manager` deals with:

- axis-level coordination
- structural skew supervision
- coupled / decoupled routing
- machine-level bridge protection

It does **not** interpret DS402 states and does **not** write the final controlword.

---

# Critical Architectural Rule

`gantry_manager` must **never** write the CiA402 controlword.

The single-writer rule remains unchanged:

- `cia402_pds` provides base controlword intent
- procedural components provide procedural bits
- `cia402_cw_compose` writes the final controlword

This rule must remain preserved in the gantry architecture.

---

# Design Goals

The gantry layer was introduced with the following goals:

- coordinate two servo channels that act on one bridge
- detect structural skew early
- support maintenance / recovery decoupling
- support future independent homing workflows
- keep CiA402 semantics isolated from machine coordination
- preserve deterministic simulation validation with `cia402_stub`

---

# Operational Modes

## 1. COUPLED

Normal gantry operation.

Behavior:

- both sides receive the same commanded position
- X1 and X2 are expected to remain mechanically aligned
- skew supervision remains active

Logical routing:

- `cmd_x1 = axis_cmd_pos`
- `cmd_x2 = axis_cmd_pos`

Use cases:

- normal positioning
- production motion
- synchronized bridge travel

---

## 2. DECOUPLED

Maintenance / recovery mode.

Behavior:

- each side receives its own independent command
- used for recovery, maintenance, alignment, or future staged homing
- skew is still monitored

Logical routing:

- `cmd_x1 = decoupled_cmd_x1`
- `cmd_x2 = decoupled_cmd_x2`

Use cases:

- independent axis recovery
- mechanical servicing
- bridge re-alignment
- future individual homing strategies

---

## 3. SKEW FAULT

Structural protection mode.

If:

`|X1 - X2| > skew_limit`

then the gantry is considered mechanically unsafe.

Expected behavior:

- set `gantry_fault = TRUE`
- set `gantry_ok = FALSE`
- stop normal command forwarding
- command each side to hold its own present position

Important detail:

On skew fault, the safest immediate HAL behavior is **not** to keep forcing both sides to the same common command.
Instead, each side should hold its own present position reference:

- `cmd_x1 = axis_feedback_x1`
- `cmd_x2 = axis_feedback_x2`

This reduces the risk of driving one side against the other through the bridge.

---

# HAL Interface

## Inputs

- `enable`  
  Enables gantry supervision.

- `couple_enable`  
  `TRUE` selects COUPLED mode. `FALSE` selects DECOUPLED mode.

- `reset_fault`  
  Clears a latched gantry fault.

- `axis_cmd_pos`  
  Common commanded position for the gantry axis in COUPLED mode.

- `decoupled_cmd_x1`  
  Independent command for X1 in DECOUPLED mode.

- `decoupled_cmd_x2`  
  Independent command for X2 in DECOUPLED mode.

- `axis_feedback_x1`  
  Position feedback from gantry side X1.

- `axis_feedback_x2`  
  Position feedback from gantry side X2.

- `skew_limit`  
  Maximum allowed absolute skew.

- `latch_fault`  
  If `TRUE`, skew fault remains active until `reset_fault` is asserted.

## Outputs

- `cmd_x1`  
  Routed command for drive X1.

- `cmd_x2`  
  Routed command for drive X2.

- `skew_error`  
  Absolute skew value: `|X1 - X2|`.

- `gantry_ok`  
  `TRUE` when the gantry is in a valid operating condition.

- `gantry_fault`  
  `TRUE` when skew protection is active.

- `coupled_active`  
  Indicates effective coupled mode.

- `reason`  
  Diagnostic reason code.

---

# Diagnostic Reason Codes

Recommended initial reason codes:

- `0` = idle / supervision not active
- `1` = coupled mode active and healthy
- `2` = decoupled mode active and healthy
- `10` = skew fault active (non-latched)
- `11` = skew fault latched
- `20` = invalid skew limit configuration

These reason codes intentionally follow the same explicit-diagnostics style already used in the V11 components.

---

# Validation Strategy

Initial V12 validation should continue using the existing simulation harness with `cia402_stub`.

Recommended scenarios:

## Scenario A — Coupled nominal

Conditions:

- `couple_enable = TRUE`
- `|X1 - X2| <= skew_limit`

Expected:

- `cmd_x1 = axis_cmd_pos`
- `cmd_x2 = axis_cmd_pos`
- `gantry_ok = TRUE`
- `gantry_fault = FALSE`

## Scenario B — Decoupled nominal

Conditions:

- `couple_enable = FALSE`
- `|X1 - X2| <= skew_limit`

Expected:

- `cmd_x1 = decoupled_cmd_x1`
- `cmd_x2 = decoupled_cmd_x2`
- `gantry_ok = TRUE`
- `gantry_fault = FALSE`

## Scenario C — Skew fault

Conditions:

- `|X1 - X2| > skew_limit`

Expected:

- `gantry_fault = TRUE`
- `gantry_ok = FALSE`
- outputs hold their respective local feedback positions

## Scenario D — Fault reset

Conditions:

- latched skew fault present
- `reset_fault = TRUE`
- skew returns below limit

Expected:

- gantry fault clears
- normal routing resumes

---

# Why this layer is above CiA402

This is one of the most important architectural decisions in V12.

A gantry problem is fundamentally a **machine coordination problem**, not a DS402 semantic problem.

Examples:

- bridge twist
- left/right side mismatch
- maintenance decoupling
- structural protection

These concerns exist regardless of whether the backend is:

- EtherCAT
- Mesa
- simulation
- another future transport

Therefore they belong above the CiA402 semantic layer.

---

# Forward Path

After the initial V12 validation, the next likely extensions are:

- integration with two independent CiA402 channels
- decoupled homing workflow definition
- gantry fault propagation into machine policy
- optional skew pre-warning threshold
- optional auto-realignment procedure hooks

The current `gantry_manager.comp` is intentionally minimal and deterministic so that the architecture can be validated before introducing more advanced behavior.
