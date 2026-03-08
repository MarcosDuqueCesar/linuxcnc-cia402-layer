# linuxcnc-cia402-layer

Vendor-agnostic **CiA402 semantic layer for LinuxCNC** implemented with modular HAL components.

The goal of this project is to provide a clean separation between:

- machine policy
- CiA402 protocol semantics
- hardware transport / fieldbus integration

This allows CiA402 behavior to be validated in simulation and reused across different hardware backends.

The project does **not modify LinuxCNC motion**.  
LinuxCNC remains the trajectory generator and motion authority.

---

# Architecture

The architecture separates responsibilities into independent layers.

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

This design prevents protocol logic, machine logic and hardware transport from becoming tightly coupled.

---

# LinuxCNC Role

LinuxCNC acts as the **Control Device** in the CiA402 architecture.

Responsibilities remain inside LinuxCNC:

- trajectory planning
- interpolation
- kinematics
- coordinated motion
- synchronization

The drive acts as the **Power Drive System (PDS)** executing the motion commands.

---

# Machine Safety Gate

The `machine_safety_gate` component implements **machine policy gating**.

Typical responsibilities:

- enable permission
- motion permission
- homing permission
- fault reset permission

This layer is intentionally **generic** and **transport independent**.

It can be used with:

- EtherCAT drives
- Mesa hardware
- simulated drives
- other future backends

Important:

This component **does not replace real safety hardware** such as:

- E-stop circuits
- STO
- safety relays
- contactors

Those must always exist in hardware.

---

# CiA402 Semantic Layer

The semantic layer implements the CiA402 protocol behavior using HAL components.

Main modules:

```text
cia402_pds
cia402_homing
cia402_cw_compose
```

Responsibilities include:

- interpreting the Statusword (6041h)
- generating the Controlword (6040h)
- supervising homing procedures
- exposing semantic signals (fault, op_enabled, etc.)

---

# Deterministic Controlword Composition

To avoid ambiguity, **only one module writes the final controlword**.

Conceptually:

```text
cw_final = cw_pds | procedure_bits
```

Where:

- `cw_pds` comes from the PDS state manager
- `procedure_bits` may include homing start signals

This avoids race conditions between HAL components.

---

# HAL Execution Order

All modules run in the same LinuxCNC realtime thread.

Conceptual order:

```text
machine_safety_gate
→ cia402_pds
→ cia402_homing
→ cia402_cw_compose
→ drive / stub
```

HAL executes functions sequentially, ensuring deterministic behavior.

---

# Operation Modes

CiA402 defines multiple operation modes.

For CNC systems the most relevant modes are:

```text
Cyclic Synchronous Position (CSP)
Homing Mode (HM)
```

CSP is preferred because LinuxCNC remains the trajectory generator.

Other CiA402 modes may be supported in the future.

---

# Simulation

The repository includes a simulated drive:

```text
cia402_stub
```

The stub emulates:

- PDS state transitions
- homing completion
- operation mode reporting
- fault behavior

This allows most of the CiA402 logic to be validated without real hardware.

---

# Gantry / Coupler (future work)

Machine coordination features such as gantry squaring belong to the **machine layer**, not the protocol layer.

Typical procedures include:

```text
decouple
home independently
square gantry
recouple
```

These mechanisms are intentionally kept separate from the CiA402 semantic layer.

---

# Documentation

Detailed documentation is available in the `docs/` directory:

```text
docs/
 ├─ architecture.md        Project architecture
 ├─ cia402_reference.md    CiA402 protocol reference
 ├─ drive_integration.md   Integrating real drives
 └─ error_codes.md         Fault handling and diagnostics
```

---

# Project Goals

The project aims to provide:

- clear separation between machine policy and drive protocol
- deterministic controlword generation
- reusable CiA402 semantics
- hardware-agnostic integration
- validation without physical drives

---

# Status

Current capabilities:

- CiA402 PDS state machine
- deterministic controlword composition
- homing supervision
- simulation stub
- modular HAL architecture

Future work may include:

- additional operation modes
- gantry / coupling logic
- transport adapters
- expanded diagnostics

---

# License

MIT License
