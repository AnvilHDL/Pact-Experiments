module fifo_v3 #(
    parameter bit          FALL_THROUGH = 1'b0, // fifo is in fall-through mode
    parameter int unsigned DATA_WIDTH   = 1,   // default data width if the fifo is of type logic
    parameter int unsigned DEPTH        = 8,    // depth can be arbitrary from 0 to 2**32
    parameter type dtype                = logic [DATA_WIDTH-1:0],
    parameter int unsigned ADDR_DEPTH   = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input  logic  clk_i,            // Clock
    input  logic  rst_ni,           // Asynchronous reset active low
    input  logic  flush_i,          // flush the queue
    input  logic  testmode_i,       // test_mode to bypass clock gating
    // status flags
    output logic  full_o,           // queue is full
    output logic  empty_o,          // queue is empty
    output logic  [ADDR_DEPTH-1:0] usage_o,  // fill pointer
    // as long as the queue is not full we can push new data
    input  dtype  data_i,           // data to push into the queue
    input  logic  push_i,           // data is valid and can be pushed to the queue
    // as long as the queue is not empty we can pop new elements
    output dtype  data_o,           // output data
    input  logic  pop_i ,           // pop head from queue
    output logic push_req,           // push request, shadow signal to say push request was accepted
    output logic pop_req ,            // pop request, shadow signal to say pop request was accepted
    output logic progress_o           // signal to indicate progress (either push or pop was accepted)
);
    // FIFO depth - handle the case of pass-through, synthesizer will do constant propagation
    localparam int unsigned FifoDepth = (DEPTH > 0) ? DEPTH : 1;
    // clock gating control
    logic gate_clock;
    logic progress_n, progress_q;

    assign progress_o = progress_q;
    // pointer to the read and write section of the queue
    logic [ADDR_DEPTH - 1:0] read_pointer_n, read_pointer_q, write_pointer_n, write_pointer_q;
    // keep a counter to keep track of the current queue status
    // this integer will be truncated by the synthesis tool
    logic [ADDR_DEPTH:0] status_cnt_n, status_cnt_q;
    // actual memory
    dtype [FifoDepth - 1:0] mem_n, mem_q;

    assign usage_o = status_cnt_q[ADDR_DEPTH-1:0];

    if (DEPTH == 0) begin : gen_pass_through
        assign empty_o     = ~push_i;
        assign full_o      = ~pop_i;
    end else begin : gen_fifo
        assign full_o       = (status_cnt_q == FifoDepth[ADDR_DEPTH:0]);
        assign empty_o      = (status_cnt_q == 0) & ~(FALL_THROUGH & push_i);
    end
    // status flags

    // read and write queue logic
    always_comb begin : read_write_comb
        // default assignment
        read_pointer_n  = read_pointer_q;
        write_pointer_n = write_pointer_q;
        status_cnt_n    = status_cnt_q;
        data_o          = (DEPTH == 0) ? data_i : mem_q[read_pointer_q];
        mem_n           = mem_q;
        gate_clock      = 1'b1;
        progress_n = 1'b0;

        // push a new element to the queue
        if (push_i && ~full_o) begin
            // push the data onto the queue
            mem_n[write_pointer_q] = data_i;
            push_req = 1'b1;
            // un-gate the clock, we want to write something
            gate_clock = 1'b0;
            progress_n = 1'b1;
            // increment the write counter
            // this is dead code when DEPTH is a power of two
            if (write_pointer_q == FifoDepth[ADDR_DEPTH-1:0] - 1)
                write_pointer_n = '0;
            else
                write_pointer_n = write_pointer_q + 1;
            // increment the overall counter
            status_cnt_n    = status_cnt_q + 1;
        end

        if (pop_i && ~empty_o) begin
            // read from the queue is a default assignment
            // but increment the read pointer...
            // this is dead code when DEPTH is a power of two
            pop_req = 1'b1;
            if (read_pointer_n == FifoDepth[ADDR_DEPTH-1:0] - 1)
                read_pointer_n = '0;
            else
                read_pointer_n = read_pointer_q + 1;
            // ... and decrement the overall count
            status_cnt_n   = status_cnt_q - 1;
            progress_n = 1'b1;
        end

        // keep the count pointer stable if we push and pop at the same time
        if (push_i && pop_i &&  ~full_o && ~empty_o)
            status_cnt_n   = status_cnt_q;

        // FIFO is in pass through mode -> do not change the pointers
        if (FALL_THROUGH && (status_cnt_q == 0) && push_i) begin
            data_o = data_i;
            if (pop_i) begin
                status_cnt_n = status_cnt_q;
                read_pointer_n = read_pointer_q;
                write_pointer_n = write_pointer_q;
            end
        end
    end

    // sequential process
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            read_pointer_q  <= '0;
            write_pointer_q <= '0;
            status_cnt_q    <= '0;
        end else begin
            if (flush_i) begin
                read_pointer_q  <= '0;
                write_pointer_q <= '0;
                status_cnt_q    <= '0;
                progress_q      <= '0;
             end else begin
                read_pointer_q  <= read_pointer_n;
                write_pointer_q <= write_pointer_n;
                status_cnt_q    <= status_cnt_n;
                progress_q      <= progress_n;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            mem_q <= {FifoDepth{dtype'('0)}};
        end else if (!gate_clock) begin
            mem_q <= mem_n;
        end
    end

endmodule // fifo_v3

module master(input logic clk_i, input logic rst_ni, input logic full_o, input logic empty_o, output logic data_i, output logic push_i, input logic data_o,  output logic full_req);

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
                if ((cycle_count % 3 == 0) || ((cycle_count & (cycle_count - 1)) == 0 && cycle_count != 0)) begin
                    state <= TRY_PUSH;
                end
            end
            TRY_PUSH: begin
                if (!full_o) begin
                    push_i <= 1;
                    data_i <= data_counter;
                    data_counter <= ~data_counter;
                    state <= WAIT_ONE;
                end else begin
                    full_req <= 1;
                    push_i <= 0;
                    // stay in TRY_PUSH
                end
            end
            WAIT_ONE: begin
                push_i <= 0;
                state <= IDLE;
                progress_o <= 1;
            end
        endcase
    end
end

endmodule

module slave(input logic clk_i, input logic rst_ni, input logic empty_o, output logic pop_i, output logic empty_req);

typedef enum logic [1:0] {IDLE, TRY_POP, WAIT_ONE} state_t;
state_t state;
logic [31:0] cycle_count;

assign pop_i = (state == TRY_POP && !empty_o);

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cycle_count <= 0;
        state <= IDLE;
    end else begin
        cycle_count <= cycle_count + 1;
        case (state)
            IDLE: begin
                if ((cycle_count % 7 == 0) || ((cycle_count & (cycle_count - 1)) == 0 && cycle_count != 0)) begin
                    state <= TRY_POP;
                end
            end
            TRY_POP: begin
                if (!empty_o) begin
                    state <= WAIT_ONE;
                end else begin
                    empty_req <= 1;
                    // stay in TRY_POP
                end
            end
            WAIT_ONE: begin
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
logic shadow_full_req;
logic shadow_empty_req;
logic shadow_push_req;
logic shadow_pop_req;
logic mst_progress;
logic slv_progress;
logic fifo_progress;

logic mst_progress_q;
logic slv_progress_q;
logic  fifo_progress_q;

fifo_v3 #(
    .FALL_THROUGH(1'b0),
    .DEPTH(MAX_TRANSACTIONS),
    .dtype(logic)
) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(1'b0),
    .testmode_i(1'b0),
    .full_o(full_o),
    .empty_o(empty_o),
    .usage_o(),
    .data_i(data_i),
    .push_i(push_i),
    .data_o(data_o),
    .pop_i(pop_i),
    .push_req(shadow_push_req),
    .pop_req(shadow_pop_req),
    .progress_o(fifo_progress)
);

master mst (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .full_o(full_o),
    .empty_o(empty_o),
    .data_i(data_i),
    .push_i(push_i),
    .data_o(data_o),
    .full_req(shadow_full_req),
    .progress_o(mst_progress)
);

slave slv (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .empty_o(empty_o),
    .pop_i(pop_i),
    .pop_req(shadow_empty_req),
    .progress_o(slv_progress)
);

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        mst_progress_q <= 0;
        slv_progress_q <= 0;
        fifo_progress_q <= 0;
    end else begin
        mst_progress_q <= mst_progress;
        slv_progress_q <= slv_progress;
        fifo_progress_q <= fifo_progress;
    end
end

// communication safety properties
assert property (@(posedge clk_i) disable iff (!rst_ni) (full_o |-> shadow_full_req));
assert property (@(posedge clk_i) disable iff (!rst_ni) (empty_o |-> shadow_empty_req));
assert property (@(posedge clk_i) disable iff (!rst_ni) (push_i |-> shadow_push_req));
assert property (@(posedge clk_i) disable iff (!rst_ni) (pop_i |-> shadow_pop_req));

// liveness properties eventually progress_o
assert property (@(posedge clk_i) disable iff (!rst_ni) eventually (mst_progress));
assert property (@(posedge clk_i) disable iff (!rst_ni) eventually (slv_progress));
assert property (@(posedge clk_i) disable iff (!rst_ni) eventually (fifo_progress));

assert property (@(posedge clk_i) disable iff (!rst_ni) (mst_progress_q |-> eventually mst_progress));
assert property (@(posedge clk_i) disable iff (!rst_ni) (slv_progress_q |-> eventually slv_progress));
assert property (@(posedge clk_i) disable iff (!rst_ni) (fifo_progress_q |-> eventually fifo_progress));




endmodule
