`timescale 1ns / 1ps

module axi_ctrl_reg #(
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 4 
)(
    input  wire                      aclk,
    input  wire                      aresetn,

    input  wire [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                      s_axi_awvalid,
    output wire                      s_axi_awready,

    input  wire [AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [3:0]                s_axi_wstrb,
    input  wire                      s_axi_wvalid,
    output wire                      s_axi_wready,

    output reg  [1:0]                s_axi_bresp,
    output reg                       s_axi_bvalid,
    input  wire                      s_axi_bready,

    output wire                      start_sig,
    output wire                      stop_sig
);

    reg [31:0] control_reg;
    reg aw_hs_done;
    reg w_hs_done;
    reg [AXI_ADDR_WIDTH-1:0] aw_addr_q;
    reg [AXI_DATA_WIDTH-1:0] w_data_q;
    reg [3:0] w_strb_q;

    assign start_sig = control_reg[0];
    assign stop_sig  = control_reg[1];

    assign s_axi_awready = (!aw_hs_done);
    assign s_axi_wready  = (!w_hs_done) ;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            aw_hs_done <= 1'b0;
            w_hs_done <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;
            control_reg <= 32'h0;
        end else begin
            if (s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid) begin
                aw_hs_done <= 1'b1;
                w_hs_done <= 1'b1;
                s_axi_bvalid <= 1'b1;
                if (s_axi_awaddr == 4'h0) begin
                    s_axi_bresp <= 2'b00;
                    if (s_axi_wstrb[0]) control_reg[7:0]   <= s_axi_wdata[7:0];
                    if (s_axi_wstrb[1]) control_reg[15:8]  <= s_axi_wdata[15:8];
                    if (s_axi_wstrb[2]) control_reg[23:16] <= s_axi_wdata[23:16];
                    if (s_axi_wstrb[3]) control_reg[31:24] <= s_axi_wdata[31:24];
                end else begin
                    s_axi_bresp <= 2'b01;
                end
            end else if (s_axi_awready && s_axi_awvalid) begin
                if (w_hs_done) begin
                    aw_hs_done <= 1'b1;
                    s_axi_bvalid <= 1'b1;
                    if (s_axi_awaddr == 4'h0) begin
                        s_axi_bresp <= 2'b00;
                        if (w_strb_q[0]) control_reg[7:0]   <= w_data_q[7:0];
                        if (w_strb_q[1]) control_reg[15:8]  <= w_data_q[15:8];
                        if (w_strb_q[2]) control_reg[23:16] <= w_data_q[23:16];
                        if (w_strb_q[3]) control_reg[31:24] <= w_data_q[31:24];
                    end else begin
                        s_axi_bresp <= 2'b01;
                    end
                end else begin
                    aw_addr_q <= s_axi_awaddr;
                    aw_hs_done <= 1'b1;
                end
            end else if (s_axi_wready && s_axi_wvalid) begin
                if (aw_hs_done) begin
                    w_hs_done <= 1'b1;
                    s_axi_bvalid <= 1'b1;
                    if (aw_addr_q == 4'h0) begin
                        s_axi_bresp <= 2'b00;
                        if (s_axi_wstrb[0]) control_reg[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) control_reg[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) control_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) control_reg[31:24] <= s_axi_wdata[31:24];
                    end else begin
                        s_axi_bresp <= 2'b01;
                    end
                end else begin
                    w_data_q <= s_axi_wdata;
                    w_strb_q <= s_axi_wstrb;
                    w_hs_done <= 1'b1;
                end
            end else if (s_axi_bready && s_axi_bvalid) begin
                w_hs_done <= 1'b0;
                aw_hs_done <= 1'b0;
                s_axi_bvalid <= 1'b0;
            end
        end
    end
endmodule