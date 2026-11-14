# Wide16 development record — 2026-11-07

## What changed

- Added a separate 16-bit core profile while retaining the 8-bit design as its own profile.
- Added independent Main and Guard programs, separate register files and 16-word private RAMs, a result-agreement supervisor, instruction SECDED checks, progress watchdogs, and a Tang Nano button/LED wrapper.
- Added a complete step-driven RTL ISA bench. It covers each implemented opcode, taken and untaken branches (including a nonzero high byte), 16-bit wraparound, RAM, HALT, reserved encodings, and reset.
- Extended `build/build.ps1` to run the 16-bit unit, core, ISA, dual-core, and board-wrapper benches and to synthesize the separate wide16 top. Its PnR report is written separately from the existing 8-bit report.

## Verification

- 5 wide16 Python unit tests passed.
- Main and Guard software models both halted with result `0x00C0`; Main retired 10 instructions and Guard retired 7. Main wrote and reloaded `0x00C0` from private RAM.
- Icarus benches passed for the 16-bit core, all ISA operations, dual-core comparison/private RAM/watchdog/ROM SECDED, and the Tang Nano wrapper's activity/reset/stall-fault LED logic.
- Gowin V1.9.12.02_SP2 completed synthesis, placement, routing, and bitstream generation for GW2AR-LV18QN88C8/I7. Resource use: 569/20,736 logic units (2.74%), 273 logic flip-flops, 8 RAM16 blocks, and 9 I/O pins. Setup slack was +27.213 ns and hold slack +0.425 ns in the reported paths.
- PnR mapped S1 to PIN88, S2 to PIN87, and the six active-low LEDs to PIN15–20. It still reports PR1014 on the PIN04 clock route, so this is not a timing-closure claim.

## Board programming record

- Staged image: `build/tangnano20k_wide16_demo.fs`
- SHA-256: `C9555F8914B3C7456538AB72290FA24127ACD3FE8A3FF6C9B7D47E5F8C2B5913`
- Gowin operation 4 (SRAM Program and Verify) printed `Error: Verify failed of at 0`; it is not counted as a successful verification.
- Gowin operation 2 (SRAM Program) then completed with exit code 0. A later user-code read returned `0x000095CA`, matching the `.fs` header, and status read returned `0x00006020`.
- No external flash operation was used. The device's reported user code confirms the image identity, but does not prove a complete bit-for-bit readback. LED behavior cannot be visually confirmed from the programming interface; expected normal behavior is LED0 and LED1 on after both cores start, with all six LEDs on after S2 injects a Main stall and the watchdog trips.

## Limits

This is an educational integer-arithmetic and fault-display bench prototype. Its synthetic `0x00C0` value is not a position estimate. It has no GPS, camera, navigation, actuator, or flight-control interface, and it is not an aircraft safety system.
