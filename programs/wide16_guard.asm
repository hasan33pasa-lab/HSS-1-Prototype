; Independent order for the same synthetic 16-bit coordinate difference.
LDI R0, 0xF4
LDIH R0, 0x12
LDI R1, 0x34
LDIH R1, 0x12
SUB R0, R1
OUT R0
HALT
