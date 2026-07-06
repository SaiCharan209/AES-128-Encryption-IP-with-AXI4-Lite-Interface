`timescale 1ns / 1ps

module write_control #(
    parameter MEM_SIZE = 1024,
    parameter ADDR_WIDTH = $clog2(MEM_SIZE), 
    parameter AXI_DATA_WIDTH = 32,
    parameter BLOCK_WIDTH = 16
)(
    input clk,
    input reset,
    input stop,

    input [127:0] AES_out,
    input [ADDR_WIDTH-1:0] AES_addr_out,
    input done,

    output reg [ADDR_WIDTH-1:0] aw_addr,
    output reg aw_valid,
    input aw_ready,

    output reg [AXI_DATA_WIDTH-1:0] w_data,
    output reg w_valid,
    input w_ready,
    output [AXI_DATA_WIDTH/8 -1:0] w_strb,

    input [1:0] b_resp,
    output reg b_resp_ready,
    input b_resp_valid,
    
    input [BLOCK_WIDTH-1:0] num_blocks_to_process,

    output empty,
    output reg done_all,
    output Busy,
    output reg Error
);

    localparam IDLE  = 2'b00;
    localparam WRITE = 2'b01;
    localparam WAIT  = 2'b10;
    localparam OKAY  = 2'b00;

    reg [1:0]state;
    
    reg [2:0] aw_count;
    reg [2:0] w_count; 
    reg [2:0] b_count; 
    
    reg [BLOCK_WIDTH-1:0] block_counter;
    reg [127:0] latched_aes_data;
    
    assign w_strb = 4'b1111;
    
    assign empty = (state == IDLE) ||(state == WRITE && w_valid && w_ready && w_count == 3);

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state            <= IDLE;
            aw_valid         <= 0;
            w_valid          <= 0;
            b_resp_ready     <= 0;
            aw_addr          <= 0;
            w_data           <= 0;
            aw_count         <= 0;
            w_count          <= 0;
            b_count          <= 0;
            block_counter    <= 0;
            done_all         <= 0;
            latched_aes_data <= 0;
            Error            <= 0;
        end else if (stop) begin
            state            <= IDLE;
            aw_valid         <= 0;
            w_valid          <= 0;
            b_resp_ready     <= 0;
            aw_addr          <= 0;
            w_data           <= 0;
            aw_count         <= 0;
            w_count          <= 0;
            b_count          <= 0;
            block_counter    <= 0;
            done_all         <= 0;
            latched_aes_data <= 0;
            Error            <= 0;
        end else begin
            case (state)

                IDLE: begin
                    done_all      <= 0;
                    block_counter <= 0;
                    aw_valid      <= 0;
                    w_valid       <= 0;
                    b_resp_ready  <= 0;
                    Error         <= 0;
                    if (done) begin
                        state            <= WRITE;
                        latched_aes_data <= AES_out;
                        aw_addr          <= AES_addr_out;
                        w_data           <= AES_out[127:96];
                        aw_valid         <= 1'b1;
                        w_valid          <= 1'b1;
                        b_resp_ready     <= 1'b1;
                        aw_count         <= 0;
                        w_count          <= 0;
                        b_count          <= 0;
                    end
                end

                WRITE: begin
                    Error <= 0;
                    if (aw_valid && aw_ready) begin
                        if (aw_count < 3) begin
                            aw_addr  <= aw_addr + 4;
                            aw_count <= aw_count + 1;
                            aw_valid <= 1'b1;
                        end else begin
                            aw_valid <= 1'b0;
                        end
                    end

                    if (w_valid && w_ready) begin
                        if (w_count < 3) begin
                            w_count <= w_count + 1;
                            case (w_count)
                                0: w_data <= latched_aes_data[95:64];
                                1: w_data <= latched_aes_data[63:32];
                                2: w_data <= latched_aes_data[31:0];
                            endcase
                        end else begin
                            if (done) begin
                                latched_aes_data <= AES_out;
                                aw_addr          <= AES_addr_out;
                                w_data           <= AES_out[127:96];
                                aw_valid         <= 1'b1;
                                w_valid          <= 1'b1;
                                aw_count         <= 0;
                                w_count          <= 0;
                            end 
                            else
                            begin
                                w_valid <= 0;
                                aw_valid <= 0;
                                w_count <= 3;
                                aw_count <= 3;
                            end
                        end
                    end

                    if (b_resp_ready && b_resp_valid) begin
                        if (b_resp != OKAY) begin
                            aw_valid     <= 1'b0;
                            w_valid      <= 1'b0;
                            Error <= 1'b1;
                        end else begin
                            Error <= 1'b0;
                            aw_valid <= 1'b1;
                            w_valid <= 1'b1;
                            if (b_count < 3) begin
                                b_count <= b_count + 1;
                            end else begin
                                block_counter <= block_counter + 1;
                                b_count       <= 0;
                                if (block_counter == (num_blocks_to_process - 1)) begin
                                    done_all     <= 1'b1;
                                    b_resp_ready <= 1'b0;
                                    state        <= IDLE;
                                    aw_valid <=0;
                                    w_valid <= 0;
                                end
                                else if(w_count == 3)
                                begin
                                    state <= WAIT;
                                    aw_valid <= 1'b0;
                                    w_valid <= 1'b0;
                                    b_resp_ready<=1'b0;
                                end
                            end
                        end
                    end

                end
                WAIT:
                begin
                    if (done) begin
                        state            <= WRITE;
                        latched_aes_data <= AES_out;
                        aw_addr          <= AES_addr_out;
                        w_data           <= AES_out[127:96];
                        aw_valid         <= 1'b1;
                        w_valid          <= 1'b1;
                        b_resp_ready     <= 1'b1;
                        aw_count         <= 0;
                        w_count          <= 0;
                        b_count          <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign Busy = (state == WRITE);
endmodule