module fifo_v3 (
    input  logic  clk_i,            // Clock
    input  logic  rst_ni,           // Asynchronous reset active low
    input  logic  flush_i,          // flush the queue
    input  logic  testmode_i,       // test_mode to bypass clock gating
    // status flags
    output logic  full_o,           // queue is full
    output logic  empty_o,          // queue is empty
    output logic  [2:0] usage_o,    // fill pointer (ADDR_DEPTH-1:0)
    // as long as the queue is not full we can push new data
    input  logic  data_i,           // data to push into the queue
    input  logic  push_i,           // data is valid and can be pushed to the queue
    // as long as the queue is not empty we can pop new elements
    output logic  data_o,           // output data
    input  logic  pop_i,            // pop head from queue
    output logic  push_req,         // push request, shadow signal to say push request was accepted
    output logic  pop_req,          // pop request, shadow signal to say pop request was accepted
    output logic  progress_o        // signal to indicate progress (either push or pop was accepted)
);

    localparam bit          FALL_THROUGH = 1'b0;
    localparam int unsigned DEPTH        = 8;
    localparam int unsigned ADDR_DEPTH   = 3;
    localparam int unsigned FifoDepth    = 8;

    logic gate_clock;
    logic progress_n, progress_q;

    assign progress_o = progress_q;

    logic [ADDR_DEPTH - 1:0] read_pointer_n, read_pointer_q, write_pointer_n, write_pointer_q;
    logic [ADDR_DEPTH:0] status_cnt_n, status_cnt_q;
    
    logic [FifoDepth - 1:0] mem_n, mem_q;

    assign usage_o = status_cnt_q[ADDR_DEPTH-1:0];

    assign full_o  = (status_cnt_q == FifoDepth[ADDR_DEPTH:0]);
    assign empty_o = (status_cnt_q == 0) & ~(FALL_THROUGH & push_i);

    // read and write queue logic
    always_comb begin : read_write_comb
        // default assignments
        read_pointer_n  = read_pointer_q;
        write_pointer_n = write_pointer_q;
        status_cnt_n    = status_cnt_q;
        data_o          = mem_q[read_pointer_q];
        mem_n           = mem_q;
        gate_clock      = 1'b1;
        progress_n      = 1'b0;
        push_req        = 1'b0; // Added default to prevent formal latches
        pop_req         = 1'b0; // Added default to prevent formal latches

        // push a new element to the queue
        if (push_i && ~full_o) begin
            mem_n[write_pointer_q] = data_i;
            push_req = 1'b1;
            gate_clock = 1'b0;
            progress_n = 1'b1;
            if (write_pointer_q == FifoDepth[ADDR_DEPTH-1:0] - 1)
                write_pointer_n = '0;
            else
                write_pointer_n = write_pointer_q + 1;
            status_cnt_n = status_cnt_q + 1;
        end

        if (pop_i && ~empty_o) begin
            pop_req = 1'b1;
            if (read_pointer_n == FifoDepth[ADDR_DEPTH-1:0] - 1)
                read_pointer_n = '0;
            else
                read_pointer_n = read_pointer_q + 1;
            status_cnt_n = status_cnt_q - 1;
            progress_n = 1'b1;
        end

        // keep the count pointer stable if we push and pop at the same time
        if (push_i && pop_i && ~full_o && ~empty_o)
            status_cnt_n = status_cnt_q;

        // FIFO is in pass through mode
        if (FALL_THROUGH && (status_cnt_q == 0) && push_i) begin
            data_o = data_i;
            if (pop_i) begin
                status_cnt_n = status_cnt_q;
                read_pointer_n = read_pointer_q;
                write_pointer_n = write_pointer_q;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            read_pointer_q  <= '0;
            write_pointer_q <= '0;
            status_cnt_q    <= '0;
            progress_q      <= '0;
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
            mem_q <= '0;
        end else if (!gate_clock) begin
            mem_q <= mem_n;
        end
    end

endmodule // fifo_v3

module master(input logic clk_i, input logic rst_ni, input logic full_o, input logic empty_o, output logic data_i, output logic push_i, input logic data_o,  output logic full_req, output logic progress_o);

    localparam int MAX_TRANSACTIONS = 8;

    typedef enum logic [1:0] {IDLE, TRY_PUSH, WAIT_ONE} state_t;
    state_t state;
    logic [31:0] cycle_count;
    logic data_counter;
    logic mst_progress_q;

    assign progress_o = mst_progress_q;
    assign full_req = full_o;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cycle_count <= 0;
            state <= IDLE;
            push_i <= 0;
            data_counter <= 0;
            data_i <= 0;
            mst_progress_q <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            mst_progress_q <= state == WAIT_ONE;
            case (state)
                IDLE: begin
                    push_i <= 0;
                    if ((cycle_count % 4 == 0) || ((cycle_count & (cycle_count - 1)) == 0 && cycle_count != 0)) begin
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
                        push_i <= 0;
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

module slave(input logic clk_i, input logic rst_ni, input logic empty_o, output logic pop_i, output logic empty_req, output logic progress_o);

    typedef enum logic [1:0] {IDLE, TRY_POP, WAIT_ONE} state_t;
    state_t state;
    logic [31:0] cycle_count;
    logic slv_progress_q;

    assign pop_i = (state == TRY_POP && !empty_o);
    assign progress_o = slv_progress_q;
    assign empty_req = empty_o;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cycle_count <= 0;
            state <= IDLE;
            slv_progress_q <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            slv_progress_q <= state == WAIT_ONE;
            case (state)
                IDLE: begin
                    if ((cycle_count % 4 == 0) || ((cycle_count & (cycle_count - 1)) == 0 && cycle_count != 0)) begin
                        state <= TRY_POP;
                    end
                end
                TRY_POP: begin
                    if (!empty_o) begin
                        state <= WAIT_ONE;
                    end else begin

                    end
                end
                WAIT_ONE: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

module tb_fifo(input logic clk_i, input logic rst_ni,output logic probe_out);

    localparam int MAX_TRANSACTIONS = 8;

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
    logic fifo_progress_q;

    fifo_v3 dut (
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
        .empty_req(shadow_empty_req),
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
assign probe_out = mst_progress_q ^ slv_progress_q ^ fifo_progress_q;
    // Formal properties
    // Formal properties
    always_ff @(posedge clk_i) begin
        // Only evaluate properties when we are out of reset
        if (rst_ni) begin
            
            // 1. Communication Safety Properties (Immediate Assertions)
            // A |-> B is logically equivalent to (!A || B)
            assert (!full_o || shadow_full_req);
            assert (!empty_o || shadow_empty_req);


           if(push_i) assert property (s_eventually shadow_push_req);
           if(pop_i) assert property (s_eventually shadow_pop_req);

            // 2. Unconditional Liveness Properties
            assert property (s_eventually mst_progress);
            assert property (s_eventually slv_progress);
            assert property (s_eventually fifo_progress);

            // 3. Conditional Liveness (Bypassing the '|->' operator)
            if (mst_progress_q)  assert property (s_eventually mst_progress);
            if (slv_progress_q)  assert property (s_eventually slv_progress);
            if (fifo_progress_q) assert property (s_eventually fifo_progress);
            
        end
    end
endmodule