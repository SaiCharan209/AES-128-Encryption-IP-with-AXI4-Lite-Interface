`timescale 1ns / 1ps

module axi_interconnect_2to1 #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                      clk,
    input  wire                      resetn,

    input  wire [ADDR_WIDTH-1:0]     m0_awaddr,
    input  wire                      m0_awvalid,
    output wire                      m0_awready,
    input  wire [DATA_WIDTH-1:0]     m0_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] m0_wstrb,
    input  wire                      m0_wvalid,
    output wire                      m0_wready,
    output wire [1:0]                m0_bresp,
    output wire                      m0_bvalid,
    input  wire                      m0_bready,

    input  wire [ADDR_WIDTH-1:0]     m0_araddr,
    input  wire                      m0_arvalid,
    output wire                      m0_arready,
    output wire [DATA_WIDTH-1:0]     m0_rdata,
    output wire [1:0]                m0_rresp,
    output wire                      m0_rvalid,
    input  wire                      m0_rready,

    input  wire [ADDR_WIDTH-1:0]     m1_awaddr,
    input  wire                      m1_awvalid,
    output wire                      m1_awready,
    input  wire [DATA_WIDTH-1:0]     m1_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] m1_wstrb,
    input  wire                      m1_wvalid,
    output wire                      m1_wready,
    output wire [1:0]                m1_bresp,
    output wire                      m1_bvalid,
    input  wire                      m1_bready,

    input  wire [ADDR_WIDTH-1:0]     m1_araddr,
    input  wire                      m1_arvalid,
    output wire                      m1_arready,
    output wire [DATA_WIDTH-1:0]     m1_rdata,
    output wire [1:0]                m1_rresp,
    output wire                      m1_rvalid,
    input  wire                      m1_rready,


    output wire [ADDR_WIDTH-1:0]     s_awaddr,
    output wire                      s_awvalid,
    input  wire                      s_awready,
    output wire [DATA_WIDTH-1:0]     s_wdata,
    output wire [(DATA_WIDTH/8)-1:0] s_wstrb,
    output wire                      s_wvalid,
    input  wire                      s_wready,
    input  wire [1:0]                s_bresp,
    input  wire                      s_bvalid,
    output wire                      s_bready,

    output wire [ADDR_WIDTH-1:0]     s_araddr,
    output wire                      s_arvalid,
    input  wire                      s_arready,
    input  wire [DATA_WIDTH-1:0]     s_rdata,
    input  wire [1:0]                s_rresp,
    input  wire                      s_rvalid,
    output wire                      s_rready
);


    reg wr_owner;     
    reg wr_busy;      
    reg wr_last;      

    wire wr_req0 = m0_awvalid;
    wire wr_req1 = m1_awvalid;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            wr_owner <= 1'b0;
            wr_busy  <= 1'b0;
            wr_last  <= 1'b1;  // so master0 gets first pick on a tie
        end else begin
            if (!wr_busy) begin
                if (wr_req0 && wr_req1) begin
                    // both requesting: round robin
                    wr_owner <= ~wr_last;
                    wr_last  <= ~wr_last;
                end else if (wr_req0) begin
                    wr_owner <= 1'b0;
                    wr_last  <= 1'b0;
                end else if (wr_req1) begin
                    wr_owner <= 1'b1;
                    wr_last  <= 1'b1;
                end

                if (s_awvalid && s_awready)
                    wr_busy <= 1'b1;
            end else begin
                if (s_bvalid && s_bready)
                    wr_busy <= 1'b0;
            end
        end
    end

    assign s_awaddr  = wr_owner ? m1_awaddr  : m0_awaddr;
    assign s_awvalid = wr_owner ? m1_awvalid : m0_awvalid;
    assign s_wdata   = wr_owner ? m1_wdata   : m0_wdata;
    assign s_wstrb   = wr_owner ? m1_wstrb   : m0_wstrb;
    assign s_wvalid  = wr_owner ? m1_wvalid  : m0_wvalid;
    assign s_bready  = wr_owner ? m1_bready  : m0_bready;

    assign m0_awready = (!wr_owner) ? s_awready : 1'b0;
    assign m1_awready = ( wr_owner) ? s_awready : 1'b0;
    assign m0_wready   = (!wr_owner) ? s_wready  : 1'b0;
    assign m1_wready   = ( wr_owner) ? s_wready  : 1'b0;

    assign m0_bresp  = (!wr_owner) ? s_bresp  : 2'b00;
    assign m1_bresp  = ( wr_owner) ? s_bresp  : 2'b00;
    assign m0_bvalid = (!wr_owner) ? s_bvalid : 1'b0;
    assign m1_bvalid = ( wr_owner) ? s_bvalid : 1'b0;

 
    reg rd_owner;
    reg rd_busy;
    reg rd_last;

    wire rd_req0 = m0_arvalid;
    wire rd_req1 = m1_arvalid;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rd_owner <= 1'b0;
            rd_busy  <= 1'b0;
            rd_last  <= 1'b1;
        end else begin
            if (!rd_busy) begin
                if (rd_req0 && rd_req1) begin
                    rd_owner <= ~rd_last;
                    rd_last  <= ~rd_last;
                end else if (rd_req0) begin
                    rd_owner <= 1'b0;
                    rd_last  <= 1'b0;
                end else if (rd_req1) begin
                    rd_owner <= 1'b1;
                    rd_last  <= 1'b1;
                end

                if (s_arvalid && s_arready)
                    rd_busy <= 1'b1;
            end else begin

                if (s_rvalid && s_rready)
                    rd_busy <= 1'b0;
            end
        end
    end

    assign s_araddr  = rd_owner ? m1_araddr  : m0_araddr;
    assign s_arvalid = rd_owner ? m1_arvalid : m0_arvalid;
    assign s_rready  = rd_owner ? m1_rready  : m0_rready;

    assign m0_arready = (!rd_owner) ? s_arready : 1'b0;
    assign m1_arready = ( rd_owner) ? s_arready : 1'b0;

    assign m0_rdata  = (!rd_owner) ? s_rdata  : {DATA_WIDTH{1'b0}};
    assign m1_rdata  = ( rd_owner) ? s_rdata  : {DATA_WIDTH{1'b0}};
    assign m0_rresp  = (!rd_owner) ? s_rresp  : 2'b00;
    assign m1_rresp  = ( rd_owner) ? s_rresp  : 2'b00;
    assign m0_rvalid = (!rd_owner) ? s_rvalid : 1'b0;
    assign m1_rvalid = ( rd_owner) ? s_rvalid : 1'b0;

endmodule
