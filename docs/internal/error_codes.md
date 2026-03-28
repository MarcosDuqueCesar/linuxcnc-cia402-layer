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

`op_enabled` is asserted only when the semantic layer has recognized the DS402 `Operation Enabled` state.

This is an important integration signal because procedures and machine policy may require the drive to be in a fully enabled state before proceeding.

### `st_6f` and `st_4f`

These are debug exposure outputs that show the masked `6041h` patterns used by the decoder:

- `st_6f = sw & 0x006F`
- `st_4f = sw & 0x004F`

They are intentionally exposed so runtime observations can be compared directly against the decode logic.

This is especially useful when validating behavior with simulated or real drives that keep the Quick Stop bit asserted differently.

---

## 6. `cia402_homing` diagnostics

`cia402_homing` is a procedural component.

It does **not** report drive hardware faults.  
It reports the state of the homing procedure itself.

Relevant outputs:

- `state`
- `reason`
- `err`
- `err-lat`
- `mode-ok`
- `mode-tmr`
- `done-tmr`
- `prog-tmr`

### `state`

Current runtime states in the real harness are:

- `0`  = `H_S_IDLE`
- `10` = `H_S_WAIT_OMD6`
- `11` = `H_S_SEND_START`
- `12` = `H_S_WAIT_DONE`
- `13` = `H_S_DONE`
- `15` = `H_S_ERROR`

Meaning:

- `H_S_IDLE`: procedure inactive
- `H_S_WAIT_OMD6`: waiting for homing mode confirmation (`omd == 6`)
- `H_S_SEND_START`: issuing the homing start pulse
- `H_S_WAIT_DONE`: homing active, waiting for completion
- `H_S_DONE`: homing completed successfully
- `H_S_ERROR`: procedure ended in an error condition

### `reason`

Current runtime reason codes in the real harness are:

- `0`  = `H_R_IDLE`
- `10` = `H_R_WAITING_MODE_DISPLAY`
- `11` = `H_R_SENDING_START_PULSE`
- `12` = `H_R_WAITING_DONE`
- `13` = `H_R_DONE`
- `20` = `H_R_ERROR_STATUS_MATCH`
- `21` = `H_R_ERROR_EXEC_DROPPED`
- `22` = `H_R_ERROR_INVALID_STATE`
- `23` = `H_R_ERROR_MODE_TIMEOUT`
- `24` = `H_R_ERROR_DONE_TIMEOUT`
- `25` = `H_R_ERROR_PROGRESS_TIMEOUT`
- `26` = `H_R_ERROR_MODE_LOST`

These reason codes are procedural diagnostics, not vendor drive alarms.

### Procedural error meanings

#### `H_R_ERROR_STATUS_MATCH` (`20`)

The procedure detected a statusword/state combination that means execution cannot continue consistently.

This is a semantic mismatch or invalid runtime condition for the procedure.

#### `H_R_ERROR_EXEC_DROPPED` (`21`)

Procedure execution dropped unexpectedly.

Typical meaning:

- enable disappeared
- gate permission was removed
- execution path was interrupted externally

This is different from a drive fault. It means the procedure lost the conditions required to continue.

#### `H_R_ERROR_INVALID_STATE` (`22`)

Internal guard for impossible or inconsistent procedural state.

This code is useful for catching unexpected transitions or defensive fallback cases in the component logic.

#### `H_R_ERROR_MODE_TIMEOUT` (`23`)

The procedure requested homing mode but mode confirmation did not arrive before timeout.

In the validated harness this corresponds to:

- `om = 6`
- expected `omd = 6`
- timeout reached while waiting in `H_S_WAIT_OMD6`

Validated example:

- `stub.inhibit-mode-ack = TRUE`
- final `ut.state = 15`
- final `ut.reason = 23`

#### `H_R_ERROR_DONE_TIMEOUT` (`24`)

The procedure started and remained active, but homing completion did not arrive before the configured done timeout.

Validated example:

- `stub.inhibit-home-done = TRUE`
- final `ut.state = 15`
- final `ut.reason = 24`

#### `H_R_ERROR_PROGRESS_TIMEOUT` (`25`)

The procedure did not observe enough progress while homing was active, so the progress watchdog expired.

Validated example:

- `stub.freeze-home-progress = TRUE`
- final `ut.state = 15`
- final `ut.reason = 25`

#### `H_R_ERROR_MODE_LOST` (`26`)

Mode confirmation was initially present but was lost while the homing procedure was already active.

Validated example:

- `stub.force-mode-drop = TRUE`
- final `ut.state = 15`
- final `ut.reason = 26`

This is intentionally separate from `MODE_TIMEOUT` because the failure happens after procedure start, not during initial mode acquisition.

### `err` and `err-lat`

- `err` indicates an active procedural error condition
- `err-lat` latches the procedural error for inspection after the transient event

This separation is useful because a short procedural error could otherwise be missed in manual runtime observation.

### `mode-ok`

`mode-ok` indicates whether the expected homing mode confirmation is currently valid.

In the current harness that means confirmation of `omd == 6`.

### Timers

The homing component exposes internal diagnostic timers:

- `mode-tmr`
- `done-tmr`
- `prog-tmr`

Purpose:

- `mode-tmr`: tracks wait time for homing mode confirmation
- `done-tmr`: tracks wait time for final homing completion
- `prog-tmr`: tracks lack of observable progress during the active homing phase

These outputs are extremely useful during bench validation because they show *which watchdog is actually moving toward failure*.

---

## 7. `machine_safety_gate` diagnostics

`machine_safety_gate` is not a drive diagnostic block.  
It is a machine-policy decision block.

It answers questions such as:

- is machine enable allowed?
- is homing allowed?
- is fault reset allowed?

Its outputs should be interpreted as policy decisions, not drive state feedback.

Typical integration use:

- block enable unless machine conditions are valid
- block homing unless the machine is in a legal state
- allow reuse across EtherCAT, Mesa, and simulation backends

---

## 8. Practical interpretation rules

When analyzing a stop or unexpected behavior, interpret layers in this order:

1. **Drive/backend fault layer**  
   Check whether the drive itself reports fault or transport failure.

2. **CiA402 semantic layer**  
   Check whether `cia402_pds` or `cia402_homing` indicates a semantic/procedural problem.

3. **Machine-policy layer**  
   Check whether the machine logic intentionally blocked the action.

This avoids a common debugging mistake: blaming the drive for what is actually a policy block, or blaming policy for what is actually a procedural timeout.

---

## 9. Runtime examples

Examples of correct interpretation:

### Example A

- `pds.state = 0x0027`
- `pds.reason = 4`
- `ut.reason = 23`

Meaning:

The drive is semantically in `Operation Enabled`, but homing failed because homing mode confirmation timed out.

This is **not** a drive hardware fault.

### Example B

- `pds.reason = 13`

Meaning:

The semantic layer sees `Fault Reaction Active`.

This is a fault-class condition at the PDS layer.

### Example C

- machine policy blocks enable
- no drive fault
- no homing procedure active

Meaning:

The system is being intentionally blocked by machine logic, not by CiA402 drive behavior.

---

## 10. Diagnostic philosophy

The project intentionally keeps diagnostics explicit and layered.

That makes the system:

- easier to validate in simulation
- easier to port to real hardware
- easier to debug at runtime
- less ambiguous when multiple subsystems interact

This separation is an important part of the architecture, not just a documentation preference.
