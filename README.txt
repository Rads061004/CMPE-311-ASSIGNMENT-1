To simulate the design, first ensure you're in the directory with the files, then execute the following command:

<Relative path to cadence xrun>/launch_cadence_xrun.sh -top chip_tb gates.vhd mux_comp.vhd comparator.vhd counter_adder.vhd dff_dlatch.vhd decoder.vhd registers.vhd tbuf.vhd cache_block.vhd next_state_logic.vhd state_register.vhd counter_logic.vhd output_logic.vhd cache_fsm_struct.vhd chip.vhd chip_tb.vhd -gui -access rwc

For example, in our case the launch_cadence_xrun executable was located two files up in a directory called cadence_setup, so we ran: 

../../cadence_setup/launch_cadence_xrun.sh -top chip_tb gates.vhd mux_comp.vhd comparator.vhd counter_adder.vhd dff_dlatch.vhd decoder.vhd registers.vhd tbuf.vhd cache_block.vhd next_state_logic.vhd state_register.vhd counter_logic.vhd output_logic.vhd cache_fsm_struct.vhd chip.vhd chip_tb.vhd -gui -access rwc