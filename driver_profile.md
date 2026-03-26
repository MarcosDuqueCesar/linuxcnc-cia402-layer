DRIVER PROFILE — CiA402 BACKEND CONTRACT

1. ARCHITECTURAL PRINCIPLE

The backend MUST NOT implement semantics.

The backend is responsible only for:
- receiving commands from the framework
- applying them to the hardware/driver
- returning coherent feedback per cycle

All semantics (homing, CSP, arbitration, watchdogs, invariants)
are implemented in the framework.

The backend is strictly:
→ executor + feedback provider

--------------------------------------------------
2. REQUIRED INTERFACE

Inputs:
- in_controlword (u32)
- in_opmode (s32)
- in_target_position (s32)

Outputs:
- out_statusword (u32)
- out_opmode_display (s32)
- out_actual_position (s32)

--------------------------------------------------
3. STATUSWORD REQUIREMENTS

The backend MUST:
- provide CiA402-consistent statusword
- avoid glitches or random oscillation
- reflect real device state

Minimum required bits:
- ready_to_switch_on
- switched_on
- operation_enabled
- fault

--------------------------------------------------
4. OPMODE DISPLAY

The backend MUST:
- report actual mode (not desired mode)
- converge in finite cycles
- not fake mode confirmation

--------------------------------------------------
5. CONTROLWORD HANDLING

The backend MUST:
- execute controlword transitions per CiA402
- support fault reset when possible
- not reinterpret semantics

--------------------------------------------------
6. POSITION CONTRACT

- target_position → command
- actual_position → feedback

Requirements:
- coherence between cmd and fb
- known scaling
- no artificial masking of error

--------------------------------------------------
7. FAULT BEHAVIOR

The backend MUST:
- report faults via statusword
- allow deterministic reset
- not hide or auto-clear faults

--------------------------------------------------
8. TIMING

The backend MUST:
- respond in finite cycles
- not stall indefinitely

Watchdogs are handled by the framework.

--------------------------------------------------
9. MULTI-AXIS

The backend MUST:
- be instantiable per axis
- not share hidden global state
- not couple axes

--------------------------------------------------
10. NON-NORMATIVE (STUB BEHAVIOR)

Stub implementations MAY include:
- fault injection
- artificial position convergence
- simplified homing logic

These are NOT requirements for real drivers.

--------------------------------------------------
11. PASS / FAIL

PASS:
- respects interface
- coherent signals
- deterministic behavior

FAIL:
- requires semantic changes
- hides errors
- breaks isolation
