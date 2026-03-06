# linuxcnc-cia402-layer

Transport-agnostic and drive-agnostic CiA402 semantic layer for LinuxCNC.

This project implements a modular semantic layer between LinuxCNC motion and
CiA402 drives. The design separates machine policy, CiA402 protocol semantics,
and transport/hardware mapping so the same core logic can be reused with:

- EtherCAT
- simulation stubs
- future Mesa-based mappings

The goal is **not** to replace LinuxCNC motion.

The goal is to provide a clean, deterministic intermediate layer that translates
LinuxCNC motion intent into CiA402 semantics.

---

# Architectural direction

The intended architecture is:

LinuxCNC motion  
↓  
machine_safety_gate  
↓  
CiA402 semantic layer  
↓  
transport / adapter layer  
↓  
drive / fieldbus  

Where:

machine_safety_gate  
Machine-level policy layer handling machine enable, estop policy and motion permission.

CiA402 semantic layer  
Implements CiA402 protocol semantics independent of transport.

Adapter layer  
Maps semantic signals to specific transports such as EtherCAT,
simulation stubs or future Mesa integrations.

---

# Current implemented components

The project currently contains four core components.

## cia402_pds.comp

CiA402 Power Drive System state manager.

Responsibilities:

- decode 6041 statusword
- generate base 6040 controlword
- detect fault state
- manage fault reset
- expose Operation Enabled gate

The decode logic intentionally uses both:

sw & 0x006F  
sw & 0x004F  

This handles the common case where some drives or stubs keep the Quick Stop
bit asserted while still being in Switch On Disabled.

Outputs include:

- cw_pds
- op_enabled
- state
- debug decode values

---

## cia402_homing.comp

Homing procedure supervisor.

Responsibilities:

- request homing opmode
- wait for opmode display confirmation
- emit homing start pulse (bit 4)
- monitor homing completion
- latch done/error conditions

Important design rule:

This module **does not own the controlword**.  
It only requests the homing start bit.

---

## cia402_cw_compose.comp

Controlword ownership module.

Purpose:

Guarantee deterministic and explicit controlword ownership.

Composition rule:

cw_final = cw_pds | start4

Where:

cw_pds → base state machine control  
start4 → homing start request

This avoids multiple writers to 6040.

---

## cia402_stub.comp

CiA402 simulated drive.

Used for validation in LinuxCNC AXIS SIM without EtherCAT hardware.

Capabilities:

- PDS state simulation
- opmode display delay simulation
- homing completion simulation
- fault injection
- fault reset timing

This allows the CiA402 semantic layer to be validated before testing
with real drives.

---

# Deterministic execution model

All components currently run in the same LinuxCNC servo thread.

Test configuration:

servo-thread: 1 kHz

Execution order:

cia402_pds  
→ cia402_homing  
→ cia402_cw_compose  
→ cia402_stub  

LinuxCNC HAL executes functions sequentially according to `addf` order.

Because:

- all modules run in the same thread
- execution order is explicit
- only one module writes the final controlword

there is **no possibility of race conditions** between these modules.

The architecture is modular but remains deterministic.

---

# Validation status

Validated in LinuxCNC AXIS SIM:

- deterministic controlword ownership
- robust PDS decode
- opmode handshake
- homing supervision
- fault injection
- fault reset behavior
- homing gated by Operation Enabled

All components run in a **1 kHz servo thread**.

---

# Repository layout

Current working layout:

comp/
    cia402_pds.comp
    cia402_homing.comp
    cia402_cw_compose.comp
    cia402_stub.comp

hal/
    stub_test.hal
    stub_test_modular.hal
    stub_test_modular_pds.hal

archive/
    experimental variants

runtime/
    local runtime artifacts (ignored by git)

---

# Planned next modules

machine_safety_gate.comp  
Machine-level safety and policy gate.

cia402_coupler.comp  
Handles drive-internal motion and command/feedback decoupling.

gantry_delta_monitor.comp  
Future gantry synchronization monitoring.

---

# License

MIT License
