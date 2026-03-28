# CiA402 Reference

This document summarizes the parts of the CiA402 specification that are relevant for the `linuxcnc-cia402-layer` project.

It is **not a full reproduction of the specification**.  
Instead, it explains the concepts that are required to understand how LinuxCNC interacts with CiA402 drives.

The goal is to clarify the terminology and the behavior expected from a CiA402 drive.

---

# Control Device and Power Drive System

In CiA402 terminology two main roles exist:

- **Control Device**
- **Power Drive System (PDS)**

For a LinuxCNC based system:

```text
LinuxCNC motion  →  Control Device
Drive            →  Power Drive System (PDS)
```

LinuxCNC generates the trajectory and target positions.  
The drive executes the commands and controls the motor power stage.

---

# Power Drive System Finite State Automaton

CiA402 defines a standardized state machine for drives called the **PDS FSA**.

Typical states include:

```text
Not Ready to Switch On
Switch On Disabled
Ready to Switch On
Switched On
Operation Enabled
Quick Stop Active
Fault Reaction Active
Fault
```

State transitions are controlled through the **Controlword (6040h)** and reported through the **Statusword (6041h)**.

The `cia402_pds` component in this project interprets these states and produces the correct controlword transitions.

---

# Controlword (6040h)

Object **6040h** is the Controlword.

It is written by the controller (LinuxCNC through the semantic layer) to command the drive state machine.

Important bits include:

```text
Bit 0  Switch On
Bit 1  Enable Voltage
Bit 2  Quick Stop
Bit 3  Enable Operation
Bit 7  Fault Reset
```

The combination of these bits determines which transition of the PDS state machine is requested.

In this project the controlword is composed deterministically using:

```text
cw_final = cw_pds | procedure_bits
```

Where:

- `cw_pds` comes from the PDS state manager
- `procedure_bits` may include homing start commands

---

# Statusword (6041h)

Object **6041h** is the Statusword.

It is reported by the drive and indicates the current state of the PDS state machine.

Typical bits include:

```text
Bit 0  Ready to Switch On
Bit 1  Switched On
Bit 2  Operation Enabled
Bit 3  Fault
Bit 5  Quick Stop
Bit 6  Switch On Disabled
```

The `cia402_pds` component decodes these patterns to determine the drive state.

Because some drives deviate slightly from the specification, mask-based decoding is used in this project.

Example:

```text
sw & 0x006F
sw & 0x004F
```

This improves compatibility across vendors.

---

# Modes of Operation

CiA402 supports multiple operation modes.

Some common ones are:

```text
Profile Position (PP)
Profile Velocity (PV)
Profile Torque (PT)
Cyclic Synchronous Position (CSP)
Cyclic Synchronous Velocity (CSV)
Cyclic Synchronous Torque (CST)
Homing Mode (HM)
```

For CNC systems, the most important modes are:

```text
Cyclic Synchronous Position (CSP)
Homing Mode (HM)
```

In CSP mode the controller continuously sends position targets to the drive.

This allows LinuxCNC to remain the trajectory generator.

---

# Mode Objects

The following objects control operation modes:

```text
6060h  Modes of Operation
6061h  Modes of Operation Display
```

- **6060h** is written by the controller.
- **6061h** is reported by the drive.

The semantic layer waits for 6061h to confirm the selected mode before proceeding with procedures such as homing.

---

# Homing Mode

Homing mode allows the drive to perform a homing sequence.

The procedure typically involves:

1. Selecting Homing Mode via 6060h
2. Waiting for 6061h confirmation
3. Starting homing using a controlword bit
4. Monitoring completion through statusword signals

The `cia402_homing` component supervises this procedure and reports completion or failure.

---

# Error Codes

Drives may report errors using object:

```text
603Fh Error Code
```

Additional diagnostic information may also be available through manufacturer-specific objects.

Future documentation may include mappings between CiA402 error codes and diagnostic outputs from the semantic layer.

---

# Summary

The `linuxcnc-cia402-layer` project implements a modular semantic layer that:

- interprets the CiA402 PDS state machine
- composes deterministic controlwords
- supervises homing procedures
- allows integration with different transport layers

Understanding the objects and concepts summarized here is essential when integrating a real CiA402 drive with LinuxCNC.
