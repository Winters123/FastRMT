create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0 -dir f:/NYC/rmt_512/rmt_512.srcs/sources_1/ip

set_property -dict [list \
    CONFIG.USE_PHASE_ALIGNMENT {true} \
    CONFIG.PRIM_IN_FREQ {250.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} \
    CONFIG.SECONDARY_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKIN1_JITTER_PS {40.0} \
    CONFIG.CLKOUT1_DRIVES {Buffer} \
    CONFIG.CLKOUT2_DRIVES {Buffer} \
    CONFIG.CLKOUT3_DRIVES {Buffer} \
    CONFIG.CLKOUT4_DRIVES {Buffer} \
    CONFIG.CLKOUT5_DRIVES {Buffer} \
    CONFIG.CLKOUT6_DRIVES {Buffer} \
    CONFIG.CLKOUT7_DRIVES {Buffer} \
    CONFIG.MMCM_DIVCLK_DIVIDE {2} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {9.625} \
    CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {9.625} \
    CONFIG.CLKOUT1_JITTER {106.624} \
    CONFIG.CLKOUT1_PHASE_ERROR {85.285}\
] [get_ips clk_wiz_0]
