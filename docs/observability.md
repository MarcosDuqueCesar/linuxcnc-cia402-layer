# Observability

This document explains how to observe and diagnose the internal state of the framework during runtime.

Observability is a core feature of the framework.

It allows you to understand:

- what the system is doing
- why it is doing it
- where a problem is coming from

---

## Core Concept

The framework exposes internal state through HAL signals.

This means:

- no black box behavior
- all decisions are visible
- faults are explicit

---

## Primary Tool

Use:

```
scripts/diag.sh
```

This is the main diagnostic interface.

---

## What diag.sh Shows

The diagnostic output includes:

### CiA402 State (PDS)

- current state
- state transitions
- semantic reason

---

### Controlword / Statusword

- controlword (6040h)
- statusword (6041h)

Allows verification of:

- correct state machine transitions
- expected bit patterns

---

### Mode of Operation

- commanded mode
- displayed mode

Ensures:

- CSP active when expected
- homing mode active when requested

---

### Mux (Arbitration)

Shows which semantic path owns the axis:

- CSP
- HOME

Rule:

```
HOME > CSP
```

---

### Watchdogs

The framework includes watchdogs for:

- motion
- homing

They detect:

- tracking errors
- stalls
- response timeouts

---

## Expected Behavior

In a healthy system:

- no unexpected faults
- stable state transitions
- correct mux ownership
- controlword follows PDS logic

---

## Using Observability

Typical workflow:

1. Run system:

```
linuxcnc <your_ini>
```

2. Open diagnostics:

```
scripts/diag.sh
```

3. Observe:

- state changes
- ownership transitions
- fault signals

---

## Fault Diagnosis

The framework helps distinguish:

### Framework Issue

- inconsistent signals
- invalid transitions
- incorrect arbitration

---

### Configuration Issue

- missing HAL links
- wrong scaling
- incorrect INI setup

---

### Hardware / Backend Issue

- unstable feedback
- EtherCAT errors
- jitter / timing problems

---

## Fault Injection

The framework includes fault injection tools.

Location:

```
scripts/faultinj/
```

These allow testing:

- tracking faults
- stall conditions
- response timeouts

This is useful for:

- validation
- stress testing
- debugging edge cases

---

## Key Advantage

Unlike traditional setups:

- no hidden logic
- no silent failures

Everything is observable.

---

## Summary

Observability provides:

- full visibility of runtime behavior
- clear fault diagnosis
- separation between logic and hardware issues

It is one of the main strengths of the framework.
