`ifdef FORMAL_COMM_SAFETY

`ifdef FORMAL_COMM_FIFO_FULL_DESIGN
module comm_fifo_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned MaxTransactions = 8;
  localparam int unsigned Bound = 64;

  logic full_o;
  logic empty_o;
  logic push_i;
  logic pop_i;
  logic shadow_full_req;
  logic shadow_empty_req;
  logic shadow_push_req;
  logic shadow_pop_req;

  tb_fifo #(
    .MAX_TRANSACTIONS(MaxTransactions)
  ) full_design (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .formal_full_o(full_o),
    .formal_empty_o(empty_o),
    .formal_push_i(push_i),
    .formal_pop_i(pop_i),
    .formal_shadow_full_req(shadow_full_req),
    .formal_shadow_empty_req(shadow_empty_req),
    .formal_shadow_push_req(shadow_push_req),
    .formal_shadow_pop_req(shadow_pop_req)
  );

  logic f_past_valid = 1'b0;
  (* anyseq *) logic track_this_push;
  logic tracking_push;
  logic [$clog2(Bound+1)-1:0] live_age;

  wire push_fire = push_i && !full_o;
  wire pop_fire = pop_i && !empty_o;

  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      tracking_push <= 1'b0;
      live_age <= '0;
    end else begin
      // Sync Safety Properties
      assert(!push_i || !full_o);
      assert(!pop_i || !empty_o);

      assert(shadow_push_req == push_fire);
      assert(shadow_pop_req == pop_fire);
      assert(shadow_full_req == full_o);
      assert(shadow_empty_req == empty_o);


      // Bounded Liveness Property
      if (!tracking_push && push_fire && track_this_push) begin
        tracking_push <= 1'b1;
        live_age <= '0;
      end else if (tracking_push && pop_fire) begin
        tracking_push <= 1'b0;
        live_age <= '0;
      end else if (tracking_push) begin
        live_age <= live_age + 1'b1;
        assert(live_age < Bound);
      end else begin
        live_age <= '0;
      end
    end
  end
endmodule
`endif

module comm_spill_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned Bound = 8;
  typedef logic [1:0] data_t;

  (* anyseq *) logic valid_i;
  (* anyseq *) logic ready_i;
  (* anyseq *) data_t data_i;

  logic ready_o;
  logic valid_o;
  data_t data_o;

  spill_register_flushable #(
    .T(data_t),
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

  logic f_past_valid = 1'b0;
  logic [1:0] shadow_count;
  data_t shadow_mem [1:0];
  logic head, tail;
  logic [$clog2(Bound+1)-1:0] live_age;

  wire in_fire = valid_i && ready_o;
  wire out_fire = valid_o && ready_i;

  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shadow_count <= '0;
      head <= 1'b0;
      tail <= 1'b0;
      live_age <= '0;
    end else begin
      assert(shadow_count <= 2);
      assert(valid_o == (shadow_count != 0));
      assert(ready_o == (shadow_count != 2));

      if (out_fire) begin
        assert(shadow_count != 0);
        assert(data_o == shadow_mem[head]);
      end

      if (in_fire && !out_fire) begin
        assert(shadow_count < 2);
        shadow_count <= shadow_count + 1'b1;
      end else if (out_fire && !in_fire) begin
        assert(shadow_count != 0);
        shadow_count <= shadow_count - 1'b1;
      end

      if (in_fire) begin
        shadow_mem[tail] <= data_i;
        tail <= ~tail;
      end
      if (out_fire) begin
        head <= ~head;
      end

      if (shadow_count != 0 && !out_fire) begin
        live_age <= live_age + 1'b1;
        assume(live_age < Bound);
        assert(live_age < Bound);
      end else begin
        live_age <= '0;
      end
    end
  end
endmodule

module comm_stream_fifo_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned Depth = 4;
  localparam int unsigned Bound = 12;
  typedef logic [1:0] data_t;

  (* anyseq *) logic valid_i;
  (* anyseq *) logic ready_i;
  (* anyseq *) data_t data_i;

  logic ready_o;
  logic valid_o;
  data_t data_o;

  passthrough_stream_fifo #(
    .Depth(Depth),
    .PrintInfo(1'b0),
    .SameCycleRW(1'b1),
    .type_t(data_t)
  ) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(1'b0),
    .testmode_i(1'b0),
    .data_i(data_i),
    .valid_i(valid_i),
    .ready_o(ready_o),
    .data_o(data_o),
    .valid_o(valid_o),
    .ready_i(ready_i)
  );

  logic f_past_valid = 1'b0;
  logic [$clog2(Depth+1)-1:0] shadow_count;
  logic [$clog2(Depth)-1:0] head, tail;
  data_t shadow_mem [Depth-1:0];
  logic [$clog2(Bound+1)-1:0] live_age;

  wire in_fire = valid_i && ready_o;
  wire out_fire = valid_o && ready_i;

  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shadow_count <= '0;
      head <= '0;
      tail <= '0;
      live_age <= '0;
    end else begin
      assert(shadow_count <= Depth);
      assume(!valid_i || ready_o);
      assume(!ready_i || valid_o);
      assert(valid_o == (shadow_count != 0));
      if (!(ready_i && valid_o)) begin
        assert(ready_o == (shadow_count != Depth));
      end

      if (out_fire) begin
        assert(shadow_count != 0);
        assert(data_o == shadow_mem[head]);
      end

      if (in_fire && !out_fire) begin
        assert(shadow_count < Depth);
        shadow_count <= shadow_count + 1'b1;
      end else if (out_fire && !in_fire) begin
        assert(shadow_count != 0);
        shadow_count <= shadow_count - 1'b1;
      end

      if (in_fire) begin
        shadow_mem[tail] <= data_i;
        tail <= (tail == Depth-1) ? '0 : tail + 1'b1;
      end
      if (out_fire) begin
        head <= (head == Depth-1) ? '0 : head + 1'b1;
      end

      if (shadow_count != 0 && !out_fire) begin
        live_age <= live_age + 1'b1;
        assume(live_age < Bound);
        assert(live_age < Bound);
      end else begin
        live_age <= '0;
      end
    end
  end
endmodule

module comm_arbiter_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned NumIn = 4;
  localparam int unsigned Bound = 8;

  (* anyseq *) logic [NumIn-1:0] req_i;
  logic [NumIn-1:0] gnt_o;
  logic [NumIn-1:0] data_i;
  logic req_o;
  logic data_o;
  logic [1:0] idx_o;
  logic [$clog2(Bound+1)-1:0] age [NumIn-1:0];

  assign data_i = 4'b1010;

  rr_arb_tree #(
    .NumIn(NumIn),
    .DataWidth(1),
    .DataType(logic),
    .ExtPrio(1'b0),
    .AxiVldRdy(1'b0),
    .LockIn(1'b0),
    .FairArb(1'b1)
  ) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(1'b0),
    .rr_i('0),
    .req_i(req_i),
    .gnt_o(gnt_o),
    .data_i(data_i),
    .req_o(req_o),
    .gnt_i(1'b1),
    .data_o(data_o),
    .idx_o(idx_o)
  );

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < NumIn; i++) begin
        age[i] <= '0;
      end
    end else begin
      assert(req_o == (|req_i));
      assert((gnt_o & (gnt_o - 1'b1)) == '0);
      for (int i = 0; i < NumIn; i++) begin
        assert(!gnt_o[i] || req_i[i]);
        if ($past(req_i[i]) && !$past(gnt_o[i])) begin
          assume(req_i[i]);
        end
        if (req_i[i] && !gnt_o[i]) begin
          age[i] <= age[i] + 1'b1;
          assert(age[i] < Bound);
        end else begin
          age[i] <= '0;
        end
      end
    end
  end
endmodule

`endif
