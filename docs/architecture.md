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
Adapter (contract boundary)
    ↓
Backend (simulated / EtherCAT)
    ↓
Drive (CiA402 Power Drive System)
```

LinuxCNC remains the authority for trajectory planning.

The framework translates motion intent into CiA402-compliant behavior.

---

## Design Principles

- LinuxCNC is the motion authority
- CiA402 semantics are isolated from transport
- Controlword has a single writer
- Arbitration is explicit and deterministic
- System is fully testable without hardware

---

## Pipeline Components

The semantic pipeline is composed of:

- `machine_safety_gate`
- `cia402_pds`
- `cia402_homing`
- `cia402_cw_compose`
- `cia402_drive_adapter`

These components form a deterministic execution chain inside the servo thread.

---

## Responsibility Split

| Layer | Responsibility |
|------|----------------|
| LinuxCNC motion | trajectory generation |
| machine_safety_gate | machine policy |
| cia402_pds | PDS state interpretation |
| cia402_homing | homing procedure |
| cia402_cw_compose | controlword arbitration |
| cia402_drive_adapter | backend interface |
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

Components:

- `cia402_pds`
- `cia402_homing`
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

Procedures never write the controlword directly.

---

## Controlword Arbitration

`cia402_cw_compose` is the only writer of the final controlword.

It merges intent from:

- PDS
- procedures

This enforces:

- single-writer rule
- no race conditions
- deterministic control

---

## Adapter Layer

`cia402_drive_adapter` is the boundary between framework and backend.

Responsibilities:

- map signals to backend
- transfer feedback to semantic layer

The adapter does not implement semantics.

---

## Backend Layer

The backend handles communication with hardware.

Examples:

- EtherCAT (lcec)
- simulation stub

This layer is replaceable without changing semantics.

---

## Observability

The framework exposes internal state through HAL.

Use:

```
scripts/diag.sh
```

This allows inspection of:

- CiA402 states
- controlword
- statusword
- watchdogs
- mux behavior

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
