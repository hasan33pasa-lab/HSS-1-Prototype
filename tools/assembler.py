from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Iterable

OPCODES = {
    "NOP": 0x0, "LDI": 0x1, "ADDI": 0x2, "XORI": 0x3,
    "OUT": 0x4, "JMP": 0x5, "JZ": 0x6, "LOAD": 0x7,
    "STORE": 0x8, "ADD": 0x9, "SUB": 0xA, "AND": 0xB,
    "OR": 0xC, "XOR": 0xD, "MOV": 0xE, "HALT": 0xF,
}
BINARY_OPS = {"ADD", "SUB", "AND", "OR", "XOR", "MOV"}
IMMEDIATE_OPS = {"LDI", "ADDI", "XORI"}
SINGLE_REG_OPS = {"OUT"}
MEMORY_OPS = {"LOAD", "STORE"}
LABEL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
REGISTER_RE = re.compile(r"^[Rr]([0-3])$")
HAMMING_DATA_POSITIONS = (3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21)


def _without_comment(line: str) -> str:
    for marker in (";", "//"):
        line = line.split(marker, 1)[0]
    return line.strip()


def encode_instruction_check(word: int) -> int:
    """Return 5 Hamming check bits plus one overall even-parity bit."""
    if not 0 <= word <= 0xFFFF:
        raise ValueError("instruction word must be a 16-bit unsigned value")
    hamming_bits = 0
    for check_index in range(5):
        check_bit = 0
        for data_index, position in enumerate(HAMMING_DATA_POSITIONS):
            if position & (1 << check_index):
                check_bit ^= (word >> data_index) & 1
        hamming_bits |= check_bit << check_index
    overall_bit = (word.bit_count() + hamming_bits.bit_count()) & 1
    return hamming_bits | (overall_bit << 5)


def _split_operands(text: str) -> list[str]:
    if not text.strip():
        return []
    return [part.strip() for part in text.split(",")]


def _parse_source(text: str) -> tuple[dict[str, int], list[tuple[int, int, str, list[str]]]]:
    labels: dict[str, int] = {}
    statements: list[tuple[int, int, str, list[str]]] = []
    pc = 0
    for line_number, raw in enumerate(text.splitlines(), start=1):
        line = _without_comment(raw)
        if not line:
            continue
        if ":" in line:
            label, line = line.split(":", 1)
            label = label.strip()
            if not LABEL_RE.fullmatch(label):
                raise ValueError(f"Line {line_number}: invalid label {label!r}")
            key = label.upper()
            if key in labels:
                raise ValueError(f"Line {line_number}: duplicate label {label!r}")
            if pc > 255:
                raise ValueError(f"Line {line_number}: program exceeds 256 instructions")
            labels[key] = pc
            line = line.strip()
            if not line:
                continue
        parts = line.split(None, 1)
        op = parts[0].upper()
        operands = _split_operands(parts[1] if len(parts) > 1 else "")
        statements.append((pc, line_number, op, operands))
        pc += 1
    if pc > 256:
        raise ValueError("Program exceeds the 256-instruction address space")
    return labels, statements


def _reg(token: str, line: int) -> int:
    match = REGISTER_RE.fullmatch(token.strip())
    if not match:
        raise ValueError(f"Line {line}: expected register R0..R3, got {token!r}")
    return int(match.group(1))


def _number(token: str, labels: dict[str, int], line: int) -> int:
    key = token.strip().upper()
    if key in labels:
        return labels[key]
    try:
        return int(token.strip(), 0)
    except ValueError as exc:
        raise ValueError(f"Line {line}: unknown number or label {token!r}") from exc


def _literal_number(token: str, line: int, description: str) -> int:
    try:
        return int(token.strip(), 0)
    except ValueError as exc:
        raise ValueError(f"Line {line}: {description} must be a numeric literal") from exc


def _imm8(token: str, labels: dict[str, int], line: int, *, allow_negative: bool = False) -> int:
    value = _number(token, labels, line)
    lower = -128 if allow_negative else 0
    if not lower <= value <= 255:
        raise ValueError(f"Line {line}: 8-bit value out of range: {value}")
    return value & 0xFF


def assemble_text(text: str) -> list[int]:
    labels, statements = _parse_source(text)
    words: list[int] = []
    for address, line, op, args in statements:
        if op not in OPCODES:
            raise ValueError(f"Line {line}: unknown instruction {op!r}")
        opcode = OPCODES[op]
        word = opcode << 12

        if op in {"NOP", "HALT"}:
            if args:
                raise ValueError(f"Line {line}: {op} takes no operands")
        elif op in IMMEDIATE_OPS:
            if len(args) != 2:
                raise ValueError(f"Line {line}: {op} expects register, immediate")
            destination = _reg(args[0], line)
            immediate = _imm8(args[1], labels, line, allow_negative=True)
            word |= destination << 10 | immediate
        elif op in SINGLE_REG_OPS:
            if len(args) != 1:
                raise ValueError(f"Line {line}: {op} expects one register")
            word |= _reg(args[0], line) << 10
        elif op == "JMP":
            if len(args) != 1:
                raise ValueError(f"Line {line}: JMP expects one address or label")
            word |= _imm8(args[0], labels, line)
        elif op == "JZ":
            if len(args) != 2:
                raise ValueError(f"Line {line}: JZ expects register, address or label")
            destination = _reg(args[0], line)
            target = _imm8(args[1], labels, line)
            word |= destination << 10 | target
        elif op in MEMORY_OPS:
            if len(args) != 2:
                raise ValueError(f"Line {line}: {op} expects register, address")
            destination = _reg(args[0], line)
            memory_address = _literal_number(args[1], line, "private RAM address")
            if not 0 <= memory_address <= 15:
                raise ValueError(f"Line {line}: private RAM address must be 0..15")
            word |= destination << 10 | memory_address
        elif op in BINARY_OPS:
            if len(args) != 2:
                raise ValueError(f"Line {line}: {op} expects two registers")
            destination = _reg(args[0], line)
            source = _reg(args[1], line)
            word |= destination << 10 | source << 8
        else:
            raise ValueError(f"Line {line}: assembler has no encoder for {op}")
        words.append(word)
    return words


def _module_body(module_name: str, words: Iterable[int]) -> list[str]:
    # Store SECDED bits from the assembled word so runtime comparison can detect
    # bus faults; recomputing the check field from that bus would mask faults.
    body = [
        f"module {module_name} (",
        "    input wire [7:0] address,",
        "    output reg [15:0] instruction,",
        "    output reg [5:0] instruction_check",
        ");",
        "    always @* begin",
        "        case (address)",
    ]
    for address, word in enumerate(words):
        body += [
            f"            8'd{address}: begin",
            f"                instruction = 16'h{word:04X};",
            f"                instruction_check = 6'h{encode_instruction_check(word):02X};",
            "            end",
        ]
    body += [
        "            default: begin",
        "                instruction = 16'hF000;",
        f"                instruction_check = 6'h{encode_instruction_check(0xF000):02X};",
        "            end",
        "        endcase",
        "    end",
        "endmodule",
        "",
    ]
    return body


def emit_instruction_rom(main_words: list[int], guard_words: list[int]) -> str:
    body = [
        "// Generated by tools/assembler.py from programs/*.asm. Do not edit by hand.",
        "",
    ]
    body += _module_body("main_program_rom", main_words)
    body += _module_body("guard_program_rom", guard_words)
    return "\n".join(body)


def _write_listing(path: Path, source: str, words: list[int]) -> None:
    _, statements = _parse_source(source)
    lines = ["ADDR  WORD  SOURCE"]
    for word, (address, line_number, op, operands) in zip(words, statements):
        args = ", ".join(operands)
        lines.append(f"{address:04X}  {word:04X}  L{line_number}: {op} {args}".rstrip())
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def assemble_files(
    main_path: Path,
    guard_path: Path,
    output_path: Path,
    artifact_dir: Path | None = None,
) -> tuple[list[int], list[int]]:
    main_text = main_path.read_text(encoding="utf-8")
    guard_text = guard_path.read_text(encoding="utf-8")
    main_words = assemble_text(main_text)
    guard_words = assemble_text(guard_text)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(emit_instruction_rom(main_words, guard_words), encoding="ascii")
    artifacts = artifact_dir if artifact_dir is not None else output_path.parent
    artifacts.mkdir(parents=True, exist_ok=True)
    _write_listing(artifacts / "main_program.lst", main_text, main_words)
    _write_listing(artifacts / "guard_program.lst", guard_text, guard_words)
    (artifacts / "main_program.mem").write_text(
        "".join(f"{word:04X}\n" for word in main_words), encoding="ascii"
    )
    (artifacts / "guard_program.mem").write_text(
        "".join(f"{word:04X}\n" for word in guard_words), encoding="ascii"
    )
    return main_words, guard_words


def main() -> int:
    parser = argparse.ArgumentParser(description="Assemble the Dual-Core Lab 16-bit ISA")
    parser.add_argument("--main", type=Path, default=Path("programs/main.asm"))
    parser.add_argument("--guard", type=Path, default=Path("programs/guard.asm"))
    parser.add_argument("--output", type=Path, default=Path("rtl/instruction_rom.v"))
    parser.add_argument("--artifact-dir", type=Path)
    args = parser.parse_args()
    try:
        main_words, guard_words = assemble_files(args.main, args.guard, args.output, args.artifact_dir)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(f"Main program: {len(main_words)} instructions")
    print(f"Guard program: {len(guard_words)} instructions")
    print(f"Generated ROM: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
