# linuxcnc-cia402-layer

Vendor-agnostic CiA402 (DS402) semantic layer for LinuxCNC, built around a clean separation between:

- machine policy
- CiA402 PDS semantics
- procedure logic such as homing
- deterministic controlword composition
- hardware / transport integration

The project is designed so LinuxCNC remains the motion authority while the CiA402 layer handles protocol semantics and the adapter layer handles real backend integration.

## Project goals

The main goal is to separate clearly:

- machine policy
- CiA402 protocol semantics
- transport / hardware integration

This separation allows:

- validation without real hardware
- lower coupling between machine logic and drive logic
- easier simulation
- backend reuse across EtherCAT, Mesa, simulation, and future adapters
- keeping LinuxCNC as the trajectory authority

## Consolidated architecture

Logical architecture:

```text
LinuxCNC motion
        |
        v
machine_safety_gate
        |
        v
CiA402 semantic layer
        |
        v
drive / transport adapter
        |
        v
CiA402 drive (Power Drive System)
```

## Separation of authorities

The project intentionally separates authority by responsibility:

| Responsibility | Owner |
|---|---|
| motion authority | LinuxCNC motion |
| machine policy authority | machine_safety_gate |
| drive PDS state authority | cia402_pds |
| procedure authority | cia402_homing |
| final 6040 ownership | cia402_cw_compose |

This avoids a common integration mistake in CiA402 systems: mixing trajectory control, drive-state control, and procedure sequencing in the same module.

## Layer roles

### LinuxCNC motion

LinuxCNC motion remains responsible for:

- trajectory generation
- interpolation
- kinematics
- coordination
- global synchronization

This project does not replace LinuxCNC motion.

### machine_safety_gate

`machine_safety_gate` is a generic machine-policy gate.

It is responsible for gating:

- enable
- motion
- homing
- fault reset

Important boundaries:

- it does not implement CiA402
- it does not write 6040
- it is not certified safety
- it does not replace hardware safety

It does not replace:

- physical E-stop
- STO
- safety relay
- contactor

The component is intentionally reusable with different backends such as:

- EtherCAT
- Mesa
- simulation
- future adapters

### CiA402 semantic layer

Main semantic components:

- `cia402_pds`
- `cia402_homing`
- `cia402_cw_compose`

Responsibilities:

- interpret statusword `6041h`
- generate base controlword semantics for `6040h`
- supervise procedures such as homing
- expose semantic signals such as:
  - `state`
  - `reason`
  - `op_enabled`
  - `fault`

### drive / transport adapter

The adapter layer is responsible for integration with real hardware.

Examples:

- EtherCAT / `lcec`
- Mesa backend
- future transport-specific adapters

This keeps backend details out of the semantic core.

## Single-writer rule for 6040

A core project rule is:

> only one module writes the final 6040 controlword.

Architecture:

```text
cia402_pds        -> cw_pds
cia402_homing     -> start_out
cia402_cw_compose -> cw_final
```

Composition concept:

```text
cw_final = cw_pds | procedure_bits
```

This avoids:

- multiple 6040 writers
- control ambiguity
- race-like design errors

## Deterministic HAL pipeline

All semantic modules are intended to run in the same LinuxCNC servo thread.

Conceptual execution order:

```text
machine_safety_gate
-> cia402_pds
-> homing gate
-> cia402_homing
-> cia402_cw_compose
-> drive / stub
```

In HAL, execution order is defined explicitly by `addf`, so these modules run sequentially, not concurrently.

That means there is no real concurrency between them as long as each signal has a single writer.

## Current CiA402 scope

Current consolidated scope:

- CSP (Cyclic Synchronous Position)
- HM (Homing Mode)

Why CSP:

For CNC use, CSP preserves LinuxCNC as trajectory generator.

Flow:

```text
LinuxCNC motion
      ↓
cyclic target position
      ↓
drive
```

This avoids delegating trajectory generation to the drive.

## Control-state robustness in `cia402_pds`

The PDS component is intended to decode valid DS402 states explicitly.

Recognized categories include:

- Not Ready to Switch On
- Switch On Disabled
- Ready to Switch On
- Switched On
- Operation Enabled
- Quick Stop Active
- Fault Reaction Active
- Fault

Important rule:

> valid DS402 states should not collapse into `UNKNOWN_STATE`.

`UNKNOWN_STATE` is reserved for patterns that are truly not recognized by the implemented decode logic.

This improves:

- diagnostics
- documentation quality
- future adapter behavior

## Quick Stop policy

Quick Stop support exists in the semantic layer, but it is not intended to be the normal stop path for LinuxCNC.

Project policy:

- normal stop remains under LinuxCNC motion / planner authority
- Quick Stop is treated as an exceptional or policy-driven path
- Quick Stop must be decoded correctly as a valid DS402 state

This keeps LinuxCNC as motion authority while still supporting DS402 semantics correctly.

## Machine-policy integration into `cia402_pds`

The architecture now reflects machine-policy gating more explicitly.

Conceptually, `cia402_pds` should act on effective requests such as:

```text
effective_enable = enable && allow_enable
effective_fault_reset = fault_reset && allow_fault_reset
```

This prevents the semantic layer from trying to progress the PDS when machine policy is explicitly blocking enable or reset.

That makes machine policy authority real in behavior, not only conceptual in documentation.

## Gantry / coupler position in the architecture

Gantry logic is intentionally not part of CiA402 semantics.

Expected functions such as:

- decouple
- home independently
- square
- recouple

belong to machine logic, not to the PDS semantic layer.

Current project direction:

before moving into gantry logic, first strengthen:

- diagnostics
- state clarity
- reason clarity
- backend-facing semantics

## Multi-axis node support

The semantic core should stay axis-centric.

Recommended model:

- one semantic instance per controlled axis / channel
- adapter layer handles whether hardware is:
  - single-axis slave
  - multi-axis slave
  - separate drives
  - simulation backend

This means multi-axis EtherCAT nodes should be handled in the adapter mapping, not by changing the semantic core to become slave-centric.

## Repository structure

```text
linuxcnc-cia402-layer
│
├─ README.md
├─ LICENSE
│
├─ comp/
│   ├─ cia402_cw_compose.comp
│   ├─ cia402_homing.comp
│   ├─ cia402_pds.comp
│   ├─ cia402_stub.comp
│   └─ machine_safety_gate.comp
│
├─ docs/
│   ├─ architecture.md
│   ├─ cia402_reference.md
│   ├─ drive_integration.md
│   └─ error_codes.md
│
├─ hal/
│   ├─ stub_test.hal
│   ├─ stub_test_modular.hal
│   └─ stub_test_modular_pds.hal
│
├─ custom.hal
├─ opc_validation.hal
└─ opc_validation.ini
```

## Validation harness levels

The HAL validation files are intended to represent progressively richer validation levels.

### `hal/stub_test.hal`

Minimal homing-oriented validation.

### `hal/stub_test_modular.hal`

Semi-modular validation without full PDS ownership.

### `hal/stub_test_modular_pds.hal`

Full modular pipeline validation.

Conceptual full pipeline:

```text
machine_safety_gate
-> cia402_pds
-> homing gate
-> cia402_homing
-> cia402_cw_compose
-> cia402_stub
```

This is the most representative harness for the intended architecture.

## Current development workflow

Current user workflow:

- Windows + Git Bash
- replace complete files in local clone
- inspect with `git diff`
- validate with `git status`
- `git add`
- `git commit`
- `git push`

Complete-file replacement is used intentionally to reduce:

- copy/paste mistakes
- formatting corruption
- unexpected line-ending issues

## Current project state

At the current stage, the project has:

- consolidated modular architecture
- clear authority separation
- deterministic 6040 ownership
- improved internal diagnostics
- validation harness aligned with the architecture

What is still intentionally pending:

- real backend adapter integration
- machine-level gantry logic
- decouple / recouple / squaring logic

## Recommended next steps

Recommended order of evolution:

1. consolidate validation with the current semantic components
2. continue strengthening diagnostics and PDS / homing robustness
3. keep machine-policy integration aligned in the harness
4. implement real backend adapter(s)
5. advance to machine-level logic such as gantry, decouple, recouple, and squaring

## Summary

The project is now structured around a clean modular model:

- LinuxCNC remains the motion authority
- machine policy is separated from protocol semantics
- CiA402 semantics are isolated in dedicated components
- the final controlword has a single owner
- backend-specific integration is kept out of the semantic core

This keeps the design reusable, testable, and much easier to evolve toward real hardware integration without losing architectural clarity.
