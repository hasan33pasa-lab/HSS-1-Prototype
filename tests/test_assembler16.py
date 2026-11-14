import unittest

from tools.assembler import encode_instruction_check
from tools.assembler16 import assemble_text16, emit_rom16
from tools.isa16_simulator import WideCore16Simulator


class Wide16AssemblerTests(unittest.TestCase):
    def test_high_byte_load_uses_extended_f_opcode(self):
        words = assemble_text16("LDI R1, 0x34\nLDIH R1, 0x12\nHALT\n")
        self.assertEqual(words, [0x1434, 0xF512, 0xF000])

    def test_binary_encoding_matches_16_bit_profile_fields(self):
        self.assertEqual(assemble_text16("ADD R2, R3\nSUB R1, R0\n"), [0x9B00, 0xA400])

    def test_rom_emits_check_bits_for_wide_programs(self):
        generated = emit_rom16([0xF512], [0xF000])
        self.assertIn("module wide16_main_program_rom", generated)
        self.assertIn(f"instruction_check = 6'h{encode_instruction_check(0xF512):02X};", generated)
        self.assertIn("instruction = 16'hF000;", generated)

    def test_synthetic_coordinate_delta_runs_in_software_model(self):
        with open("programs/wide16_main.asm", encoding="utf-8") as source_file:
            main = WideCore16Simulator(assemble_text16(source_file.read())).run()
        with open("programs/wide16_guard.asm", encoding="utf-8") as source_file:
            guard = WideCore16Simulator(assemble_text16(source_file.read())).run()
        self.assertEqual(main.result, 0x00C0)
        self.assertEqual(guard.result, 0x00C0)
        self.assertEqual(main.data_memory[0], 0x00C0)
        self.assertEqual(guard.data_memory[0], 0x0000)

    def test_immediates_are_unsigned_bytes_and_ram_addresses_are_bounded(self):
        with self.assertRaisesRegex(ValueError, "8-bit value out of range"):
            assemble_text16("LDIH R0, 0x100")
        with self.assertRaisesRegex(ValueError, "private RAM address must be 0..15"):
            assemble_text16("STORE R0, 16")


if __name__ == "__main__":
    unittest.main()
