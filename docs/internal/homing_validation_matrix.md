
# CiA402 Homing Validation Matrix

Project: `linuxcnc-cia402-layer`

This document formalizes the runtime validation of the `cia402_homing` procedural component
using the HAL simulation harness present in the project.

The validation environment allows deterministic testing of homing behavior without real
hardware by using the `cia402_stub` component.

The goal of this matrix is to verify:

- correct homing procedure sequencing
- correct mode confirmation behavior
- correct timeout handling
- correct diagnostic reason codes
- correct interaction with machine policy and PDS state

Validated harness components:

machine_safety_gate  
cia402_pds  
cia402_homing  
cia402_cw_compose  
cia402_stub

Main HAL harness used:

`hal/stub_test_modular_pds.hal`

--------------------------------------------------

# 1. Execution Preconditions

Working directory:

cd <your-linuxcnc-workspace>

LinuxCNC must be running with the servo thread active.

Base system condition before tests:

- drive in Operation Enabled
- PDS nominal
- no active faults
- homing request cleared

Expected nominal state:

pds.state  = 39  
pds.reason = 4  
statusword = 0x0237

Meaning:

DS402 state: Operation Enabled

--------------------------------------------------

# 2. Homing Mode Behavior

In the current harness configuration:

Requested mode:

om = 6

Expected mode display confirmation:

omd = 6

Internal waiting state:

H_S_WAIT_OMD6

This behavior matches the implementation inside `cia402_homing.comp`.

--------------------------------------------------

# 3. Homing Validation Cases

## 3.1 Nominal Homing

Condition

Normal homing request with valid machine policy.

Sequence

1. homing request issued
2. machine policy allows homing
3. gate releases ut.enable
4. homing procedure starts
5. mode confirmed
6. homing completes
7. ut transitions to DONE

Expected final state

ut.state  = 13  
ut.reason = 13

Meaning

H_S_DONE  
H_R_DONE

Result

PASS

--------------------------------------------------

## 3.2 DONE_TIMEOUT

Test condition

stub.inhibit-home-done = TRUE

Effect

The stub keeps producing motion activity but never asserts the homing completion signal.

Observed behavior

- procedure enters WAIT_DONE
- done signal never arrives
- progress watchdog does not fire
- done timeout expires

Observed final state

ut.state    = 15  
ut.reason   = 24  
ut.err-lat  = TRUE  
ut.done-tmr = 120000  
ut.prog-tmr = 1

Meaning

H_S_ERROR  
H_R_ERROR_DONE_TIMEOUT

Result

PASS

--------------------------------------------------

## 3.3 PROGRESS_TIMEOUT

Test condition

stub.freeze-home-progress = TRUE

Effect

The stub stops updating the observable position while homing is active.

Observed behavior

- homing procedure starts
- no observable motion progress
- progress watchdog expires before done timeout

Observed final state

ut.state    = 15  
ut.reason   = 25  
ut.err-lat  = TRUE  
ut.prog-tmr = 10000  
ut.done-tmr = 9999

Meaning

H_S_ERROR  
H_R_ERROR_PROGRESS_TIMEOUT

Result

PASS

--------------------------------------------------

## 3.4 MODE_LOST

Test condition

stub.force-mode-drop = TRUE

Effect

The drive mode confirmation is lost while homing is active.

Observed behavior

- homing starts normally
- mode confirmation disappears
- procedure detects mode loss
- procedure terminates with explicit error

Observed final state

ut.state   = 15  
ut.reason  = 26  
ut.err-lat = TRUE  
ut.mode-ok = FALSE

Meaning

H_S_ERROR  
H_R_ERROR_MODE_LOST

Result

PASS

Note

A later static observation of the stub may show `omd` normalized again because the stub
logic only forces the drop during homing activity.

--------------------------------------------------

## 3.5 MODE_TIMEOUT

Test condition

stub.inhibit-mode-ack = TRUE

Effect

The drive never confirms the requested mode change.

Observed behavior

- homing request issued
- procedure waits in H_S_WAIT_OMD6
- om changes to 6
- omd remains 8
- mode timeout expires

Observed final state

ut.state    = 15  
ut.reason   = 23  
ut.err-lat  = TRUE  
ut.mode-ok  = FALSE  
ut.mode-tmr = 2000  
ut.om       = 6  
ut.omd      = 8

Meaning

H_S_ERROR  
H_R_ERROR_MODE_TIMEOUT

Result

PASS

--------------------------------------------------

# 4. Neutral Post-Test State

After clearing the harness and removing test injections, the system returns to a neutral state:

ut.enable   = FALSE  
ut.home     = FALSE  
ut.homing   = FALSE  
ut.err-lat  = FALSE  
ut.state    = 0  
ut.reason   = 0  
ut.mode-tmr = 0  
ut.done-tmr = 0  
ut.prog-tmr = 0  
ut.om       = 8  
ut.omd      = 8  
ut.sw       = 0x0237

Meaning

H_S_IDLE  
H_R_IDLE

The harness is ready for the next validation cycle.

--------------------------------------------------

# 5. Validation Summary

The HAL simulation harness is capable of validating the following homing behaviors:

Nominal homing completion  
Completion timeout detection  
Motion progress watchdog detection  
Mode loss detection  
Mode confirmation timeout detection

These results confirm that the `cia402_homing` component correctly handles both
nominal operation and multiple failure modes without requiring real hardware.

