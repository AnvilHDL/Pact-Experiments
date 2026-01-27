// TileLink CrossBar Testbench with 2 Masters and 2 Slaves

module tl_master(
    input logic clk_i,
    input logic rst_ni,
    input logic [1:0] id,
    // D channel (response from crossbar)
    output logic d_ready,
    input logic d_valid,
    input logic [2:0] d_bits_opcode,
    input logic [2:0] d_bits_param,
    input logic [1:0] d_bits_size,
    input logic [1:0] d_bits_source,
    input logic [1:0] d_bits_sink,
    input logic d_bits_denied,
    input logic [7:0] d_bits_data,
    input logic d_bits_corrupt,
    // A channel (request to crossbar)
    input logic a_ready,
    output logic a_valid,
    output logic [2:0] a_bits_opcode,
    output logic [2:0] a_bits_param,
    output logic [1:0] a_bits_size,
    output logic [1:0] a_bits_source,
    output logic [15:0] a_bits_address,
    output logic a_bits_mask,
    output logic [7:0] a_bits_data,
    output logic a_bits_corrupt,
    // Unused channels
    output logic e_valid,
    output logic [1:0] e_bits_sink,
    input logic e_ready,
    output logic c_valid,
    output logic [2:0] c_bits_opcode,
    output logic [2:0] c_bits_param,
    output logic [1:0] c_bits_size,
    output logic [1:0] c_bits_source,
    output logic [15:0] c_bits_address,
    output logic [7:0] c_bits_data,
    output logic c_bits_corrupt,
    input logic c_ready,
    input logic b_valid,
    input logic [2:0] b_bits_opcode,
    input logic [2:0] b_bits_param,
    input logic [1:0] b_bits_size,
    input logic [1:0] b_bits_source,
    input logic [15:0] b_bits_address,
    input logic b_bits_mask,
    input logic [7:0] b_bits_data,
    input logic b_bits_corrupt,
    output logic b_ready
);

typedef enum logic {IDLE, WAITING} state_t;
state_t state;
logic [31:0] cycle_count;

// Accept D channel responses every cycle
assign d_ready = 1'b1;

// Unused channels
assign e_valid = 1'b0;
assign e_bits_sink = 2'b0;
assign c_valid = 1'b0;
assign c_bits_opcode = 3'b0;
assign c_bits_param = 3'b0;
assign c_bits_size = 2'b0;
assign c_bits_source = 2'b0;
assign c_bits_address = 16'b0;
assign c_bits_data = 8'b0;
assign c_bits_corrupt = 1'b0;
assign b_ready = 1'b0;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cycle_count <= 0;
        state <= IDLE;
        a_valid <= 0;
        a_bits_opcode <= 3'b0;
        a_bits_param <= 3'b0;
        a_bits_size <= 2'b0;
        a_bits_source <= id;
        a_bits_address <= 16'b0;
        a_bits_mask <= 1'b1;
        a_bits_data <= 8'b0;
        a_bits_corrupt <= 1'b0;
    end else begin
        cycle_count <= cycle_count + 1;
        case (state)
            IDLE: begin
                a_valid <= 0;
                // Try to send request on even cycles
                if (cycle_count % 2 == 0) begin
                    a_valid <= 1;
                    a_bits_opcode <= 3'b000; // Get
                    a_bits_source <= id;
                    a_bits_address <= {14'b0, id};
                    a_bits_data <= {6'b0, id};
                    state <= WAITING;
                end
            end
            WAITING: begin
                if (a_ready) begin
                    a_valid <= 0;
                    state <= IDLE;
                end
            end
        endcase
    end
end

endmodule

module tl_slave(
    input logic clk_i,
    input logic rst_ni,
    input logic [1:0] id,
    // A channel (request from crossbar)
    output logic a_ready,
    input logic a_valid,
    input logic [2:0] a_bits_opcode,
    input logic [2:0] a_bits_param,
    input logic [1:0] a_bits_size,
    input logic [1:0] a_bits_source,
    input logic [15:0] a_bits_address,
    input logic a_bits_mask,
    input logic [7:0] a_bits_data,
    input logic a_bits_corrupt,
    // D channel (response to crossbar)
    input logic d_ready,
    output logic d_valid,
    output logic [2:0] d_bits_opcode,
    output logic [2:0] d_bits_param,
    output logic [1:0] d_bits_size,
    output logic [1:0] d_bits_source,
    output logic [1:0] d_bits_sink,
    output logic d_bits_denied,
    output logic [7:0] d_bits_data,
    output logic d_bits_corrupt,
    // Unused channels
    input logic e_valid,
    input logic [1:0] e_bits_sink,
    output logic e_ready,
    input logic c_valid,
    input logic [2:0] c_bits_opcode,
    input logic [2:0] c_bits_param,
    input logic [1:0] c_bits_size,
    input logic [1:0] c_bits_source,
    input logic [15:0] c_bits_address,
    input logic [7:0] c_bits_data,
    input logic c_bits_corrupt,
    output logic c_ready,
    output logic b_valid,
    output logic [2:0] b_bits_opcode,
    output logic [2:0] b_bits_param,
    output logic [1:0] b_bits_size,
    output logic [1:0] b_bits_source,
    output logic [15:0] b_bits_address,
    output logic b_bits_mask,
    output logic [7:0] b_bits_data,
    output logic b_bits_corrupt,
    input logic b_ready
);

typedef enum logic {IDLE, RESPONDING} state_t;
state_t state;
logic [31:0] cycle_count;
logic [1:0] pending_source;

// Accept A channel requests every cycle
assign a_ready = 1'b1;

// Unused channels
assign e_ready = 1'b1;
assign c_ready = 1'b0;
assign b_valid = 1'b0;
assign b_bits_opcode = 3'b0;
assign b_bits_param = 3'b0;
assign b_bits_size = 2'b0;
assign b_bits_source = 2'b0;
assign b_bits_address = 16'b0;
assign b_bits_mask = 1'b0;
assign b_bits_data = 8'b0;
assign b_bits_corrupt = 1'b0;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cycle_count <= 0;
        state <= IDLE;
        d_valid <= 0;
        d_bits_opcode <= 3'b0;
        d_bits_param <= 3'b0;
        d_bits_size <= 2'b0;
        d_bits_source <= 2'b0;
        d_bits_sink <= 2'b0;
        d_bits_denied <= 1'b0;
        d_bits_data <= 8'b0;
        d_bits_corrupt <= 1'b0;
        pending_source <= 2'b0;
    end else begin
        cycle_count <= cycle_count + 1;
        
        // Accept incoming A channel requests
        if (a_valid && a_ready) begin
            pending_source <= a_bits_source;
            state <= RESPONDING;
        end
        
        case (state)
            IDLE: begin
                d_valid <= 0;
            end
            RESPONDING: begin
                d_valid <= 1;
                d_bits_opcode <= 3'b001; // AccessAckData
                d_bits_source <= pending_source;
                d_bits_data <= {6'b0, id};
                if (d_ready) begin
                    d_valid <= 0;
                    state <= IDLE;
                end
            end
        endcase
    end
end

endmodule

module tb_tlcrossbar(input logic clk_i, input logic rst_ni);

// Master 0 signals
logic m0_e_ready, m0_e_valid;
logic [1:0] m0_e_bits_sink;
logic m0_c_ready, m0_c_valid;
logic [2:0] m0_c_bits_opcode, m0_c_bits_param;
logic [1:0] m0_c_bits_size, m0_c_bits_source;
logic [15:0] m0_c_bits_address;
logic [7:0] m0_c_bits_data;
logic m0_c_bits_corrupt;
logic m0_b_ready, m0_b_valid;
logic [2:0] m0_b_bits_opcode, m0_b_bits_param;
logic [1:0] m0_b_bits_size, m0_b_bits_source;
logic [15:0] m0_b_bits_address;
logic m0_b_bits_mask;
logic [7:0] m0_b_bits_data;
logic m0_b_bits_corrupt;
logic m0_d_ready, m0_d_valid;
logic [2:0] m0_d_bits_opcode, m0_d_bits_param;
logic [1:0] m0_d_bits_size, m0_d_bits_source, m0_d_bits_sink;
logic m0_d_bits_denied;
logic [7:0] m0_d_bits_data;
logic m0_d_bits_corrupt;
logic m0_a_ready, m0_a_valid;
logic [2:0] m0_a_bits_opcode, m0_a_bits_param;
logic [1:0] m0_a_bits_size, m0_a_bits_source;
logic [15:0] m0_a_bits_address;
logic m0_a_bits_mask;
logic [7:0] m0_a_bits_data;
logic m0_a_bits_corrupt;

// Master 1 signals
logic m1_e_ready, m1_e_valid;
logic [1:0] m1_e_bits_sink;
logic m1_c_ready, m1_c_valid;
logic [2:0] m1_c_bits_opcode, m1_c_bits_param;
logic [1:0] m1_c_bits_size, m1_c_bits_source;
logic [15:0] m1_c_bits_address;
logic [7:0] m1_c_bits_data;
logic m1_c_bits_corrupt;
logic m1_b_ready, m1_b_valid;
logic [2:0] m1_b_bits_opcode, m1_b_bits_param;
logic [1:0] m1_b_bits_size, m1_b_bits_source;
logic [15:0] m1_b_bits_address;
logic m1_b_bits_mask;
logic [7:0] m1_b_bits_data;
logic m1_b_bits_corrupt;
logic m1_d_ready, m1_d_valid;
logic [2:0] m1_d_bits_opcode, m1_d_bits_param;
logic [1:0] m1_d_bits_size, m1_d_bits_source, m1_d_bits_sink;
logic m1_d_bits_denied;
logic [7:0] m1_d_bits_data;
logic m1_d_bits_corrupt;
logic m1_a_ready, m1_a_valid;
logic [2:0] m1_a_bits_opcode, m1_a_bits_param;
logic [1:0] m1_a_bits_size, m1_a_bits_source;
logic [15:0] m1_a_bits_address;
logic m1_a_bits_mask;
logic [7:0] m1_a_bits_data;
logic m1_a_bits_corrupt;

// Slave 0 signals
logic s0_e_ready, s0_e_valid;
logic [1:0] s0_e_bits_sink;
logic s0_c_ready, s0_c_valid;
logic [2:0] s0_c_bits_opcode, s0_c_bits_param;
logic [1:0] s0_c_bits_size, s0_c_bits_source;
logic [15:0] s0_c_bits_address;
logic [7:0] s0_c_bits_data;
logic s0_c_bits_corrupt;
logic s0_b_ready, s0_b_valid;
logic [2:0] s0_b_bits_opcode, s0_b_bits_param;
logic [1:0] s0_b_bits_size, s0_b_bits_source;
logic [15:0] s0_b_bits_address;
logic s0_b_bits_mask;
logic [7:0] s0_b_bits_data;
logic s0_b_bits_corrupt;
logic s0_d_ready, s0_d_valid;
logic [2:0] s0_d_bits_opcode, s0_d_bits_param;
logic [1:0] s0_d_bits_size, s0_d_bits_source, s0_d_bits_sink;
logic s0_d_bits_denied;
logic [7:0] s0_d_bits_data;
logic s0_d_bits_corrupt;
logic s0_a_ready, s0_a_valid;
logic [2:0] s0_a_bits_opcode, s0_a_bits_param;
logic [1:0] s0_a_bits_size, s0_a_bits_source;
logic [15:0] s0_a_bits_address;
logic s0_a_bits_mask;
logic [7:0] s0_a_bits_data;
logic s0_a_bits_corrupt;

// Slave 1 signals
logic s1_e_ready, s1_e_valid;
logic [1:0] s1_e_bits_sink;
logic s1_c_ready, s1_c_valid;
logic [2:0] s1_c_bits_opcode, s1_c_bits_param;
logic [1:0] s1_c_bits_size, s1_c_bits_source;
logic [15:0] s1_c_bits_address;
logic [7:0] s1_c_bits_data;
logic s1_c_bits_corrupt;
logic s1_b_ready, s1_b_valid;
logic [2:0] s1_b_bits_opcode, s1_b_bits_param;
logic [1:0] s1_b_bits_size, s1_b_bits_source;
logic [15:0] s1_b_bits_address;
logic s1_b_bits_mask;
logic [7:0] s1_b_bits_data;
logic s1_b_bits_corrupt;
logic s1_d_ready, s1_d_valid;
logic [2:0] s1_d_bits_opcode, s1_d_bits_param;
logic [1:0] s1_d_bits_size, s1_d_bits_source, s1_d_bits_sink;
logic s1_d_bits_denied;
logic [7:0] s1_d_bits_data;
logic s1_d_bits_corrupt;
logic s1_a_ready, s1_a_valid;
logic [2:0] s1_a_bits_opcode, s1_a_bits_param;
logic [1:0] s1_a_bits_size, s1_a_bits_source;
logic [15:0] s1_a_bits_address;
logic s1_a_bits_mask;
logic [7:0] s1_a_bits_data;
logic s1_a_bits_corrupt;

TLCrossBar dut (
    .clock(clk_i),
    .reset(~rst_ni),
    // Master 0
    .masterLinksIO_0_e_ready(m0_e_ready),
    .masterLinksIO_0_e_valid(m0_e_valid),
    .masterLinksIO_0_e_bits_sink(m0_e_bits_sink),
    .masterLinksIO_0_c_ready(m0_c_ready),
    .masterLinksIO_0_c_valid(m0_c_valid),
    .masterLinksIO_0_c_bits_opcode(m0_c_bits_opcode),
    .masterLinksIO_0_c_bits_param(m0_c_bits_param),
    .masterLinksIO_0_c_bits_size(m0_c_bits_size),
    .masterLinksIO_0_c_bits_source(m0_c_bits_source),
    .masterLinksIO_0_c_bits_address(m0_c_bits_address),
    .masterLinksIO_0_c_bits_data(m0_c_bits_data),
    .masterLinksIO_0_c_bits_corrupt(m0_c_bits_corrupt),
    .masterLinksIO_0_b_ready(m0_b_ready),
    .masterLinksIO_0_b_valid(m0_b_valid),
    .masterLinksIO_0_b_bits_opcode(m0_b_bits_opcode),
    .masterLinksIO_0_b_bits_param(m0_b_bits_param),
    .masterLinksIO_0_b_bits_size(m0_b_bits_size),
    .masterLinksIO_0_b_bits_source(m0_b_bits_source),
    .masterLinksIO_0_b_bits_address(m0_b_bits_address),
    .masterLinksIO_0_b_bits_mask(m0_b_bits_mask),
    .masterLinksIO_0_b_bits_data(m0_b_bits_data),
    .masterLinksIO_0_b_bits_corrupt(m0_b_bits_corrupt),
    .masterLinksIO_0_d_ready(m0_d_ready),
    .masterLinksIO_0_d_valid(m0_d_valid),
    .masterLinksIO_0_d_bits_opcode(m0_d_bits_opcode),
    .masterLinksIO_0_d_bits_param(m0_d_bits_param),
    .masterLinksIO_0_d_bits_size(m0_d_bits_size),
    .masterLinksIO_0_d_bits_source(m0_d_bits_source),
    .masterLinksIO_0_d_bits_sink(m0_d_bits_sink),
    .masterLinksIO_0_d_bits_denied(m0_d_bits_denied),
    .masterLinksIO_0_d_bits_data(m0_d_bits_data),
    .masterLinksIO_0_d_bits_corrupt(m0_d_bits_corrupt),
    .masterLinksIO_0_a_ready(m0_a_ready),
    .masterLinksIO_0_a_valid(m0_a_valid),
    .masterLinksIO_0_a_bits_opcode(m0_a_bits_opcode),
    .masterLinksIO_0_a_bits_param(m0_a_bits_param),
    .masterLinksIO_0_a_bits_size(m0_a_bits_size),
    .masterLinksIO_0_a_bits_source(m0_a_bits_source),
    .masterLinksIO_0_a_bits_address(m0_a_bits_address),
    .masterLinksIO_0_a_bits_mask(m0_a_bits_mask),
    .masterLinksIO_0_a_bits_data(m0_a_bits_data),
    .masterLinksIO_0_a_bits_corrupt(m0_a_bits_corrupt),
    // Master 1
    .masterLinksIO_1_e_ready(m1_e_ready),
    .masterLinksIO_1_e_valid(m1_e_valid),
    .masterLinksIO_1_e_bits_sink(m1_e_bits_sink),
    .masterLinksIO_1_c_ready(m1_c_ready),
    .masterLinksIO_1_c_valid(m1_c_valid),
    .masterLinksIO_1_c_bits_opcode(m1_c_bits_opcode),
    .masterLinksIO_1_c_bits_param(m1_c_bits_param),
    .masterLinksIO_1_c_bits_size(m1_c_bits_size),
    .masterLinksIO_1_c_bits_source(m1_c_bits_source),
    .masterLinksIO_1_c_bits_address(m1_c_bits_address),
    .masterLinksIO_1_c_bits_data(m1_c_bits_data),
    .masterLinksIO_1_c_bits_corrupt(m1_c_bits_corrupt),
    .masterLinksIO_1_b_ready(m1_b_ready),
    .masterLinksIO_1_b_valid(m1_b_valid),
    .masterLinksIO_1_b_bits_opcode(m1_b_bits_opcode),
    .masterLinksIO_1_b_bits_param(m1_b_bits_param),
    .masterLinksIO_1_b_bits_size(m1_b_bits_size),
    .masterLinksIO_1_b_bits_source(m1_b_bits_source),
    .masterLinksIO_1_b_bits_address(m1_b_bits_address),
    .masterLinksIO_1_b_bits_mask(m1_b_bits_mask),
    .masterLinksIO_1_b_bits_data(m1_b_bits_data),
    .masterLinksIO_1_b_bits_corrupt(m1_b_bits_corrupt),
    .masterLinksIO_1_d_ready(m1_d_ready),
    .masterLinksIO_1_d_valid(m1_d_valid),
    .masterLinksIO_1_d_bits_opcode(m1_d_bits_opcode),
    .masterLinksIO_1_d_bits_param(m1_d_bits_param),
    .masterLinksIO_1_d_bits_size(m1_d_bits_size),
    .masterLinksIO_1_d_bits_source(m1_d_bits_source),
    .masterLinksIO_1_d_bits_sink(m1_d_bits_sink),
    .masterLinksIO_1_d_bits_denied(m1_d_bits_denied),
    .masterLinksIO_1_d_bits_data(m1_d_bits_data),
    .masterLinksIO_1_d_bits_corrupt(m1_d_bits_corrupt),
    .masterLinksIO_1_a_ready(m1_a_ready),
    .masterLinksIO_1_a_valid(m1_a_valid),
    .masterLinksIO_1_a_bits_opcode(m1_a_bits_opcode),
    .masterLinksIO_1_a_bits_param(m1_a_bits_param),
    .masterLinksIO_1_a_bits_size(m1_a_bits_size),
    .masterLinksIO_1_a_bits_source(m1_a_bits_source),
    .masterLinksIO_1_a_bits_address(m1_a_bits_address),
    .masterLinksIO_1_a_bits_mask(m1_a_bits_mask),
    .masterLinksIO_1_a_bits_data(m1_a_bits_data),
    .masterLinksIO_1_a_bits_corrupt(m1_a_bits_corrupt),
    // Slave 0
    .slaveLinksIO_0_e_ready(s0_e_ready),
    .slaveLinksIO_0_e_valid(s0_e_valid),
    .slaveLinksIO_0_e_bits_sink(s0_e_bits_sink),
    .slaveLinksIO_0_c_ready(s0_c_ready),
    .slaveLinksIO_0_c_valid(s0_c_valid),
    .slaveLinksIO_0_c_bits_opcode(s0_c_bits_opcode),
    .slaveLinksIO_0_c_bits_param(s0_c_bits_param),
    .slaveLinksIO_0_c_bits_size(s0_c_bits_size),
    .slaveLinksIO_0_c_bits_source(s0_c_bits_source),
    .slaveLinksIO_0_c_bits_address(s0_c_bits_address),
    .slaveLinksIO_0_c_bits_data(s0_c_bits_data),
    .slaveLinksIO_0_c_bits_corrupt(s0_c_bits_corrupt),
    .slaveLinksIO_0_b_ready(s0_b_ready),
    .slaveLinksIO_0_b_valid(s0_b_valid),
    .slaveLinksIO_0_b_bits_opcode(s0_b_bits_opcode),
    .slaveLinksIO_0_b_bits_param(s0_b_bits_param),
    .slaveLinksIO_0_b_bits_size(s0_b_bits_size),
    .slaveLinksIO_0_b_bits_source(s0_b_bits_source),
    .slaveLinksIO_0_b_bits_address(s0_b_bits_address),
    .slaveLinksIO_0_b_bits_mask(s0_b_bits_mask),
    .slaveLinksIO_0_b_bits_data(s0_b_bits_data),
    .slaveLinksIO_0_b_bits_corrupt(s0_b_bits_corrupt),
    .slaveLinksIO_0_d_ready(s0_d_ready),
    .slaveLinksIO_0_d_valid(s0_d_valid),
    .slaveLinksIO_0_d_bits_opcode(s0_d_bits_opcode),
    .slaveLinksIO_0_d_bits_param(s0_d_bits_param),
    .slaveLinksIO_0_d_bits_size(s0_d_bits_size),
    .slaveLinksIO_0_d_bits_source(s0_d_bits_source),
    .slaveLinksIO_0_d_bits_sink(s0_d_bits_sink),
    .slaveLinksIO_0_d_bits_denied(s0_d_bits_denied),
    .slaveLinksIO_0_d_bits_data(s0_d_bits_data),
    .slaveLinksIO_0_d_bits_corrupt(s0_d_bits_corrupt),
    .slaveLinksIO_0_a_ready(s0_a_ready),
    .slaveLinksIO_0_a_valid(s0_a_valid),
    .slaveLinksIO_0_a_bits_opcode(s0_a_bits_opcode),
    .slaveLinksIO_0_a_bits_param(s0_a_bits_param),
    .slaveLinksIO_0_a_bits_size(s0_a_bits_size),
    .slaveLinksIO_0_a_bits_source(s0_a_bits_source),
    .slaveLinksIO_0_a_bits_address(s0_a_bits_address),
    .slaveLinksIO_0_a_bits_mask(s0_a_bits_mask),
    .slaveLinksIO_0_a_bits_data(s0_a_bits_data),
    .slaveLinksIO_0_a_bits_corrupt(s0_a_bits_corrupt),
    // Slave 1
    .slaveLinksIO_1_e_ready(s1_e_ready),
    .slaveLinksIO_1_e_valid(s1_e_valid),
    .slaveLinksIO_1_e_bits_sink(s1_e_bits_sink),
    .slaveLinksIO_1_c_ready(s1_c_ready),
    .slaveLinksIO_1_c_valid(s1_c_valid),
    .slaveLinksIO_1_c_bits_opcode(s1_c_bits_opcode),
    .slaveLinksIO_1_c_bits_param(s1_c_bits_param),
    .slaveLinksIO_1_c_bits_size(s1_c_bits_size),
    .slaveLinksIO_1_c_bits_source(s1_c_bits_source),
    .slaveLinksIO_1_c_bits_address(s1_c_bits_address),
    .slaveLinksIO_1_c_bits_data(s1_c_bits_data),
    .slaveLinksIO_1_c_bits_corrupt(s1_c_bits_corrupt),
    .slaveLinksIO_1_b_ready(s1_b_ready),
    .slaveLinksIO_1_b_valid(s1_b_valid),
    .slaveLinksIO_1_b_bits_opcode(s1_b_bits_opcode),
    .slaveLinksIO_1_b_bits_param(s1_b_bits_param),
    .slaveLinksIO_1_b_bits_size(s1_b_bits_size),
    .slaveLinksIO_1_b_bits_source(s1_b_bits_source),
    .slaveLinksIO_1_b_bits_address(s1_b_bits_address),
    .slaveLinksIO_1_b_bits_mask(s1_b_bits_mask),
    .slaveLinksIO_1_b_bits_data(s1_b_bits_data),
    .slaveLinksIO_1_b_bits_corrupt(s1_b_bits_corrupt),
    .slaveLinksIO_1_d_ready(s1_d_ready),
    .slaveLinksIO_1_d_valid(s1_d_valid),
    .slaveLinksIO_1_d_bits_opcode(s1_d_bits_opcode),
    .slaveLinksIO_1_d_bits_param(s1_d_bits_param),
    .slaveLinksIO_1_d_bits_size(s1_d_bits_size),
    .slaveLinksIO_1_d_bits_source(s1_d_bits_source),
    .slaveLinksIO_1_d_bits_sink(s1_d_bits_sink),
    .slaveLinksIO_1_d_bits_denied(s1_d_bits_denied),
    .slaveLinksIO_1_d_bits_data(s1_d_bits_data),
    .slaveLinksIO_1_d_bits_corrupt(s1_d_bits_corrupt),
    .slaveLinksIO_1_a_ready(s1_a_ready),
    .slaveLinksIO_1_a_valid(s1_a_valid),
    .slaveLinksIO_1_a_bits_opcode(s1_a_bits_opcode),
    .slaveLinksIO_1_a_bits_param(s1_a_bits_param),
    .slaveLinksIO_1_a_bits_size(s1_a_bits_size),
    .slaveLinksIO_1_a_bits_source(s1_a_bits_source),
    .slaveLinksIO_1_a_bits_address(s1_a_bits_address),
    .slaveLinksIO_1_a_bits_mask(s1_a_bits_mask),
    .slaveLinksIO_1_a_bits_data(s1_a_bits_data),
    .slaveLinksIO_1_a_bits_corrupt(s1_a_bits_corrupt)
);

tl_master master0 (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .id(2'b00),
    .d_ready(m0_d_ready),
    .d_valid(m0_d_valid),
    .d_bits_opcode(m0_d_bits_opcode),
    .d_bits_param(m0_d_bits_param),
    .d_bits_size(m0_d_bits_size),
    .d_bits_source(m0_d_bits_source),
    .d_bits_sink(m0_d_bits_sink),
    .d_bits_denied(m0_d_bits_denied),
    .d_bits_data(m0_d_bits_data),
    .d_bits_corrupt(m0_d_bits_corrupt),
    .a_ready(m0_a_ready),
    .a_valid(m0_a_valid),
    .a_bits_opcode(m0_a_bits_opcode),
    .a_bits_param(m0_a_bits_param),
    .a_bits_size(m0_a_bits_size),
    .a_bits_source(m0_a_bits_source),
    .a_bits_address(m0_a_bits_address),
    .a_bits_mask(m0_a_bits_mask),
    .a_bits_data(m0_a_bits_data),
    .a_bits_corrupt(m0_a_bits_corrupt),
    .e_valid(m0_e_valid),
    .e_bits_sink(m0_e_bits_sink),
    .e_ready(m0_e_ready),
    .c_valid(m0_c_valid),
    .c_bits_opcode(m0_c_bits_opcode),
    .c_bits_param(m0_c_bits_param),
    .c_bits_size(m0_c_bits_size),
    .c_bits_source(m0_c_bits_source),
    .c_bits_address(m0_c_bits_address),
    .c_bits_data(m0_c_bits_data),
    .c_bits_corrupt(m0_c_bits_corrupt),
    .c_ready(m0_c_ready),
    .b_valid(m0_b_valid),
    .b_bits_opcode(m0_b_bits_opcode),
    .b_bits_param(m0_b_bits_param),
    .b_bits_size(m0_b_bits_size),
    .b_bits_source(m0_b_bits_source),
    .b_bits_address(m0_b_bits_address),
    .b_bits_mask(m0_b_bits_mask),
    .b_bits_data(m0_b_bits_data),
    .b_bits_corrupt(m0_b_bits_corrupt),
    .b_ready(m0_b_ready)
);

tl_master master1 (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .id(2'b01),
    .d_ready(m1_d_ready),
    .d_valid(m1_d_valid),
    .d_bits_opcode(m1_d_bits_opcode),
    .d_bits_param(m1_d_bits_param),
    .d_bits_size(m1_d_bits_size),
    .d_bits_source(m1_d_bits_source),
    .d_bits_sink(m1_d_bits_sink),
    .d_bits_denied(m1_d_bits_denied),
    .d_bits_data(m1_d_bits_data),
    .d_bits_corrupt(m1_d_bits_corrupt),
    .a_ready(m1_a_ready),
    .a_valid(m1_a_valid),
    .a_bits_opcode(m1_a_bits_opcode),
    .a_bits_param(m1_a_bits_param),
    .a_bits_size(m1_a_bits_size),
    .a_bits_source(m1_a_bits_source),
    .a_bits_address(m1_a_bits_address),
    .a_bits_mask(m1_a_bits_mask),
    .a_bits_data(m1_a_bits_data),
    .a_bits_corrupt(m1_a_bits_corrupt),
    .e_valid(m1_e_valid),
    .e_bits_sink(m1_e_bits_sink),
    .e_ready(m1_e_ready),
    .c_valid(m1_c_valid),
    .c_bits_opcode(m1_c_bits_opcode),
    .c_bits_param(m1_c_bits_param),
    .c_bits_size(m1_c_bits_size),
    .c_bits_source(m1_c_bits_source),
    .c_bits_address(m1_c_bits_address),
    .c_bits_data(m1_c_bits_data),
    .c_bits_corrupt(m1_c_bits_corrupt),
    .c_ready(m1_c_ready),
    .b_valid(m1_b_valid),
    .b_bits_opcode(m1_b_bits_opcode),
    .b_bits_param(m1_b_bits_param),
    .b_bits_size(m1_b_bits_size),
    .b_bits_source(m1_b_bits_source),
    .b_bits_address(m1_b_bits_address),
    .b_bits_mask(m1_b_bits_mask),
    .b_bits_data(m1_b_bits_data),
    .b_bits_corrupt(m1_b_bits_corrupt),
    .b_ready(m1_b_ready)
);

tl_slave slave0 (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .id(2'b00),
    .a_ready(s0_a_ready),
    .a_valid(s0_a_valid),
    .a_bits_opcode(s0_a_bits_opcode),
    .a_bits_param(s0_a_bits_param),
    .a_bits_size(s0_a_bits_size),
    .a_bits_source(s0_a_bits_source),
    .a_bits_address(s0_a_bits_address),
    .a_bits_mask(s0_a_bits_mask),
    .a_bits_data(s0_a_bits_data),
    .a_bits_corrupt(s0_a_bits_corrupt),
    .d_ready(s0_d_ready),
    .d_valid(s0_d_valid),
    .d_bits_opcode(s0_d_bits_opcode),
    .d_bits_param(s0_d_bits_param),
    .d_bits_size(s0_d_bits_size),
    .d_bits_source(s0_d_bits_source),
    .d_bits_sink(s0_d_bits_sink),
    .d_bits_denied(s0_d_bits_denied),
    .d_bits_data(s0_d_bits_data),
    .d_bits_corrupt(s0_d_bits_corrupt),
    .e_valid(s0_e_valid),
    .e_bits_sink(s0_e_bits_sink),
    .e_ready(s0_e_ready),
    .c_valid(s0_c_valid),
    .c_bits_opcode(s0_c_bits_opcode),
    .c_bits_param(s0_c_bits_param),
    .c_bits_size(s0_c_bits_size),
    .c_bits_source(s0_c_bits_source),
    .c_bits_address(s0_c_bits_address),
    .c_bits_data(s0_c_bits_data),
    .c_bits_corrupt(s0_c_bits_corrupt),
    .c_ready(s0_c_ready),
    .b_valid(s0_b_valid),
    .b_bits_opcode(s0_b_bits_opcode),
    .b_bits_param(s0_b_bits_param),
    .b_bits_size(s0_b_bits_size),
    .b_bits_source(s0_b_bits_source),
    .b_bits_address(s0_b_bits_address),
    .b_bits_mask(s0_b_bits_mask),
    .b_bits_data(s0_b_bits_data),
    .b_bits_corrupt(s0_b_bits_corrupt),
    .b_ready(s0_b_ready)
);

tl_slave slave1 (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .id(2'b01),
    .a_ready(s1_a_ready),
    .a_valid(s1_a_valid),
    .a_bits_opcode(s1_a_bits_opcode),
    .a_bits_param(s1_a_bits_param),
    .a_bits_size(s1_a_bits_size),
    .a_bits_source(s1_a_bits_source),
    .a_bits_address(s1_a_bits_address),
    .a_bits_mask(s1_a_bits_mask),
    .a_bits_data(s1_a_bits_data),
    .a_bits_corrupt(s1_a_bits_corrupt),
    .d_ready(s1_d_ready),
    .d_valid(s1_d_valid),
    .d_bits_opcode(s1_d_bits_opcode),
    .d_bits_param(s1_d_bits_param),
    .d_bits_size(s1_d_bits_size),
    .d_bits_source(s1_d_bits_source),
    .d_bits_sink(s1_d_bits_sink),
    .d_bits_denied(s1_d_bits_denied),
    .d_bits_data(s1_d_bits_data),
    .d_bits_corrupt(s1_d_bits_corrupt),
    .e_valid(s1_e_valid),
    .e_bits_sink(s1_e_bits_sink),
    .e_ready(s1_e_ready),
    .c_valid(s1_c_valid),
    .c_bits_opcode(s1_c_bits_opcode),
    .c_bits_param(s1_c_bits_param),
    .c_bits_size(s1_c_bits_size),
    .c_bits_source(s1_c_bits_source),
    .c_bits_address(s1_c_bits_address),
    .c_bits_data(s1_c_bits_data),
    .c_bits_corrupt(s1_c_bits_corrupt),
    .c_ready(s1_c_ready),
    .b_valid(s1_b_valid),
    .b_bits_opcode(s1_b_bits_opcode),
    .b_bits_param(s1_b_bits_param),
    .b_bits_size(s1_b_bits_size),
    .b_bits_source(s1_b_bits_source),
    .b_bits_address(s1_b_bits_address),
    .b_bits_mask(s1_b_bits_mask),
    .b_bits_data(s1_b_bits_data),
    .b_bits_corrupt(s1_b_bits_corrupt),
    .b_ready(s1_b_ready)
);

endmodule
