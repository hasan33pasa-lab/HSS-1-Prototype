param(
    [switch]$SkipSynthesis,
    [string]$IcarusBin = 'C:\msys64\ucrt64\bin',
    [string]$GowinShell = 'C:\Gowin\Gowin_V1.9.12.02_SP2_x64\IDE\bin\gw_sh.exe'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$iverilog = Join-Path $IcarusBin 'iverilog.exe'
$vvp = Join-Path $IcarusBin 'vvp.exe'
$python = (Get-Command py.exe -ErrorAction Stop).Source
$originalPath = $env:PATH

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments, [string]$Description)
    Write-Output "> $Executable $($Arguments -join ' ')"
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Description failed (exit $LASTEXITCODE)." }
}

function Invoke-Bench {
    param([string]$Name, [string[]]$Sources)
    $output = "build\$Name.vvp"
    Invoke-Checked $iverilog (@('-g2012', '-Wall', '-o', $output) + $Sources) "$Name compilation"
    Invoke-Checked $vvp @($output) "$Name simulation"
}

Push-Location $root
try {
    if (-not (Test-Path -LiteralPath $iverilog)) { throw "Icarus Verilog not found at $iverilog" }
    if (-not (Test-Path -LiteralPath $vvp)) { throw "Icarus runtime not found at $vvp" }
    New-Item -ItemType Directory -Path 'build\generated16' -Force | Out-Null

    Invoke-Checked $python @('-m', 'tools.assembler16', '--output', 'rtl\wide16_program_rom.v', '--artifact-dir', 'build\generated16') 'Assembler'
    Invoke-Checked $python @('-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_assembler16.py', '-v') 'Wide16 Python tests'

    $env:PATH = "$IcarusBin;C:\msys64\usr\bin;$env:PATH"
    Invoke-Bench 'wide_tiny_core16' @('rtl\wide16_program_rom.v', 'rtl\wide_tiny_core.v', 'sim\tb_wide_tiny_core.v')
    Invoke-Bench 'wide16_isa' @('rtl\wide_tiny_core.v', 'sim\tb_wide_tiny_core_isa.v')
    Invoke-Bench 'dual_core_wide16' @('rtl\wide16_program_rom.v', 'rtl\progress_watchdog.v', 'rtl\wide_tiny_core.v', 'rtl\dual_core_wide16_lab_top.v', 'sim\tb_dual_core_wide16_lab.v')
    Invoke-Bench 'board_wide16' @('rtl\wide16_program_rom.v', 'rtl\progress_watchdog.v', 'rtl\wide_tiny_core.v', 'rtl\dual_core_wide16_lab_top.v', 'rtl\lab_activity_leds.v', 'rtl\button_filter.v', 'rtl\tangnano20k_wide16_lab_top.v', 'sim\tb_tangnano20k_wide16_lab_top.v')

    if (-not $SkipSynthesis) {
        if (-not (Test-Path -LiteralPath $GowinShell)) { throw "Gowin Tcl shell not found at $GowinShell" }
        $projectRoot = $root.Replace('\', '/')
        $tcl = (Get-Content 'build\gowin_synth_wide16.tcl' -Raw).Replace('@PROJECT_ROOT@', $projectRoot)
        [System.IO.File]::WriteAllText((Join-Path $root 'build\gowin_synth_wide16.generated.tcl'), $tcl, [System.Text.Encoding]::ASCII)
        Invoke-Checked $GowinShell @('build\gowin_synth_wide16.generated.tcl') 'Gowin wide16 PnR'
        Invoke-Checked $python @('tools\gowin_report.py', '--pnr-dir', 'build\gowin_work_wide16\tangnano20k_wide16_lab\impl\pnr', '--label', 'HSS-1 wide16 lab top', '--basename', 'tangnano20k_wide16_lab_top', '--output', 'reports\wide16_pnr_summary.md') 'PnR report summary'
    }
    Write-Output 'HSS-1 wide16 build completed successfully.'
}
finally {
    $env:PATH = $originalPath
    Pop-Location
}
