"""Software reference runner for the separate 16-bit datapath profile."""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

from .assembler16 import assemble_text16

MASK16 = 0xFFFF
MASK8 = 0xFF
HALT_WORD = 0xF000


@dataclass
class Core16State:
    pc: int = 0
    registers: list[int] = field(default_factory=lambda: [0] * 4)
    data_memory: list[int] = field(default_factory=lambda: [0] * 16)
    result: int = 0
    retired_count: int = 0
    halted: bool = False


TraceCallback = Callable[[int, int, Core16State], None]


class WideCore16Simulator:
    def __init__(self, program: list[int]):
        if len(program) > 256:
            raise ValueError("program exceeds the 256-word instruction address space")
        if any(not isinstance(word, int) or not 0 <= word <= MASK16 for word in program):
            raise ValueError("every instruction must be a 16-bit unsigned word")
        self.program = list(program)
        self.state = Core16State()

    def fetch(self) -> int:
        return self.program[self.state.pc] if self.state.pc < len(self.program) else HALT_WORD

    def step(self, run_enable: bool = True) -> tuple[int, int] | None:
        state = self.state
        if state.halted or not run_enable:
            return None

        address = state.pc
        instruction = self.fetch()
        opcode = (instruction >> 12) & 0xF
        destination = (instruction >> 10) & 0x3
        source = (instruction >> 8) & 0x3
        immediate = instruction & MASK8
        memory_address = instruction & 0xF
        next_pc = (state.pc + 1) & MASK8
        state.retired_count = (state.retired_count + 1) & MASK16

        if opcode == 0x0:
            state.pc = next_pc
        elif opcode == 0x1:
            state.registers[destination] = immediate
            state.pc = next_pc
        elif opcode == 0x2:
            state.registers[destination] = (state.registers[destination] + immediate) & MASK16
            state.pc = next_pc
        elif opcode == 0x3:
            state.registers[destination] ^= immediate
            state.pc = next_pc
        elif opcode == 0x4:
            state.result = state.registers[destination]
            state.pc = next_pc
        elif opcode == 0x5:
            state.pc = immediate
        elif opcode == 0x6:
            state.pc = immediate if state.registers[destination] == 0 else next_pc
        elif opcode == 0x7:
            state.registers[destination] = state.data_memory[memory_address]
            state.pc = next_pc
        elif opcode == 0x8:
            state.data_memory[memory_address] = state.registers[destination]
            state.pc = next_pc
        elif opcode == 0x9:
            state.registers[destination] = (
                state.registers[destination] + state.registers[source]
            ) & MASK16
            state.pc = next_pc
        elif opcode == 0xA:
            state.registers[destination] = (
                state.registers[destination] - state.registers[source]
            ) & MASK16
            state.pc = next_pc
        elif opcode == 0xB:
            state.registers[destination] &= state.registers[source]
            state.pc = next_pc
        elif opcode == 0xC:
            state.registers[destination] |= state.registers[source]
            state.pc = next_pc
        elif opcode == 0xD:
            state.registers[destination] ^= state.registers[source]
            state.pc = next_pc
        elif opcode == 0xE:
            state.registers[destination] = state.registers[source]
            state.pc = next_pc
        elif ((instruction >> 8) & 0x3) == 0x1:
            state.registers[destination] = (
                state.registers[destination] & 0x00FF
            ) | (immediate << 8)
            state.pc = next_pc
        else:
            state.halted = True
        return address, instruction

    def run(self, max_steps: int = 10_000, trace: TraceCallback | None = None) -> Core16State:
        if max_steps < 1:
            raise ValueError("max_steps must be at least 1")
        for _ in range(max_steps):
            if self.state.halted:
                break
            executed = self.step()
            if executed is not None and trace is not None:
                trace(executed[0], executed[1], self.state)
        if not self.state.halted:
            raise TimeoutError(f"program did not halt within {max_steps} instructions")
        return self.state


def _format_trace(address: int, instruction: int, state: Core16State) -> None:
    registers = " ".join(f"R{index}={value:04X}" for index, value in enumerate(state.registers))
    print(
        f"PC={address:02X} IR={instruction:04X} -> PC={state.pc:02X} "
        f"{registers} OUT={state.result:04X} RET={state.retired_count:04X} "
        f"HALT={int(state.halted)}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a 16-bit datapath .asm program")
    parser.add_argument("source", type=Path, help="assembly source file")
    parser.add_argument("--max-steps", type=int, default=10_000)
    parser.add_argument("--trace", action="store_true")
    args = parser.parse_args()
    try:
        program = assemble_text16(args.source.read_text(encoding="utf-8"))
        state = WideCore16Simulator(program).run(
            max_steps=args.max_steps,
            trace=_format_trace if args.trace else None,
        )
    except (OSError, ValueError, TimeoutError) as exc:
        parser.error(str(exc))
    print(f"halted: {str(state.halted).lower()}")
    print(f"pc: {state.pc}")
    print(f"retired: {state.retired_count}")
    print(f"result: {state.result} (0x{state.result:04X})")
    print("registers: " + " ".join(f"R{i}=0x{value:04X}" for i, value in enumerate(state.registers)))
    print("ram: " + " ".join(f"{value:04X}" for value in state.data_memory))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
