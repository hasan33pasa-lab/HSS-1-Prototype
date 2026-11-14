; Synthetic 16-bit coordinate-delta workload for the separate wide core.
; 0x12F4 - 0x1234 = 0x00C0; then store and reload the result.
LDI R0, 0x34
LDIH R0, 0x12
LDI R1, 0xF4
LDIH R1, 0x12
SUB R1, R0
STORE R1, 0
LDI R2, 0
LOAD R2, 0
OUT R2
HALT
