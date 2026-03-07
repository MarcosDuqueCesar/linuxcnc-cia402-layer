# linuxcnc-cia402-layer

Modular CiA402 semantic layer for LinuxCNC (EtherCAT and other transports).

⚠️ **Experimental project**

This repository explores a modular CiA402 semantic layer for LinuxCNC.

The current implementation has been validated in simulation using a HAL
drive stub. Real hardware integration (EtherCAT / lcec) is the next step.

The architecture is still evolving.

---

Transport-agnostic and drive-agnostic CiA402 semantic layer for LinuxCNC.

This project implements a modular HAL-based architecture that separates:

* machine safety policy
* CiA402 protocol semantics
* transport / fieldbus integration

The goal is to make CiA402 drives usable in LinuxCNC without embedding
protocol-specific logic inside motion or transport drivers.

The same semantic layer can work with:

* EtherCAT
* simulation stubs
* future Mesa integrations
* other transports

This repository currently focuses on validating the architecture in simulation
before integrating with real EtherCAT hardware.

---

# Table of Contents

* Design Goals
* Current Components
* Execution Model
* Repository Layout
* Validation Status
* Project Status
* Future Work
* License

---

# Design Goals

## Deterministic behavior

All modules execute inside the LinuxCNC servo thread.

Execution order is explicitly defined in HAL.

Only one component writes the final CiA402 controlword.

---

## Explicit controlword ownership

The final controlword is composed explicitly:

cw_final = cw_pds | start4

This guarantees that:

* only one module writes the controlword
* protocol semantics remain deterministic
* race conditions between modules are avoided

---

## Transport independence

The CiA402 semantic layer is not tied to EtherCAT.

Transport adapters can map the semantic layer to:

* EtherCAT
* simulation stubs
* Mesa hardware
* other drivers

---

## Machine safety separation

Machine safety policy should not be embedded inside protocol logic.

The intended architecture separates layers clearly:

```
LinuxCNC motion
      ↓
machine_safety_gate
      ↓
CiA402 semantic layer
      ↓
transport adapter
      ↓
drive / fieldbus
```

**Important note**

This project does **not replace or modify the LinuxCNC motion controller**.

LinuxCNC motion remains responsible for trajectory generation,
coordination, and global motion logic.

The CiA402 layer only translates motion semantics into the
CiA402 protocol used by smart drives.

The machine_safety_gate is a machine-policy layer for enable,
fault-reset, homing, and motion permissions. It does **not replace
hardware E-stop chains, STO, contactors, or other certified
safety functions**.

---

# Current Components

## machine_safety_gate.comp

Machine policy gate placed between LinuxCNC motion and the CiA402 layer.

Responsibilities:

* gate enable requests
* gate fault reset requests
* gate homing requests
* gate motion permissions

The gate enforces machine-level conditions such as:

* E-stop state
* machine power state
* drive readiness

It prevents the CiA402 layer from enabling drives when the machine
is not in a valid operational state.

Important:

This component implements machine policy only.
It does not implement the CiA402 protocol and does not replace
hardware safety systems such as E-stop chains or STO.

---

## cia402_pds.comp

CiA402 Power Drive System state manager.

Responsibilities:

* decode CiA402 statusword (6041)
* manage CiA402 state transitions
* generate base controlword (6040)
* expose Operation Enabled
* handle fault reset

The decode logic checks both masks:

sw & 0x006F
sw & 0x004F

This handles drives that keep the Quick Stop bit asserted
while still being in Switch On Disabled.

Outputs:

cw_pds
op_enabled
state
reason

---

## cia402_homing.comp

Homing procedure supervisor.

Responsibilities:

* request homing operation mode
* wait for opmode display confirmation
* generate homing start pulse (bit 4)
* monitor homing completion
* latch done/error conditions

Important design rule:

This module does **not own the controlword**.

It only requests the homing start bit.

---

## cia402_cw_compose.comp

Controlword ownership module.

Purpose:

Guarantee deterministic controlword composition.

Rule:

cw_final = cw_pds | start4

Where:

cw_pds → base state machine output
start4 → homing start request

This avoids multiple writers to object 6040.

---

## cia402_stub.comp

Simulation stub used for validation without real hardware.

Capabilities:

* PDS state simulation
* homing completion simulation
* operation mode display delay
* fault injection
* fault reset timing

This allows the entire CiA402 layer to be tested in
LinuxCNC AXIS simulation.

---

# Execution Model

All modules run in the same servo thread.

Example configuration:

servo-thread: 1 kHz

Execution order:

```
machine_safety_gate
→ cia402_pds
→ cia402_homing
→ cia402_cw_compose
→ cia402_stub
```

LinuxCNC HAL executes functions sequentially according to addf order.

Because:

* modules share the same thread
* execution order is explicit
* controlword ownership is unique

the architecture remains deterministic.

---

# Repository Layout

```
comp/
    machine_safety_gate.comp
    cia402_pds.comp
    cia402_homing.comp
    cia402_cw_compose.comp
    cia402_stub.comp

hal/
    stub_test.hal
    stub_test_modular.hal
    stub_test_modular_pds.hal

docs/
    architecture.md
    design_notes.md
    error_codes.md
    roadmap.md

opc_validation.ini
opc_validation.hal
```

---

# Validation Status

Validated in LinuxCNC AXIS simulation:

* deterministic controlword ownership
* robust PDS decoding
* homing supervision
* operation mode handshake
* fault injection
* fault reset behavior
* homing gated by Operation Enabled

Servo thread frequency used for testing:

1 kHz

---

# Project Status

Current state:

* CiA402 PDS state machine implemented
* deterministic controlword ownership
* homing supervision logic
* HAL drive stub for simulation testing

Next milestone:

integration with real EtherCAT drives via lcec.

---

# Future Work

Next steps:

* finalize machine safety gate layer
* implement EtherCAT adapter (lcec backend)
* test with real CiA402 drives
* Mesa hardware integration example
* additional CiA402 operation modes

---

# License

MIT License
