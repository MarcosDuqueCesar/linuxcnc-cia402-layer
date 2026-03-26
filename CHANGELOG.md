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

### Changed
- Complete repository cleanup (removed runtime artifacts, logs, zips, backups)
- Reorganized project structure to reflect framework architecture
- Standardized naming and structure of binding files
- Unified script layout and removed experimental runtime files
- Updated .gitignore to enforce clean repository policy

### Removed
- Legacy test harness files from root HAL directory
- Runtime-generated files and validation artifacts
- Temporary and experimental debug outputs
- Backup and snapshot files (.bak, .bkp, etc)

### Notes
- This version represents a stable, distributable framework state
- Backend remains simulated; real hardware validation is pending
- Binding layer prepared for third-party EtherCAT integration
- No changes to CiA402 semantics, mux arbitration, or watchdog logic
