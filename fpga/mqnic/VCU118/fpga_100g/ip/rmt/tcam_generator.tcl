read_vhdl -library cam  ./ip/xilinx_cam/dmem.vhd
read_vhdl -library cam  [glob ./ip/xilinx_cam/cam*.vhd]

add_files [glob ./lib_rmt/rmtv2/*.mif]

