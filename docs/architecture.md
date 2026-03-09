
# Architecture

This document describes the architecture of the `linuxcnc-cia402-layer` project.

The design separates **machine policy**, **CiA402 protocol semantics**, and **hardware transport integration**
into independent layers.

This separation allows the CiA402 behavior to be validated in simulation and reused across
different hardware backends without modifying LinuxCNC motion.

LinuxCNC remains the authority for trajectory planning and coordinated motion.

The CiA402 layer acts as a semantic bridge between LinuxCNC motion and CiA402 drives.

---

# Architectural Overview

Logical control pipeline:

LinuxCNC motion
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
transport backend
        ↓
drive (Power Drive System)

This pipeline represents the **semantic control path** between LinuxCNC and a CiA402 drive.

---

# Design Goals

The architecture was designed with the following goals:

- keep LinuxCNC as the motion authority
- isolate CiA402 semantics from transport details
- allow deterministic validation in simulation
- support multiple hardware backends
- avoid race conditions in controlword generation
- keep responsibilities clearly separated

This allows the project to support:

- EtherCAT
- Mesa
- simulation harnesses
- future transport adapters

---

# Responsibility Split

Each layer has a strictly defined responsibility.

| Layer | Responsibility |
|------|----------------|
| LinuxCNC motion | trajectory generation and motion coordination |
| machine_safety_gate | machine policy decisions |
| cia402_pds | DS402 Power Drive System semantic interpretation |
| cia402_homing | homing procedure logic |
| cia402_cw_compose | single writer of the final controlword |
| cia402_drive_adapter | transport/backend integration |
| backend | communication with the drive |
| drive | execution of DS402 commands |

---

# Machine Policy Layer

`machine_safety_gate` represents machine‑level policy.

Examples of decisions made here:

- machine enable allowed or blocked
- homing allowed or blocked
- reset allowed or blocked

This layer is intentionally transport‑agnostic.

It can be reused with:

- EtherCAT
- Mesa
- simulation
- future backends

It does **not replace certified safety systems** such as:

- hardware E‑stop
- STO
- safety relay chains

---

# CiA402 Semantic Layer

The CiA402 semantic layer interprets the DS402 protocol behavior and converts it
into clear HAL‑level signals.

Components:

- `cia402_pds`
- `cia402_homing`
- `cia402_cw_compose`

This layer **does not depend on transport technology**.

It operates purely on CiA402 semantics.

---

# Power Drive System Interpretation

`cia402_pds` interprets the CiA402 **Power Drive System finite state automaton**
from the statusword (6041h).

Outputs include:

- semantic state
- semantic reason code
- operation enabled flag
- fault indication
- base controlword intent

The decoder uses masked patterns:

st_6f = sw & 0x006F  
st_4f = sw & 0x004F

This approach allows compatibility with drives that implement the Quick Stop bit
differently.

---

# Procedural Layer

Procedural components implement higher‑level drive procedures.

Currently implemented:

- `cia402_homing`

Responsibilities:

- request homing mode
- generate homing start pulses
- supervise completion
- detect timeout and progress failures
- expose procedural diagnostics

Future procedures may include:

- probe procedures
- rigid tapping procedures
- gantry synchronization helpers

Procedures must **not directly write the controlword**.

---

# Controlword Arbitration

`cia402_cw_compose` is the **single writer of the final controlword**.

It merges intent from:

- `cia402_pds`
- procedural components

The resulting signal is:

cw_final

This rule prevents a common integration error:

multiple independent writers attempting to control the same controlword bits.

By centralizing arbitration, the system avoids race conditions and ambiguity.

---

# Adapter Layer

`cia402_drive_adapter` connects the semantic layer to the selected backend.

Responsibilities:

- map HAL signals to backend registers or PDOs
- transfer statusword feedback to the semantic layer
- forward the final controlword to the backend

The adapter must remain **thin**.

It must **not reinterpret DS402 states** or procedural logic.

---

# Transport Backends

Backends implement the physical communication with the drive.

Examples:

EtherCAT  
Mesa FPGA interface  
simulation harness

The semantic layer does not depend on backend implementation details.

---

# Multi‑Axis Architecture

For multi‑axis systems, the rule is:

one semantic pipeline per axis.

Example:

axis0:
- cia402_pds
- cia402_homing
- cia402_cw_compose
- adapter mapping

axis1:
- cia402_pds
- cia402_homing
- cia402_cw_compose
- adapter mapping

Servo thread scheduling should group components by **stage**, not by axis.

Example ordering:

policy blocks  
PDS blocks  
procedural blocks  
controlword compose blocks  
adapter blocks  
backend

This maintains deterministic execution ordering.

---

# Simulation and Validation

The project includes a HAL simulation harness using:

`cia402_stub`

This allows deterministic validation of:

- PDS state transitions
- homing procedures
- error conditions
- timeout behavior

The harness makes it possible to validate semantic behavior **without real hardware**.

---

# Architectural Properties

This architecture provides several important properties:

- deterministic controlword ownership
- clear separation of responsibility
- backend independence
- simulation‑first validation capability
- improved debug clarity
- reduced integration ambiguity

These properties make the project suitable for gradual evolution from
simulation to real hardware deployment.

---

# Summary

The architecture of `linuxcnc-cia402-layer` intentionally separates:

- motion authority
- machine policy
- CiA402 semantics
- procedural logic
- backend integration

This layered design allows the CiA402 behavior to be validated independently of
hardware and keeps the system robust against integration ambiguity.
