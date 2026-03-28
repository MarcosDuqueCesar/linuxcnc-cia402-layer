# Hardware Integration

This document explains how to connect the framework to real hardware.

The framework separates:

- CiA402 semantics
- machine policy
- hardware transport

Only the adapter layer interacts with real drives.

---

## High-Level Flow

```
LinuxCNC Motion
    ↓
machine_safety_gate
    ↓
cia402_pds
    ↓
cia402_homing
    ↓
cia402_cw_compose
    ↓
cia402_drive_adapter
    ↓
backend (EtherCAT / Mesa / simulation)
    ↓
drive
```

---

## Key Concept

The adapter is the boundary between:

```
framework ↔ backend ↔ drive
```

It translates signals and does not implement semantics.

---

## Minimal CiA402 Interface

### Commands

- controlword (6040h)
- mode of operation (6060h)
- target position

### Feedback

- statusword (6041h)
- mode display (6061h)
- actual position

---

## Controlword Rule

The adapter must forward:

```
cw_final
```

It must not modify controlword logic.

---

## HAL Integration

Semantic layer → adapter:

- controlword
- mode command
- target position

Adapter → semantic layer:

- statusword
- mode display
- position feedback

---

## EtherCAT Integration

Typical mapping:

- 6040h → controlword PDO
- 6041h ← statusword PDO
- 6060h → mode command PDO
- 6061h ← mode display PDO

---

## Real-Time Requirements

You must have:

- real-time kernel (PREEMPT_RT)
- stable low jitter

Otherwise:

- motion becomes unstable
- EtherCAT may fail
- watchdogs may trigger

---

## Mesa Integration

Same interface mapped to FPGA / HAL pins.

---

## Simulation

The framework supports full simulation.

No hardware required.

---

## Multi-Axis

- one pipeline per axis
- one adapter per axis

---

## Workflow

1. Validate in simulation
2. Load hardware
3. Inspect pins:

```
halcmd show pin | grep <backend>
```

4. Map adapter
5. Run:

```
scripts/diag.sh
```

---

## Troubleshooting

Check:

- HAL loads
- pins exist
- correct mappings
- system jitter

---

## Summary

Framework = semantics + logic  
User = hardware + configuration  
Adapter = connection between both
