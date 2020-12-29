create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name key_mask_ram_101w_16d

set_property -dict [list \
	CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
	CONFIG.Load_Init_File {false} \
	CONFIG.Write_Depth_A {16} \
	CONFIG.Write_Width_A {101} \
	CONFIG.Read_Width_A {101} \
	CONFIG.Operating_Mode_A {NO_CHANGE} \
	CONFIG.Write_Width_B {101} \
	CONFIG.Read_Width_B {101} \
	CONFIG.Enable_B {Use_ENB_Pin} \
	CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
	CONFIG.Register_PortB_Output_of_Memory_Primitives {true} \
	CONFIG.Port_B_Clock {100} \
	CONFIG.Port_B_Enable_Rate {100} \
] [get_ips key_mask_ram_101w_16d]

set_property generate_synth_checkpoint false [get_files key_mask_ram_101w_16d.xci]
reset_target all [get_ips key_mask_ram_101w_16d]
generate_target all [get_ips key_mask_ram_101w_16d]
