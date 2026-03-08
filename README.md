# linuxcnc-cia402-layer

Vendor-agnostic modular CiA402 semantic layer for LinuxCNC.

The project separates four concerns that are commonly mixed in drive integrations:

- machine policy
- CiA402 PDS semantics
- procedure semantics such as homing
- transport / hardware integration

This separation allows the same semantic core to be validated in simulation, reused across different backends, and kept independent from any specific transport.

## Design goals

- keep LinuxCNC as the authority for motion and trajectory generation
- isolate CiA402 state-machine behavior from machine policy
- avoid ambiguous ownership of controlword 6040h
- support validation without real hardware
- prepare a clean path for future EtherCAT, Mesa, and simulation adapters

## Consolidated architecture

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

## Authority split

| Responsibility | Module |
|---|---|
| Motion authority | LinuxCNC motion |
| Machine policy authority | machine_safety_gate |
| Drive state authority | cia402_pds |
| Procedure authority | cia402_homing |
| Final controlword ownership | cia402_cw_compose |

This avoids a common CiA402 integration failure mode: mixing trajectory control, PDS control, and procedure control in the same block.

## Layer roles

### LinuxCNC motion

Responsible for:

- trajectory generation
- interpolation
- kinematics
- coordinated motion
- global synchronization

This project does not replace LinuxCNC motion.

### machine_safety_gate

Generic machine-policy layer.

It gates requests such as:

- enable
- homing
- motion
- fault reset

Important limits:

- does not implement CiA402
- does not write controlword 6040h directly
- does not replace certified safety
- does not replace hardware safety

It does not replace:

- physical E-stop
- STO
- safety relays
- contactors

Because it is policy-oriented rather than protocol-oriented, it is conceptually reusable with:

- EtherCAT
- Mesa
- simulation
- future backends

### CiA402 semantic layer

Core components:

- `cia402_pds`
- `cia402_homing`
- `cia402_cw_compose`

Responsibilities:

- decode statusword 6041h semantics
- generate base controlword 6040h intent
- supervise procedure-level behavior such as homing
- expose semantic signals such as state, reason, op-enabled, and fault

### drive / transport adapter

Backend-facing integration layer.

Examples:

- EtherCAT / lcec adapter
- Mesa-oriented adapter
- simulation adapter
- future transport-specific integrations

The semantic core should remain axis-centric, while the adapter may be node-aware or channel-aware.

## Single-writer rule for controlword 6040h

Only one module writes the final controlword.

Architecture:

```text
cia402_pds        -> cw_pds
cia402_homing     -> procedure bits / start request
cia402_cw_compose -> cw_final
```

Conceptually:

```text
cw_final = cw_pds | procedure_bits
```

This avoids:

- multiple writers to 6040h
- ambiguous bit ownership
- composition races

## Deterministic HAL pipeline

All components are intended to run in the same LinuxCNC servo thread through ordered `addf` execution.

Typical conceptual order:

```text
machine_safety_gate
-> cia402_pds
-> cia402_homing
-> cia402_cw_compose
-> adapter / stub
```

There is no true concurrency here as long as each signal has a single writer.

## Scope and operating modes

Initial scope:

- CSP (Cyclic Synchronous Position)
- HM (Homing Mode)

Reasoning:

For CNC use, CSP preserves LinuxCNC as trajectory generator.

```text
LinuxCNC motion
      ↓
cyclic target position
      ↓
drive
```

This avoids delegating path generation to the drive.

## Quick Stop in this project

Quick Stop is supported as a valid CiA402 semantic condition, but it is not intended to be the normal stop path for LinuxCNC.

Project position:

- normal stop should remain planner / motion driven
- Quick Stop is treated as an exceptional or policy-driven path
- `Quick Stop Active` is a valid DS402 state and should not be treated as unknown
- `Fault Reaction Active` is also a valid DS402 condition and should not be treated as unknown

## Gantry / coupler direction

Gantry behavior belongs to machine logic, not to CiA402 semantics.

Planned machine-level functions include:

- decouple
- independent homing
- squaring
- recouple

This logic should remain outside the CiA402 semantic core.

## Repository structure

```text
linuxcnc-cia402-layer/
├─ README.md
├─ LICENSE
├─ comp/
│  ├─ cia402_cw_compose.comp
│  ├─ cia402_homing.comp
│  ├─ cia402_pds.comp
│  ├─ cia402_stub.comp
│  └─ machine_safety_gate.comp
├─ docs/
│  ├─ architecture.md
│  ├─ cia402_reference.md
│  ├─ drive_integration.md
│  └─ error_codes.md
├─ hal/
│  ├─ stub_test.hal
│  ├─ stub_test_modular.hal
│  └─ stub_test_modular_pds.hal
├─ custom.hal
├─ opc_validation.hal
└─ opc_validation.ini
```

## Current state

The project is currently focused on:

- consolidated modular architecture
- explicit semantic ownership boundaries
- deterministic controlword composition
- improved internal diagnostics
- validation harnesses aligned with the architecture

Recent architectural refinements include:

- stronger DS402 decode in `cia402_pds`
- explicit handling for Quick Stop Active
- explicit handling for Fault Reaction Active
- tighter integration between machine policy and PDS enable / fault-reset gating
- modular harnesses updated to reflect real layer ordering

## Adapter direction

Future real-hardware integration should preserve this rule:

- semantic layer remains per-axis / per-channel
- adapter handles backend-specific object mapping

This is important for systems such as:

- one drive per axis
- multi-axis drives
- EtherCAT nodes exposing several CiA402 channels
- Mesa-based backends

In other words, multi-axis-node complexity belongs in the adapter, not in the semantic core.

## Project status summary

The repository is evolving toward a reusable CiA402 semantic framework for LinuxCNC with:

- clear separation of responsibilities
- one final writer for 6040h
- improved semantic diagnostics
- cleaner validation structure
- a future path toward real backend adapters
