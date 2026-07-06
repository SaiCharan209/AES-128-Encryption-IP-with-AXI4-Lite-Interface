module status_reg #(
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 4
)
(
    input  wire clk,
    input  wire aresetn,

    input  wire done,
    input  wire busy,
    input  wire idle,
    input  wire error,

    input  wire [AXI_ADDR_WIDTH-1:0] ar_addr,
    input  wire ar_valid,
    output wire  ar_ready,

    input  wire r_ready,
    output reg  r_valid,
    output reg  [AXI_DATA_WIDTH-1:0] r_data,
    output reg  [1:0] r_resp
);
    localparam [1:0] OKAY = 2'b00, SLVERR = 2'b10;

    reg done_latched;

    assign ar_ready = (!r_valid);

    always @(posedge clk or negedge aresetn) begin
        if (!aresetn) begin
            done_latched <= 1'b0;
        end else if (done) begin
            done_latched <= 1'b1;
        end else if (ar_ready && ar_valid && ar_addr == 4'h0) begin
            done_latched <= 1'b0;
        end
    end

    always @(posedge clk or negedge aresetn) begin
        if (!aresetn) begin
            r_valid  <= 1'b0;
            r_data   <= 32'd0;
            r_resp   <= OKAY;
        end else begin
         if (ar_ready && ar_valid) begin
                r_valid <= 1'b1;
                if (ar_addr == 4'h0) begin
                    r_data <= {28'd0,error, done_latched, busy, idle};
                    r_resp <= OKAY;
                end else begin
                    r_data <= 32'hDEADBEEF;
                    r_resp <= SLVERR;
                end
            end else if (r_valid && r_ready) begin
                r_valid <= 1'b0;
            end
        end
    end
endmodule