# Error Codes and Diagnostics

This document explains the diagnostic layers used by this project and how to interpret them.

A core design goal of `linuxcnc-cia402-layer` is to keep these layers separate:

- drive-level faults
- CiA402 semantic-layer diagnostics
- machine-policy diagnostics

These layers are related, but they are **not the same thing**.

---

## 1. Drive-level faults

This is the diagnostic level reported by the drive or backend itself.

Typical sources:

- Statusword `6041h` fault bit
- Error Code `603Fh`
- vendor-specific diagnostic objects
- transport/backend watchdog or communication fault channels
- hardware inhibit / STO feedback

A drive fault means the **Power Drive System** reports an error condition.

Examples:

- overcurrent
- overvoltage
- encoder error
- following error internal to the drive
- internal power stage fault
- STO / hardware inhibit feedback
- vendor-specific alarm

In this project, drive-level faults are **not** the same as semantic-layer procedural or policy diagnostics.

---

## 2. CiA402 semantic-layer diagnostics

The semantic layer interprets CiA402 behavior and exposes internal state/reason values.

Main modules:

- `cia402_pds`
- `cia402_homing`
- `cia402_cw_compose` (composition ownership, not a fault source by itself)

These modules do **not** replace vendor diagnostics.
They explain what the semantic layer believes is happening.

---

## 3. Machine-policy diagnostics

The machine-policy layer decides whether the machine is allowed to proceed.

Main module:

- `machine_safety_gate`

This layer is intentionally generic and reusable with:

- EtherCAT
- Mesa
- simulation
- future adapters/backends

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

These are very different situations:

1. the drive reports a real hardware fault
2. the PDS is in a valid but non-enabled DS402 state
3. homing was aborted because procedure execution dropped
4. machine policy is blocking enable because machine-on is false
5. fault reset was requested but machine policy blocked it

All of these may stop motion, but they have different causes and require different actions.

---

## 5. `cia402_pds` diagnostics

`cia402_pds` interprets the CiA402 Power Drive System state machine from `6041h` and generates the base `6040h` controlword fragment.

Outputs of interest:

- `state`
- `reason`
- `fault`
- `op_enabled`
- `st_6f`
- `st_4f`

### `state`

`state` reports the recognized DS402 state value used by the module.

Recognized states now include:

- `0x0000` = Not Ready to Switch On
- `0x0040` = Switch On Disabled
- `0x0021` = Ready to Switch On
- `0x0023` = Switched On
- `0x0027` = Operation Enabled
- `0x0007` = Quick Stop Active
- `0x000F` = Fault Reaction Active
- `0x0008` = Fault

If a pattern is not recognized, the module exposes the masked fallback value for debug and reports `UNKNOWN_STATE`.

### `reason`

`reason` explains the semantic diagnostic path selected by the module.

Current `cia402_pds` reason codes:

- `0`  = `PDS_R_NOT_READY`
- `1`  = `PDS_R_SWITCH_ON_DISABLED`
- `2`  = `PDS_R_READY_TO_SWITCH_ON`
- `3`  = `PDS_R_SWITCHED_ON`
- `4`  = `PDS_R_OPERATION_ENABLED`
- `10` = `PDS_R_FAULT_PRESENT`
- `11` = `PDS_R_FAULT_RESET_REQUESTED`
- `12` = `PDS_R_QUICK_STOP_ACTIVE`
- `13` = `PDS_R_FAULT_REACTION_ACTIVE`
- `14` = `PDS_R_FAULT_RESET_BLOCKED`
- `20` = `PDS_R_UNKNOWN_STATE`

### `fault`

`fault` is asserted when the semantic layer sees a fault-class condition.

That includes:

- DS402 `Fault`
- DS402 `Fault Reaction Active`

This makes `fault` useful as a high-level stop indicator, while detailed interpretation still comes from `state` and `reason`.

### `op_enabled`

`op_enabled` is asserted only when the semantic layer has recognized the DS402 state as `Operation Enabled`.

### `st_6f` and `st_4f`

These are debug outputs exposing the masked statusword values used by the decoder:

- `st_6f = sw & 0x006F`
- `st_4f = sw & 0x004F`

They are useful when debugging ambiguous state decode.

### Important implementation details

#### A. Robust `Switch On Disabled` decode

Some stubs or drives keep QS-related bits in a way that makes the normal `0x006F` mask ambiguous for `Switch On Disabled`.

For that reason, this project accepts `Switch On Disabled` using:

- normal masked decode behavior
- plus a robust exception path via `st_4f`

This is a semantic-layer decode choice, not a vendor alarm.

#### B. `Quick Stop Active` is a valid DS402 state

`Quick Stop Active` must **not** fall into `UNKNOWN_STATE`.

It is a valid DS402 condition and should be diagnosed explicitly.

#### C. `Fault Reaction Active` is also a valid DS402 state

`Fault Reaction Active` is a real DS402 state and must be separated from both:

- ordinary `Fault`
- `UNKNOWN_STATE`

This improves diagnostic clarity during transient fault handling.

#### D. Machine-policy gating now affects PDS progression

`cia402_pds` now receives machine-policy gating inputs:

- `allow_enable`
- `allow_fault_reset`

Effective behavior is therefore based on gated requests, not raw operator intent alone.

Conceptually:

- `effective_enable = enable && allow_enable`
- `effective_fault_reset = fault_reset && allow_fault_reset`

So a denied enable or denied reset is not automatically a semantic decode problem.

---

## 6. `cia402_homing` diagnostics

`cia402_homing` supervises homing behavior at the semantic/procedural layer.

Outputs of interest include:

- `state`
- `reason`
- `active`
- `done`
- `error`
- `done_p`

### Current state values

- `H_S_IDLE`
- `H_S_WAIT_OMD6`
- `H_S_SEND_START`
- `H_S_WAIT_DONE`
- `H_S_DONE`
- `H_S_ERROR`

### Current reason values

- `H_R_IDLE`
- `H_R_WAITING_MODE_DISPLAY`
- `H_R_SENDING_START_PULSE`
- `H_R_WAITING_DONE`
- `H_R_DONE`
- `H_R_ERROR_STATUS_MATCH`
- `H_R_ERROR_EXEC_DROPPED`
- `H_R_ERROR_INVALID_STATE`

### Important distinction

A homing error does not automatically mean the drive itself faulted.

Examples of semantic/procedural homing errors:

- mode display did not match expected homing mode
- execution dropped during homing
- procedure reached an invalid internal state
- future timeout condition

These are procedure-level conditions.
They are not the same as `603Fh` or a hardware fault.

---

## 7. `machine_safety_gate` diagnostics

`machine_safety_gate` is a machine-policy gate.

Outputs of interest include:

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
- the transport/backend failed at protocol level

It may simply mean machine policy is intentionally blocking progression.

### Current reason codes

Current `machine_safety_gate` reason codes are:

- `0` = `MSG_R_OK`
- `1` = `MSG_R_BLOCK_ESTOP`
- `2` = `MSG_R_BLOCK_MACHINE_OFF`
- `3` = `MSG_R_BLOCK_BACKEND_NOT_READY`

These are policy reasons, not drive alarms.

### Relationship to `cia402_pds`

The current architecture now connects machine-policy gating directly into `cia402_pds`.

This means:

- machine policy may block PDS progression
- machine policy may block fault reset
- those situations are not automatically DS402 faults

---

## 8. Example diagnostic interpretation

### Example A: drive fault present

Possible observation:

- `cia402_pds.fault = 1`
- `cia402_pds.state = 0x0008`
- `cia402_pds.reason = PDS_R_FAULT_PRESENT`

Meaning:

- the semantic layer sees a DS402 fault state
- the drive is faulted
- next action may require reading `603Fh` or vendor diagnostics

### Example B: fault reaction in progress

Possible observation:

- `cia402_pds.fault = 1`
- `cia402_pds.state = 0x000F`
- `cia402_pds.reason = PDS_R_FAULT_REACTION_ACTIVE`

Meaning:

- the drive is still in the DS402 fault-reaction phase
- this is not the same as steady-state `Fault`
- recovery logic should wait for the actual post-reaction state

### Example C: machine blocked but no drive fault

Possible observation:

- `machine_safety_gate.machine_ok = 0`
- `machine_safety_gate.reason = MSG_R_BLOCK_MACHINE_OFF`
- `cia402_pds.fault = 0`

Meaning:

- machine policy is blocking operation because machine-on is false
- this is not a drive fault

### Example D: fault reset requested but blocked by policy

Possible observation:

- `fault_reset` request present
- `machine_safety_gate.allow_fault_reset = 0`
- `cia402_pds.reason = PDS_R_FAULT_RESET_BLOCKED`

Meaning:

- reset intent exists
- machine policy denied it
- this is not the same as the drive rejecting reset

### Example E: homing procedure error without drive fault

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
- `machine_safety_gate.allow_enable`
- `machine_safety_gate.allow_fault_reset`

### B) What DS402 state is the semantic layer seeing?

Check:

- `cia402_pds.state`
- `cia402_pds.reason`
- `cia402_pds.st_6f`
- `cia402_pds.st_4f`

### C) Is the drive in a valid but non-operational DS402 state?

Check specifically for:

- `Quick Stop Active`
- `Fault Reaction Active`
- `Switch On Disabled`

### D) Did the drive actually report a fault?

Check:

- `cia402_pds.fault`
- `6041h` fault bit
- `603Fh`
- vendor diagnostics

### E) Is the problem procedural?

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
A valid DS402 transient state is not automatically an unknown state.
