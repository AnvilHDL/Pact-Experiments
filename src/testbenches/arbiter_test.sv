// Copyright 2018 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
`define COMMON_CELLS_ASSERTS_OFF
/// A trailing zero counter / leading zero counter.
/// Set MODE to 0 for trailing zero counter => cnt_o is the number of trailing zeros (from the LSB)
/// Set MODE to 1 for leading zero counter  => cnt_o is the number of leading zeros  (from the MSB)
/// If the input does not contain a zero, `empty_o` is asserted. Additionally `cnt_o` contains
/// the maximum number of zeros - 1. For example:
///   in_i = 000_0000, empty_o = 1, cnt_o = 6 (mode = 0)
///   in_i = 000_0001, empty_o = 0, cnt_o = 0 (mode = 0)
///   in_i = 000_1000, empty_o = 0, cnt_o = 3 (mode = 0)
/// Furthermore, this unit contains a more efficient implementation for Verilator (simulation only).
/// This speeds up simulation significantly.

package cf_math_pkg;

    /// Ceiled Division of Two Natural Numbers
    ///
    /// Returns the quotient of two natural numbers, rounded towards plus infinity.
    function automatic integer ceil_div (input longint dividend, input longint divisor);
        automatic longint remainder;

        // pragma translate_off
        `ifndef VERILATOR
        if (dividend < 0) begin
            $fatal(1, "Dividend %0d is not a natural number!", dividend);
        end

        if (divisor < 0) begin
            $fatal(1, "Divisor %0d is not a natural number!", divisor);
        end

        if (divisor == 0) begin
            $fatal(1, "Division by zero!");
        end
        `endif
        // pragma translate_on

        remainder = dividend;
        for (ceil_div = 0; remainder > 0; ceil_div++) begin
            remainder = remainder - divisor;
        end
    endfunction

    /// Index width required to be able to represent up to `num_idx` indices as a binary
    /// encoded signal.
    /// Ensures that the minimum width if an index signal is `1`, regardless of parametrization.
    ///
    /// Sample usage in type definition:
    /// As parameter:
    ///   `parameter type idx_t = logic[cf_math_pkg::idx_width(NumIdx)-1:0]`
    /// As typedef:
    ///   `typedef logic [cf_math_pkg::idx_width(NumIdx)-1:0] idx_t`
    function automatic integer unsigned idx_width (input integer unsigned num_idx);
        return (num_idx > 32'd1) ? unsigned'($clog2(num_idx)) : 32'd1;
    endfunction

endpackage


module lzc #(
  /// The width of the input vector.
  parameter int unsigned WIDTH = 2,
  /// Mode selection: 0 -> trailing zero, 1 -> leading zero
  parameter bit          MODE  = 1'b0,
  /// Dependent parameter. Do **not** change!
  ///
  /// Width of the output signal with the zero count.
  parameter int unsigned CNT_WIDTH = cf_math_pkg::idx_width(WIDTH)
) (
  /// Input vector to be counted.
  input  logic [WIDTH-1:0]     in_i,
  /// Count of the leading / trailing zeros.
  output logic [CNT_WIDTH-1:0] cnt_o,
  /// Counter is empty: Asserted if all bits in in_i are zero.
  output logic                 empty_o
);

  if (WIDTH == 1) begin : gen_degenerate_lzc

    assign cnt_o[0] = !in_i[0];
    assign empty_o = !in_i[0];

  end else begin : gen_lzc

    localparam int unsigned NumLevels = $clog2(WIDTH);

  `ifndef COMMON_CELLS_ASSERTS_OFF
    `ASSERT_INIT(width_0, WIDTH > 0, "input must be at least one bit wide")
  `endif

    logic [WIDTH-1:0][NumLevels-1:0] index_lut;
    logic [2**NumLevels-1:0] sel_nodes;
    logic [2**NumLevels-1:0][NumLevels-1:0] index_nodes;

    logic [WIDTH-1:0] in_tmp;

    // reverse vector if required
    always_comb begin : flip_vector
      for (int unsigned i = 0; i < WIDTH; i++) begin
        in_tmp[i] = (MODE) ? in_i[WIDTH-1-i] : in_i[i];
      end
    end

    for (genvar j = 0; unsigned'(j) < WIDTH; j++) begin : g_index_lut
      assign index_lut[j] = (NumLevels)'(unsigned'(j));
    end

    for (genvar level = 0; unsigned'(level) < NumLevels; level++) begin : g_levels
      if (unsigned'(level) == NumLevels - 1) begin : g_last_level
        for (genvar k = 0; k < 2 ** level; k++) begin : g_level
          // if two successive indices are still in the vector...
          if (unsigned'(k) * 2 < WIDTH - 1) begin : g_reduce
            assign sel_nodes[2 ** level - 1 + k] = in_tmp[k * 2] | in_tmp[k * 2 + 1];
            assign index_nodes[2 ** level - 1 + k] = (in_tmp[k * 2] == 1'b1)
              ? index_lut[k * 2] :
                index_lut[k * 2 + 1];
          end
          // if only the first index is still in the vector...
          if (unsigned'(k) * 2 == WIDTH - 1) begin : g_base
            assign sel_nodes[2 ** level - 1 + k] = in_tmp[k * 2];
            assign index_nodes[2 ** level - 1 + k] = index_lut[k * 2];
          end
          // if index is out of range
          if (unsigned'(k) * 2 > WIDTH - 1) begin : g_out_of_range
            assign sel_nodes[2 ** level - 1 + k] = 1'b0;
            assign index_nodes[2 ** level - 1 + k] = '0;
          end
        end
      end else begin : g_not_last_level
        for (genvar l = 0; l < 2 ** level; l++) begin : g_level
          assign sel_nodes[2 ** level - 1 + l] =
              sel_nodes[2 ** (level + 1) - 1 + l * 2] | sel_nodes[2 ** (level + 1) - 1 + l * 2 + 1];
          assign index_nodes[2 ** level - 1 + l] = (sel_nodes[2 ** (level + 1) - 1 + l * 2] == 1'b1)
            ? index_nodes[2 ** (level + 1) - 1 + l * 2] :
              index_nodes[2 ** (level + 1) - 1 + l * 2 + 1];
        end
      end
    end

    assign cnt_o = NumLevels > unsigned'(0) ? index_nodes[0] : {($clog2(WIDTH)) {1'b0}};
    assign empty_o = NumLevels > unsigned'(0) ? ~sel_nodes[0] : ~(|in_i);

  end : gen_lzc

`ifndef COMMON_CELLS_ASSERTS_OFF
  `ASSERT_INIT(width_0, WIDTH >= 1, "The WIDTH must at least be one bit wide!")
`endif

endmodule : lzc



// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
//         Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>, ETH Zurich
// Date: 02.04.2019
// Description: logarithmic arbitration tree with round robin arbitration scheme.

// `include "common_cells/assertions.svh"

/// The rr_arb_tree employs non-starving round robin-arbitration - i.e., the priorities
/// rotate each cycle.
///
/// ## Fair vs. unfair Arbitration
///
/// This refers to fair throughput distribution when not all inputs have active requests.
/// This module has an internal state `rr_q` which defines the highest priority input. (When
/// `ExtPrio` is `1'b1` this state is provided from the outside.) The arbitration tree will
/// choose the input with the same index as currently defined by the state if it has an active
/// request. Otherwise a *random* other active input is selected. The parameter `FairArb` is used
/// to distinguish between two methods of calculating the next state.
/// * `1'b0`: The next state is calculated by advancing the current state by one. This leads to the
///           state being calculated without the context of the active request. Leading to an
///           unfair throughput distribution if not all inputs have active requests.
/// * `1'b1`: The next state jumps to the next unserved request with higher index.
///           This is achieved by using two trailing-zero-counters (`lzc`). The upper has the masked
///           `req_i` signal with all indices which will have a higher priority in the next state.
///           The trailing zero count defines the input index with the next highest priority after
///           the current one is served. When the upper is empty the lower `lzc` provides the
///           wrapped index if there are outstanding requests with lower or same priority.
/// The implication of throughput fairness on the module timing are:
/// * The trailing zero counter (`lzc`) has a loglog relation of input to output timing. This means
///   that in this module the input to register path scales with Log(Log(`NumIn`)).
/// * The `rr_arb_tree` data multiplexing scales with Log(`NumIn`). This means that the input to output
///   timing path of this module also scales scales with Log(`NumIn`).
/// This implies that in this module the input to output path is always longer than the input to
/// register path. As the output data usually also terminates in a register the parameter `FairArb`
/// only has implications on the area. When it is `1'b0` a static plus one adder is instantiated.
/// If it is `1'b1` two `lzc`, a masking logic stage and a two input multiplexer are instantiated.
/// However these are small in respect of the data multiplexers needed, as the width of the `req_i`
/// signal is usually less as than `DataWidth`.
localparam int unsigned NumIn = 8;
localparam int unsigned DataWidth = 1;
typedef logic DataType;
localparam bit FairArb = 1'b1;
localparam bit ExtPrio = 1'b0;
localparam bit LockIn = 1'b0;
localparam bit AxiVldRdy = 1'b0;
localparam int unsigned IdxWidth = 3;
typedef logic[2:0] idx_t;

module rr_arb_tree (
  /// Clock, positive edge triggered.
  input  logic                clk_i,
  /// Asynchronous reset, active low.
  input  logic                rst_ni,
  /// Clears the arbiter state. Only used if `ExtPrio` is `1'b0` or `LockIn` is `1'b1`.
  input  logic                flush_i,
  /// External round-robin priority. Only used if `ExtPrio` is `1'b1.`
  input  idx_t                rr_i,
  /// Input requests arbitration.
  input  logic    [NumIn-1:0] req_i,
  /* verilator lint_off UNOPTFLAT */
  /// Input request is granted.
  output logic    [NumIn-1:0] gnt_o,
  /* verilator lint_on UNOPTFLAT */
  /// Input data for arbitration.
  input  DataType [NumIn-1:0] data_i,
  /// Output request is valid.
  output logic                req_o,
  /// Output request is granted.
  input  logic                gnt_i,
  /// Output data.
  output DataType             data_o,
  /// Index from which input the data came from.
  output idx_t                idx_o
);

  // just pass through in this corner case
  if (NumIn == unsigned'(1)) begin : gen_pass_through
    assign req_o    = req_i[0];
    assign gnt_o[0] = gnt_i;
    assign data_o   = data_i[0];
    assign idx_o    = '0;
  // non-degenerate cases
  end else begin : gen_arbiter
    localparam int unsigned NumLevels = unsigned'($clog2(NumIn));

    /* verilator lint_off UNOPTFLAT */
    idx_t    [2**NumLevels-2:0] index_nodes; // used to propagate the indices
    DataType [2**NumLevels-2:0] data_nodes;  // used to propagate the data
    logic    [2**NumLevels-2:0] gnt_nodes;   // used to propagate the grant to masters
    logic    [2**NumLevels-2:0] req_nodes;   // used to propagate the requests to slave
    /* lint_off */
    idx_t                       rr_q;
    logic [NumIn-1:0]           req_d;

    // the final arbitration decision can be taken from the root of the tree
    assign req_o        = req_nodes[0];
    assign data_o       = data_nodes[0];
    assign idx_o        = index_nodes[0];

    if (ExtPrio) begin : gen_ext_rr
      assign rr_q       = rr_i;
      assign req_d      = req_i;
    end else begin : gen_int_rr
      idx_t rr_d;

      // lock arbiter decision in case we got at least one req and no acknowledge
      if (LockIn) begin : gen_lock
        logic  lock_d, lock_q;
        logic [NumIn-1:0] req_q;

        assign lock_d     = req_o & ~gnt_i;
        assign req_d      = (lock_q) ? req_q : req_i;

        always_ff @(posedge clk_i or negedge rst_ni) begin : p_lock_reg
          if (!rst_ni) begin
            lock_q <= '0;
          end else begin
            if (flush_i) begin
              lock_q <= '0;
            end else begin
              lock_q <= lock_d;
            end
          end
        end

        `ifndef COMMON_CELLS_ASSERTS_OFF
          `ASSERT(lock, req_o && (!gnt_i && !flush_i) |=> idx_o == $past(idx_o),
                  clk_i, !rst_ni || flush_i,
                  "Lock implies same arbiter decision in next cycle if output is not ready.")

          logic [NumIn-1:0] req_tmp;
          assign req_tmp = req_q & req_i;
          `ASSUME(lock_req, lock_d |=> req_tmp == req_q, clk_i, !rst_ni || flush_i,
                  "It is disallowed to deassert unserved request signals when LockIn is enabled.")
        `endif

        always_ff @(posedge clk_i or negedge rst_ni) begin : p_req_regs
          if (!rst_ni) begin
            req_q  <= '0;
          end else begin
            if (flush_i) begin
              req_q  <= '0;
            end else begin
              req_q  <= req_d;
            end
          end
        end
      end else begin : gen_no_lock
        assign req_d = req_i;
      end

      if (FairArb) begin : gen_fair_arb
        logic [NumIn-1:0] upper_mask,  lower_mask;
        idx_t             upper_idx,   lower_idx,   next_idx;
        logic             upper_empty, lower_empty;

        for (genvar i = 0; i < NumIn; i++) begin : gen_mask
          assign upper_mask[i] = (i >  rr_q) ? req_d[i] : 1'b0;
          assign lower_mask[i] = (i <= rr_q) ? req_d[i] : 1'b0;
        end

        lzc #(
          .WIDTH ( NumIn ),
          .MODE  ( 1'b0  )
        ) i_lzc_upper (
          .in_i    ( upper_mask  ),
          .cnt_o   ( upper_idx   ),
          .empty_o ( upper_empty )
        );

        lzc #(
          .WIDTH ( NumIn ),
          .MODE  ( 1'b0  )
        ) i_lzc_lower (
          .in_i    ( lower_mask  ),
          .cnt_o   ( lower_idx   ),
          .empty_o ( /*unused*/  )
        );

        assign next_idx = upper_empty      ? lower_idx : upper_idx;
        assign rr_d     = (gnt_i && req_o) ? next_idx  : rr_q;

      end else begin : gen_unfair_arb
        assign rr_d = (gnt_i && req_o) ? ((rr_q == idx_t'(NumIn-1)) ? '0 : rr_q + 1'b1) : rr_q;
      end

      // this holds the highest priority
      always_ff @(posedge clk_i or negedge rst_ni) begin : p_rr_regs
        if (!rst_ni) begin
          rr_q   <= '0;
        end else begin
          if (flush_i) begin
            rr_q   <= '0;
          end else begin
            rr_q   <= rr_d;
          end
        end
      end
    end

    assign gnt_nodes[0] = gnt_i;

    // arbiter tree
    for (genvar level = 0; unsigned'(level) < NumLevels; level++) begin : gen_levels
      for (genvar l = 0; l < 2**level; l++) begin : gen_level
        // local select signal
        logic sel;
        // index calcs
        localparam int unsigned Idx0 = 2**level-1+l;// current node
        localparam int unsigned Idx1 = 2**(level+1)-1+l*2;
        //////////////////////////////////////////////////////////////
        // uppermost level where data is fed in from the inputs
        if (unsigned'(level) == NumLevels-1) begin : gen_first_level
          // if two successive indices are still in the vector...
          if (unsigned'(l) * 2 < NumIn-1) begin : gen_reduce
            assign req_nodes[Idx0]   = req_d[l*2] | req_d[l*2+1];

            // arbitration: round robin
            assign sel =  ~req_d[l*2] | req_d[l*2+1] & rr_q[NumLevels-1-level];

            assign index_nodes[Idx0] = idx_t'(sel);
            assign data_nodes[Idx0]  = (sel) ? data_i[l*2+1] : data_i[l*2];
            assign gnt_o[l*2]        = gnt_nodes[Idx0] & (AxiVldRdy | req_d[l*2])   & ~sel;
            assign gnt_o[l*2+1]      = gnt_nodes[Idx0] & (AxiVldRdy | req_d[l*2+1]) & sel;
          end
          // if only the first index is still in the vector...
          if (unsigned'(l) * 2 == NumIn-1) begin : gen_first
            assign req_nodes[Idx0]   = req_d[l*2];
            assign index_nodes[Idx0] = '0;// always zero in this case
            assign data_nodes[Idx0]  = data_i[l*2];
            assign gnt_o[l*2]        = gnt_nodes[Idx0] & (AxiVldRdy | req_d[l*2]);
          end
          // if index is out of range, fill up with zeros (will get pruned)
          if (unsigned'(l) * 2 > NumIn-1) begin : gen_out_of_range
            assign req_nodes[Idx0]   = 1'b0;
            assign index_nodes[Idx0] = idx_t'('0);
            assign data_nodes[Idx0]  = DataType'('0);
          end
        //////////////////////////////////////////////////////////////
        // general case for other levels within the tree
        end else begin : gen_other_levels
          assign req_nodes[Idx0]   = req_nodes[Idx1] | req_nodes[Idx1+1];

          // arbitration: round robin
          assign sel =  ~req_nodes[Idx1] | req_nodes[Idx1+1] & rr_q[NumLevels-1-level];

          assign index_nodes[Idx0] = (sel) ?
            idx_t'({1'b1, index_nodes[Idx1+1][NumLevels-unsigned'(level)-2:0]}) :
            idx_t'({1'b0, index_nodes[Idx1][NumLevels-unsigned'(level)-2:0]});

          assign data_nodes[Idx0]  = (sel) ? data_nodes[Idx1+1] : data_nodes[Idx1];
          assign gnt_nodes[Idx1]   = gnt_nodes[Idx0] & ~sel;
          assign gnt_nodes[Idx1+1] = gnt_nodes[Idx0] & sel;
        end
        //////////////////////////////////////////////////////////////
      end
    end

    `ifndef COMMON_CELLS_ASSERTS_OFF
    `ASSERT_INIT(numin_0, NumIn, "Input must be at least one element wide.")
    `ASSERT_INIT(lockin_and_extprio, !(LockIn && ExtPrio),
                 "Cannot use LockIn feature together with external ExtPrio.")

    `ASSERT(hot_one, $onehot0(gnt_o), clk_i, !rst_ni || flush_i,
            "Grant signal must be hot1 or zero.")

    `ASSERT(gnt0, |gnt_o |-> gnt_i, clk_i, !rst_ni || flush_i, "Grant out implies grant in.")

    `ASSERT(gnt1, req_o |-> gnt_i |-> |gnt_o, clk_i, !rst_ni || flush_i,
            "Req out and grant in implies grant out.")

    `ASSERT(gnt_idx, req_o |->  gnt_i |-> gnt_o[idx_o], clk_i, !rst_ni || flush_i,
            "Idx_o / gnt_o do not match.")

    `ASSERT(req0, |req_i |-> req_o, clk_i, !rst_ni || flush_i, "Req in implies req out.")

    `ASSERT(req1, req_o |-> |req_i, clk_i, !rst_ni || flush_i, "Req out implies req in.")
    `endif
  end

endmodule : rr_arb_tree

module slave_arb(input logic clk_i, input logic rst_ni, output logic req_o, input logic gnt_i, output DataType data_o, input logic [1:0] id);

typedef enum logic {IDLE, REQUESTING} state_t;
state_t state;
logic [31:0] cycle_count;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cycle_count <= 0;
        state <= IDLE;
        req_o <= 0;
        data_o <= 0;
    end else begin
        cycle_count <= cycle_count + 1;
        case (state)
            IDLE: begin
                req_o <= 0;
                if ((cycle_count % 3 == 0) || ((cycle_count & (cycle_count - 1)) == 0 && cycle_count != 0)) begin
                    state <= REQUESTING;
                    req_o <= 1;
                    data_o <= DataType'(id);
                end
            end
            REQUESTING: begin
                req_o <= 1;
                data_o <= DataType'(id);
                if (gnt_i) begin
                    state <= IDLE;
                    req_o <= 0;
                end
            end
        endcase
    end
end

`ifdef FORMAL_COMM_SAFETY
// Communication-safety self-report, read hierarchically by the formal
// harness in formal/comm_safety/sv/comm_safety_common.sv.
//   f_req  : this participant is requesting and expects exactly one grant.
//   f_busy : in flight (waiting for that grant).
wire f_req  = (state == REQUESTING);
wire f_busy = (state == REQUESTING);
`endif


endmodule

module master_arb(input logic clk_i, input logic rst_ni, input logic req_o, input DataType data_o, input idx_t idx_o, output logic gnt_i);

logic [31:0] cycle_count;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cycle_count <= 0;
        gnt_i <= 0;
    end else begin
        cycle_count <= cycle_count + 1;
        gnt_i <= ((cycle_count % 7 == 0) || ((cycle_count & (cycle_count - 1)) == 0 && cycle_count != 0)) && req_o;
    end
end

`ifdef FORMAL_COMM_SAFETY
// Communication-safety self-report, read hierarchically by the formal
// harness in formal/comm_safety/sv/comm_safety_common.sv.
//   f_gnt : this participant is issuing a grant in this cycle; a grant that
//           meets no pending request is a phantom exchange.
wire f_gnt = gnt_i;
`endif


endmodule

module tb_arbiter(input logic clk_i, input logic rst_ni);

localparam int unsigned NumSlaves = 4;

logic [NumSlaves-1:0] req_i;
logic [NumSlaves-1:0] gnt_o;
DataType [NumSlaves-1:0] data_i;
logic req_o;
logic gnt_i;
DataType data_o;
idx_t idx_o;

rr_arb_tree dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(1'b0),
    .rr_i('0),
    .req_i(req_i),
    .gnt_o(gnt_o),
    .data_i(data_i),
    .req_o(req_o),
    .gnt_i(gnt_i),
    .data_o(data_o),
    .idx_o(idx_o)
);

genvar i;
generate
    for (i = 0; i < NumSlaves; i++) begin : gen_slaves
        slave_arb slave (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .req_o(req_i[i]),
            .gnt_i(gnt_o[i]),
            .data_o(data_i[i]),
            .id(i[1:0])
        );
    end
endgenerate

master_arb mst (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .req_o(req_o),
    .data_o(data_o),
    .idx_o(idx_o),
    .gnt_i(gnt_i)
);

`ifdef ARBITER_TB_TRACE
logic [31:0] trace_cycle;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        trace_cycle <= 0;
    end else begin
        if (req_o && gnt_i) begin
            $display("[Cycle %0d] Master granted slave %0d data %0d",
                     trace_cycle, idx_o, data_o);
        end
        trace_cycle <= trace_cycle + 1;
    end
end
`endif

endmodule
