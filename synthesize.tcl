set OUTPUT_DIR ./run_dir
set_attribute lib_search_path ../CommonFiles/libdir 
set_attribute library {osu05_stdcells.lib} 
load Basic-Components/mips32.vhd -vhdl
load Basic-Components/utils.vhd -vhdl
load Basic-Components/Gates/and_2in.vhd -vhdl
load Basic-Components/Gates/inv_1bit.vhd -vhdl
load Basic-Components/Gates/nand_2in.vhd -vhdl
load Basic-Components/Gates/nor_2in.vhd -vhdl
load Basic-Components/Gates/or_2in.vhd -vhdl
load Basic-Components/Gates/or_Nin.vhd -vhdl
load Basic-Components/Gates/xor_2in.vhd -vhdl
load Basic-Components/Utility-Components/mux_1bit_2in.vhd -vhdl
load Basic-Components/Utility-Components/mux_1bit_Min.vhd -vhdl
load Basic-Components/Utility-Components/mux_Nbit_2in.vhd -vhdl
load Basic-Components/Utility-Components/mux_Nbit_Min.vhd -vhdl
load Basic-Components/Utility-Components/decoder_Nbit.vhd -vhdl
load Basic-Components/Utility-Components/extender_Nbit_Mbit.vhd -vhdl
load Basic-Components/Utility-Components/onescomplementer_Nbit.vhd -vhdl
load Basic-Components/Utility-Components/rightshifter_Nbit.vhd -vhdl
load Basic-Components/Utility-Components/leftshifter_Nbit.vhd -vhdl
load Basic-Components/ALU-Components/addersubtracter_Nbit.vhd -vhdl
load Basic-Components/ALU-Components/ALU_1bit.vhd -vhdl
load Basic-Components/ALU-Components/ALU_Nbit.vhd -vhdl
load Basic-Components/ALU-Components/fulladder_1bit.vhd -vhdl
load Basic-Components/ALU-Components/fulladder_Nbit.vhd -vhdl
load Basic-Components/Register-Components/dff.vhd -vhdl
load Basic-Components/Register-Components/register_Nbit.vhd -vhdl
load Basic-Components/Register-Components/registerfile_Nbit_Mreg.vhd -vhdl

load Project-B/SCPv3/components/cpurecords.vhd -vhdl
load Project-B/SCPv3/components/alucontrolv3.vhd -vhdl
load Project-B/SCPv3/components/controlv3.vhd -vhdl
load Project-B/SCPv3/cpuv3.vhd -vhdl
elaborate cpuv3nents/instruction_decoder.vhd -vhdl
load Project-B/SCPv3/components/alucontrolv3.vhd -vhdl
load Project-B/SCPv3/components/controlv3.vhd -vhdl
load Project-B/SCPv3/components/mem.vhd -vhdl
load Project-B/SCPv3/cpuv3.vhd -vhdl
elaborate cpuv3