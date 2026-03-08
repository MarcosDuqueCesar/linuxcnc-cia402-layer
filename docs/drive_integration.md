# Drive Integration

This document explains how the `linuxcnc-cia402-layer` semantic layer connects to a real CiA402 drive.

The project intentionally separates:

- machine policy
- protocol semantics
- hardware transport

This makes it possible to reuse the same CiA402 semantic logic with different hardware backends such as EtherCAT, Mesa hardware, or simulation.

---

# Integration Layers

A typical integration stack looks like this:

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
drive adapter
        |
        v
transport layer (EtherCAT / Mesa / other)
        |
        v
CiA402 drive
```

Each layer has a specific responsibility.

---

# Semantic Layer Responsibilities

The semantic layer is implemented by the HAL components in the `comp/` directory.

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
- exposing semantic signals such as operation enabled and faults

These modules do **not depend on any specific fieldbus**.

---

# Drive Adapter Layer

Between the semantic layer and the transport layer sits the **drive adapter**.

The adapter maps:

- HAL pins
- CiA402 objects
- fieldbus process data

Conceptually:

```text
HAL signals
     |
     v
CiA402 object mapping
     |
     v
PDO / hardware interface
```

The adapter ensures that the semantic layer remains independent of the hardware protocol.

---

# EtherCAT Integration

With EtherCAT the adapter typically connects to the LinuxCNC EtherCAT driver (`lcec`).

The mapping usually looks like:

```text
HAL pin             EtherCAT PDO object
--------------------------------------
controlword   ->    0x6040
statusword    <-    0x6041
opmode        ->    0x6060
opmode_disp   <-    0x6061
target_pos    ->    0x607A
actual_pos    <-    0x6064
```

The EtherCAT driver exchanges these values cyclically with the drive.

---

# Mesa Hardware Integration

Mesa hardware can also be used as a backend for the semantic layer.

In this case the adapter maps HAL pins to Mesa registers or FPGA logic.

Example conceptual mapping:

```text
HAL pin
   |
   v
Mesa register / FPGA interface
   |
   v
drive interface
```

Because the semantic layer is HAL-based, it can operate with Mesa hardware in the same way it does with EtherCAT.

---

# Simulation

The repository includes a simulated drive:

```text
cia402_stub
```

This component emulates:

- PDS state transitions
- homing completion
- fault conditions
- operation mode reporting

Simulation allows most of the CiA402 logic to be validated without real hardware.

---

# Typical HAL Signal Flow

A simplified signal flow may look like this:

```text
LinuxCNC motion
        |
        v
machine_safety_gate
        |
        v
cia402_pds
        |
        v
cia402_homing
        |
        v
cia402_cw_compose
        |
        v
drive adapter
        |
        v
transport (EtherCAT / Mesa)
        |
        v
drive
```

The exact HAL wiring depends on the transport layer and the specific drive.

---

# Position Control with CSP

For CNC systems the preferred CiA402 mode is:

```text
Cyclic Synchronous Position (CSP)
```

In CSP mode:

- LinuxCNC generates the trajectory
- target positions are sent cyclically to the drive
- the drive performs the servo loop

This preserves LinuxCNC as the motion controller while the drive acts as the power stage.

---

# Homing Integration

When using CiA402 homing mode:

1. The semantic layer requests homing mode (6060h).
2. The drive confirms using 6061h.
3. The homing start bit is sent through the controlword.
4. The semantic layer monitors completion.

The `cia402_homing` component supervises this procedure and reports the result to LinuxCNC.

---

# Vendor Differences

Although CiA402 standardizes many objects, real drives may differ in:

- exact state patterns
- additional diagnostic objects
- homing behavior
- PDO layouts

The semantic layer handles most protocol behavior, but the adapter may still require vendor-specific configuration.

---

# Summary

Drive integration is intentionally separated from protocol semantics.

The architecture allows:

- testing without hardware
- reuse of the CiA402 logic
- support for multiple transports

The adapter layer connects the generic CiA402 semantic logic to the specific hardware interface used by the machine.
