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
- critical decisions are visible
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

- current state (raw/derived)
- observable state transitions

Note:

High-level semantic reasoning is inferred from signals, not explicitly printed.

---

### Controlword / Statusword

- controlword (6040h)
- statusword (6041h)

Allows verification of:

- correct state machine transitions
- expected bit patterns

---

### Mode of Operation (partial visibility)

Mode-related behavior can be inferred from:

- controlword transitions
- motion behavior

Note:

Explicit mode signals are not fully expanded in diag.sh output.

---

### Arbitration (implicit)

Arbitration effects can be inferred indirectly from:

- controlword behavior
- motion activity
- homing vs CSP transitions

Rule:

```
HOME > CSP
```

Note:

Mux internals are not explicitly exposed by diag.sh.

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
- controlword follows PDS logic
- watchdogs remain inactive during normal operation

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
- controlword / statusword evolution
- watchdog signals

---

## Fault Diagnosis

The framework helps distinguish:

### Framework Issue

- inconsistent signals
- invalid transitions
- incorrect arbitration behavior (inferred)

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

All critical runtime signals are observable.

---

## Summary

Observability provides:

- visibility of runtime behavior
- clear fault diagnosis
- separation between logic and hardware issues

It is one of the main strengths of the framework.
