
# Gantry Validation Matrix

This document records the runtime validation of the `gantry_manager` component
introduced in V12 of the linuxcnc-cia402-layer project.

The objective of this validation is to verify the correct supervisory behavior
of the gantry layer controlling two drives attached to a single mechanical axis.

The validation was performed using a deterministic HAL harness:

hal/stub_test_gantry.hal

---

# Test Environment

Component under test:

gantry_manager.comp

Execution environment:

HAL realtime simulation using `halrun`.

Architecture context:

LinuxCNC motion
↓
machine_safety_gate
↓
gantry_manager
↓
cia402 semantic layer
↓
drive adapter
↓
backend
↓
drive

---

# Scenario A — Coupled Mode

Configuration:

couple_enable = TRUE

Inputs:

axis_cmd_pos = 100
axis_feedback_x1 = 100
axis_feedback_x2 = 100

Expected behavior:

cmd_x1 = axis_cmd_pos
cmd_x2 = axis_cmd_pos
gantry_ok = TRUE
gantry_fault = FALSE
skew_error = 0

Observed result:

cmd_x1 = 100
cmd_x2 = 100
gantry_ok = TRUE
gantry_fault = FALSE
skew_error = 0

Result:

PASS

---

# Scenario B — Decoupled Mode

Configuration:

couple_enable = FALSE

Inputs:

axis_feedback_x1 = 10
axis_feedback_x2 = 20

decoupled_cmd_x1 = 11
decoupled_cmd_x2 = 19

Expected behavior:

Each side receives its independent command.

cmd_x1 = decoupled_cmd_x1
cmd_x2 = decoupled_cmd_x2

Observed result:

cmd_x1 = 11
cmd_x2 = 19
gantry_ok = TRUE
gantry_fault = FALSE

Result:

PASS

---

# Scenario C — Skew Fault Detection

Configuration:

couple_enable = TRUE
skew_limit = 5

Inputs:

axis_feedback_x1 = 0
axis_feedback_x2 = 20

Computed skew:

skew_error = 20

Expected behavior:

gantry_fault = TRUE
gantry_ok = FALSE
coupled mode disabled
outputs switch to safe mode

Observed result:

gantry_fault = TRUE
gantry_ok = FALSE
coupled_active = FALSE
cmd_x1 = axis_feedback_x1
cmd_x2 = axis_feedback_x2

Result:

PASS

---

# Scenario D — Automatic Recovery (Non‑Latched Fault)

Configuration:

latch_fault = FALSE

Procedure:

1. Trigger skew fault
2. Remove skew condition

Expected behavior:

Supervisor automatically returns to normal operation.

Observed result:

gantry_fault cleared
gantry_ok = TRUE
coupled_active = TRUE

Result:

PASS

---

# Scenario E — Latched Fault

Configuration:

latch_fault = TRUE

Procedure:

1. Trigger skew fault
2. Remove skew condition

Expected behavior:

Fault remains active until reset command is issued.

Observed result:

gantry_fault remains TRUE
gantry_ok remains FALSE

Result:

PASS

---

# Scenario F — Latched Fault Reset

Configuration:

latch_fault = TRUE

Procedure:

1. Trigger skew fault
2. Remove skew condition
3. Issue reset_fault = TRUE

Expected behavior:

Fault cleared and supervisor returns to normal operation.

Observed result:

gantry_fault = FALSE
gantry_ok = TRUE
coupled_active = TRUE

Result:

PASS

---

# Conclusion

The `gantry_manager` component behaves as a structural supervisor for a
dual‑drive gantry axis.

The following properties were verified in runtime:

• correct command replication in coupled mode
• independent command control in decoupled mode
• reliable skew detection
• structural protection behavior during skew fault
• automatic recovery when faults are not latched
• correct latched fault behavior
• deterministic reset of latched faults

The component is considered **validated for the V12 architecture stage**
and ready for further integration with the CiA402 drive layer and machine
control policy.
