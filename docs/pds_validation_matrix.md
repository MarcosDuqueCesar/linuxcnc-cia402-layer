# CiA402 PDS Validation Matrix

This document describes the validation scenarios executed for the CiA402
Power Drive System (PDS) state machine implemented in the `cia402_pds`
component.

The objective is to verify that the component correctly interprets the
Statusword (6041) and generates the appropriate Controlword (6040)
commands according to the CiA402 state machine.

The validation was executed using the deterministic simulation harness
based on `cia402_stub`.

------------------------------------------------------------------------

# Tested States

The following CiA402 states were validated during runtime testing.

  -----------------------------------------------------------------------
  State       Description              Expected Behavior
  ----------- ------------------------ ----------------------------------
  Ready To    Drive ready but not      PDS prepares transition to
  Switch On   energized                Switched On

  Switched On Drive energized but      Await enable request
              motion not enabled       

  Operation   Drive fully operational  Motion allowed
  Enabled                              

  Quick Stop  Quick stop triggered     Drive decelerates and disables
  Active                               motion

  Fault       Drive executing fault    Await transition to Fault
  Reaction    reaction                 
  Active                               

  Fault       Drive fault state        Requires fault reset

  Fault Reset Reset command issued     Transition back to Ready To Switch
  Requested                            On
  -----------------------------------------------------------------------

------------------------------------------------------------------------

# Validation Procedure

Each state transition was verified by forcing the appropriate Statusword
pattern using the `cia402_stub` component.

The following aspects were validated:

-   correct state decoding
-   correct controlword generation
-   correct fault detection
-   correct transition sequencing
-   absence of illegal transitions

------------------------------------------------------------------------

# Statusword Masks Used

The PDS component exposes two internal masked statusword patterns used
for state decoding.

  Mask            Purpose
  --------------- -----------------------------------
  `sw & 0x006F`   Standard CiA402 state mask
  `sw & 0x004F`   Switch On Disabled exception mask

These masks are exposed via debug pins to allow runtime verification.

------------------------------------------------------------------------

# Verified Transition Paths

The following transition paths were validated:

Fault → Fault Reset Requested → Ready To Switch On → Switched On →
Operation Enabled

Operation Enabled → Quick Stop Active → Switched On

Fault Reaction Active → Fault

------------------------------------------------------------------------

# Negative Scenario Validation

The following abnormal situations were also tested:

  Scenario                                Expected Result
  --------------------------------------- ---------------------
  invalid statusword pattern              state decode error
  fault during operation                  transition to Fault
  fault reset issued in non-fault state   ignored

------------------------------------------------------------------------

# Deterministic Test Harness

All tests were executed using the HAL simulation harness composed of:

machine_safety_gate\
cia402_pds\
cia402_homing\
cia402_cw_compose\
cia402_stub

The `cia402_stub` component allows deterministic forcing of Statusword
patterns to simulate drive behavior without requiring real hardware.

------------------------------------------------------------------------

# Validation Result

All tested state transitions behaved according to the CiA402 state
machine specification.

No race conditions or ambiguous controlword generation were observed.

The architecture maintains the critical design property of a **single
writer of the final controlword**, implemented by `cia402_cw_compose`.

------------------------------------------------------------------------

# Conclusion

The `cia402_pds` component correctly implements the CiA402 Power Drive
System state machine semantics and behaves deterministically under the
tested scenarios.

This validation confirms that the semantic layer is suitable for
integration with real CiA402 drives through the drive adapter layer.
