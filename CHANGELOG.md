# Changelog

All notable changes to this project will be documented in this file.

---

## V0.9.9 — Documentation Alignment & Diagnostics Guide

### Added
- Practical diagnostics guide (`docs/diag_doc.md`) with usage, interpretation, and real-world mapping
- Real-world mapping section linking watchdog patterns to common field issues

### Changed
- Quick start updated to simulation-first (no profile/topology required to run examples)
- User guide aligned with runtime behavior and CLI being optional
- Observability documentation aligned with actual `diag.sh` output (no mux explicit claims)
- Architecture documentation updated to reflect current runtime components and adapter
- Driver profile documentation clarified as declarative contract (not literal HAL mapping)
- Backend contract naming made explicit in docs (adapter_{axis}.*)

### Notes
- No changes to runtime semantics or HAL behavior
- Focus on removing ambiguity and improving onboarding for third-party users
- Profiles remain declarative; runtime validation recommended via `halcmd` and `diag.sh`

---

## V0.9.9.3 — Repository Cleanup & Structure Finalization

### Added
- Standardized HAL binding scaffolds (single-axis and multi-axis)
- Adapter contract fully aligned across all drivers
- Structured HAL directories:
  - hal/core
  - hal/topology
  - hal/examples
  - hal/adapters
  - hal/legacy
- Driver profile documentation and validation assets
- Fault injection and validation scripts (organized under scripts/)
- Observability tooling (`diag.sh`, monitoring and snapshot utilities)

### Changed
- Complete repository cleanup (removed runtime artifacts, logs, zips, backups)
- Reorganized project structure to reflect framework architecture
- Standardized naming and structure of binding files
- Unified script layout and removed experimental runtime artifacts
- Updated `.gitignore` to enforce clean repository policy
- Refactored HAL layout to clearly separate:
  - core semantics
  - topology
  - examples
  - adapter layer

### Removed
- Legacy test harness files from root HAL directory
- Runtime-generated validation outputs and logs
- Temporary and experimental debug files
- Backup and snapshot files (`.bak`, `.bkp`, etc)
- Binary artifacts (`.so`)

### Experimental
- Initial gantry topology introduced as experimental
- Not validated with real hardware
- Intended for community testing and feedback
- No guarantees on synchronization, stability, or edge-case handling

### Notes
- This version represents a stable, distributable framework state
- Backend remains simulated; real hardware validation is pending
- Binding layer is prepared for third-party EtherCAT (lcec) integration
- No changes to:
  - CiA402 semantics
  - mux arbitration (HOME > CSP)
  - watchdog behavior
- Framework validated in simulated environment for:
  - single-axis
  - multi-axis XY
  - multi-axis XYZ

---

## V0.9.9.2 — Binding Scaffold Introduction

### Added
- Initial HAL binding scaffold for real backend integration
- Leadshine EL8 pilot binding structure
- Adapter interface defined as binding contract boundary

### Notes
- Binding remains unconnected to real hardware
- Backend still simulated
- Transition phase toward real hardware integration started

---

## V0.9.9.1 — Driver Profile Formalization

### Added
- Driver profile schema finalized
- Profile validation scripts introduced
- Initial set of driver profiles defined

### Notes
- Profiles serve as source of truth for binding generation
- No direct HAL binding from profiles yet

---

## V0.9.9.0 — Framework Stabilization

### Added
- Complete CiA402 semantic layer
- mux arbitration (HOME > CSP)
- Motion and homing supervision
- Observability baseline
- Multi-axis support (XY, XYZ)

### Notes
- All core semantics validated in runtime (simulated backend)
- Framework considered stable at semantic level

---

## Previous Versions (0.9.8.x)

### Highlights
- Initial modular CiA402 implementation
- Introduction of CSP motion component
- Homing integration and supervision
- Fault injection framework
- Runtime validation harness
- Iterative stabilization of mux and controlword composition

---
