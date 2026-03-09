# Drive Integration

This document explains how the CiA402 semantic layer connects to real hardware
backends while keeping the core architecture vendor-agnostic.

The project intentionally separates three concerns:

1. machine policy
2. CiA402 semantic interpretation
3. hardware / transport integration

Only the adapter layer interacts with real drives or transport-specific objects.

---

## Architectural Position

Complete control pipeline:

LinuxCNC motion  
→ machine_safety_gate  
→ cia402_pds  
→ cia402_homing  
→ cia402_cw_compose  
→ cia402_drive_adapter  
→ transport backend  
→ drive

The semantic layer never talks directly to EtherCAT, Mesa, or any specific bus.

This is a core architectural rule of the project.

---

## Why the adapter exists

The adapter is the boundary between:

- transport-independent CiA402 HAL semantics
- transport-specific process data or register mapping

Its purpose is to translate signal names and object mapping, not to reinterpret
the protocol.

The adapter should remain thin.

It should not own:

- DS402 state decoding
- machine policy decisions
- homing procedure logic
- controlword arbitration policy

Those responsibilities already belong to other layers.

---

## Responsibility split

### `machine_safety_gate`

Responsible for machine policy.

Examples:

- enable allowed or blocked
- homing allowed or blocked
- reset allowed or blocked

### `cia402_pds`

Responsible for DS402 semantic interpretation of the Power Drive System.

Examples:

- decode of `6041h`
- semantic state output
- semantic reason output
- base PDS controlword intent

### `cia402_homing`

Responsible for procedural homing behavior.

Examples:

- mode request for homing
- start pulse generation
- done / timeout / progress supervision
- procedural diagnostics

### `cia402_cw_compose`

Responsible for final controlword ownership.

This is the single writer of the final controlword.

This is a critical architectural property because it prevents multiple competing
writers from directly driving the same `6040h` path.

### `cia402_drive_adapter`

Responsible for integration with the chosen backend.

Examples:

- map HAL controlword to EtherCAT PDO, Mesa register, or simulated endpoint
- map backend statusword back to the semantic layer
- move mode command / mode display signals across the boundary

The adapter does **not** decide what the state means.

---

## Minimal CiA402 boundary

The semantic layer requires only the stable CiA402 command/feedback boundary.

### Commands sent toward the drive

| Object | Description |
|------|-------------|
| `6040h` | Controlword |
| `6060h` | Mode of operation |

### Feedback returned from the drive

| Object | Description |
|------|-------------|
| `6041h` | Statusword |
| `6061h` | Mode display |

These objects form the minimum stable boundary between the semantic layer and
the backend.

Additional vendor objects may exist, but they should not be allowed to blur the
core semantic boundary.

---

## HAL signal mapping

Semantic layer → adapter:

- `cw_final` → drive controlword
- `mode_cmd` → drive mode of operation command

Adapter → semantic layer:

- drive statusword → `sw`
- drive mode display → `mode_disp`

The naming on the backend side may vary by transport, but the semantic meaning
must remain stable.

No extra DS402 interpretation should be inserted in the adapter.

---

## Controlword ownership rule

The adapter must consume the already-arbitrated final controlword.

That means:

- `cia402_pds` generates PDS intent
- `cia402_homing` generates procedural intent
- `cia402_cw_compose` merges intents and owns `cw_final`
- the adapter forwards `cw_final` to the backend

This is important.

The adapter must **not** independently modify the controlword policy, because
that would recreate exactly the kind of ambiguity and race condition that the
architecture is designed to avoid.

---

## Example backends

### EtherCAT

Typical mapping idea:

- controlword → PDO carrying `6040h`
- statusword  ← PDO carrying `6041h`
- mode_cmd    → PDO carrying `6060h`
- mode_disp   ← PDO carrying `6061h`

The exact object mapping depends on the drive and the EtherCAT XML/device
description, but the semantic boundary remains the same.

### Mesa

The same semantic interface can be mapped to Mesa-side registers, FPGA logic,
or other implementation-specific endpoints.

The important point is that Mesa is still only a backend path here.

Machine policy and CiA402 semantics must remain outside the adapter.

### Simulation / Stub

In the current validation harness, the adapter can map directly to the stub or
to the simulated HAL path.

This allows:

- semantic validation without real hardware
- deterministic negative-case testing
- reproducible runtime observation of DS402 and procedural behavior

---

## Multi-axis systems

For multi-axis systems, the semantic rule remains:

- one semantic pipeline instance per axis

That means, per axis:

- one `cia402_pds`
- one procedural layer instance when needed
- one `cia402_cw_compose`
- one adapter mapping path

The backend may expose:

- separate slaves
- multiple axes inside one node
- offset object ranges

The adapter handles these transport details.

The semantic layer should not need to care whether the backend uses:

- one node per axis
- multiple axes in one node
- a simulated path
- Mesa endpoint mapping

---

## Multi-axis scheduling rule

When multiple axes exist, grouping in the servo thread should be done by logical
stage, not by axis.

Conceptually:

- all machine-policy blocks
- all PDS blocks
- all procedural blocks
- all controlword compose blocks
- all adapters
- backend

This preserves deterministic layer ordering and avoids cross-axis ambiguity.

---

## Error handling boundary

The adapter is not the owner of semantic faults.

### Adapter/backend class issues

Typical examples:

- communication loss
- backend not ready
- transport watchdog event
- missing PDO update
- register access failure

These should be surfaced as backend or transport conditions.

### Semantic-layer issues

Typical examples:

- DS402 fault semantic state
- mode timeout
- mode lost during homing
- done timeout
- progress timeout

These belong to the semantic layer, not to the adapter.

### Machine-policy issues

Typical examples:

- machine not enabled
- homing not allowed
- reset blocked by policy

These belong to `machine_safety_gate`.

Keeping these layers separate is essential for debug clarity.

---

## Practical interpretation

When something fails, read the system in this order:

1. backend / transport condition  
2. DS402 semantic state (`cia402_pds`)  
3. procedural state (`cia402_homing` or future procedures)  
4. machine policy result

That ordering helps avoid common integration mistakes such as blaming the
transport for what is actually a procedural timeout, or blaming the drive for
what is actually a policy block.

---

## What the current V11 harness proves

The current validation harness already proves an important architectural point:

- the semantic layer can be validated without hardware
- the procedural layer can be forced into multiple negative cases deterministically
- controlword ownership can remain centralized
- backend integration can stay thin

This is one of the strongest properties of the project, because it prepares the
same architecture for future transition from simulation to real adapter paths.

---

## Summary

The adapter layer exists to connect a stable semantic CiA402 HAL interface to a
specific transport or backend.

It must remain thin and transport-specific.

It must not absorb responsibilities that belong to:

- machine policy
- DS402 semantic interpretation
- procedural logic
- final controlword arbitration

In this architecture:

- LinuxCNC remains the motion authority
- `machine_safety_gate` remains the machine-policy authority
- `cia402_pds` remains the DS402 semantic authority
- `cia402_homing` remains the homing procedural authority
- `cia402_cw_compose` remains the single writer of the final controlword
- `cia402_drive_adapter` remains the backend integration boundary

That separation is what makes the project portable, testable, and resistant to
integration ambiguity.
