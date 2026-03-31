# Architecture

This document describes how the `linuxcnc-cia402-layer` framework is structured and how it operates.

The architecture separates:

- machine policy
- CiA402 semantics
- hardware transport

This allows the system to be:

- validated in simulation
- reused across different hardware backends
- deterministic and debuggable

---

## High-Level Overview

```
LinuxCNC Motion
    ↓
Machine Policy (machine_safety_gate)
    ↓
CiA402 Semantic Layer
    ↓
Adapter (backend boundary)
    ↓
Backend (simulation / external transport)
    ↓
Drive (CiA402 Power Drive System)
```

LinuxCNC remains the authority for trajectory planning.

The framework translates motion intent into CiA402-compliant behavior.

---

## Design Principles

- LinuxCNC is the motion authority
- CiA402 semantics are isolated from transport
- Final controlword has a single writer
- Arbitration is explicit and deterministic
- System is fully testable without hardware

---

## Pipeline Components

The runtime semantic pipeline includes (non-exhaustive):

- `machine_safety_gate`
- `cia402_pds`
- `cia402_homing`
- `cia402_motion_csp`
- `cia402_axis_semantic_mux`
- `cia402_invariant_monitor`
- `cia402_cw_compose`
- `cia402_backend_adapter`

These components form a deterministic execution chain inside the servo thread.

Note:

The exact composition may vary depending on topology (single axis, multi-axis, etc.), but the controlword path and arbitration remain consistent.

---

## Responsibility Split

| Layer | Responsibility |
|------|----------------|
| LinuxCNC motion | trajectory generation |
| machine_safety_gate | machine policy |
| cia402_pds | PDS state interpretation |
| cia402_homing | homing procedure |
| cia402_motion_csp | CSP motion semantics |
| cia402_axis_semantic_mux | arbitration between semantic sources |
| cia402_cw_compose | final controlword composition |
| cia402_backend_adapter | backend interface (virtual or real) |
| backend | communication transport |
| drive | CiA402 execution |

---

## Machine Policy Layer

`machine_safety_gate` controls machine-level permissions.

Examples:

- enable allowed
- homing allowed
- fault reset allowed

This layer is independent from hardware transport.

Important:

This is NOT a safety system and does not replace:

- E-stop circuits
- STO
- safety relays

---

## CiA402 Semantic Layer

The semantic layer interprets CiA402 behavior and produces deterministic signals.

Core components include:

- `cia402_pds`
- `cia402_homing`
- `cia402_motion_csp`
- `cia402_axis_semantic_mux`
- `cia402_invariant_monitor`
- `cia402_cw_compose`

This layer does not depend on:

- EtherCAT
- Mesa
- any specific backend

---

## Power Drive System (PDS)

`cia402_pds` interprets the CiA402 state machine from the statusword.

It produces:

- semantic state
- operation enabled flag
- fault indication
- controlword intent

Implementation uses masked decoding to remain compatible with different drives.

---

## Procedural Layer

Procedures implement higher-level behavior.

Currently:

- `cia402_homing`

Responsibilities:

- request homing mode
- supervise execution
- detect failure conditions

Procedures do not write the final backend controlword directly.

---

## Controlword Arbitration

`cia402_cw_compose` is the only writer of the final controlword.

It merges intent from:

- PDS
- procedures
- motion / mux arbitration

This enforces:

- single-writer rule
- no race conditions
- deterministic control

---

## Adapter Layer

`cia402_backend_adapter` is the boundary between framework and backend.

Responsibilities:

- map semantic signals to backend interface
- transfer feedback to the semantic layer

The adapter does not implement semantics.

---

## Backend Layer

The backend handles communication with hardware or simulation.

Current validated backend:

- simulation (via `cia402_backend_adapter`)

Other backends (e.g. EtherCAT/LCEC) are not part of the core runtime path and require explicit binding.

This layer is replaceable without changing semantics.

---

## Observability

The framework exposes internal state through HAL.

Use:

```
scripts/diag.sh
```

This allows inspection of:

- watchdog state
- motion supervision signals
- controlword / statusword paths
- selected raw CiA402 signals

Note:

The diagnostics focus on essential runtime signals and do not expose all internal components (e.g. full mux internals).

---

## Summary

The architecture enforces:

- clear separation of responsibilities
- deterministic behavior
- hardware independence

This allows:

- validation without hardware
- easier debugging
- scalable multi-axis systems
