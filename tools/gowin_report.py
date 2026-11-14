from __future__ import annotations

import argparse
import re
from pathlib import Path


def _required(pattern: str, text: str, label: str) -> re.Match[str]:
    match = re.search(pattern, text, flags=re.MULTILINE)
    if match is None:
        raise ValueError(f"Could not read {label} from the Gowin report")
    return match


def _minimum_slacks(timing_text: str) -> tuple[list[float], list[float]]:
    lines = timing_text.splitlines()
    setup: list[float] = []
    hold: list[float] = []
    for index, line in enumerate(lines[:-1]):
        kind = line.strip()
        if kind not in {"SETUP", "HOLD"}:
            continue
        try:
            slack = float(lines[index + 1].strip())
        except ValueError as exc:
            raise ValueError(f"Invalid {kind.lower()} slack in timing paths") from exc
        (setup if kind == "SETUP" else hold).append(slack)
    if not setup or not hold:
        raise ValueError("Gowin timing report must include setup and hold paths")
    return setup, hold


def _html_resource_count(synthesis_text: str, label: str) -> tuple[int, int]:
    pattern = rf'<td\s+class="label">{re.escape(label)}</td>\s*<td>\s*(\d+)\s*/\s*(\d+)\s*</td>'
    match = re.search(pattern, synthesis_text, flags=re.IGNORECASE)
    if match is None:
        raise ValueError(f"Could not read {label} resources from the Gowin synthesis report")
    return int(match.group(1)), int(match.group(2))


def summarize_pnr(
    pnr_directory: Path, label: str, basename: str = "tangnano20k_lab_top"
) -> dict[str, object]:
    report_path = pnr_directory / f"{basename}.rpt.txt"
    timing_path = pnr_directory / f"{basename}.timing_paths"
    log_path = pnr_directory / f"{basename}.log"
    synthesis_path = pnr_directory.parent / "gwsynthesis" / f"{basename}_syn.rpt.html"
    report = report_path.read_text(encoding="utf-8", errors="replace")
    timing = timing_path.read_text(encoding="utf-8", errors="replace")
    log = log_path.read_text(encoding="utf-8", errors="replace")

    tool = _required(r"<Tool Version>:\s*(.+)", report, "tool version").group(1).strip()
    part = _required(r"<Part Number>:\s*(.+)", report, "part number").group(1).strip()
    created = _required(r"<Created Time>:\s*(.+)", report, "created time").group(1).strip()
    logic = _required(r"^\s*Logic\s+\|\s+(\d+)\s*/\s*(\d+)", report, "logic resources")
    primitives = _required(
        r"--LUT,ALU,ROM16\s+\|\s+\d+\((\d+) LUT,\s*(\d+) ALU,\s*(\d+) ROM16\)",
        report,
        "logic primitive counts",
    )
    ram16 = _required(r"--SSRAM\(RAM16\)\s+\|\s+(\d+)", report, "RAM16 count")
    registers = _required(r"^\s*Register\s+\|\s+(\d+)\s*/\s*(\d+)", report, "register resources")
    logic_registers = _required(
        r"^\s*--Logic Register as FF\s+\|\s+(\d+)\s*/\s*(\d+)",
        report,
        "logic flip-flop resources",
    )
    io_registers = _required(
        r"^\s*--I/O Register as FF\s+\|\s+(\d+)\s*/\s*(\d+)",
        report,
        "I/O flip-flop resources",
    )
    cls = _required(r"^\s*CLS\s+\|\s+(\d+)\s*/\s*(\d+)", report, "CLS resources")
    io_ports = _required(r"^\s*I/O Port\s+\|\s+(\d+)\s*/\s*(\d+)", report, "I/O port resources")
    primary_clock = _required(
        r"^\s*PRIMARY\s+\|\s+(\d+)\s*/\s*(\d+)", report, "primary clock resources"
    )
    gclk_pin = _required(r"^\s*GCLK_PIN\s+\|\s+(\d+)\s*/\s*(\d+)", report, "global clock pin resources")
    clock_pin = _required(
        r"^clk_27mhz\s+\|\s+-\s+\|\s+(\d+/\d+)\s+\|\s+Y\s+\|\s+in\s+\|\s+\S+\s+\|\s+(\S+)",
        report,
        "clock input pin",
    )
    setup, hold = _minimum_slacks(timing)
    warnings = re.findall(r"WARN\s+\(([^)]+)\)", log)
    warning_details = [
        f"{code}: {message.strip()}"
        for code, message in re.findall(r"WARN\s+\(([^)]+)\)\s*:\s*(.+)", log)
    ]
    synthesis_report = synthesis_path.read_text(encoding="utf-8", errors="replace") if synthesis_path.is_file() else None
    bsram = _html_resource_count(synthesis_report, "BSRAM") if synthesis_report is not None else None

    summary: dict[str, object] = {
        "label": label,
        "tool": tool,
        "part": part,
        "created": created,
        "logic_used": int(logic.group(1)),
        "logic_total": int(logic.group(2)),
        "luts": int(primitives.group(1)),
        "alus": int(primitives.group(2)),
        "rom16": int(primitives.group(3)),
        "ram16": int(ram16.group(1)),
        "registers_used": int(logic_registers.group(1)),
        "registers_total": int(logic_registers.group(2)),
        "io_registers_used": int(io_registers.group(1)),
        "io_registers_total": int(io_registers.group(2)),
        "register_sites_used": int(registers.group(1)),
        "register_sites_total": int(registers.group(2)),
        "cls_used": int(cls.group(1)),
        "cls_total": int(cls.group(2)),
        "io_ports_used": int(io_ports.group(1)),
        "io_ports_total": int(io_ports.group(2)),
        "primary_clock_used": int(primary_clock.group(1)),
        "primary_clock_total": int(primary_clock.group(2)),
        "gclk_pin_used": int(gclk_pin.group(1)),
        "gclk_pin_total": int(gclk_pin.group(2)),
        "clock_location": clock_pin.group(1),
        "clock_function": clock_pin.group(2),
        "setup_count": len(setup),
        "hold_count": len(hold),
        "min_setup_slack": min(setup),
        "min_hold_slack": min(hold),
        "warnings": warnings,
        "warning_details": warning_details,
    }
    if bsram is not None:
        summary["bsram_used"], summary["bsram_total"] = bsram
    return summary


def render_markdown(summary: dict[str, object]) -> str:
    warnings = summary["warnings"]
    warning_details = summary.get("warning_details", [])
    if warnings and warning_details:
        warning_text = "; ".join(f"`{detail}`" for detail in warning_details)
    else:
        warning_text = ", ".join(f"`{warning}`" for warning in warnings) if warnings else "None in the PnR log"
    logic_percent = 100 * int(summary["logic_used"]) / int(summary["logic_total"])
    lines = [
            f"# Gowin PnR summary — {summary['label']}",
            "",
            f"Generated from the tool reports created at {summary['created']}.",
            "",
            f"- **Tool and part:** {summary['tool']}; {summary['part']}",
            f"- **Clock input:** PIN{int(summary['clock_location'].split('/')[0]):02d} (`{summary['clock_function']}`)",
            f"- **Logic:** {summary['logic_used']}/{summary['logic_total']} ({logic_percent:.2f}%); {summary['luts']} LUT, {summary['alus']} ALU, {summary['rom16']} ROM16; {summary['ram16']} RAM16 blocks",
            f"- **Registers:** {summary['registers_used']}/{summary['registers_total']} logic FF; {summary['io_registers_used']}/{summary['io_registers_total']} I/O FF (combined register sites {summary['register_sites_used']}/{summary['register_sites_total']})",
        ]
    if "bsram_used" in summary:
        lines.append(f"- **Block SRAM:** {summary['bsram_used']}/{summary['bsram_total']} BSRAM blocks")
    lines.extend(
        [
            f"- **Placement and I/O resources:** {summary['cls_used']}/{summary['cls_total']} CLS; {summary['io_ports_used']}/{summary['io_ports_total']} I/O ports",
            f"- **Clock resources:** {summary['primary_clock_used']}/{summary['primary_clock_total']} primary; {summary['gclk_pin_used']}/{summary['gclk_pin_total']} global clock input pins",
            f"- **Static timing paths:** {summary['setup_count']} setup, {summary['hold_count']} hold; minimum listed slack {summary['min_setup_slack']:+.3f} ns setup, {summary['min_hold_slack']:+.3f} ns hold",
            f"- **PnR warnings:** {warning_text}",
            "",
            "This is a Gowin synthesis/place-and-route report summary. It does not establish physical board operation.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize a Gowin Tang Nano 20K PnR report")
    parser.add_argument("--pnr-dir", type=Path, required=True)
    parser.add_argument("--label", default="Default PIN04")
    parser.add_argument("--basename", default="tangnano20k_lab_top")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        summary = summarize_pnr(args.pnr_dir, args.label, args.basename)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(render_markdown(summary), encoding="utf-8")
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
    print(f"PnR summary: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
