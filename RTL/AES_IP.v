`timescale 1ns / 1ps

module aes_top #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 4,
    parameter C_M_AXI_DATA_WIDTH = 32,
    parameter MEM_SIZE           = 1024,
    parameter C_M_AXI_ADDR_WIDTH = 32
)(
    input  wire                              aclk,
    input  wire                              aresetn,



    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire                              s_axi_awvalid,
    output wire                              s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output wire                              s_axi_wready,
    // Write Response Channel (Control Reg)
    output wire [1:0]                        s_axi_bresp,
    output wire                              s_axi_bvalid,
    input  wire                              s_axi_bready,

    // Read Address Channel (Status Reg)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire                              s_axi_arvalid,
    output wire                              s_axi_arready,
    // Read Data Channel (Status Reg)
    output wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output wire [1:0]                        s_axi_rresp,
    output wire                              s_axi_rvalid,
    input  wire                              s_axi_rready,



    output wire [C_M_AXI_ADDR_WIDTH-1:0]     m_axi_araddr,
    output wire                              m_axi_arvalid,
    input  wire                              m_axi_arready,
    // Read Data Channel
    input  wire [C_M_AXI_DATA_WIDTH-1:0]     m_axi_rdata,
    input  wire [1:0]                        m_axi_rresp,
    input  wire                              m_axi_rvalid,
    output wire                              m_axi_rready,
    
    // Write Address Channel
    output wire [C_M_AXI_ADDR_WIDTH-1:0]     m_axi_awaddr,
    output wire                              m_axi_awvalid,
    input  wire                              m_axi_awready,
    // Write Data Channel
    output wire [C_M_AXI_DATA_WIDTH-1:0]     m_axi_wdata,
    output wire [(C_M_AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output wire                              m_axi_wvalid,
    input  wire                              m_axi_wready,
    // Write Response Channel
    input  wire [1:0]                        m_axi_bresp,
    input  wire                              m_axi_bvalid,
    output wire                              m_axi_bready,

    input  wire [127:0]                      aes_key,
    input  wire                              aes_key_valid,
    input  wire [15:0]                       num_blocks_to_process,
    

    output wire                              aes_key_ready
);

    wire         start_sig;
    wire         stop_sig;
    wire         status_done;
    wire         status_idle;
    wire         status_error;
    wire         status_busy;

    wire [127:0] aes_in_data;
    wire [C_M_AXI_ADDR_WIDTH-1:0] aes_in_addr;
    wire         aes_in_valid;
    wire         aes_core_ready;


    wire [127:0] aes_out_data;
    wire [C_M_AXI_ADDR_WIDTH-1:0] aes_out_addr;
    wire         aes_out_done;
    
  
    wire         write_buffer_empty;
    wire         write_done_all;
    wire         write_busy,read_busy,aes_busy;
    wire         read_error, write_error;

    assign status_busy = write_busy || read_busy || aes_busy;
    assign status_idle = !status_busy;
    assign status_error = write_error || read_error;


    axi_ctrl_reg #(
        .AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) ctrl_inst (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .start_sig     (start_sig),
        .stop_sig      (stop_sig)
    );


    status_reg #(
        .AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) stat_inst (
        .clk           (aclk),
        .aresetn       (aresetn),
        .done          (write_done_all), 
        .busy          (status_busy),
        .idle          (status_idle),
        .error         (status_error),
        .ar_addr       (s_axi_araddr),
        .ar_valid      (s_axi_arvalid),
        .ar_ready      (s_axi_arready),
        .r_ready       (s_axi_rready),
        .r_valid       (s_axi_rvalid),
        .r_data        (s_axi_rdata),
        .r_resp        (s_axi_rresp)
    );


    read_control #(
        .MEM_SIZE(MEM_SIZE),
        .ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
        .BASE_ADDR(0),
        .DATA_WIDTH(C_M_AXI_DATA_WIDTH)
    ) rd_ctrl_inst (
        .clk           (aclk),
        .reset         (aresetn),
        .stop          (stop_sig),
        .start         (start_sig),
        .AES_ready     (aes_core_ready),
        .num_blocks_to_process(num_blocks_to_process),
        .ar_ready      (m_axi_arready),
        .ar_valid      (m_axi_arvalid),
        .ar_addr       (m_axi_araddr),
        .r_data        (m_axi_rdata),
        .r_valid       (m_axi_rvalid),
        .r_ready       (m_axi_rready),
        .r_resp        (m_axi_rresp),
        .AES_in        (aes_in_data),
        .AES_addr_out  (aes_in_addr),
        .AES_in_valid  (aes_in_valid),
        .Busy          (read_busy),
        .Error         (read_error)
    );

  
    AES #(
        .DATA_WIDTH(128),
        .KEY_WIDTH(128),
        .AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH)
    ) aes_core_inst (
        .clk           (aclk),
        .reset         (aresetn),
        .stop           (stop_sig),
        .input_valid   (aes_in_valid),
        .empty         (write_buffer_empty),
        .key_valid     (aes_key_valid),
        .Plain_Text    (aes_in_data),
        .Key           (aes_key),
        .Addr_in       (aes_in_addr),
        .Cipher_Text   (aes_out_data),
        .Addr_out      (aes_out_addr),
        .Busy          (aes_busy),
        .Done          (aes_out_done),
        .AES_ready     (aes_core_ready),
        .key_ready     (aes_key_ready)
    );

    write_control #(
        .MEM_SIZE(MEM_SIZE),
        .ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH)
    ) wr_ctrl_inst (
        .clk                   (aclk),
        .reset                 (aresetn),
        .stop                  (stop_sig),
        .AES_out               (aes_out_data),
        .AES_addr_out          (aes_out_addr),
        .done                  (aes_out_done),
        .aw_addr               (m_axi_awaddr),
        .aw_valid              (m_axi_awvalid),
        .aw_ready              (m_axi_awready),
        .w_data                (m_axi_wdata),
        .w_valid               (m_axi_wvalid),
        .w_ready               (m_axi_wready),
        .w_strb                (m_axi_wstrb),
        .b_resp                (m_axi_bresp),
        .b_resp_ready          (m_axi_bready),
        .b_resp_valid          (m_axi_bvalid),
        .num_blocks_to_process (num_blocks_to_process),
        .empty                 (write_buffer_empty),
        .done_all              (write_done_all),
        .Busy                  (write_busy),
        .Error                 (write_error)
    );

endmodule