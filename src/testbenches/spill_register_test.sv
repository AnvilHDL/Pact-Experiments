// Copyright 2021 ETH Zurich and University of Bologna.
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>

// `include "common_cells/assertions.svh"

/// A register with handshakes that completely cuts any combinational paths
/// between the input and output. This spill register can be flushed.
// Copyright 2018 ETH Zurich and University of Bologna.
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>


/// Wrapper around the flushable spill register to maintain back-ward
/// compatibility.
module spill_register #(
  parameter type T      = logic,
  parameter bit  Bypass = 1'b0     // make this spill register transparent
) (
  input  logic clk_i   ,
  input  logic rst_ni  ,
  input  logic valid_i ,
  output logic ready_o ,
  input  T     data_i  ,
  output logic valid_o ,
  input  logic ready_i ,
  output T     data_o
);

  spill_register_flushable #(
    .T(T),
    .Bypass(Bypass)
  ) spill_register_flushable_i (
    .clk_i,
    .rst_ni,
    .valid_i,
    .flush_i(1'b0),
    .ready_o,
    .data_i,
    .valid_o,
    .ready_i,
    .data_o
  );

endmodule

module spill_register_flushable #(
  parameter type T           = logic,
  parameter bit  Bypass      = 1'b0   // make this spill register transparent
) (
  input  logic clk_i   ,
  input  logic rst_ni  ,
  input  logic valid_i ,
  input  logic flush_i ,
  output logic ready_o ,
  input  T     data_i  ,
  output logic valid_o ,
  input  logic ready_i ,
  output T     data_o
);

  if (Bypass) begin : gen_bypass
    assign valid_o = valid_i;
    assign ready_o = ready_i;
    assign data_o  = data_i;
  end else begin : gen_spill_reg
    // The A register.
    T a_data_q;
    logic a_full_q;
    logic a_fill, a_drain;

    always_ff @(posedge clk_i or negedge rst_ni) begin : ps_a_data
      if (!rst_ni)
        a_data_q <= T'('0);
      else if (a_fill)
        a_data_q <= data_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : ps_a_full
      if (!rst_ni)
        a_full_q <= 0;
      else if (a_fill || a_drain)
        a_full_q <= a_fill;
    end

    // The B register.
    T b_data_q;
    logic b_full_q;
    logic b_fill, b_drain;

    always_ff @(posedge clk_i or negedge rst_ni) begin : ps_b_data
      if (!rst_ni)
        b_data_q <= T'('0);
      else if (b_fill)
        b_data_q <= a_data_q;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : ps_b_full
      if (!rst_ni)
        b_full_q <= 0;
      else if (b_fill || b_drain)
        b_full_q <= b_fill;
    end

    // Fill the A register when the A or B register is empty. Drain the A register
    // whenever it is full and being filled, or if a flush is requested.
    assign a_fill = valid_i && ready_o && (!flush_i);
    assign a_drain = (a_full_q && !b_full_q) || flush_i;

    // Fill the B register whenever the A register is drained, but the downstream
    // circuit is not ready. Drain the B register whenever it is full and the
    // downstream circuit is ready, or if a flush is requested.
    assign b_fill = a_drain && (!ready_i) && (!flush_i);
    assign b_drain = (b_full_q && ready_i) || flush_i;

    // We can accept input as long as register B is not full.
    // Note: flush_i and valid_i must not be high at the same time,
    // otherwise an invalid handshake may occur
    assign ready_o = !a_full_q || !b_full_q;

    // The unit provides output as long as one of the registers is filled.
    assign valid_o = a_full_q | b_full_q;

    // We empty the spill register before the slice register.
    assign data_o = b_full_q ? b_data_q : a_data_q;

//     `ifndef COMMON_CELLS_ASSERTS_OFF
//     `ASSERT(flush_valid, flush_i |-> ~valid_i, clk_i, !rst_ni,
//            "Trying to flush and feed the spill register simultaneously. You will lose data!")
//    `endif
  end
endmodule

module master_spill(input logic clk_i, input logic rst_ni, input logic ready_o, output logic valid_i, output logic data_i);

typedef enum logic {IDLE, TRY_PUSH} state_t;
state_t state;
logic [31:0] cycle_count;
logic data_counter;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cycle_count <= 0;
        state <= IDLE;
        valid_i <= 0;
        data_counter <= 0;
    end else begin
        cycle_count <= cycle_count + 1;
        case (state)
            IDLE: begin
                valid_i <= 0;
                if (cycle_count % 2 == 0) begin
                    state <= TRY_PUSH;
                end
            end
            TRY_PUSH: begin
                valid_i <= 1;
                data_i <= data_counter;
                if (ready_o) begin
                    data_counter <= ~data_counter;
                    state <= IDLE;
                end
            end
        endcase
    end
end

`ifdef FORMAL_COMM_SAFETY
// Communication-safety self-report, read hierarchically by the formal
// harness in formal/comm_safety/sv/comm_safety_common.sv.
//   f_attempt : first cycle of a push attempt (the FSM has just entered
//               TRY_PUSH); every attempt is meant to complete exactly one
//               push handshake with the DUT.
//   f_busy    : this participant is in flight (it has started a push and
//               has not yet reached its progress point).
logic f_try_q;
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) f_try_q <= 1'b0;
    else         f_try_q <= (state == TRY_PUSH);
end
wire f_attempt = (state == TRY_PUSH) && !f_try_q;
wire f_busy    = (state == TRY_PUSH);
`endif


endmodule

module slave_spill(input logic clk_i, input logic rst_ni, input logic valid_o, output logic ready_i);

typedef enum logic {IDLE, TRY_POP} state_t;
state_t state;
logic [31:0] cycle_count;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cycle_count <= 0;
        state <= IDLE;
        ready_i <= 0;
    end else begin
        cycle_count <= cycle_count + 1;
        case (state)
            IDLE: begin
                ready_i <= 0;
                if (cycle_count % 4 == 0) begin
                    state <= TRY_POP;
                end
            end
            TRY_POP: begin
                if (valid_o && (cycle_count % 3 == 0)) begin
                    ready_i <= 1;
                    state <= IDLE;
                end else begin
                    ready_i <= 0;
                    state <= IDLE;
                end
            end
        endcase
    end
end

`ifdef FORMAL_COMM_SAFETY
// Communication-safety self-report, read hierarchically by the formal
// harness in formal/comm_safety/sv/comm_safety_common.sv.
//   f_pop_commit : this participant has committed to receive `data` in this
//                  cycle. ready_i is a one-cycle pulse that is raised only
//                  after the FSM decided to pop, so a committed receive that
//                  finds valid_o low is a dropped exchange.
//   f_busy       : the participant is deciding (TRY_POP); it never blocks on
//                  the DUT, so it has no in-flight obligation of its own.
wire f_pop_commit = ready_i;
wire f_busy       = (state == TRY_POP);
`endif


endmodule

module tb_spill(input logic clk_i, input logic rst_ni);

logic valid_i;
logic ready_o;
logic data_i;
logic valid_o;
logic ready_i;
logic data_o;

spill_register_flushable #(
    .T(logic),
    .Bypass(1'b0)
) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .valid_i(valid_i),
    .flush_i(1'b0),
    .ready_o(ready_o),
    .data_i(data_i),
    .valid_o(valid_o),
    .ready_i(ready_i),
    .data_o(data_o)
);

master_spill mst (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .ready_o(ready_o),
    .valid_i(valid_i),
    .data_i(data_i)
);

slave_spill slv (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .valid_o(valid_o),
    .ready_i(ready_i)
);

`ifdef SPILL_REG_TB_TRACE
logic [31:0] trace_cycle;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        trace_cycle <= 0;
    end else begin
        if (valid_i && ready_o) begin
            $display("[Cycle %0d] Enqueued data %0d", trace_cycle, data_i);
        end
        if (valid_o && ready_i) begin
            $display("[Cycle %0d] Received data %0d", trace_cycle, data_o);
        end
        trace_cycle <= trace_cycle + 1;
    end
end
`endif

endmodule
