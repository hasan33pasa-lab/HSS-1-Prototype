# Separate 16-bit datapath profile

## Purpose

The existing board image remains the stable 8-bit baseline. This profile starts a separate 16-bit integer datapath so the project can measure a wider core without changing the currently loaded demonstrator.

## Architecture

- 16-bit registers, ALU, result, and private RAM words; four registers and 16 private RAM words per core.
- 8-bit program counter and 16-bit fixed-width instructions. This keeps the current ROM's 16-bit instruction format and 6-bit SECDED check field.
- `LDI` loads an unsigned low byte and clears the high byte. `LDIH` replaces the high byte while preserving the low byte. A full 16-bit constant is formed with those two instructions.
- Register arithmetic wraps modulo 65,536. Immediate operations use an unsigned 8-bit immediate. `JZ` tests all 16 register bits.
- `F000` remains `HALT`. The extended `F` opcode with subfield `01` is `LDIH`; other reserved `F` encodings stop safely.
- The Main and Guard example programs independently compute the synthetic delta `0x12F4 - 0x1234 = 0x00C0`. Main also stores and reloads its result from private RAM.

## Current files

- RTL datapath: `rtl/wide_tiny_core.v`
- Assembler and software model: `tools/assembler16.py`, `tools/isa16_simulator.py`
- Synthetic programs: `programs/wide16_main.asm`, `programs/wide16_guard.asm`
- Generated ROM: `rtl/wide16_program_rom.v`
- Two-core lab supervisor: `rtl/dual_core_wide16_lab_top.v`
- Separate Tang Nano wrapper: `rtl/tangnano20k_wide16_lab_top.v`

## Bench status

- Main and Guard use separate programs, register files, and private RAMs.
- The example programs compute the same synthetic 16-bit delta. A mismatch, a stalled core, or a bad SECDED instruction check latches the lab supervisor fault.
- The separate board wrapper uses S1 to reset and S2 to stall Main for a watchdog demonstration. LED0 and LED1 show that each core has made progress; all six LEDs show a supervisor fault.
- Icarus simulations cover the core, two-core comparison, watchdog and instruction-integrity faults, button filtering, reset, and LED indications.
- An ISA conformance bench steps every implemented instruction encoding, checks taken and untaken branches (including a nonzero high byte), 16-bit wraparound, private RAM, HALT, reserved encodings, and reset.
- This is a small educational integer core and bench demonstration. It has no sensor interfaces, memory protection, operating system, flight-control interface, or safety certification. The LED and fault tests are not evidence that an aircraft can be controlled safely.

This profile is separate from the 8-bit default top. Synthesis and volatile SRAM programming are tracked independently; external flash is not part of the workflow.

The current image was staged at `build/tangnano20k_wide16_demo.fs` and sent through the SRAM Program operation. The device-reported user code (`0x000095CA`) matches the bitstream header. Gowin's SRAM Program and Verify operation reported `Verify failed at 0`, so full readback has not been confirmed; this image's physical LED response also has not been observed by the operator in this work session. See `reports/wide16-development-2026-11-07.md` for the exact record.
