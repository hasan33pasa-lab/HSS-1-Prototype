# HSS-1 Prototype

**A student-led 16-bit, two-core FPGA processor prototype, documented one test at a time.**

HSS-1 is an educational laboratory project built around a Sipeed Tang Nano 20K FPGA. This review snapshot contains a small 16-bit datapath, two independently executing cores, private RAMs, a ROM integrity check, and a stop-only progress watchdog. The example programs perform synthetic arithmetic; they do not process GPS, camera, navigation, or aircraft data.

## Current status

- The Main and Guard examples independently compute `0x12F4 - 0x1234 = 0x00C0`.
- The included 16-bit assembler tests and four RTL benches passed in the recorded build. The full development project also passed 74 Python tests and its configured simulations on 2026-11-07; this review bundle intentionally contains only the tests relevant to the wide16 profile.
- Gowin synthesis and place-and-route completed for the Tang Nano 20K profile. The report lists 569/20,736 logic units (2.74%), 273 logic flip-flops, and 8 RAM16 blocks. The PIN04 clock still has a PR1014 generic-routing warning; this is not a clock-closure claim.
- The board input in this design is 27 MHz, with a slow instruction-enable step for visible LEDs. A 32 MHz processor clock has not been measured and is not claimed.
- An SRAM Program operation completed and the FPGA-reported user code matched the staged bitstream header. A separate SRAM Program and Verify operation reported `Verify failed at 0`; full readback is unconfirmed. Physical LED behavior was not visually confirmed in the recorded session.

See [the architecture note](docs/wide-core16-design.md), [the development and hardware record](reports/wide16-development-2026-11-07.md), and [the Gowin PnR summary](reports/wide16_pnr_summary.md) for details and limitations.

## Scope and safety

This is a bench-only educational prototype. It has no sensor, camera, navigation, motor, or flight-control connection. It is not a flight computer, secure element, or safety-certified system. Its two cores and supervisor are implemented in the same reprogrammable FPGA fabric; the fault checks are not a security boundary.

## Build and simulate

Requirements: Python 3, Icarus Verilog (`iverilog` and `vvp`), and PowerShell. Gowin IDE is optional unless running place-and-route.

From this folder, run:

```powershell
.\build\build.ps1 -SkipSynthesis
```

To also run Gowin synthesis and place-and-route, omit `-SkipSynthesis` and set `-GowinShell` if the IDE is installed elsewhere. The generated bitstream is placed under `build/gowin_work_wide16/`; the script does not program the FPGA or its flash.

## Feedback and proposed fixes

Bug reports, test cases, and design suggestions are welcome. Please include the source file or instruction, exact steps to reproduce, expected and observed behavior, and tool versions. Start with an Issue to agree on a change before sending a large patch.

Code and documentation in this repository are licensed under the MIT License; see [LICENSE](LICENSE). Contributions are submitted under the same license. By opening a pull request, contributors confirm they have the right to submit their changes under these terms.

## Attribution

HSS-1 is an independent student project. Sipeed Tang Nano 20K and Gowin are third-party product and company names; this project is not affiliated with or endorsed by their owners.
