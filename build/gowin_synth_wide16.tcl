create_project -name tangnano20k_wide16_lab -dir {@PROJECT_ROOT@/build/gowin_work_wide16} -pn GW2AR-LV18QN88C8/I7 -device_version C -force
add_file {@PROJECT_ROOT@/rtl/wide16_program_rom.v}
add_file {@PROJECT_ROOT@/rtl/progress_watchdog.v}
add_file {@PROJECT_ROOT@/rtl/wide_tiny_core.v}
add_file {@PROJECT_ROOT@/rtl/dual_core_wide16_lab_top.v}
add_file {@PROJECT_ROOT@/rtl/lab_activity_leds.v}
add_file {@PROJECT_ROOT@/rtl/button_filter.v}
add_file {@PROJECT_ROOT@/rtl/tangnano20k_wide16_lab_top.v}
add_file {@PROJECT_ROOT@/constraints/tangnano20k_lab.cst}
add_file {@PROJECT_ROOT@/constraints/tangnano20k_lab.sdc}
set_option -top_module tangnano20k_wide16_lab_top
set_option -output_base_name tangnano20k_wide16_lab_top
run syn
run pnr
