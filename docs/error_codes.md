# Error Codes

This document explains how error reporting works in CiA402 drives and how
errors are exposed in the `linuxcnc-cia402-layer` semantic layer.

It focuses on the objects and signals typically used for fault detection and
diagnostics when integrating a CiA402 drive with LinuxCNC.

---

# Fault Detection in CiA402

CiA402 drives report faults through multiple mechanisms:

- Statusword fault bit
- Error code object
- Manufacturer-specific diagnostic objects

The semantic layer interprets these signals and exposes simplified fault
information to LinuxCNC.

---

# Statusword Fault Bit

The primary fault indication in CiA402 is the **Fault bit** in the Statusword
(6041h).

Typical representation:

```text
Statusword (6041h)

Bit 3  Fault
```

When this bit is set, the drive is in the **Fault** state of the PDS state
machine.

Example states related to faults:

```text
Fault Reaction Active
Fault
```

The `cia402_pds` component monitors this bit to detect fault conditions.

---

# Error Code Object (603Fh)

CiA402 defines object:

```text
603Fh  Error Code
```

This object contains a numeric code describing the fault that occurred.

Typical examples include:

```text
Overvoltage
Undervoltage
Overcurrent
Overtemperature
Encoder failure
Communication error
```

The exact meaning of the codes may vary between vendors.

---

# Fault Reset

A drive fault is usually cleared using the **Fault Reset** bit in the
Controlword (6040h).

Typical representation:

```text
Controlword (6040h)

Bit 7  Fault Reset
```

The reset sequence normally follows this pattern:

1. Fault detected
2. Controlword sets Fault Reset bit
3. Drive returns to "Switch On Disabled"
4. Normal startup sequence resumes

The `cia402_pds` component generates the appropriate controlword patterns
for this transition.

---

# Semantic Layer Fault Signals

The semantic layer exposes simplified fault indicators for use in HAL and
LinuxCNC logic.

Typical signals include:

```text
fault
op_enabled
state
reason
```

Example usage:

```text
fault == true  → drive is in fault state
op_enabled     → drive is in Operation Enabled
state          → decoded PDS state
reason         → internal diagnostic reason
```

These signals allow machine logic to respond to faults without decoding the
CiA402 state machine directly.

---

# Diagnostic Strategy

A typical diagnostic workflow may involve:

1. Detecting a fault via Statusword bit
2. Reading object 603Fh for the error code
3. Checking vendor documentation for the code meaning
4. Resetting the fault via Controlword

The semantic layer simplifies steps 1 and 4 while still allowing access to
raw diagnostic information if needed.

---

# Vendor-Specific Diagnostics

Although CiA402 standardizes many objects, vendors often provide additional
diagnostic information through manufacturer-specific objects.

Examples may include:

- extended error codes
- warning flags
- internal drive state information

When integrating a specific drive, consult the vendor documentation for
these objects.

---

# Summary

CiA402 fault handling is based on:

- Statusword fault indication
- Error code object (603Fh)
- Controlword fault reset

The `linuxcnc-cia402-layer` semantic layer interprets these signals and
provides simplified fault information to LinuxCNC and HAL components.

This approach allows consistent fault handling across different CiA402
drives and transport layers.
