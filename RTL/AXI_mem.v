`timescale 1ns / 1ps

module axi_mem #(
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 32,
    parameter MEM_SIZE = 8192
)(
    input clk,
    input resetn,


    input  wire [AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire                       s_axi_awvalid,
    output wire                       s_axi_awready,
    
    input  wire [AXI_DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [3:0]                 s_axi_wstrb,
    input  wire                       s_axi_wvalid,
    output wire                       s_axi_wready,
    
    output reg  [1:0]                 s_axi_bresp,
    output reg                        s_axi_bvalid,
    input  wire                       s_axi_bready,


    input  wire [AXI_ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire                       s_axi_arvalid,
    output wire                       s_axi_arready,
    
    output reg  [AXI_DATA_WIDTH-1:0]  s_axi_rdata,
    output reg  [1:0]                 s_axi_rresp,
    output reg                        s_axi_rvalid,
    input  wire                       s_axi_rready
);

    localparam OKAY   = 2'b00;
    localparam SLVERR = 2'b10;

    reg [AXI_DATA_WIDTH-1:0] mem [0:(MEM_SIZE/4)-1];

    integer i;

    reg aw_hs_done, w_hs_done;
    reg [AXI_ADDR_WIDTH-1:0]  aw_addr_q;
    reg [AXI_DATA_WIDTH-1:0]  w_data_q;
    reg [3:0]                 w_strb_q;

    assign s_axi_awready = (!aw_hs_done) || (s_axi_bvalid && s_axi_bready);
    assign s_axi_wready  = (!w_hs_done)  || (s_axi_bvalid && s_axi_bready);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            aw_hs_done   <= 1'b0;
            w_hs_done    <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= OKAY;
        end else begin
            if (s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid) begin
                aw_hs_done   <= 1'b1;
                w_hs_done    <= 1'b1;
                s_axi_bvalid <= 1'b1;
                if (s_axi_awaddr < MEM_SIZE-3) begin
                    s_axi_bresp <= OKAY;
                    for (i = 0; i < 4; i = i+1) begin
                        if (s_axi_wstrb[i])
                            mem[s_axi_awaddr[AXI_ADDR_WIDTH-1:2]][(i*8)+:8] <= s_axi_wdata[(i*8)+:8];
                    end
                end else begin
                    s_axi_bresp <= SLVERR;
                end
            end 
            else if (s_axi_awready && s_axi_awvalid) begin
                if (w_hs_done) begin
                    aw_hs_done   <= 1'b1;
                    s_axi_bvalid <= 1'b1;
                    if (s_axi_awaddr < MEM_SIZE-3) begin
                        s_axi_bresp <= OKAY;
                        for (i = 0; i < 4; i = i+1) begin
                            if (w_strb_q[i])
                                mem[s_axi_awaddr[AXI_ADDR_WIDTH-1:2]][(i*8)+:8] <= w_data_q[(i*8)+:8];
                        end
                    end else begin
                        s_axi_bresp <= SLVERR;
                    end
                end else begin
                    aw_addr_q  <= s_axi_awaddr;
                    aw_hs_done <= 1'b1;
                end
            end 
            else if (s_axi_wready && s_axi_wvalid) begin
                if (aw_hs_done) begin
                    w_hs_done    <= 1'b1;
                    s_axi_bvalid <= 1'b1;
                    if (aw_addr_q < MEM_SIZE-3) begin
                        s_axi_bresp <= OKAY;
                        for (i = 0; i < 4; i = i+1) begin
                            if (s_axi_wstrb[i])
                                mem[aw_addr_q[AXI_ADDR_WIDTH-1:2]][(i*8)+:8] <= s_axi_wdata[(i*8)+:8];
                        end
                    end else begin
                        s_axi_bresp <= SLVERR;
                    end
                end else begin 
                    w_data_q  <= s_axi_wdata;
                    w_strb_q  <= s_axi_wstrb;
                    w_hs_done <= 1'b1;
                end
            end 
            else if (s_axi_bready && s_axi_bvalid) begin
                w_hs_done    <= 1'b0;
                aw_hs_done   <= 1'b0;
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    assign s_axi_arready = (~s_axi_rvalid) || s_axi_rready;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= OKAY;
            s_axi_rdata  <= 32'd0;
        end else begin
            if (s_axi_arready && s_axi_arvalid) begin
                s_axi_rvalid <= 1'b1;
                if (s_axi_araddr < MEM_SIZE-3) begin
                    s_axi_rdata <= mem[s_axi_araddr[AXI_ADDR_WIDTH-1:2]];
                    s_axi_rresp <= OKAY;
                end else begin
                    s_axi_rdata <= 32'hDEADBEEF;
                    s_axi_rresp <= SLVERR;
                end
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule

