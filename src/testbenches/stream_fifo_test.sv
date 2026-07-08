// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
// - Thomas Benz  <tbenz@iis.ee.ethz.ch>
// - Tobias Senti <tsenti@ethz.ch>

// `include "common_cells/assertions.svh"
// `include "common_cells/registers.svh"
`define FF(__q, __d, __reset_value, __clk = `REG_DFLT_CLK, __arst_n = `REG_DFLT_RST) \
  always_ff @(posedge (__clk) or negedge (__arst_n)) begin                           \
    if (!__arst_n) begin                                                             \
      __q <= (__reset_value);                                                        \
    end else begin                                                                   \
      __q <= (__d);                                                                  \
    end                                                                              \
  end

  `define FFL(__q, __d, __load, __reset_value, __clk = `REG_DFLT_CLK, __arst_n = `REG_DFLT_RST) \
  always_ff @(posedge (__clk) or negedge (__arst_n)) begin                                    \
    if (!__arst_n) begin                                                                      \
      __q <= (__reset_value);                                                                 \
    end else begin                                                                            \
      __q <= (__load) ? (__d) : (__q);                                                        \
    end                                                                                       \
  end
/// Stream FIFO that does not cut the timing path. When full; pushing data is allowed if in
/// the same cycle data is popped. Creates longer timing paths but can use buffer space more
/// efficiently.
module passthrough_stream_fifo #(
    /// Depth can be arbitrary from 2 to 2**32
    parameter int unsigned Depth       = 32'd8,
    /// Print information when the simulation launches
    parameter bit          PrintInfo   = 1'b0,
    /// If the FIFO is full, allow reading and writing in the same cycle
    parameter bit          SameCycleRW = 1'b1,
    /// Type of the FIFO
    parameter type         type_t      = logic
) (
    /// Clock
    input  logic                 clk_i,
    /// Asynchronous reset active low
    input  logic                 rst_ni,
    /// Fifo flush
    input  logic                 flush_i,
    /// Bypass clock gat
    /// data to push into the FIFO
    input  type_t                data_i,
    /// input data valid
    input  logic                 valid_i,
    /// FIFO is not full
    output logic                 ready_o,
    /// output data
    output type_t                data_o,
    /// FIFO is not empty
    output logic                 valid_o,
    /// pop head from FIFO
    input  logic                 ready_i
);
    /// Bit Width of the read and write pointers
    /// One additional bit to detect overflows
    localparam int unsigned PointerWidth = $clog2(Depth) + 1;

    // Read and write pointers
    logic [PointerWidth-1:0]  read_ptr_d,  read_ptr_q;
    logic [PointerWidth-1:0] write_ptr_d, write_ptr_q;

    // Data
    type_t [Depth-1 :0] data_d, data_q;

    // Enable storage
    logic load_data;

    assign data_o = data_q[read_ptr_q[PointerWidth-2:0]];

    // Logic
    always_comb begin
        // Default
        load_data   = 1'b0;
        read_ptr_d  = read_ptr_q;
        write_ptr_d = write_ptr_q;
        data_d      = data_q;

        if (flush_i) begin // Flush
            read_ptr_d  = '0;
            write_ptr_d = '0;
            valid_o     = 1'b0;
            ready_o     = 1'b0;
        end else begin
            // Read
            valid_o = read_ptr_q[PointerWidth-1] == write_ptr_q[PointerWidth-1]
                ? read_ptr_q[PointerWidth-2:0] != write_ptr_q[PointerWidth-2:0] : 1'b1;
            if (ready_i && valid_o) begin
                if (read_ptr_q[PointerWidth-2:0] == (Depth-1)) begin
                    // On overflow reset pointer to zero and flip imaginary bit
                    read_ptr_d[PointerWidth-2:0] = '0;
                    read_ptr_d[PointerWidth-1]   = !read_ptr_q[PointerWidth-1];
                end else begin
                    // Increment counter
                    read_ptr_d = read_ptr_q + 'd1;
                end
            end

            // Write -> Also able to write if we read in the same cycle
            ready_o     = (read_ptr_q[PointerWidth-1] == write_ptr_q[PointerWidth-1]
                ? 1'b1 : write_ptr_q[PointerWidth-2:0] != read_ptr_q[PointerWidth-2:0])
                || (SameCycleRW && ready_i && valid_o);

            if (valid_i && ready_o) begin
                load_data = 1'b1;
                data_d[write_ptr_q[PointerWidth-2:0]] = data_i;

                if (write_ptr_q[PointerWidth-2:0] == (Depth-1)) begin
                    // On overflow reset pointer to zero and flip imaginary bit
                    write_ptr_d[PointerWidth-2:0] = '0;
                    write_ptr_d[PointerWidth-1]   = !write_ptr_q[PointerWidth-1];
                end else begin
                    // Increment pointer
                    write_ptr_d = write_ptr_q + 'd1;
                end
            end
        end
    end

    // Flip Flops
    `FF( read_ptr_q,  read_ptr_d, '0, clk_i, rst_ni)
    `FF(write_ptr_q, write_ptr_d, '0, clk_i, rst_ni)

    `FFL(data_q, data_d, load_data, '0, clk_i, rst_ni)


    // no full push
    // `ASSERT_NEVER(CheckFullPush, (!ready_o & valid_i), clk_i, !rst_ni)
    // // empty pop
    // `ASSERT_NEVER(CheckEmptyPop, (!valid_o & ready_i), clk_i, !rst_ni)

endmodule

module master(input logic clk_i, input logic rst_ni, input logic full_o, input logic empty_o, output logic data_i, output logic push_i, input logic data_o);

parameter int MAX_TRANSACTIONS = 8;

typedef enum logic [1:0] {IDLE, TRY_PUSH, WAIT_ONE} state_t;
state_t state;
logic [31:0] cycle_count;
logic data_counter;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cycle_count <= 0;
        state <= IDLE;
        push_i <= 0;
        data_counter <= 0;
    end else begin
        cycle_count <= cycle_count + 1;
        case (state)
            IDLE: begin
                push_i <= 0;
                if ((cycle_count % 4 == 0) || ((cycle_count & (cycle_count - 1)) == 0 && cycle_count != 0)) begin
                    state <= TRY_PUSH;
                end
            end
            TRY_PUSH: begin
                push_i <= 1;
                data_i <= data_counter;
                if (full_o) begin
                    data_counter <= ~data_counter;
                    state <= WAIT_ONE;
                end
            end
            WAIT_ONE: begin
                push_i <= 0;
                state <= IDLE;
            end
        endcase
    end
end

endmodule

module slave(input logic clk_i, input logic rst_ni, input logic empty_o, output logic pop_i);

typedef enum logic [1:0] {IDLE, TRY_POP, WAIT_ONE} state_t;
state_t state;
logic [31:0] cycle_count;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cycle_count <= 0;
        state <= IDLE;
        pop_i <= 0;
    end else begin
        cycle_count <= cycle_count + 1;
        case (state)
            IDLE: begin
                pop_i <= 0;
                if ((cycle_count % 4 == 0) || ((cycle_count & (cycle_count - 1)) == 0 && cycle_count != 0)) begin
                    state <= TRY_POP;
                end
            end
            TRY_POP: begin
                pop_i <= 1;
                if (empty_o) begin
                    state <= WAIT_ONE;
                end
            end
            WAIT_ONE: begin
                pop_i <= 0;
                state <= IDLE;
            end
        endcase
    end
end

endmodule

module tb_fifo(input logic clk_i, input logic rst_ni);

parameter int MAX_TRANSACTIONS = 8;

logic full_o;
logic empty_o;
logic data_i;
logic push_i;
logic data_o;
logic pop_i;

passthrough_stream_fifo #(
    .Depth(MAX_TRANSACTIONS),
    .PrintInfo(1'b1),
    .SameCycleRW(1'b1),
    .type_t(logic)
) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(1'b0),
    .data_i(data_i),
    .valid_i(push_i),
    .ready_o(full_o),
    .data_o(data_o),
    .valid_o(empty_o),
    .ready_i(pop_i)
);
master mst (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .full_o(full_o),
    .empty_o(empty_o),
    .data_i(data_i),
    .push_i(push_i),
    .data_o(data_o)
);

slave slv (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .empty_o(empty_o),
    .pop_i(pop_i)
);

`ifdef STREAM_FIFO_TB_TRACE
logic [31:0] trace_cycle;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        trace_cycle <= 0;
    end else begin
        if (push_i && full_o) begin
            $display("[Cycle %0d] Pushed %0d", trace_cycle, data_i);
        end
        if (pop_i && empty_o) begin
            $display("[Cycle %0d] Popped %0d", trace_cycle, data_o);
        end
        trace_cycle <= trace_cycle + 1;
    end
end
`endif

endmodule
