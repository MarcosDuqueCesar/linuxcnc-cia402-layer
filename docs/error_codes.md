# Error Codes and Diagnostics

This document explains the different diagnostic layers used by this project.

A key design goal of `linuxcnc-cia402-layer` is to keep these layers separate:

- drive-level faults
- semantic-layer state/reason
- machine-policy blocking

These are related, but they are **not the same thing**.

---

## 1. Drive-level faults

This is the diagnostic level reported by the drive itself.

Typical sources:

- Statusword `6041h` fault bit
- Error Code `603Fh`
- vendor-specific diagnostic objects
- backend-specific fault channels

### Important distinction

A drive fault means the **Power Drive System** reports an error condition.

Examples:

- overcurrent
- following error inside the drive
- encoder error
- overvoltage
- internal drive fault
- STO / hardware inhibit feedback
- vendor-specific alarm

In this project, drive-level faults are not the same as semantic-layer procedural errors.

---

## 2. CiA402 semantic-layer diagnostics

The semantic layer interprets CiA402 behavior and exposes internal state/reason values.

Main modules:

- `cia402_pds`
- `cia402_homing`

These modules do **not** replace vendor diagnostics.
They explain what the semantic layer believes is happening.

---

## 3. Machine-policy diagnostics

The machine-policy layer decides whether the machine is allowed to proceed.

Main module:

- `machine_safety_gate`

This layer is intentionally generic and can be used with:

- EtherCAT
- Mesa
- simulation
- future backends

It is not itself a certified safety system.

It does **not** replace:

- hardware E-stop
- STO
- safety relay
- contactor
- certified safety chain

---

## 4. Why these layers must stay separate

A common integration mistake is to merge all failures into a single vague "error".

That creates ambiguity.

For example, these are very different situations:

1. the drive reports a real hardware fault
2. the PDS is in a valid but non-enabled state
3. homing was aborted because execution dropped
4. machine policy is blocking enable because machine-on is false

All of those may stop motion, but they have different causes and require different actions.

---

## 5. `cia402_pds` diagnostics

`cia402_pds` is responsible for interpreting the CiA402 Power Drive System state machine from `6041h` and generating the base `6040h` controlword.

Outputs of interest:

- `state`
- `reason`
- `fault`
- `op_enabled`
- `st_6f`
- `st_4f`

### `state`

`state` reports the recognized DS402 state value used by the module.

Typical values:

- `0x0000` = Not Ready to Switch On
- `0x0040` = Switch On Disabled
- `0x0021` = Ready to Switch On
- `0x0023` = Switched On
- `0x0027` = Operation Enabled
- `0x0008` = Fault

If the state is not recognized in the normal decode path, the module exposes the masked fallback value for debug.

### `reason`

`reason` explains the current diagnostic path chosen by the module.

Current `cia402_pds` reason codes:

- `0`  = `PDS_R_NOT_READY`
- `1`  = `PDS_R_SWITCH_ON_DISABLED`
- `2`  = `PDS_R_READY_TO_SWITCH_ON`
- `3`  = `PDS_R_SWITCHED_ON`
- `4`  = `PDS_R_OPERATION_ENABLED`
- `10` = `PDS_R_FAULT_PRESENT`
- `11` = `PDS_R_FAULT_RESET_REQUESTED`
- `20` = `PDS_R_UNKNOWN_STATE`

### `fault`

`fault` is asserted when the drive fault bit is present in `6041h`.

This indicates a drive-level fault condition is active.

### `op_enabled`

`op_enabled` is asserted only when the semantic layer has recognized the DS402 state as `Operation Enabled`.

### `st_6f` and `st_4f`

These are debug outputs that expose the masked statusword values used by the decoder:

- `st_6f = sw & 0x006F`
- `st_4f = sw & 0x004F`

They are useful when debugging state decode issues.

### Important implementation detail

Some stubs or drives keep QS (bit 5) asserted in a way that makes the normal `0x006F` mask ambiguous for `Switch On Disabled`.

For that reason, this project accepts `Switch On Disabled` using:

- normal masked decode behavior
- plus a robust exception path via `st_4f`

This is a semantic-layer decode choice, not a vendor alarm.

---

## 6. `cia402_homing` diagnostics

`cia402_homing` supervises homing behavior at the semantic/procedural layer.

Outputs of interest typically include:

- `state`
- `reason`
- `active`
- `done`
- `error`
- `done_p`

### Important distinction

A homing error does not automatically mean the drive itself faulted.

Examples of semantic/procedural homing errors:

- mode display did not match expected homing mode
- execution dropped during homing
- procedure reached an invalid internal state
- future timeout condition

These are procedure-level conditions.

They are not the same as `603Fh` or a hardware fault.

### Current practical interpretation

At the moment, `cia402_homing` already exposes state/reason, but its error reasons are still more generic than the PDS target structure.

That is acceptable for now, but future refinement should distinguish at least:

- status/match failure
- execution dropped
- invalid internal state
- timeout

---

## 7. `machine_safety_gate` diagnostics

`machine_safety_gate` is a machine-policy gate.

Its outputs typically include:

- `machine_ok`
- `allow_enable`
- `allow_homing`
- `allow_motion`
- `allow_fault_reset`
- `reason`

### What it means

If this module blocks operation, it does **not** necessarily mean:

- the drive is faulted
- the CiA402 semantic layer is wrong
- the transport/backend failed

It may simply mean machine policy is intentionally blocking progression.

### Current reason codes

Current `machine_safety_gate` reason codes are:

- `0` = OK
- `1` = E-stop not OK
- `2` = machine off
- `3` = drives/backend not ready

These are policy reasons, not drive alarms.

---

## 8. Example diagnostic interpretation

### Example A: drive fault present

Possible observation:

- `cia402_pds.fault = 1`
- `cia402_pds.state = 0x0008`
- `cia402_pds.reason = 10`

Meaning:

- the semantic layer sees a DS402 fault state
- the drive is faulted
- next action may require reading `603Fh` or vendor diagnostics

### Example B: machine blocked but no drive fault

Possible observation:

- `machine_safety_gate.machine_ok = 0`
- `machine_safety_gate.reason = 2`
- `cia402_pds.fault = 0`

Meaning:

- machine policy is blocking operation because machine-on is false
- this is not a drive fault

### Example C: homing procedure error without drive fault

Possible observation:

- `cia402_homing.error = 1`
- `cia402_pds.fault = 0`

Meaning:

- the homing procedure failed semantically or procedurally
- this does not by itself prove a drive-level alarm

---

## 9. Recommended debugging order

When something goes wrong, debug in this order:

1. machine-policy layer
2. semantic-layer state/reason
3. drive-level diagnostics

Practical questions:

### A) Is the machine intentionally blocked?
Check:

- `machine_safety_gate.machine_ok`
- `machine_safety_gate.reason`

### B) What DS402 state is the semantic layer seeing?
Check:

- `cia402_pds.state`
- `cia402_pds.reason`
- `cia402_pds.st_6f`
- `cia402_pds.st_4f`

### C) Did the drive actually report a fault?
Check:

- `cia402_pds.fault`
- `6041h` fault bit
- `603Fh`
- vendor diagnostics

### D) Is the problem procedural?
Check:

- `cia402_homing.state`
- `cia402_homing.reason`
- `cia402_homing.error`

---

## 10. Design intent summary

This project intentionally separates:

- drive fault reporting
- semantic interpretation
- machine policy

That separation improves:

- debug clarity
- adapter portability
- simulation fidelity
- future backend integration
- maintainability

A blocked machine is not automatically a faulted drive.
A procedure failure is not automatically a DS402 alarm.
A DS402 alarm is not automatically a machine-policy decision.