module read_control #(
    parameter MEM_SIZE = 1024,
    parameter ADDR_WIDTH = $clog2(MEM_SIZE),
    parameter BASE_ADDR = 0,
    parameter DATA_WIDTH = 32,
    parameter BLOCK_WIDTH = 16
) (
    input clk,
    input reset,
    input stop,

    input start,
    input AES_ready,

    input [BLOCK_WIDTH-1:0] num_blocks_to_process,

    input ar_ready,
    output reg ar_valid,
    output reg [ADDR_WIDTH-1:0] ar_addr,

    input [31:0] r_data,
    input r_valid,
    output reg r_ready,
    input [1:0] r_resp,

    output reg [127:0] AES_in,
    output reg [ADDR_WIDTH-1:0] AES_addr_out,
    output reg AES_in_valid,
    output reg Error,
    output Busy

);

    parameter OKAY = 2'b00,
              SLVERR = 2'b10;
              
    parameter IDLE = 2'd0,
              READ = 2'd1,
              WAIT = 2'd2;

    reg [1:0] state;
    reg [ADDR_WIDTH-1:0] prev_addr;
    reg [1:0] count;
    reg [DATA_WIDTH-1:0] mem_array [3:0];
    reg [2:0] addr_count;
    reg [BLOCK_WIDTH-1:0] block_counter;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            block_counter <= 0;
        end
        else if (stop) begin 
            state <= IDLE;
            block_counter <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    block_counter <= 0;
                    if (start && num_blocks_to_process > 0) 
                        state <= READ;
                end
                READ: begin
                    if (count == 3 && r_valid && r_ready) begin
                        if (AES_ready) begin
                            block_counter <= block_counter + 1;
                            if (block_counter == (num_blocks_to_process - 1))
                                state <= IDLE; 
                        end else begin
                            state <= WAIT;
                        end
                    end
                end    
                WAIT: begin
                    if (AES_ready) begin
                        block_counter <= block_counter + 1;
                        if (block_counter == (num_blocks_to_process - 1))
                            state <= IDLE;
                        else
                            state <= READ;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

reg [ADDR_WIDTH-1:0]ar_addr_reg_q;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            count <= 2'b0;
            ar_addr <= BASE_ADDR;
            ar_valid <= 1'b0;
            r_ready <= 1'b0;
            addr_count <= 3'd0;
            AES_in_valid <= 1'b0;
            prev_addr <= BASE_ADDR;
            AES_in <= 128'd0;
            AES_addr_out <= BASE_ADDR;
            ar_addr_reg_q <= BASE_ADDR;
            Error <= 0;
        end else begin
            case (state)
                IDLE: begin
                    count <= 2'b0;
                    ar_addr <= BASE_ADDR;
                    ar_valid <= 1'b0;
                    r_ready <= 1'b0;
                    addr_count <= 3'd0;
                    AES_in_valid <= 1'b0;
                    prev_addr <= BASE_ADDR;
                    AES_in <= 128'd0;
                    AES_addr_out <= BASE_ADDR;
                    Error <= 1'b0;
                    
                    if (start && num_blocks_to_process > 0) begin
                        count <= 2'b0;
                        addr_count <= 3'd0;
                        ar_valid <= 1'b1;
                        r_ready <= 1'b1;
                        ar_addr <= BASE_ADDR;
                        prev_addr <= BASE_ADDR;
                    end
                end

                READ: begin
                    if(r_resp == SLVERR) begin
                        r_ready <= 1'b0;
                        Error <= 1'b1;
                    end else begin
                        r_ready <= 1'b1;
                        Error <= 1'b0;
                    end
                    
                    if (ar_valid && ar_ready) begin
                        ar_addr <= ar_addr + 4; // Always increment on handshake!
                        if (addr_count == ((block_counter ==(num_blocks_to_process-1))?2:((block_counter == 0)?4:3))) begin
                            ar_valid <= 1'b0;
                        end else begin
                            addr_count <= addr_count + 1;
                            ar_valid <= 1'b1;
                        end
                    end
                    

                    if (r_valid && r_ready) begin
                        mem_array[count] <= r_data;
                        if (count == 3) begin
                            if (AES_ready) begin
                                AES_in <= {mem_array[0], mem_array[1], mem_array[2], r_data};
                                AES_addr_out <= prev_addr;
                                prev_addr <= ar_addr;
                                AES_in_valid <= 1'b1;
                                count <= 2'b0;
                                addr_count <= 3'd0;
                                
                                if (block_counter < (num_blocks_to_process - 1)) begin
                                    ar_valid <=1'b1;
                                    r_ready <= 1'b1;
                                end else begin
                                    r_ready <= 1'b0;
                                    ar_valid <= 1'b0;
                                end
                            end else begin
                                AES_in_valid <= 1'b0;
                                ar_valid <= 1'b0;
                                r_ready <= 1'b0;
                                ar_addr_reg_q <= ar_addr;
                            end
                        end else begin
                            count <= count + 1;
                            AES_in_valid <= 1'b0;

                        end
                    end else begin
                        AES_in_valid <= 1'b0;
                    end
                end

                WAIT: begin
                    if (AES_ready) begin
                        AES_in <= {mem_array[0], mem_array[1], mem_array[2], mem_array[3]};
                        AES_addr_out <= prev_addr;
                        prev_addr <= ar_addr_reg_q;
                        AES_in_valid <= 1'b1;
                        count <= 2'b0;
                        addr_count <= 3'd0;
                        
                        if (block_counter < (num_blocks_to_process - 1)) begin
                            r_ready <= 1'b1;
                            ar_valid <= 1'b1;
                        end else begin
                            r_ready <= 1'b0;
                            ar_valid <= 1'b0;
                        end
                    end else begin
                        ar_valid <= 1'b0;
                        r_ready <= 1'b0;
                        AES_in_valid <= 1'b0;
                    end
                end
            endcase
        end
    end
    assign Busy = (state == READ);
endmodule