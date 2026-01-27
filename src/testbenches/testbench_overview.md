# Testbenches

This document provides a brief description of all the testbenches

## TileLink  (`TLCrossBar_test.sv`)

- **Purpose**: Tests a TileLink crossbar interconnect with 2 masters and 2 slaves
- **Data Width**: 8-bit data channels
- **Functionality**: 
  - Masters send transactions to slaves in every even cycles
  - Slaves respond in sequence of transaction A -> D

## FIFO  (`fifo_test.sv`)

- **Purpose**: Tests a basic FIFO buffer
- **Data Width**: 1-bit data
- **Functionality**:
  - Single master pushes data into FIFO (tries exponential cycles)
  - Single slave reads data from FIFO


## Stream FIFO (`stream_fifo_test.sv`)
- **Purpose**: Tests a stream FIFO with ready/valid handshake
- **Data Width**: 1-bit data
- **Functionality**:
    - Same as FIFO test but with ready/valid interface

## Arbiter  (`arbiter_test.sv`)
- **Purpose**: Tests a round-robin arbiter with 4 slaves
- **Data Width**: 1-bit data
- **Functionality**:
  - 4 slaves compete for access to single master
  - Round-robin arbitration policy
  - Each slave tries to sends at power-of-2 cycles and master responds in multiples of 3 cycles

## Spill Register (`spill_register_test.sv`)
- **Purpose**: Tests a spill register for data buffering
- **Data Width**: 1-bit data
- **Functionality**:
  - Fix the logic issue in the spill register (push and pop happening even when full/empty)
  - Upstram master tries to send even cycles
  - Downstream slave reads at multiples of 4 if its multiple of 3 as well then spills

## AXI Lite Mux 

(`axi_lite_write_mux_tb.sv`) /(`axi_lite_read_mux_tb.sv`)
- **Purpose**: Tests write-only AXI Lite multiplexer / read-only multiplexer separately
- **Data Width**: 8-bit data (kept due to assertion requirements)
- **Functionality**: Slave writes in exponentials of 2 cycles, masters proceed serially

## AXI Lite Demux Components

(`axi_lite_demux_write_tb.sv`) /  (`axi_lite_demux_read_tb.sv`)
- **Purpose**: Tests write-only AXI Lite demultiplexer and read-only demultiplexer seperately
- **Data Width**: 8-bit data
- **Functionality**: Same as mux but selects master in round-robin fashion
