# Contributing

Thank you for reviewing HSS-1. Bug reports, test cases, documentation fixes, and design suggestions are welcome.

## Before opening a pull request

Open an Issue first for changes beyond a small typo. Include the problem, evidence, expected behavior, and proposed scope so the maintainers can agree on the change before implementation.

## Reproduce the current build

Run the included 16-bit test suite and RTL benches from PowerShell:

```powershell
.\build\build.ps1 -SkipSynthesis
```

Include the exact command, operating system, Python/Icarus versions, and any waveform or error log relevant to the change. Do not report the FPGA as physically verified based only on simulation.

## Project scope

This repository is a bench-only educational processor prototype. Changes must not describe it as an aircraft controller, safety-certified processor, or working GPS/camera system. Keep sensor, motor, and flight-control integrations outside this project.

## License

By submitting a contribution, you agree that it is offered under the repository's MIT License and that you have the right to submit it on those terms.
