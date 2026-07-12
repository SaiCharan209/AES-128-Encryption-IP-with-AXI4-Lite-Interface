`timescale 1ns / 1ps

module sys_top #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 4,
    parameter C_M_AXI_DATA_WIDTH = 32,
    parameter MEM_SIZE           = 8192,
    parameter C_M_AXI_ADDR_WIDTH = 32
)(
    input  wire                                clk,
    input  wire                                resetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire                              s_axi_awvalid,
    output wire                              s_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output wire                              s_axi_wready,
    output wire [1:0]                        s_axi_bresp,
    output wire                              s_axi_bvalid,
    input  wire                              s_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire                              s_axi_arvalid,
    output wire                              s_axi_arready,
    output wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output wire [1:0]                        s_axi_rresp,
    output wire                              s_axi_rvalid,
    input  wire                              s_axi_rready,

    input  wire [C_M_AXI_ADDR_WIDTH-1:0]     s_axi_portB_awaddr,
    input  wire                              s_axi_portB_awvalid,
    output wire                              s_axi_portB_awready,
    input  wire [C_M_AXI_DATA_WIDTH-1:0]     s_axi_portB_wdata,
    input  wire [(C_M_AXI_DATA_WIDTH/8)-1:0] s_axi_portB_wstrb,
    input  wire                              s_axi_portB_wvalid,
    output wire                              s_axi_portB_wready,
    output wire [1:0]                        s_axi_portB_bresp,
    output wire                              s_axi_portB_bvalid,
    input  wire                              s_axi_portB_bready,
    input  wire [C_M_AXI_ADDR_WIDTH-1:0]     s_axi_portB_araddr,
    input  wire                              s_axi_portB_arvalid,
    output wire                              s_axi_portB_arready,
    output wire [C_M_AXI_DATA_WIDTH-1:0]     s_axi_portB_rdata,
    output wire [1:0]                        s_axi_portB_rresp,
    output wire                              s_axi_portB_rvalid,
    input  wire                              s_axi_portB_rready,

    input  wire [127:0]                      aes_key,
    input  wire                              aes_key_valid,
    input  wire [15:0]                       num_blocks_to_process,
    output wire                              aes_key_ready
);


    wire [C_M_AXI_ADDR_WIDTH-1:0]     m_axi_awaddr;
    wire                              m_axi_awvalid, m_axi_awready;
    wire [C_M_AXI_DATA_WIDTH-1:0]     m_axi_wdata;
    wire [(C_M_AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb;
    wire                              m_axi_wvalid,  m_axi_wready;
    wire [1:0]                        m_axi_bresp;
    wire                              m_axi_bvalid,  m_axi_bready;

    wire [C_M_AXI_ADDR_WIDTH-1:0]     m_axi_araddr;
    wire                              m_axi_arvalid, m_axi_arready;
    wire [C_M_AXI_DATA_WIDTH-1:0]     m_axi_rdata;
    wire [1:0]                        m_axi_rresp;
    wire                              m_axi_rvalid,  m_axi_rready;


    wire [C_M_AXI_ADDR_WIDTH-1:0]     bram_awaddr;
    wire                              bram_awvalid, bram_awready;
    wire [C_M_AXI_DATA_WIDTH-1:0]     bram_wdata;
    wire [(C_M_AXI_DATA_WIDTH/8)-1:0] bram_wstrb;
    wire                              bram_wvalid,  bram_wready;
    wire [1:0]                        bram_bresp;
    wire                              bram_bvalid,  bram_bready;

    wire [C_M_AXI_ADDR_WIDTH-1:0]     bram_araddr;
    wire                              bram_arvalid, bram_arready;
    wire [C_M_AXI_DATA_WIDTH-1:0]     bram_rdata;
    wire [1:0]                        bram_rresp;
    wire                              bram_rvalid,  bram_rready;


    aes_top #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
        .MEM_SIZE(MEM_SIZE),
        .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH)
    ) aes_inst (
        .aclk(clk), .aresetn(resetn),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),   .s_axi_wstrb(s_axi_wstrb),     .s_axi_wvalid(s_axi_wvalid),   .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),   .s_axi_bvalid(s_axi_bvalid),   .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),   .s_axi_rresp(s_axi_rresp),     .s_axi_rvalid(s_axi_rvalid),   .s_axi_rready(s_axi_rready),

        .m_axi_araddr(m_axi_araddr), .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),   .m_axi_rresp(m_axi_rresp),     .m_axi_rvalid(m_axi_rvalid),   .m_axi_rready(m_axi_rready),

        .m_axi_awaddr(m_axi_awaddr), .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),   .m_axi_wstrb(m_axi_wstrb),     .m_axi_wvalid(m_axi_wvalid),   .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),   .m_axi_bvalid(m_axi_bvalid),   .m_axi_bready(m_axi_bready),

        .aes_key(aes_key), .aes_key_valid(aes_key_valid),
        .num_blocks_to_process(num_blocks_to_process), .aes_key_ready(aes_key_ready)

    );


    axi_interconnect_2to1 #(
        .ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
        .DATA_WIDTH(C_M_AXI_DATA_WIDTH)
    ) axi_ic_inst (
        .clk(clk),
        .resetn(resetn),

        .m0_awaddr(m_axi_awaddr), .m0_awvalid(m_axi_awvalid), .m0_awready(m_axi_awready),
        .m0_wdata(m_axi_wdata),   .m0_wstrb(m_axi_wstrb),     .m0_wvalid(m_axi_wvalid),   .m0_wready(m_axi_wready),
        .m0_bresp(m_axi_bresp),   .m0_bvalid(m_axi_bvalid),   .m0_bready(m_axi_bready),
        .m0_araddr(m_axi_araddr), .m0_arvalid(m_axi_arvalid), .m0_arready(m_axi_arready),
        .m0_rdata(m_axi_rdata),   .m0_rresp(m_axi_rresp),     .m0_rvalid(m_axi_rvalid),   .m0_rready(m_axi_rready),

        .m1_awaddr(s_axi_portB_awaddr), .m1_awvalid(s_axi_portB_awvalid), .m1_awready(s_axi_portB_awready),
        .m1_wdata(s_axi_portB_wdata),   .m1_wstrb(s_axi_portB_wstrb),     .m1_wvalid(s_axi_portB_wvalid),   .m1_wready(s_axi_portB_wready),
        .m1_bresp(s_axi_portB_bresp),   .m1_bvalid(s_axi_portB_bvalid),   .m1_bready(s_axi_portB_bready),
        .m1_araddr(s_axi_portB_araddr), .m1_arvalid(s_axi_portB_arvalid), .m1_arready(s_axi_portB_arready),
        .m1_rdata(s_axi_portB_rdata),   .m1_rresp(s_axi_portB_rresp),     .m1_rvalid(s_axi_portB_rvalid),   .m1_rready(s_axi_portB_rready),

        .s_awaddr(bram_awaddr), .s_awvalid(bram_awvalid), .s_awready(bram_awready),
        .s_wdata(bram_wdata),   .s_wstrb(bram_wstrb),     .s_wvalid(bram_wvalid),   .s_wready(bram_wready),
        .s_bresp(bram_bresp),   .s_bvalid(bram_bvalid),   .s_bready(bram_bready),
        .s_araddr(bram_araddr), .s_arvalid(bram_arvalid), .s_arready(bram_arready),
        .s_rdata(bram_rdata),   .s_rresp(bram_rresp),     .s_rvalid(bram_rvalid),   .s_rready(bram_rready)
    );


    axi_bram #(
        .AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
        .MEM_SIZE(MEM_SIZE)
    ) mem_inst (
        .clk(clk),
        .resetn(resetn),

        .s_axi_awaddr(bram_awaddr),
        .s_axi_awvalid(bram_awvalid),
        .s_axi_awready(bram_awready),
        .s_axi_wdata(bram_wdata),
        .s_axi_wstrb(bram_wstrb),
        .s_axi_wvalid(bram_wvalid),
        .s_axi_wready(bram_wready),
        .s_axi_bresp(bram_bresp),
        .s_axi_bvalid(bram_bvalid),
        .s_axi_bready(bram_bready),

        .s_axi_araddr(bram_araddr),
        .s_axi_arvalid(bram_arvalid),
        .s_axi_arready(bram_arready),
        .s_axi_rdata(bram_rdata),
        .s_axi_rresp(bram_rresp),
        .s_axi_rvalid(bram_rvalid),
        .s_axi_rready(bram_rready)
    );

endmodule