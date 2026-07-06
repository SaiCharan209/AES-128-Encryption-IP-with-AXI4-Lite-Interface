`timescale 1ns / 1ps


// =============================================================================
//  tb_sys_top_500_vectors
//  500 unique AES-128 ECB test vectors, Key = 2b7e151628aed2a6abf7158809cf4f3c
//  Plaintext blocks are loaded via AXI Port-B, the AES core is triggered via
//  the AXI control port, and results are read back and checked against the
//  pre-computed expected ciphertexts.
// =============================================================================

module tb_sys_top_500_vectors;

    // =========================================================
    // 1. SYSTEM PARAMETERS & CONFIGURATION
    // =========================================================
    parameter C_S_AXI_DATA_WIDTH = 32;
    parameter C_S_AXI_ADDR_WIDTH = 4;
    parameter C_M_AXI_DATA_WIDTH = 32;

    // 500 blocks * 16 bytes = 8000 bytes  →  next power-of-2 = 8192
    parameter MEM_SIZE           = 8192;
    parameter C_M_AXI_ADDR_WIDTH = 32;

    localparam [127:0] AES_KEY   = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    localparam NUM_BLOCKS        = 500;

    // =========================================================
    // 2. SIGNALS & INTERFACES
    // =========================================================
    reg clk;
    reg resetn;

    // AXI Control/Status Interface (Port A – AES Core)
    reg  [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,   s_axi_araddr;
    reg                               s_axi_awvalid,  s_axi_arvalid,
                                      s_axi_wvalid,   s_axi_bready,  s_axi_rready;
    reg  [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata;
    reg  [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb;
    wire                              s_axi_awready,  s_axi_arready,
                                      s_axi_wready,   s_axi_bvalid,  s_axi_rvalid;
    wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata;
    wire [1:0]                        s_axi_bresp,    s_axi_rresp;

    // AXI Memory Interface (Port B – CPU access / verification)
    reg  [C_M_AXI_ADDR_WIDTH-1:0]     s_axi_portB_awaddr, s_axi_portB_araddr;
    reg                               s_axi_portB_awvalid, s_axi_portB_arvalid,
                                      s_axi_portB_wvalid,  s_axi_portB_bready, s_axi_portB_rready;
    reg  [C_M_AXI_DATA_WIDTH-1:0]     s_axi_portB_wdata;
    reg  [(C_M_AXI_DATA_WIDTH/8)-1:0] s_axi_portB_wstrb;
    wire                              s_axi_portB_awready, s_axi_portB_arready,
                                      s_axi_portB_wready,  s_axi_portB_bvalid, s_axi_portB_rvalid;
    wire [C_M_AXI_DATA_WIDTH-1:0]     s_axi_portB_rdata;
    wire [1:0]                        s_axi_portB_bresp, s_axi_portB_rresp;

    // Hardware Sideband
    reg  [127:0] aes_key;
    reg          aes_key_valid;
    reg  [15:0]  num_blocks_to_process;
    wire         aes_key_ready;

    // Verification
    reg [127:0] pt_array       [0:NUM_BLOCKS-1];
    reg [127:0] ct_expect_array[0:NUM_BLOCKS-1];
    reg [127:0] extracted_ct;

    integer i, pass_count, fail_count;
    reg [31:0] status_reg_read, rw0, rw1, rw2, rw3;
    real start_time, end_time, elapsed_ns, total_bits, throughput_gbps, throughput_mbps;

    // =========================================================
    // 3. UNIT UNDER TEST
    // =========================================================
    sys_top #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
        .MEM_SIZE(MEM_SIZE)
    ) uut (
        .clk(clk), .resetn(resetn),
        // Port A
        .s_axi_awaddr(s_axi_awaddr),   .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),     .s_axi_wstrb(s_axi_wstrb),     .s_axi_wvalid(s_axi_wvalid),   .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),     .s_axi_bvalid(s_axi_bvalid),   .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),   .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),     .s_axi_rresp(s_axi_rresp),     .s_axi_rvalid(s_axi_rvalid),   .s_axi_rready(s_axi_rready),
        // Port B
        .s_axi_portB_awaddr(s_axi_portB_awaddr),   .s_axi_portB_awvalid(s_axi_portB_awvalid), .s_axi_portB_awready(s_axi_portB_awready),
        .s_axi_portB_wdata(s_axi_portB_wdata),     .s_axi_portB_wstrb(s_axi_portB_wstrb),     .s_axi_portB_wvalid(s_axi_portB_wvalid),   .s_axi_portB_wready(s_axi_portB_wready),
        .s_axi_portB_bresp(s_axi_portB_bresp),     .s_axi_portB_bvalid(s_axi_portB_bvalid),   .s_axi_portB_bready(s_axi_portB_bready),
        .s_axi_portB_araddr(s_axi_portB_araddr),   .s_axi_portB_arvalid(s_axi_portB_arvalid), .s_axi_portB_arready(s_axi_portB_arready),
        .s_axi_portB_rdata(s_axi_portB_rdata),     .s_axi_portB_rresp(s_axi_portB_rresp),     .s_axi_portB_rvalid(s_axi_portB_rvalid),   .s_axi_portB_rready(s_axi_portB_rready),
        // Sideband
        .aes_key(aes_key), .aes_key_valid(aes_key_valid),
        .num_blocks_to_process(num_blocks_to_process), .aes_key_ready(aes_key_ready)
    );

    // =========================================================
    // 4. CLOCK GENERATION  (100 MHz)
    // =========================================================
    initial begin clk = 0; forever #5 clk = ~clk; end

    // =========================================================
    // 5. AXI TASKS
    // =========================================================
    task axi_ctrl_write(input [C_S_AXI_ADDR_WIDTH-1:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            s_axi_awaddr = addr; s_axi_awvalid = 1;
            s_axi_wdata  = data; s_axi_wstrb   = 4'hF; s_axi_wvalid = 1;
            wait(s_axi_awready && s_axi_wready);
            @(posedge clk); s_axi_awvalid = 0; s_axi_wvalid = 0;
            wait(s_axi_bvalid); s_axi_bready = 1;
            @(posedge clk); s_axi_bready = 0;
        end
    endtask

    task axi_ctrl_read(input [C_S_AXI_ADDR_WIDTH-1:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            s_axi_araddr = addr; s_axi_arvalid = 1;
            wait(s_axi_arready);
            @(posedge clk); s_axi_arvalid = 0; s_axi_rready = 1;
            wait(s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge clk); s_axi_rready = 0;
        end
    endtask

    task axi_mem_write(input [C_M_AXI_ADDR_WIDTH-1:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            s_axi_portB_awaddr = addr; s_axi_portB_awvalid = 1;
            s_axi_portB_wdata  = data; s_axi_portB_wstrb   = 4'hF; s_axi_portB_wvalid = 1;
            wait(s_axi_portB_awready && s_axi_portB_wready);
            @(posedge clk); s_axi_portB_awvalid = 0; s_axi_portB_wvalid = 0;
            wait(s_axi_portB_bvalid); s_axi_portB_bready = 1;
            @(posedge clk); s_axi_portB_bready = 0;
        end
    endtask

    task axi_mem_read(input [C_M_AXI_ADDR_WIDTH-1:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            s_axi_portB_araddr = addr; s_axi_portB_arvalid = 1;
            wait(s_axi_portB_arready);
            @(posedge clk); s_axi_portB_arvalid = 0; s_axi_portB_rready = 1;
            wait(s_axi_portB_rvalid);
            data = s_axi_portB_rdata;
            @(posedge clk); s_axi_portB_rready = 0;
        end
    endtask

    // =========================================================
    // 6. MAIN TEST SEQUENCE
    // =========================================================
    initial begin
        $timeformat(-9, 2, " ns", 12);
        $dumpfile("simulation_trace_500.vcd");
        $dumpvars(0, tb_sys_top_500_vectors);

        // --- Reset & default signal values ---
        resetn = 0; pass_count = 0; fail_count = 0;
        s_axi_awaddr = 0; s_axi_awvalid = 0; s_axi_wdata = 0; s_axi_wstrb = 0;
        s_axi_wvalid = 0; s_axi_bready = 0; s_axi_araddr = 0; s_axi_arvalid = 0; s_axi_rready = 0;
        s_axi_portB_awaddr = 0; s_axi_portB_awvalid = 0; s_axi_portB_wdata = 0; s_axi_portB_wstrb = 0;
        s_axi_portB_wvalid = 0; s_axi_portB_bready = 0; s_axi_portB_araddr = 0;
        s_axi_portB_arvalid = 0; s_axi_portB_rready = 0;
        aes_key = 0; aes_key_valid = 0; num_blocks_to_process = 0;

        // =====================================================
        // TEST VECTORS
        // Key = 2b7e151628aed2a6abf7158809cf4f3c
        // Generated with a pure-Python AES-128 ECB implementation
        // validated against all NIST FIPS-197 known-answer vectors.
        // =====================================================
        // =====================================================
        // TEST VECTORS
        // Key = 2b7e151628aed2a6abf7158809cf4f3c
        // Generated with a pure-Python AES-128 ECB implementation
        // validated against all NIST FIPS-197 known-answer vectors.
        // =====================================================
        pt_array[  0] = 128'h395B3D53B7DAFC910C44DEBDC85B7A54; ct_expect_array[  0] = 128'hE60999DECF9FB080CEB76AD6558EC1CC;
        pt_array[  1] = 128'h0FA8B3812023A3BA98894219AD10DA56; ct_expect_array[  1] = 128'h4A3B7B4ABA226A3882141EC3E7AD41FF;
        pt_array[  2] = 128'h983D168905F70233E61102DCB7C5C42A; ct_expect_array[  2] = 128'h4F266D658D3B4A9E86DA58EB847EBE6D;
        pt_array[  3] = 128'h0ED0738EA5D85CD222BFE39FE1724A79; ct_expect_array[  3] = 128'h43F94264B1E35D15FEA9150D4BF89FA4;
        pt_array[  4] = 128'h242E4F7900F4B691A26B2B4DDB6616E8; ct_expect_array[  4] = 128'h99BE8FBDC33CA7744A42AD1206C02744;
        pt_array[  5] = 128'h720B384B06E20DFD17E46E64EB13FF7A; ct_expect_array[  5] = 128'h8C241A4EC7EBF9DA0D71E6368A63E4A4;
        pt_array[  6] = 128'h8ED260C8C36CF7F93590033D7DA24D0D; ct_expect_array[  6] = 128'h22C9F496A5D377939459026E37DF8749;
        pt_array[  7] = 128'h02CC1C4C530FC97991B0C8D4CBF83266; ct_expect_array[  7] = 128'h1E7188BCF3EAA21D12D774549A9F04C5;
        pt_array[  8] = 128'hE9E18225038FBDC9E58ACB95B1CB078D; ct_expect_array[  8] = 128'hBD6BCFA40BD46799110D6281276D01B0;
        pt_array[  9] = 128'h1AC84B77BCC36E3A01DBADE49EBC10D1; ct_expect_array[  9] = 128'hF8B7B9780F37EBD5228DC4BECB70B25D;
        pt_array[ 10] = 128'h5529DBEB1693FFFF570EECA0F5D3FA13; ct_expect_array[ 10] = 128'hDCB8577CD784A8D7101F889568412479;
        pt_array[ 11] = 128'h9B5D64D0CBE2A109C414606A80A402AC; ct_expect_array[ 11] = 128'hDC799BF57EEC0FC5EC17F1DC637E3EB7;
        pt_array[ 12] = 128'hA31BFA5DB4F5014156BC12E2BA6AF8D1; ct_expect_array[ 12] = 128'hB88DDB419B57FDEDC49BC5B1B45B3434;
        pt_array[ 13] = 128'h1357191E42127D535582BF847D3BC3F5; ct_expect_array[ 13] = 128'h6575313F9418204DC3F888D9332B7204;
        pt_array[ 14] = 128'h7792B4BB6E5F9956FD5A115B384D9FEC; ct_expect_array[ 14] = 128'h3A47CA97937D051B3DAA414B08DA4612;
        pt_array[ 15] = 128'hDDFB149361657E5C3728B6F48B6367A0; ct_expect_array[ 15] = 128'hD49BE5336826950AFCFAD9FA1077BEE7;
        pt_array[ 16] = 128'h85B14DB313A9CBC844F94FC14179DA98; ct_expect_array[ 16] = 128'h69050CEDF5DEC057DC82A4B0607E2D7A;
        pt_array[ 17] = 128'h00487EB3B27D06E97DDE65B564CD6E9B; ct_expect_array[ 17] = 128'h73F47E3015A7C8E8D4FBAC82AF5524BA;
        pt_array[ 18] = 128'hC65650482EF74576F35406D9469107CF; ct_expect_array[ 18] = 128'hBE3621A656F2746C89704726813E80D7;
        pt_array[ 19] = 128'h4E5AC34C925077AAC27449A6735A3D1D; ct_expect_array[ 19] = 128'h5BBD468FF87BB12ACD9E5A0B78519D96;
        pt_array[ 20] = 128'h1E2306A9F4A0142B8D38B3273ED93D38; ct_expect_array[ 20] = 128'h725FFC6E01E450F6D93D2BAAD8B21CC0;
        pt_array[ 21] = 128'hA37A35CA997646C54DD9F4E6FFE80C32; ct_expect_array[ 21] = 128'h7E2F9238B8C18E1DE23D57D614D97DDB;
        pt_array[ 22] = 128'hB0A286FF910A14CCB016B9E4C827FDEA; ct_expect_array[ 22] = 128'hA0318702C2C68894EC1A299BD5BD0EBB;
        pt_array[ 23] = 128'hEA64E7EADD8A8C4135926D7B18BC8373; ct_expect_array[ 23] = 128'h89536933FA2C781CA981551E2D67CBF0;
        pt_array[ 24] = 128'hD60D8F63EAEF4BDC56A731A40E74DA77; ct_expect_array[ 24] = 128'h2D9D9C4B41D966C411178760978CEAC5;
        pt_array[ 25] = 128'h699ABC68EEE9CC28C9D92F7B334E8EFB; ct_expect_array[ 25] = 128'hEB04D6D84993B93A1ADDC7AD508E3C24;
        pt_array[ 26] = 128'h660ADBEF313838BF1AE1A52F0127343D; ct_expect_array[ 26] = 128'h3623ABBBD76EC1A8D7E6E980823CE15F;
        pt_array[ 27] = 128'hFAEE2A5E2069C2235061C12B53D89F7C; ct_expect_array[ 27] = 128'hFB508E88C28CA5E2C71CE490A6685C0A;
        pt_array[ 28] = 128'h3B5AEF54A36EFBB673C2DC80E0CFE973; ct_expect_array[ 28] = 128'hAF12B6059603F1927F32C29EC20A9760;
        pt_array[ 29] = 128'h22C58FAAA5F42B92E0E5863A121BE947; ct_expect_array[ 29] = 128'hE1720830F5D5879DED262EEE368D25BB;
        pt_array[ 30] = 128'h0D08784162A652E9F5F194FAFD88E130; ct_expect_array[ 30] = 128'h008ECEE72FE4CAB0ECDE1CF41EEEC52E;
        pt_array[ 31] = 128'hDB55632456427F3C0858D062C701295F; ct_expect_array[ 31] = 128'h19D40CE036BFBE7008D90A3F4413F4D3;
        pt_array[ 32] = 128'hAB992CA718769B0765187A89E601C430; ct_expect_array[ 32] = 128'h2F6D1591E039371D173268B4BE8753D1;
        pt_array[ 33] = 128'hE2DFC0B41593BDA13E7D5CEB1E7FDA67; ct_expect_array[ 33] = 128'h138F427D3A47A5046CD3FB013C5927F9;
        pt_array[ 34] = 128'h7767ECCE5F6A27EFCBF27EFA4D0EDF14; ct_expect_array[ 34] = 128'hE819C1A25618C0E27291BB739698B831;
        pt_array[ 35] = 128'h5CC81EBAB27E1D8472DEB3F953BCCDEB; ct_expect_array[ 35] = 128'h4B20CABC5A8A60C17AA5F4AD63408921;
        pt_array[ 36] = 128'h6E4325ED4DF2C3D587AC3DC7D40C5807; ct_expect_array[ 36] = 128'h50E1A7E8F5EAB486F1672610D62E493A;
        pt_array[ 37] = 128'h6ADB9874F2E78A0A7288A1773FED8384; ct_expect_array[ 37] = 128'hB536DF88F991EDD750760660008845DC;
        pt_array[ 38] = 128'hFBF671A7C6C298DDE5E10021BF41D734; ct_expect_array[ 38] = 128'hB26D70C136B880934CFDED4889FA1673;
        pt_array[ 39] = 128'hDA3E530D7331D83308CF282B8F926618; ct_expect_array[ 39] = 128'hE22AE29FCFB677043C673B4A98866AEF;
        pt_array[ 40] = 128'hB8C3BE2619F40CF3199AEE6F92C871AD; ct_expect_array[ 40] = 128'hB6D80BF013077273DECBCC47C53E14EA;
        pt_array[ 41] = 128'h7D929919FAE404E894B2C9B8AB9924E7; ct_expect_array[ 41] = 128'hDE717CDC11DB13228FCF9D9A2254535A;
        pt_array[ 42] = 128'h73E40381AF344EC8622CF72A671EDED6; ct_expect_array[ 42] = 128'h49ED48762705BE0153B61D722F7D3825;
        pt_array[ 43] = 128'h65A0A537C93009FF42AE8AFD1E5BD751; ct_expect_array[ 43] = 128'hEB37D82D905070751AD07DC90EC997E9;
        pt_array[ 44] = 128'h2C0F918D05C357FE4668E8CA328107BA; ct_expect_array[ 44] = 128'hED997A56634C24C2F4CCC479AD31D50B;
        pt_array[ 45] = 128'hDA9B800805805B0E2932364CA7F04A29; ct_expect_array[ 45] = 128'hB757FC8CE8EF1D6206EBB25AE7BF5837;
        pt_array[ 46] = 128'h2C3B0D41A4711F76B1CBEA27BC0854D9; ct_expect_array[ 46] = 128'h0F87272245E443C5F235FDA912269EE3;
        pt_array[ 47] = 128'h560E5BB7C7B0655EB50640612E25162F; ct_expect_array[ 47] = 128'hC9B8B9FF2B7D7780010526371039F500;
        pt_array[ 48] = 128'h15068F01CE61D71FD790A40578A62610; ct_expect_array[ 48] = 128'h79DA4B5296F32AD8BE473E63C2E8C487;
        pt_array[ 49] = 128'h9F2B703FAD92CDA7A6807DED20EB8603; ct_expect_array[ 49] = 128'h21F8C7BDA90D5FBB5DCD88F9DF19D8CE;
        pt_array[ 50] = 128'h904D3D5F6EBD3203A87EE6898D5E826A; ct_expect_array[ 50] = 128'h75D47B9274FC91FC7E34AE76726E3838;
        pt_array[ 51] = 128'h318FFFBD251721BAA2373AD2E6630614; ct_expect_array[ 51] = 128'h344483411B6E1C5361B81BB3983390CB;
        pt_array[ 52] = 128'h312D687701EC4A1A8A49CD04057A522E; ct_expect_array[ 52] = 128'h8D9855C0C080DCB74319892F38FA9561;
        pt_array[ 53] = 128'h79E4444D9340A3F48B68E90D933072DE; ct_expect_array[ 53] = 128'h4102198B20525147F74CC3D2C8E087A0;
        pt_array[ 54] = 128'hBA624DCDD95E8026CCD267E99DA66975; ct_expect_array[ 54] = 128'h6D2BC0AC7A5BD321359F7ADA8DB54EC0;
        pt_array[ 55] = 128'h63355688D592868D1FBF7FCE029AE0A5; ct_expect_array[ 55] = 128'h11F13A9E2AEA95EE3FA832418C14A18A;
        pt_array[ 56] = 128'h857A6C1A061E4F6FBC216EA6AF5DB966; ct_expect_array[ 56] = 128'hC622A19449CBD661E3DE0EDB746202CC;
        pt_array[ 57] = 128'hCABB93D12806ED56B9907256737684A4; ct_expect_array[ 57] = 128'hB788DB9976FB65DB3125250AEAAA323E;
        pt_array[ 58] = 128'h95721307C3BE0A034101C196B7F48F6D; ct_expect_array[ 58] = 128'h34715DE66E9BD91C88447F56CF7AAF9D;
        pt_array[ 59] = 128'h875FAFF2EB56593AB05117970DAA7398; ct_expect_array[ 59] = 128'h8451E45A1D2E8D990676EB6F6FAF901B;
        pt_array[ 60] = 128'hAA0C79D8C9786405BA3961AB51D424DC; ct_expect_array[ 60] = 128'hD113D296C978990B6FAA3551A463433F;
        pt_array[ 61] = 128'h6E1FAAB1AE094A194387C179FDC212AF; ct_expect_array[ 61] = 128'h1FE0D20F5A3AF04831DA43A656D11951;
        pt_array[ 62] = 128'hD99D7C25910E56A48F05DE2F92AE3A55; ct_expect_array[ 62] = 128'h22F0B8720C49C35E1958EAA288E2909F;
        pt_array[ 63] = 128'h7A1B7C2AE98EBDB3C5D0BA5E683CF31A; ct_expect_array[ 63] = 128'hF61A99BCA6D1D4E48907F9EF1D1C3AD2;
        pt_array[ 64] = 128'h7A6C6949C24A06F35E5C63BB83C5DBDC; ct_expect_array[ 64] = 128'hEAD55DB13AA6997871DA8276051B7667;
        pt_array[ 65] = 128'hEEAD5BDB8BEC1FFCE339CB8EAD299C4F; ct_expect_array[ 65] = 128'h8F3BA48EF840D441EF21B9D17878A1F0;
        pt_array[ 66] = 128'h08314063A49A55952FB6CB084A5733E0; ct_expect_array[ 66] = 128'hA29F7461EA50964370D576187C4A58A9;
        pt_array[ 67] = 128'h1A3158A7819F5779E7ECA2B03B65583C; ct_expect_array[ 67] = 128'hBDB2E04241BA49F061B7CD27C346CBFA;
        pt_array[ 68] = 128'hAF4020BC42F9BEF15835D9ED54412AB4; ct_expect_array[ 68] = 128'h5ACE11993100F608A8A5918FC80620B2;
        pt_array[ 69] = 128'h5609836876D665478FA0ABC93FC438FC; ct_expect_array[ 69] = 128'h0AF31A9BFE4ADBE0296CA3C3BBE29571;
        pt_array[ 70] = 128'hF87E2B721E6C36156C443BAEE577DF3D; ct_expect_array[ 70] = 128'h7B674163F72235A75083EE2C9F0E624A;
        pt_array[ 71] = 128'hB224E09A99DCEF19EBF0E5F056ADB865; ct_expect_array[ 71] = 128'h737793938A8CB2C78D97ABCC6CF8B06A;
        pt_array[ 72] = 128'h4E9533F2312E86C3458907BA4D118536; ct_expect_array[ 72] = 128'hFCC67C0AE53E0856CBAD03CD0790D0B5;
        pt_array[ 73] = 128'hB0C1F95C372F506833322B8C5050BCC8; ct_expect_array[ 73] = 128'h4E5E40D8478A22EBAD8F645F656359DD;
        pt_array[ 74] = 128'h1975C6BD79EB54FDE316B8390F5810A0; ct_expect_array[ 74] = 128'hBEF652F615E4B3EA20D0005C72F8989C;
        pt_array[ 75] = 128'h40DFB6DF6AEAB7A8194897A6C2E50703; ct_expect_array[ 75] = 128'h3E80338C23F71E6A7CD839C1D649ED34;
        pt_array[ 76] = 128'hC1267894BC2553106AE83D26C877D8F5; ct_expect_array[ 76] = 128'hE6B59F4EB82BED84FA9263AAE40DDBFD;
        pt_array[ 77] = 128'h6CED3A5287653B55814D4E00FD17B60F; ct_expect_array[ 77] = 128'h8C90D6C86A43964E61EE59B8662BCB29;
        pt_array[ 78] = 128'hB6D6FE5E2BA77497C7346C7CF3E4A851; ct_expect_array[ 78] = 128'h093E0B65044C5D1236D39B15FCE137E3;
        pt_array[ 79] = 128'h2F727DF3F01958132516445721E44215; ct_expect_array[ 79] = 128'h1CF70FDD3F3FEAA46AD8BDF6B336018A;
        pt_array[ 80] = 128'hEC7D5A49D46F9704EFDDB9934D391AAD; ct_expect_array[ 80] = 128'h59A6996AF194612926A49BC6A0555D91;
        pt_array[ 81] = 128'hC73E3F6D682A18753540A09CC6A84C92; ct_expect_array[ 81] = 128'h9BFBA23DBA55504A343128238A5683B3;
        pt_array[ 82] = 128'h326B7F865CEB71B0A242549564842C98; ct_expect_array[ 82] = 128'hD6C63CDB1C234789DEF95B7D2DC25564;
        pt_array[ 83] = 128'h56BB0828749F6FB0C725E5E890C68F41; ct_expect_array[ 83] = 128'h1EE4BB6A349C6A7A93166CE04449112D;
        pt_array[ 84] = 128'hC0490517B0F38630E6DB0E073E04E852; ct_expect_array[ 84] = 128'h7859BFFE7F57D43F0A3FB6ED4C4B2107;
        pt_array[ 85] = 128'hF07579133D71EEB50745EC4A403697AD; ct_expect_array[ 85] = 128'hF2DD37300FF0D8AE2FFEEFE5F8648240;
        pt_array[ 86] = 128'hA1F95EAC5EB25678327E47B0BF7878FD; ct_expect_array[ 86] = 128'h0D438B6E07283A8A542CB998A5668315;
        pt_array[ 87] = 128'h8586F80B33B4F186131AD4AFA08709D9; ct_expect_array[ 87] = 128'hE50BC457CC88A09BD159BF28ABBFDD41;
        pt_array[ 88] = 128'h43D5A2D33BB04046DEA16A02D0B0088D; ct_expect_array[ 88] = 128'h4A4AFAA688E29F1780BABBA65919462C;
        pt_array[ 89] = 128'h70DF6D441AB6371E1B98D6ECF48060CE; ct_expect_array[ 89] = 128'hF24955DBDDB4D81324D73809ACCFB109;
        pt_array[ 90] = 128'hB6B421B8F30737D7155128753769C0F8; ct_expect_array[ 90] = 128'hA72DD9A89BB779FF3456DA8A442BD17A;
        pt_array[ 91] = 128'h4932D352CD91223E47FFEBC834690BDF; ct_expect_array[ 91] = 128'h512C6A73430365D540BDCE68D4E874B4;
        pt_array[ 92] = 128'h7B1E41234B11926CFDAA50B430D4F09A; ct_expect_array[ 92] = 128'h1462F238083D921CDB96660979B0AB31;
        pt_array[ 93] = 128'h7995B1912C9017637B5E68DBC5F433C9; ct_expect_array[ 93] = 128'h2E55C990E54990FD4BC17B2C5ABC1C59;
        pt_array[ 94] = 128'hCF3A53FF0992BD5C13C84F973157FD53; ct_expect_array[ 94] = 128'hEBA1C3C5419103B17748F0EF49909314;
        pt_array[ 95] = 128'h956602FBCEB8B5397316F6D5A6E4AF08; ct_expect_array[ 95] = 128'hD07836E9B2C8343B42D66AEE96175922;
        pt_array[ 96] = 128'hC2C58A064F085C5EA2B2CDF28C97E616; ct_expect_array[ 96] = 128'hFE2114D4CB43D2DA4D0D27E3D99FFA50;
        pt_array[ 97] = 128'h6CC8BCE8352B8D131D2F99BE0F562520; ct_expect_array[ 97] = 128'h4871060595B75C265FF12A498A848211;
        pt_array[ 98] = 128'hEF9FBE9E5FA4873B30D863FFE035FDE9; ct_expect_array[ 98] = 128'h683907E54C830B843194FB208D66FDEB;
        pt_array[ 99] = 128'h83D73DEECFB738EF775ABF689EAC894C; ct_expect_array[ 99] = 128'h1B7FBDEADB32F1ABFE3B73B00FA4FDEB;
        pt_array[100] = 128'hF9A7BBA5A3DF1D1023AEFE47CA57FA86; ct_expect_array[100] = 128'hB8657BD925625F53E7BA629821852E23;
        pt_array[101] = 128'hE505468A3B1DF608F594A1DDDEF24058; ct_expect_array[101] = 128'h8C2309853527C6D2C64D2D339C9C1057;
        pt_array[102] = 128'h4BB52E850F3F39950411F81111DBA51D; ct_expect_array[102] = 128'h38C1547598510D2A3608DC8F5E5EEB57;
        pt_array[103] = 128'h488983E51C30E6D3E0B289B34DACB6E2; ct_expect_array[103] = 128'hD96CE3572168F5C659B7C4F7FE8F77A0;
        pt_array[104] = 128'hFC6ED472818CF9CF6CC1F2BF87C81591; ct_expect_array[104] = 128'h70B2A5504EC2CAFDCCFF83616B94E5D3;
        pt_array[105] = 128'h66203D970186493BA0499C1862912245; ct_expect_array[105] = 128'hEED7562AA537FFAE87EECBD56C7F1070;
        pt_array[106] = 128'hF483723ADB59DE04FE6A42C53704DAFE; ct_expect_array[106] = 128'h7E14A6AE4E1899AD325825BA88204E56;
        pt_array[107] = 128'h8E1DF64442716FC4BBE6706D7514F5F1; ct_expect_array[107] = 128'hE246DB9D3513992613E6726BDCD22B23;
        pt_array[108] = 128'h878E65E75C9FD102D8FFAE021D9E025E; ct_expect_array[108] = 128'hB0CD82F72E4A1E9954E7C7BE900A1390;
        pt_array[109] = 128'h5806606F31B25AB6E4B62676E2333327; ct_expect_array[109] = 128'hBBFE1CE60AAA6775562E6D4E7DC3A2E1;
        pt_array[110] = 128'h1178DA561C30842772D6DF5FC549D8B6; ct_expect_array[110] = 128'h78D1ED3AA458175077B5226CA7614A38;
        pt_array[111] = 128'hB937726EE15B1B362BDE3506EC5EA116; ct_expect_array[111] = 128'h524C8C7021B165FC22B08CA29ED89976;
        pt_array[112] = 128'h829C10828BE4F91E72A767AE4FE755BB; ct_expect_array[112] = 128'hB9F6614FE29E3C60215C810BDC93CE25;
        pt_array[113] = 128'hDCF624566ADE9851CFBA4E5D85E941A7; ct_expect_array[113] = 128'h9260CE99110974BBA6F68E96837E4ED3;
        pt_array[114] = 128'h7E67F74CDECF5A3829F29CEAE2A0393F; ct_expect_array[114] = 128'h39F4809229A3D896AF693A778052D61F;
        pt_array[115] = 128'h39C4B5E0F07FB45595AE2A820A9A802F; ct_expect_array[115] = 128'hF7F7C441F03DC821C2FF23A97139E522;
        pt_array[116] = 128'h76C8A7D7030634D60A3BF06E271B7984; ct_expect_array[116] = 128'h0633940FED7EE94192F549CA73382018;
        pt_array[117] = 128'hF05FFED448F77657845A3C5B2DAC67A6; ct_expect_array[117] = 128'h3431623CDE4C897AE3F3A50376D38F5E;
        pt_array[118] = 128'h613D92BB3C08F6C2A1BCB33D4EEABE0D; ct_expect_array[118] = 128'h1C82B317B90650C08028DC112AB96F8F;
        pt_array[119] = 128'hBD335FA4BD08A85E52BA37C57724114A; ct_expect_array[119] = 128'h5071100B4DF415BD43EDA5BDCED6E065;
        pt_array[120] = 128'h63324F049FAD19DACCA7E97DCCA529A8; ct_expect_array[120] = 128'h120F7D64C00EB49382F2F478DFC44759;
        pt_array[121] = 128'h6BD62BC3D2A8BE57C266546C6980FB04; ct_expect_array[121] = 128'hB31B84B98CEAB8F58DF6857806735B1F;
        pt_array[122] = 128'hA8B2F7C1557793C06F95AC8F5E4C2FD7; ct_expect_array[122] = 128'h2995E2265D92ACED4A2082374B34794D;
        pt_array[123] = 128'hC6DA847C9C33DA0BCC978CDF60FA0024; ct_expect_array[123] = 128'h6C84F2C7ECDEEB21F9C60F0789AA80F8;
        pt_array[124] = 128'h693DE65AAA5F2514DF26F32CE4A18AC6; ct_expect_array[124] = 128'h69F8F09ABD0E7A89C174D912B7F9D02A;
        pt_array[125] = 128'h6F756F708A7F9967F1B9B6747794F475; ct_expect_array[125] = 128'hD143C49091CD3EAD0B15442379430202;
        pt_array[126] = 128'hE9706B51C292A35554E6F6B7F9BC1FA5; ct_expect_array[126] = 128'hC53C53671F6BEF84E0E0015DC6984AD5;
        pt_array[127] = 128'hE81A7906DEF3491C74A6EAE3B425767A; ct_expect_array[127] = 128'hB131A930256D0C839370305F0D7BBE58;
        pt_array[128] = 128'hB2CF6C5BB89F2E2C33F70FFD8D34F6BF; ct_expect_array[128] = 128'h0ACB41EBEB0237FCB71A76D41328F4EC;
        pt_array[129] = 128'h96D7ED8C576AC3C1CB509DD5F8B0B9CC; ct_expect_array[129] = 128'hC4743F9F9C4F055C3978F80CC8B00135;
        pt_array[130] = 128'hFA2CBBAEB104D8321B76983534355421; ct_expect_array[130] = 128'h55F7F99D92EB6BFBAEBC468558EA1E3D;
        pt_array[131] = 128'h493A139C75A9AA45A046E4EBE950133A; ct_expect_array[131] = 128'h8F9E50258593DFD667D8D75C8523E727;
        pt_array[132] = 128'hCD2B3C28A14E7DFCF792670B78FA5ED0; ct_expect_array[132] = 128'hB364372901D903832D0158FD8E2A5C37;
        pt_array[133] = 128'h1C5BAC430746C43D9DA146A525FF4D89; ct_expect_array[133] = 128'h1F67FA946DD4CB3642DFB858A1D6B4DB;
        pt_array[134] = 128'hEAF6ED567F2BA204168C2F17648ACE8B; ct_expect_array[134] = 128'h27AB8C0DA44D54C4C2CEA0EF4B9119C9;
        pt_array[135] = 128'h62D18070C22B876E062A93430ACD1DEE; ct_expect_array[135] = 128'h1332AFF68D08E960A83A6EBBB8D8D140;
        pt_array[136] = 128'h0651AC07C31DF60D208F07DE4AEC727D; ct_expect_array[136] = 128'hDB0F9190122711BB701DFBD90147E56F;
        pt_array[137] = 128'hAB09BEBFD512052E1F3444876443532D; ct_expect_array[137] = 128'h4E260BC695CEB683B70B3E84D5ECB742;
        pt_array[138] = 128'hB872CDE427584694631994D0A0BFB77A; ct_expect_array[138] = 128'h2E147F7BEA0427BC67ABB5B0AE422317;
        pt_array[139] = 128'hB0B7C1A45FE3007E69280A1461F27C6C; ct_expect_array[139] = 128'h8F43D9623D0E2C90F3BDF9A953FF721F;
        pt_array[140] = 128'h557F4FDE8A5E3587BD08D62D3E573E69; ct_expect_array[140] = 128'h6B04DFCAD03ABD5BC29D038FC0887B69;
        pt_array[141] = 128'h5E599C8137ADBC22EFE7E9A3F1DC14EA; ct_expect_array[141] = 128'h296A330A8A697BABF4FA422115587446;
        pt_array[142] = 128'h95DBCB02DC595D39C263A842B6F46005; ct_expect_array[142] = 128'hB5BC3D42A927097D15B85E604D62FCB2;
        pt_array[143] = 128'h987EA51812847C7D6776784C70F4CC5E; ct_expect_array[143] = 128'h9663AF92FE49445DF90FA1B01B64D208;
        pt_array[144] = 128'h6589E09BD396695A3FCCC5B46CC77271; ct_expect_array[144] = 128'hDC0FA6219AED5BA794C72B7EABCAC8E4;
        pt_array[145] = 128'hB08015FD4C585BD70474BEE4602043C0; ct_expect_array[145] = 128'hC71909BA55F9DD52D8F1B157B72D41C1;
        pt_array[146] = 128'h175B573A80FDC8D657A06A702554B603; ct_expect_array[146] = 128'hAA756A303ACDA0327F8F1CA7872FAF97;
        pt_array[147] = 128'hCF27338C08232CB4AEB09B4012D4EEBC; ct_expect_array[147] = 128'h640A8BC8F7A58D2FE41D72B4BAE4282C;
        pt_array[148] = 128'hCD1EF49BD68E3F35F3DF61A0BA7DA104; ct_expect_array[148] = 128'h6AA7EB8FAB1864E33C5B73C811CD214E;
        pt_array[149] = 128'h622BD18F8D45324A3D3DCC828CDF0C07; ct_expect_array[149] = 128'hF606FABC400B7B3CC40630665F72EE08;
        pt_array[150] = 128'hE5A70E43975E85001762160167560AD3; ct_expect_array[150] = 128'hD1D4B788660EE5DF1A01D19CA7AB9358;
        pt_array[151] = 128'h9CE943477C97BCAA9BEA3EBFC976F10E; ct_expect_array[151] = 128'h574A29AB9DA460F6D2A6F0D10EE2FDD4;
        pt_array[152] = 128'hC504A00AE4A6780A3F8C0C9B8A0F004B; ct_expect_array[152] = 128'hA2F7C7C2CCAB3A374B26750B3A3F80D3;
        pt_array[153] = 128'h817CAAF10CB2F00C2370502DED92AFF2; ct_expect_array[153] = 128'hE021833CB39F568FFB1F44057DF448B8;
        pt_array[154] = 128'hEDACDF571898DA33AB2F638C81DA219B; ct_expect_array[154] = 128'hD55E6719EBC059ED9F4A83C3A7F547CD;
        pt_array[155] = 128'h755B07104BA7E6193F491C44780B1C43; ct_expect_array[155] = 128'h4D10D957F56B094153A5D2DEFC6A2BBF;
        pt_array[156] = 128'hA0ABDC30E3EBDD233EB315DDFAEC4E9A; ct_expect_array[156] = 128'h30B91D4B30A4128BB5598BFC1F9AEE4B;
        pt_array[157] = 128'h764ECA5AC79C01974A189E380E31BEB4; ct_expect_array[157] = 128'h1D3705AAAB61CDE39C3738E61D96EB8E;
        pt_array[158] = 128'h6DEBAA438EF530FCFFB0C24D9805A65C; ct_expect_array[158] = 128'h79745A5D7F260E9F265C6E5F98A32680;
        pt_array[159] = 128'h798B87B3791EC3FB63FA7176D567A09D; ct_expect_array[159] = 128'h0B759D8304B2E2D79CAB4ECBFB0F06A1;
        pt_array[160] = 128'h2D1B6533454ABF2C545B869FA7F59900; ct_expect_array[160] = 128'h62437456007F42CEC92EE6A426CF7983;
        pt_array[161] = 128'hBE56D04F16C36CFD21F133FB1C0C9E02; ct_expect_array[161] = 128'h41093A807049988BC84F40DF2E5F44FD;
        pt_array[162] = 128'h93CCD78076439078FFDF88F530978B43; ct_expect_array[162] = 128'h4DF3F21993E484E27CFE91A279D16D91;
        pt_array[163] = 128'h4F16334E3882528513106E4B7ABC39AC; ct_expect_array[163] = 128'h7C69D32AA045DB2731F616E2EDD96871;
        pt_array[164] = 128'hB2856FA7D04DDDF712CB38B689F61852; ct_expect_array[164] = 128'h6584A182E85843168871074E28C7B691;
        pt_array[165] = 128'h72338D5471D92FD01DB9F4070F5BFCEB; ct_expect_array[165] = 128'h86A9AF15CE1980EA8E546D59016A61F2;
        pt_array[166] = 128'h1C32FEEA09174E726E1D84B0F9DB255C; ct_expect_array[166] = 128'h75B545BAE4067B5DBC0E9007281B1488;
        pt_array[167] = 128'h388BCFC65B9F482CE9D279AE56025254; ct_expect_array[167] = 128'h80020B60A68CFD2DCB431043CD9C4494;
        pt_array[168] = 128'h8B3B5358AB6E9B75AA2682D7100E9C5D; ct_expect_array[168] = 128'h4F5A481D6A3F93D28EA62A95F7275D6F;
        pt_array[169] = 128'hCF15136E64DDF737778570640BF51588; ct_expect_array[169] = 128'h40325F4BD3604CBF95BA57E32EBB3319;
        pt_array[170] = 128'hB01A066405C03374A8E6ACB69113BAF8; ct_expect_array[170] = 128'hE37443911B6E10236B64FA8AAFFFF415;
        pt_array[171] = 128'h0FF280DFCBA4C7C3E37CC716E4966AE5; ct_expect_array[171] = 128'h4DE3255B2ACCAD8E2914F0B88966E85F;
        pt_array[172] = 128'hEB559943C3FCFD88324EFE81EFAD86BD; ct_expect_array[172] = 128'hD11E0DA5D5A3B3F82035126F5278AA06;
        pt_array[173] = 128'hF92B343BEDDEB602087FBEB35EA13DE0; ct_expect_array[173] = 128'h8F8207DA7046C06526A989E74F2C2E78;
        pt_array[174] = 128'hEE300357DF5E45F38276F352A6FB28F5; ct_expect_array[174] = 128'h449B4A25F56F07B03122742AF10B30A9;
        pt_array[175] = 128'h6131AC081DD4D16CACE263AED5572B13; ct_expect_array[175] = 128'h6F90EAF347BF5C3A9E3B35844A3806EB;
        pt_array[176] = 128'h566166FD6E2D56FAAA0AD9DFE189BE34; ct_expect_array[176] = 128'hE11B0B8525149EE6EEE0A092674C98AC;
        pt_array[177] = 128'hDDD6BC6905001D0249BA38135247590D; ct_expect_array[177] = 128'h4219EA350EE310F56616DE5122BC79ED;
        pt_array[178] = 128'h7E3F30659EDF83633D436923E7ED4FBE; ct_expect_array[178] = 128'hE6AB8E4D7CCF3F1E6BA577A351B168C0;
        pt_array[179] = 128'h601DC12149790883904097DCD00643ED; ct_expect_array[179] = 128'h4F70FCD6F70A7F8517D09924311B58CC;
        pt_array[180] = 128'h57313A7F3FCE5F490A853ED555C2CC85; ct_expect_array[180] = 128'h99B4AEFA2AB213832416F5477550082B;
        pt_array[181] = 128'hB08A428892118A16E36FA8113146F23B; ct_expect_array[181] = 128'h198546B6F663E4B5F4F0C7F554468FB4;
        pt_array[182] = 128'hC89DE3E17F46E64346CFAC736C1BD05E; ct_expect_array[182] = 128'hDDD0EE240631089263BEB1F5808A0EE6;
        pt_array[183] = 128'hD365024321399F382E1F84639EBA4279; ct_expect_array[183] = 128'hE6BB8E1EA05B44B8C7720AF859B7F6B8;
        pt_array[184] = 128'h993480568B77719C65ED772DFB6C6060; ct_expect_array[184] = 128'h6DB20D477D5AB754194EA891C4C1AE97;
        pt_array[185] = 128'hA79D00E7D1D9D3D39E9BEA5323602150; ct_expect_array[185] = 128'hF4DC269969548DBD5A4DC5BBC4934B1D;
        pt_array[186] = 128'hB9452BBBA919BF3E803C167DA26CE790; ct_expect_array[186] = 128'h4736B772C7A4EF1B7526002E31B2BD2B;
        pt_array[187] = 128'hF15687E31625A35DFE1102E86DF824E5; ct_expect_array[187] = 128'hEDA1D374FCCA5210F5A8991427EC61FF;
        pt_array[188] = 128'h74D41A6EAC794CE50874BF3F35BBA1B3; ct_expect_array[188] = 128'hA8261CC26736BC04648C64B8E27B7EB7;
        pt_array[189] = 128'hDB9F21FA4E31156642935D607F2664D5; ct_expect_array[189] = 128'h77356D10540BE3849B4FC9673A3FCD6D;
        pt_array[190] = 128'h83F00F9E8A0D149DB066DCAFFD83792E; ct_expect_array[190] = 128'hC63F2D577BC1A0F0F8DF5BB2CB7F322D;
        pt_array[191] = 128'hE44784871837606B18C0C7B318002A93; ct_expect_array[191] = 128'h77594087519D2F55129889D49FD044D7;
        pt_array[192] = 128'h70F2524CFDF8D08DCBDD304E78605E8E; ct_expect_array[192] = 128'h1393CF2A4FB35ACC26254DD4ADE9003C;
        pt_array[193] = 128'h94777F1B7DE4430B8F3DE7D51453D40A; ct_expect_array[193] = 128'hCA85BEC8A7937C3CC475AE56A1486232;
        pt_array[194] = 128'h744408F3792CF91BFE5FF742A745573E; ct_expect_array[194] = 128'h793A81038DF1571BB7EF9D96093E4D8D;
        pt_array[195] = 128'hCBD319AB841A45F693959418BAF833A4; ct_expect_array[195] = 128'h4BDE5CE95A2D4AF9070AA4031BFE16FC;
        pt_array[196] = 128'h68898C9E46ACE4E028F5EC35FF4F7BC9; ct_expect_array[196] = 128'hE2A69F459E150B153752127D134BEB64;
        pt_array[197] = 128'h8968D8461894F7939DADCC5A38D6A410; ct_expect_array[197] = 128'hCA688ACBF17EEA9F73FCB62DD7CB2224;
        pt_array[198] = 128'h9B9747B71CA5DF8227A93EA84C7C2B9C; ct_expect_array[198] = 128'h09FCE20257EF26493A4DC2A8B7019759;
        pt_array[199] = 128'h7565D97EE37CBD447938F031D74420E9; ct_expect_array[199] = 128'h140289F4618975C000CB21FF6AB2D6EF;
        pt_array[200] = 128'hB395F4469BA24928C78CC3F8E77C70E6; ct_expect_array[200] = 128'hDFD9B4C1F7834C1A35B905E578D2158B;
        pt_array[201] = 128'hE6C5DE1DA98AF405B79A91A7DE48369C; ct_expect_array[201] = 128'hCB7D245E41393EDCFBAB3D555EC3EA2E;
        pt_array[202] = 128'hC6356988D7D36B8771B70250D4345C9E; ct_expect_array[202] = 128'h72A071D0A52BCBB11BD15D3060A345D9;
        pt_array[203] = 128'hE119E213D05499AA1FDE3C8E8926F608; ct_expect_array[203] = 128'h6070F30A91C1BDEF416A0027BC49EBB8;
        pt_array[204] = 128'h4229A104F391BCC80DD50B037D70BF00; ct_expect_array[204] = 128'h3508CB1538BB18E81E2EC01093852471;
        pt_array[205] = 128'hB4CD3FDDAE3E1AE9C09F5910C101A338; ct_expect_array[205] = 128'hA160C3A610F52CC2650DA21A5A49FFC5;
        pt_array[206] = 128'h804B189B970631628328CC07435A4599; ct_expect_array[206] = 128'hF5EBAABB891B1BB074017EE7FEBF80C3;
        pt_array[207] = 128'hD9C855D0653277406AA5E688703B6671; ct_expect_array[207] = 128'h91F877619D4F84E7BE6CD9F52DD18F7E;
        pt_array[208] = 128'hD3C339B1DE6AECF98EF4480BDD1E6800; ct_expect_array[208] = 128'hDE13E8F4F0D13742AC3D046856361C88;
        pt_array[209] = 128'hCE4150417BE9AFABA5B0B7944767228A; ct_expect_array[209] = 128'h79D3BFCF5BB7A9B0B4B9F6E35A4BF0BE;
        pt_array[210] = 128'h60E09C5D3EC0C1F471A98832223BBA18; ct_expect_array[210] = 128'hFFE469B630E52F2C818CCEC0499D8E94;
        pt_array[211] = 128'h5436071D04357353C3D1ED55BA7AF389; ct_expect_array[211] = 128'hFC6600CB2ED457CBB2E82C6034A16FD3;
        pt_array[212] = 128'h2276DD89DC755AF98102CBC43CA700A1; ct_expect_array[212] = 128'h6859D18E6346CA22D126EB356524F6BA;
        pt_array[213] = 128'h9ADFEEC7D894BA09BE9A195D4BBAFF4F; ct_expect_array[213] = 128'h33BDF3595AEE4FF80F1AF335901EBB7C;
        pt_array[214] = 128'hE4AB68C72923F26C31F818783C4ACB8E; ct_expect_array[214] = 128'h78708BBA744A501D183B41134BB43C7B;
        pt_array[215] = 128'h0B3A52578068AA38B33082F388FA029E; ct_expect_array[215] = 128'hE0CDB82FFDC56A14F8EF5ECFFC49C10E;
        pt_array[216] = 128'h3BFBFD2C6C560AE0D2EEF6EACFED94A1; ct_expect_array[216] = 128'h98ED994481542DF0259B38F8E3BEAA0F;
        pt_array[217] = 128'h4CA4B8D7F3F1C792FF3A65BDEF83F1EC; ct_expect_array[217] = 128'h2BE694B908E4515262A08480F5719A52;
        pt_array[218] = 128'hB8AEB887725583A71DB54E93C3388C3E; ct_expect_array[218] = 128'hDDEBB8443645D02BE2E723C18BBF91C8;
        pt_array[219] = 128'hECEA5DA69DFF9913C18F5F2AAB5590C2; ct_expect_array[219] = 128'hDDB70A54AC2507904B5F62B1AFF7AA17;
        pt_array[220] = 128'h49CC47D7014C6FB1CF3F4C1A0CB08FFC; ct_expect_array[220] = 128'h98F6B25FE9EA6D14C09883F420584AA0;
        pt_array[221] = 128'hDBE5243E16C7EA8F977F66319767B07D; ct_expect_array[221] = 128'h98488767E26390A5DF1648FF5CB68090;
        pt_array[222] = 128'h83C75CA053F5C89BD4F5E14BC5F3BB27; ct_expect_array[222] = 128'hDF3EE87D13B24D463C1345C62CCA3BB4;
        pt_array[223] = 128'hEB865EAE45686F69B70D9FFB1E06709A; ct_expect_array[223] = 128'h12F553D77204E2E24A8EECED76C68AD9;
        pt_array[224] = 128'hB1FDCEE75520881A520779E46FC2C7DA; ct_expect_array[224] = 128'h91AAEA85D447FEDCC8145518E2DD8D77;
        pt_array[225] = 128'h8469081645F046567C747B036ECCDFBD; ct_expect_array[225] = 128'h04D60DB2718FF9C6D7F87725B1B49D63;
        pt_array[226] = 128'h0D163A9E0DBB5033039297A3735DB984; ct_expect_array[226] = 128'h57F8E0452B720570A8DA449116835795;
        pt_array[227] = 128'h4C7A9767FB6E5670A05527263F2DA7C2; ct_expect_array[227] = 128'h0E8E4C7274943F294E9209FE9FDB65CB;
        pt_array[228] = 128'hBF0526B0D17AC7DF00A19046A41BBCEA; ct_expect_array[228] = 128'h780B9DE0939B1F98C1CB7A5D12A7A5BB;
        pt_array[229] = 128'hDBDF9DCD2093CD4D800EDE2CCB5F8365; ct_expect_array[229] = 128'hA8A3BA49BAFC8EF0B50A50DEA367F4C4;
        pt_array[230] = 128'hEDFDCD69EE99E9A786D008421FFE1364; ct_expect_array[230] = 128'h466DE1A553F134BE432C2447AA30AD01;
        pt_array[231] = 128'h9C792165CAC7E11E57CD75DE66CFFF86; ct_expect_array[231] = 128'h6F57055FA23A5F9AC391EE60CB37B889;
        pt_array[232] = 128'hC877F527B4827D03DAC87AE730AB3272; ct_expect_array[232] = 128'h51E7822CD14F723E132EB571FDC11602;
        pt_array[233] = 128'h2BAD2523540F8E92D4330172947580E0; ct_expect_array[233] = 128'h5E10C963E68F8F6ED279A71A8FDEBD47;
        pt_array[234] = 128'h380C447044FA7E5EBD9344D0B281B10C; ct_expect_array[234] = 128'h239FD09598DFC919B18F171DE40D2A0F;
        pt_array[235] = 128'h756F63CF2047352C0441E7C7A781F8D3; ct_expect_array[235] = 128'h2CBA02E84A20DA0CBAE2B22306089914;
        pt_array[236] = 128'hF41F432709E9EB3E7BB3F0FE0010BEB3; ct_expect_array[236] = 128'hC891B1348F61F9404D3CE2456A42724D;
        pt_array[237] = 128'hBD2887BCA4542977FE9186A88AA1EC73; ct_expect_array[237] = 128'hF8A350940AAAB089D6E5987FAE21A8FE;
        pt_array[238] = 128'hD4DEF7D7F8BD7942A78C14B4035A5A17; ct_expect_array[238] = 128'h0674B5CCFFF99B6F448B3B88EFE0DC51;
        pt_array[239] = 128'hE2E47A47963B1B0B4AFC57A68EEA8963; ct_expect_array[239] = 128'h4A7976715C8F5824E810686AD223A80B;
        pt_array[240] = 128'h5678B5BCCB58FF8E65E35A084B419FE5; ct_expect_array[240] = 128'hA7B823512DC935F9F52242A7F5D3D56C;
        pt_array[241] = 128'h5A9C7C7E3BC09EA51C4029AC1D11DB1F; ct_expect_array[241] = 128'h125ECB9EC51747F04376A550F85CB9D0;
        pt_array[242] = 128'hBC0CD9BD650DBFAAEEBA5CA89CF073D7; ct_expect_array[242] = 128'hBEB8D5E01B0916BA959C580E4139C233;
        pt_array[243] = 128'h661DE545B8E3CAAE81A1B3652C8EB86C; ct_expect_array[243] = 128'hDDDC46584960C57B60604D3CAAECE1E7;
        pt_array[244] = 128'h2398F34C7342A2BC0D9FAA66F12BC773; ct_expect_array[244] = 128'h9A153B26BED277130C6BC068F099F15A;
        pt_array[245] = 128'h01E0D575ED7FF87DDECE045190C0F197; ct_expect_array[245] = 128'hB25966C7083CDE7F686E03B408161040;
        pt_array[246] = 128'h570914E742D224E36BE2095049B67430; ct_expect_array[246] = 128'hC07F935ABC496290B64DD2C4B24B0214;
        pt_array[247] = 128'h5D314C48D49C3F4A8581CB53E1E1CD5C; ct_expect_array[247] = 128'hA6251D5002D570B72B2E81220288301A;
        pt_array[248] = 128'hDFAF5B27F76BD6BE50304F77C6FAB252; ct_expect_array[248] = 128'hA2E00F5ABDF85294609C301AABB09CCF;
        pt_array[249] = 128'h99969B317C2FFB81E4EBE92A007CEDE9; ct_expect_array[249] = 128'h5203DD771E2A8EB4436D3D080F49391B;
        pt_array[250] = 128'h0BACE65513F197EBE914A0E2514559F0; ct_expect_array[250] = 128'hEC7FF8FD0FE3A5C080D20F2594822FBD;
        pt_array[251] = 128'h33C84AF815076BF28E35825627F56569; ct_expect_array[251] = 128'hCA310EB78861A073E1A8F70D6AFC1D11;
        pt_array[252] = 128'h03DE9F9EE0F6C3F943B936D0F131AB9E; ct_expect_array[252] = 128'h3390B498919169DCEB173C3135611CAE;
        pt_array[253] = 128'hD95AD2C8BFB19E3D2B1ADEA8007AE165; ct_expect_array[253] = 128'h0AFC0143D0522ADD49BF18C1572E9000;
        pt_array[254] = 128'h2DFEA806EA8CAB0A10855C3777FB916B; ct_expect_array[254] = 128'hDA3EAA8468833B39228CDE2725E120CB;
        pt_array[255] = 128'h4A16123DD1356A1BA123E0ABD7D17E69; ct_expect_array[255] = 128'h3108B10A336E4995694434897C4C8E40;
        pt_array[256] = 128'hB8A425E20FB0A1646FE58818DCF95E5E; ct_expect_array[256] = 128'hDE46696258C06B97057C7E331597CA57;
        pt_array[257] = 128'h2755A0AED8F2D4F33DE858546A508AD3; ct_expect_array[257] = 128'hD8E4D60AB1A525B66F279654138EDEAA;
        pt_array[258] = 128'h4CE2682F7882AAF1134C865008B527A6; ct_expect_array[258] = 128'h0067560D206E7013DAE46447ED2FD60B;
        pt_array[259] = 128'h9C9AD1965E38D6A83A9675F938230D3A; ct_expect_array[259] = 128'h25F74CFBBBBF5A2543C799793004265C;
        pt_array[260] = 128'h238DF8C6C41333EC7399B48FD1E5BA07; ct_expect_array[260] = 128'h3F224B07FA23E1E52D8E7382BA3B264B;
        pt_array[261] = 128'hD27174F200FB5336B61308CC3A0E0939; ct_expect_array[261] = 128'hD21D42AD0B107B6178CCF72893865DFE;
        pt_array[262] = 128'hF5DF316246C5351BEC4B1FD463F2EFED; ct_expect_array[262] = 128'h5DCDC178FE771ACE43DBCF541B6E6C07;
        pt_array[263] = 128'hA6F7E857EE15B92D9228DB8574E32EF6; ct_expect_array[263] = 128'h9DB562128EEBA310EF36C9A2F9A9DDD3;
        pt_array[264] = 128'h64725E07C99E72C7604B6905EDFAF348; ct_expect_array[264] = 128'h01E869FD25871A83909D53DBB5E64D41;
        pt_array[265] = 128'h2A57617D2B19253071C00DB791713487; ct_expect_array[265] = 128'h560E33EFFD380BE547F3455334D656D0;
        pt_array[266] = 128'h7E39151102C70C64A81E674AA21BAF0B; ct_expect_array[266] = 128'h25F485B256376D7E2480999F7D9AA196;
        pt_array[267] = 128'hAACE914C6CB119984472C3A180E8F7DA; ct_expect_array[267] = 128'h6101DCEA53C982E46B8E4A3EA9BA7B0A;
        pt_array[268] = 128'h11F97B91A4F6DF363D944908004901F0; ct_expect_array[268] = 128'hBA2CBAC234ADE6C1F1E7BCCD6B496B85;
        pt_array[269] = 128'h0C87AB8BF0DD985624CB1C25F1BE70BB; ct_expect_array[269] = 128'h9127443D5654898D3B0BA91CDA513A4D;
        pt_array[270] = 128'h6E8F9E3B37732486080178292AB6529D; ct_expect_array[270] = 128'hB2EB969F9DEB0307F13B3A636326D386;
        pt_array[271] = 128'hCFA7BBE8944F6D76CEF61F3CF81AA0FD; ct_expect_array[271] = 128'h5FFA963C539282C4B475C3E137972F6C;
        pt_array[272] = 128'h24975C109DFAC6DC36A16D084E32A98A; ct_expect_array[272] = 128'h4069A393DBD7889F06998DACB7A27530;
        pt_array[273] = 128'hE739E8D92693DE9EB46A431392CF4C4D; ct_expect_array[273] = 128'hB2FDED3515CB7C1EB143FF87EB6BAA99;
        pt_array[274] = 128'h12576BADA22D7B0F88F7D5B33F1D99D4; ct_expect_array[274] = 128'hD553BA524126A0D786281CDEFBE12094;
        pt_array[275] = 128'h25BAEB309D08E4D34DF48AC1ABAFDF29; ct_expect_array[275] = 128'h23755166FC7976AAA05CD24F90810593;
        pt_array[276] = 128'hCA4197F28C4CCB229A3F2BBB01FC4255; ct_expect_array[276] = 128'h9BEA8AC1F9438CC098525D44FE67B081;
        pt_array[277] = 128'hE84AA2947D7DCAA98888C0B7012E85ED; ct_expect_array[277] = 128'h20A7759BBAB1050B64769DCA7D05064F;
        pt_array[278] = 128'h27488B04DDB8C756406EEC6284DDE1EC; ct_expect_array[278] = 128'h5DFAF0480264978F4BF3060ECBF1EDF1;
        pt_array[279] = 128'h27980BC301725668A6076AA4C1684751; ct_expect_array[279] = 128'h698DF91C46C400A643FD31BCBF8279F2;
        pt_array[280] = 128'hBE06E363813F9F4AB2A5959B970FECC9; ct_expect_array[280] = 128'h6EA54E2C2AD7E50BAF3B19618D33D98C;
        pt_array[281] = 128'hDAF5479FA0E1ACFFCB16DB2290225DA9; ct_expect_array[281] = 128'h7CBAF8417377ACA45EB73605B5C545BF;
        pt_array[282] = 128'h570961E853D0743E1A3D441D6AC66EE8; ct_expect_array[282] = 128'hF9CE569E837745AB54295C75FE2AA717;
        pt_array[283] = 128'h2C6C60228F837BBB01FF113BA196610E; ct_expect_array[283] = 128'hB0ED4B8BC42C6F36CCD61576309110B2;
        pt_array[284] = 128'h9CCC5C6649BD0E62DF6E2AFC36B91654; ct_expect_array[284] = 128'h53FE2C76C2ECD966F5F0CAD45157AF95;
        pt_array[285] = 128'h9EC9A6DF4F5F07B3392BB206E6AC4B4C; ct_expect_array[285] = 128'hAAEEB9C699EF8C311A27FF84B07FA17C;
        pt_array[286] = 128'h99157FE9BD6F7AFA15E253A1FAB862BC; ct_expect_array[286] = 128'h66088A9B606D7D7C3DF9F9DE382600DA;
        pt_array[287] = 128'h4753EE168F0374F645A3A47731AAAA28; ct_expect_array[287] = 128'h393BE0850EB77737B851B4936091C361;
        pt_array[288] = 128'hB9B98FCD2DB1076FD60E50721A688749; ct_expect_array[288] = 128'h119FCE6488EDDB5DC55785081E1B68F3;
        pt_array[289] = 128'h81A0A6010D7AB1C78DA868BF3521A0BB; ct_expect_array[289] = 128'hA686008DDDF5737982E19516932322CC;
        pt_array[290] = 128'hF2678E925899DF921B413226C14A3C76; ct_expect_array[290] = 128'h2869108ADCE2ECAD86D2983D8E52F403;
        pt_array[291] = 128'h9596F5B5F8E85C62E9E922A1E30E0A53; ct_expect_array[291] = 128'h6857CA8E2076C193D48F2751A8AFBD97;
        pt_array[292] = 128'hCC29D0AA1901EADDB51E16D6513EFD6F; ct_expect_array[292] = 128'h633EAE5B9F2F094EEE08384161ABF664;
        pt_array[293] = 128'h744169219631799BA2A0C159CC79AC29; ct_expect_array[293] = 128'h67EB40469AC1974A3059E80654FFE059;
        pt_array[294] = 128'h83A099681095A12FD8A2416BB0ED83F5; ct_expect_array[294] = 128'h6A5BDBC086E083BAEB275A6B728053B4;
        pt_array[295] = 128'h377C42F81B88A7CFB1B58143185D26EF; ct_expect_array[295] = 128'h0503426813977AA73160F955AE337D76;
        pt_array[296] = 128'hFE88A3995CE1F8C69E0783C5A21368EA; ct_expect_array[296] = 128'h399B6A6CAE6F4CE30D9352168A0715D6;
        pt_array[297] = 128'h8DDA60B8F2BCE98F648E5CDFA4734288; ct_expect_array[297] = 128'hAFC9102774E9D888433B4D6F736AB62B;
        pt_array[298] = 128'hA9EA2E6097CEA5106338C105CB3031D4; ct_expect_array[298] = 128'h546C556B96FC8144AB7B9F7B764C5298;
        pt_array[299] = 128'hFA776972C7CAE70F6968B5DD182AC0CD; ct_expect_array[299] = 128'hA81D61A5238D30F1F65EE2A189F3FB3B;
        pt_array[300] = 128'hEF119D19CE50BAA30C4051D06EBB0909; ct_expect_array[300] = 128'hCE0C8C7AABC1B47FF679A3AA6E249948;
        pt_array[301] = 128'hB60DF20F75607A150A5488D9E8AB9097; ct_expect_array[301] = 128'hC2C001F717A8A06F76158CD058C41032;
        pt_array[302] = 128'h7761FB88D1E47102B81B011099384E60; ct_expect_array[302] = 128'hDD1674A1B193A06360800C98ADF7003C;
        pt_array[303] = 128'hDD99414F439475EB9A7CA896D33C9358; ct_expect_array[303] = 128'hCC59EC89EDA20F1EE0BD4C8F1C65F0CB;
        pt_array[304] = 128'hFA1366F029A492CA2B24206F683EFE1E; ct_expect_array[304] = 128'h43019DBEA1E39FB471DD65A76942B5FE;
        pt_array[305] = 128'h3A897E1E5D19FE488595264CA4BFC2F2; ct_expect_array[305] = 128'h24DA0B0DFDB45619BA12A617AC149143;
        pt_array[306] = 128'h9A127E4CC3855EA04CD2675C3C6157ED; ct_expect_array[306] = 128'h95CD05303A9C57D8F1A1BAF9156F9714;
        pt_array[307] = 128'hCAD52A0C46DD7A775573164C83E55275; ct_expect_array[307] = 128'h65828CBF5724C89913AE51044D7DDC11;
        pt_array[308] = 128'hA9BA073EC5AD9A4D6E03E82B3FF7F39A; ct_expect_array[308] = 128'hEBD7040B6BAC1BFE9DC71E30EC00D458;
        pt_array[309] = 128'hD3A1596C78A438DE1E1FCDD3C93F2449; ct_expect_array[309] = 128'hE565A65ACCEC912D24476E9DAE43C699;
        pt_array[310] = 128'h3FF9E742B1B1B7ECE0DAC2ADC046311C; ct_expect_array[310] = 128'h74A5885A758346D0F1DF73CE62ACF04E;
        pt_array[311] = 128'h25AF52A60E903C7EF24CBE0B295CBE0A; ct_expect_array[311] = 128'h5B6EDD83CC28903A10AFD8A7048697D7;
        pt_array[312] = 128'h0B582C6305B7FF58ABC30743B1EC55E0; ct_expect_array[312] = 128'h3C0D7E0F196B3A0AF1BEF12C156423AB;
        pt_array[313] = 128'h56F8A5DEC584D447ED7A9DEE9CBEDF11; ct_expect_array[313] = 128'hDE46A3ACF4E2B12629EE4F7945BECA13;
        pt_array[314] = 128'h8997BC0CAC1C36A02090130B95B5919A; ct_expect_array[314] = 128'h3D0C570048231E8104720EA26BFB4C3F;
        pt_array[315] = 128'hD74B269735363BBBE5828E6FA2842BAF; ct_expect_array[315] = 128'h8DFAEC41C8BE194D1D029A0BDBABCED6;
        pt_array[316] = 128'hBBD98C4859906AAEAE7AA0070BA42578; ct_expect_array[316] = 128'h1B77D2C6DDE2C705CD609253996AA6E9;
        pt_array[317] = 128'h89ACBFE233FF22FED566271E880A5668; ct_expect_array[317] = 128'hA80FB22360CBA3AC45BB76E6ACE87F0E;
        pt_array[318] = 128'hCB6363C17AF35BAB6FD723408A8B49A2; ct_expect_array[318] = 128'h599A87F73CAE9A276796131E0C6A11D7;
        pt_array[319] = 128'h975CF787CABC2E3F65A8CF9B532FD1C3; ct_expect_array[319] = 128'hEAF089A571519D83AA48608EA5F8CAE2;
        pt_array[320] = 128'h7C6790B88AEC03528CAFF93882C640BC; ct_expect_array[320] = 128'h28B9186906EECBBDC1835E18D22C6922;
        pt_array[321] = 128'h5F56C21BDA6818245B03A633A7280C60; ct_expect_array[321] = 128'h544DE1FDAB9B92E9DBE36B8C28DCA2F6;
        pt_array[322] = 128'h5920126601856EFABF5D8BFAE2B98B32; ct_expect_array[322] = 128'hCF534389CABE93D1A1553E81495348A1;
        pt_array[323] = 128'h39975563F4627B3C186D6022631B00E6; ct_expect_array[323] = 128'h51EFC512559D1CF4840A591F31BC1C28;
        pt_array[324] = 128'hBEAED8B3BF219C3593D7171628114C5F; ct_expect_array[324] = 128'h70F1CBD23436DB52432BED4E704DDED2;
        pt_array[325] = 128'h6BA8B460EC13DC7E18AA072114F2619A; ct_expect_array[325] = 128'h999CC2D3936700C84A4325FA86A51B58;
        pt_array[326] = 128'h0DCAD7EB2FD77BA792AB4D804EEE9162; ct_expect_array[326] = 128'h4894C4750B8F7F3CA8F685948994DE06;
        pt_array[327] = 128'h973CE5565B8EBA2A6AD101FB48A547A4; ct_expect_array[327] = 128'h5F0B4CAB859C3DAF3B763314ABC3EB68;
        pt_array[328] = 128'h1BF7EC96D150081EE149BE0522BA8CEF; ct_expect_array[328] = 128'h6D5A20B36C317728434297DB9ADC0397;
        pt_array[329] = 128'hBA62B603D39CD8AAAF3D24DE079A4359; ct_expect_array[329] = 128'hDEC338266C87FACE275F5D15FD072727;
        pt_array[330] = 128'h8B7D2A6FFED833457C3A2D6FB51FAE20; ct_expect_array[330] = 128'hA5DD5A9741C4D7A5DA4B30AAECB6C7C2;
        pt_array[331] = 128'h930E07AA64EEBD2168EB06F277FE3EF3; ct_expect_array[331] = 128'h65DCC59998201D0ADE0505F174887258;
        pt_array[332] = 128'hE5EF6DD62A83280CD0102D6D51C3546B; ct_expect_array[332] = 128'h74A864D8AF53072E35B792F9B217EBC1;
        pt_array[333] = 128'hB3D12330970D802FFF111C1DFC751A57; ct_expect_array[333] = 128'h0AB4B1EB56414EBEF07197C7952C98AE;
        pt_array[334] = 128'hB2E87BDE26A77E5A338F3E7F96ED48D7; ct_expect_array[334] = 128'hA3ACDA4D9D24DAAFC1F1A7AD8E523B83;
        pt_array[335] = 128'hD01672B41FA2F564772B75DCEF5FEF48; ct_expect_array[335] = 128'hE1DF932FEE6120B7A7E6250E2F67FC31;
        pt_array[336] = 128'hCA569C2A8BF12E890A715075DFD522A3; ct_expect_array[336] = 128'hB0ECCF31BE63F967200800CA91FB5122;
        pt_array[337] = 128'hE00E2547EAA9E99DD76179148FCA6225; ct_expect_array[337] = 128'h0ED6347E4ECE335DEBB54744DCEA2092;
        pt_array[338] = 128'h0566122BED650651591B5F81B274BED3; ct_expect_array[338] = 128'hF74BD7BE4A2776E417DE4E2FCF717CEA;
        pt_array[339] = 128'h8D5E49A136C7C6562F29FD3B35A9F10A; ct_expect_array[339] = 128'h4A557743CA49AA8F52BBF18FCF6F56CC;
        pt_array[340] = 128'h31A4B61E141DCCBAE5B0B8D7375EBE38; ct_expect_array[340] = 128'h05E50DDB1537F0B3C0F78D6AB5DBD9A5;
        pt_array[341] = 128'h6E67BB72DB9F4C7BE7D74A23052B729E; ct_expect_array[341] = 128'hDBDFC293077BF0772492A1A087AF77EB;
        pt_array[342] = 128'h22220F972C1B701EB2FFAE67BC7994EB; ct_expect_array[342] = 128'h0B55C3C4DB27594E0F7F8FF0E8AF3327;
        pt_array[343] = 128'h4167A07C31F6B0C3DBF7507F347E4939; ct_expect_array[343] = 128'h6920C0F4CAFEAF3843398E9221B82CD1;
        pt_array[344] = 128'h26FB25AA876DA97494DC4875FDF39C72; ct_expect_array[344] = 128'h32D7B8E758432A9BC5409C79BE8723A3;
        pt_array[345] = 128'hD2312BD808749839EF46596E9AEC94A8; ct_expect_array[345] = 128'h9C5D02027912EBE4BEA2CB1F867EC65C;
        pt_array[346] = 128'hECBBF0CAB31AE59E86390D988E5E3D99; ct_expect_array[346] = 128'hE2E1C2183BB69353C49C951721107688;
        pt_array[347] = 128'h4953250FD60CE98A835B43D1D9E6F7C7; ct_expect_array[347] = 128'h2DBCB9E42C0841BAA054EF452D32959F;
        pt_array[348] = 128'hC07DA179E471D2F475425431B0BC6CA1; ct_expect_array[348] = 128'hD9F5BCBCD5F0B0FD2F00E3B5EA18BD5C;
        pt_array[349] = 128'h4AA02B28C4C17E13E9A5E44DA2F4F5A1; ct_expect_array[349] = 128'hBF2D1F76FA53E92967F47327A38559CA;
        pt_array[350] = 128'h9BDFC334E3133E841B9B7D590110189F; ct_expect_array[350] = 128'h15409A20FA7C6E275A0E506CFF7038AA;
        pt_array[351] = 128'h19B95552AA01A626EAA34493C36D82A6; ct_expect_array[351] = 128'h9E4FD0C48DF6F1AE38210AE3809DC7B5;
        pt_array[352] = 128'h1E54EEE0ACB2571CF62143899360AFBB; ct_expect_array[352] = 128'h7694578D733724016D7BE3D149809392;
        pt_array[353] = 128'h8A27559C340BE93705792EB2AAF71721; ct_expect_array[353] = 128'h9DCEF36CE03BE5C0F80F94F73DB2DAD0;
        pt_array[354] = 128'h28019ACDB7C58A16072BE536131A8A1B; ct_expect_array[354] = 128'h58C53071CA962312ADB5ED568EA0E198;
        pt_array[355] = 128'h360D56D1D031FBC53CAB5C8D4DC38044; ct_expect_array[355] = 128'hD5DC2AE4643B9868F1C34D4B5A70BE07;
        pt_array[356] = 128'hC841B4F9DD70516B2FB99AF32A5D2D94; ct_expect_array[356] = 128'hB298913E5AC9E5858CCC733963DE2AAE;
        pt_array[357] = 128'h12500B69667225970576DE99923F182F; ct_expect_array[357] = 128'h6ECCB5042CDD558498E981D7F4201050;
        pt_array[358] = 128'h389CE9208714730B2FD82A0BB5180554; ct_expect_array[358] = 128'h69F8BACE7516944B58BC1F30C6DEABC9;
        pt_array[359] = 128'hC43606FD98C2180A90897A463CFD949C; ct_expect_array[359] = 128'h7A8F2F16582CA81C99F81F42A50961B0;
        pt_array[360] = 128'h279A784B7B4304F77975B24544D90684; ct_expect_array[360] = 128'h426C7840F1E3E4B444D24AADF3BD34D5;
        pt_array[361] = 128'hA8DB9A8C6A0CF2009D7AFECE75A4EE94; ct_expect_array[361] = 128'h880C5FC89CD454969F635A6C24839F5E;
        pt_array[362] = 128'h14BBDD24B206C039837ACB41B88D9B65; ct_expect_array[362] = 128'hBBBC65C1DAA63A8084C24CDD3F26D4D0;
        pt_array[363] = 128'h55A939858E96223CD318B9C821A2AA50; ct_expect_array[363] = 128'hE75D45D1811D6D424E88F8B177EC4062;
        pt_array[364] = 128'h6D980A68A039131EF89D95DFD0F1BA3E; ct_expect_array[364] = 128'hF34912B9338509D87536F674BF5E7224;
        pt_array[365] = 128'hB860119C86393C3F4E6D1455E6C5B966; ct_expect_array[365] = 128'h27BE4752111071EF5C8E3BAA7765F1BE;
        pt_array[366] = 128'h400BCF0DF9E8288CEEF76B68EDEF2F03; ct_expect_array[366] = 128'hE98A70761B9381A3BBD9A0DF9806F51B;
        pt_array[367] = 128'h42B54334D06ED1AF23F63FD2F4206103; ct_expect_array[367] = 128'h626185A19DF73F32492983F2FFAA1B5C;
        pt_array[368] = 128'hC73CA38DAFBE8AE1E8161F649B46B08B; ct_expect_array[368] = 128'h7D6772050345EB85FDEDBB6EEF1055EB;
        pt_array[369] = 128'h5716AAB54C89C5AF9441417A256A2354; ct_expect_array[369] = 128'h901304BDEE658911E7C78311FA674610;
        pt_array[370] = 128'h1D708BFB0B1C43117239D9F31B507EAE; ct_expect_array[370] = 128'hAD26CB4423AF493D2C341E0883943CF8;
        pt_array[371] = 128'h0B8953888FBE918AB94A7E64B5774CAD; ct_expect_array[371] = 128'hE1AE1A3E1B788F44227720A6A38EA02B;
        pt_array[372] = 128'h1241124EB87AB0329627938CC159D231; ct_expect_array[372] = 128'hEAEEC96D0496794610F9E4C8CBC05303;
        pt_array[373] = 128'hBC8839306CDC91F6001BD8FB8C21B968; ct_expect_array[373] = 128'hB9B136D51B5FF2E026F3F29753D50487;
        pt_array[374] = 128'h3DC149F2FDFD15E938BBA33632D3C78C; ct_expect_array[374] = 128'h8CD21226C167C34FE287F85944B7ECAE;
        pt_array[375] = 128'hCE6184F864BB5E79E7AFBACA7C9AE077; ct_expect_array[375] = 128'h01223ACCC3622201E0E262858AD0322E;
        pt_array[376] = 128'hE8ECF9E4849BB0A480E7A691DE1FDE95; ct_expect_array[376] = 128'hEFE989021345AB7FA4F18B55865D19F7;
        pt_array[377] = 128'hE1B03962E06BFA51EC70A0EA3FF90D9A; ct_expect_array[377] = 128'hD680B5799DFBE2C5969536B449450553;
        pt_array[378] = 128'hABE1136024A483C67FE1C6F5809BB227; ct_expect_array[378] = 128'hB528DCD433DE857A544C44155A9D0823;
        pt_array[379] = 128'hD0084AB782BDF22F50E8BC3168F76B0C; ct_expect_array[379] = 128'h27990A3755963BF581D54C3DB3284EDE;
        pt_array[380] = 128'h6799E9733D6D8111C903BB0443EDB930; ct_expect_array[380] = 128'h2A1657B5C4881404A09D11F3299F3118;
        pt_array[381] = 128'h1828C4C542993238821625241927D76C; ct_expect_array[381] = 128'hE8C1BDCCC84C0068508A4CF9B10B8608;
        pt_array[382] = 128'h9A42500D66522A7A6BD4F428CD05DD60; ct_expect_array[382] = 128'h98826AD222C35C52E861E537E3126051;
        pt_array[383] = 128'h1FA634DB7443B7F54F9A5F218C487428; ct_expect_array[383] = 128'hA3651AA9CCADD76D04CA61B261311968;
        pt_array[384] = 128'h2EC13BA860A02049353C4D4FA7E0E300; ct_expect_array[384] = 128'h55827A743ED1D4289F9955DD46E31960;
        pt_array[385] = 128'h301E957C4DFE6009402E63FC7EA5CF29; ct_expect_array[385] = 128'h21AEA8BF7E0667BCF93DE971AD7596C5;
        pt_array[386] = 128'h8DDD7E4A7976AD04CE6FC3DF77BDAECC; ct_expect_array[386] = 128'h604FF1AACAF99F0A1B4C6996C8C0C457;
        pt_array[387] = 128'h93B259851A15B1C891FD5DD21FDDACC0; ct_expect_array[387] = 128'h5D65F4AC2B899F91F5B58297EBA232AC;
        pt_array[388] = 128'hC56B2BB62D56526814F874BC7617C76E; ct_expect_array[388] = 128'h70BFDC63D26BB35EA53A5E282B4FC9A5;
        pt_array[389] = 128'h512696D5C3038389089D7C4A79CC80A5; ct_expect_array[389] = 128'h7CE62412023B5FF57C3AB59990C411B3;
        pt_array[390] = 128'hCDDE0F0BB5993B5B90EAEE66C87FC91C; ct_expect_array[390] = 128'h891DE2D18B51A370C98986D983341D04;
        pt_array[391] = 128'h4A8741ECEC67237E778C4C87DD653627; ct_expect_array[391] = 128'h78E754147D77E91919583290370B8F3E;
        pt_array[392] = 128'h6A4C29210E1C276FFC6568376F9B5530; ct_expect_array[392] = 128'hDDDD3605616A9345FF03B38A02B29A57;
        pt_array[393] = 128'hD7D54902039DC7A3380CCF8EE1852247; ct_expect_array[393] = 128'h3079FB751852599BF4C1B0A6ECE2350A;
        pt_array[394] = 128'hF58FEE0153E950CE1069D89226F82E19; ct_expect_array[394] = 128'h9A9A538755C5503C2AA8B49D6AB5CC62;
        pt_array[395] = 128'h5BA9941968711591454C671018690911; ct_expect_array[395] = 128'h959D4D85DEDE1204FEDF4DA097906EF0;
        pt_array[396] = 128'hE1B0516EC49DD6093B5DF79C4BD3CCF4; ct_expect_array[396] = 128'hFFFFBE4C09CF5D5A0137EF2EFA925959;
        pt_array[397] = 128'h28B49E05674B57C011C8B0A5193868E2; ct_expect_array[397] = 128'h3591DD0EAFACBBAF7E4721A0333A66FA;
        pt_array[398] = 128'h34504BCFC2BB13D33919BFEEAE5B2A43; ct_expect_array[398] = 128'hD412E11641A5F5593F4102730869952C;
        pt_array[399] = 128'hB045F9EB556EDCA5AEAF8778EF89C4B5; ct_expect_array[399] = 128'h93564362728B2C615F896F3CA6C9BF58;
        pt_array[400] = 128'h3F555A81FEE19AC858F4ECB57782CFA2; ct_expect_array[400] = 128'hF3EC791DE4B6C85EE8D6017271738375;
        pt_array[401] = 128'hD22D55BF4122379AEAB5CE5A984B2A21; ct_expect_array[401] = 128'h01541C6624F0BC700D76509711ADE47D;
        pt_array[402] = 128'h680862D7673B3A017DC8AABDFB0F3DA8; ct_expect_array[402] = 128'hB17AE6426846039255A18CF487DFB943;
        pt_array[403] = 128'h570AEC8A8BAFD0C4104FF13DD997C3AA; ct_expect_array[403] = 128'h24E270B0AB6FF08074E84D29CF123B59;
        pt_array[404] = 128'h385A90AA2127B8744C0A63B9910D1639; ct_expect_array[404] = 128'h778D374B70757B1FD9FB3A73F7F3DBAB;
        pt_array[405] = 128'h7C642C95928E6B262A31E6E83B147EE5; ct_expect_array[405] = 128'h78F25BE5EFD306BFC6FE2D768D009DA8;
        pt_array[406] = 128'h325A524E3FACBCFDBD4CCC3BB7FB6200; ct_expect_array[406] = 128'h29F060681B83CCC2328A1A89E5E23E63;
        pt_array[407] = 128'hFD36E7107FFC0CF05BF97E6EAAC5D523; ct_expect_array[407] = 128'h23C41A3A2D6B93771C7FDC3F06A64815;
        pt_array[408] = 128'h74B19A325D7BA6DF566640940432E1A8; ct_expect_array[408] = 128'hDCDA35A859B7C0A8D3ED822B51E98F16;
        pt_array[409] = 128'hD08DCAB5EF3C85750366F041BC5D22A1; ct_expect_array[409] = 128'h62E5406612E5CEFCA8C20CDFE250778B;
        pt_array[410] = 128'h0AC56CE26A644070B345C87023FB5BD0; ct_expect_array[410] = 128'h0AB59C4F68BCDD0675528053002E1E31;
        pt_array[411] = 128'h42AD6F2FA72940123D97C76062F7D5B9; ct_expect_array[411] = 128'h751951097E453EA1567E1B4E4DA328FB;
        pt_array[412] = 128'h010C5EA3EDAAE054F46E56DF1CC6106F; ct_expect_array[412] = 128'hDB78A558E5DCB676B25FED3F0A7D2EC9;
        pt_array[413] = 128'h6A05F424D002CFDD5A4FC54AA88B0C61; ct_expect_array[413] = 128'h7FFE20026462935348E38F4F5F5793FB;
        pt_array[414] = 128'h0DCDE678A379AA214EB7618E350F464F; ct_expect_array[414] = 128'h0679BE75DF259CBD1E9946DD8613D485;
        pt_array[415] = 128'h0968434684CA4424DC794CC33D9B937C; ct_expect_array[415] = 128'h7F93AF8426CA388E431575927D1FACA1;
        pt_array[416] = 128'h55B5B8CB70462FFA9BEC74FC2977B84D; ct_expect_array[416] = 128'h8DD02C74CE90C4DEE77348BDEC973DE5;
        pt_array[417] = 128'hACF1C709FF64228A24392FE487FC4F43; ct_expect_array[417] = 128'h341D78652665E3ED98FDD5C8B48120AA;
        pt_array[418] = 128'hA50D7462FC34F9B4031E52912DAE7118; ct_expect_array[418] = 128'hEE73C13A8D1D2E62AB795BA835D0A61B;
        pt_array[419] = 128'h54A0DE8B39004E3FED8BEBC7360DF85B; ct_expect_array[419] = 128'h9A673698AB03AA9B425DDD1A1B785F6B;
        pt_array[420] = 128'h6BB2DD0A005C6BB5916EF8DB8DF8733B; ct_expect_array[420] = 128'h753C03F28DAC8959F26EDFDE22666B88;
        pt_array[421] = 128'hC4493343F58634D242CAC1D9D08313B2; ct_expect_array[421] = 128'h5E10DBADCA80AE7799EAFA3C45E2496D;
        pt_array[422] = 128'h1793026C698C70218DFDADE4A1E17850; ct_expect_array[422] = 128'h4A64C7CB4F89596AE8F33B7F725BC651;
        pt_array[423] = 128'h9C7C8365B4ABF21AA51246A121C4E9F3; ct_expect_array[423] = 128'h5BA61BC1324E8CF8822C09891A559004;
        pt_array[424] = 128'h2B3E8FFF783AABA088FD9C4E9DAADF7A; ct_expect_array[424] = 128'hBFBAB2EFCD34920319B8574E92DC1EAC;
        pt_array[425] = 128'hDC38E8511EA5693E06E04AC60CAEC901; ct_expect_array[425] = 128'hBCCE99AC7FE26BFE353548276F6AE565;
        pt_array[426] = 128'hC104CECF2A5AC66321F61EDD8843D32E; ct_expect_array[426] = 128'h1AC3D41C3A84FD05FD60BB47041CD672;
        pt_array[427] = 128'hE31AD0FC7A117663B32F252699E0F505; ct_expect_array[427] = 128'h4C43BED40F9421977FE15BB9DCF24AB6;
        pt_array[428] = 128'hA54E978250D057CD7D8BB556D2A52986; ct_expect_array[428] = 128'h95825F6DBC814A9FB00D28591E1259C5;
        pt_array[429] = 128'h2A44AA71E92774951CC73E007C076B09; ct_expect_array[429] = 128'h87AF02B437AF56FC5C41E2ED54B81D44;
        pt_array[430] = 128'h7C538B045C35FA83A674BED7BEA96D10; ct_expect_array[430] = 128'h0CF2E40CBE8FB6C85873135B3DA0C253;
        pt_array[431] = 128'h86A322257AE93C97D7653AC747C1487F; ct_expect_array[431] = 128'hBD3245D6592E503BB9DB60FB05E06FCF;
        pt_array[432] = 128'h91C6337927B6E1F5962CEFCD72A0815A; ct_expect_array[432] = 128'h7DA4AB7101BAC26512DE7282902A6260;
        pt_array[433] = 128'hDF5C1457638D63B6876027214CBEE18D; ct_expect_array[433] = 128'h18973208741FA9B2EA5BC6BBB8F74803;
        pt_array[434] = 128'h4967DB1DFE494A77978393B73376001E; ct_expect_array[434] = 128'hBC7CD06C387301357AFAB872C2AAA171;
        pt_array[435] = 128'hAA1D2AFA46A3D52B18177FB925F4CDEB; ct_expect_array[435] = 128'hD1B435EDD78D1C727A9E12531C1B10A1;
        pt_array[436] = 128'h18D10E2641C930366A9976E45943FB0B; ct_expect_array[436] = 128'h39641B2924A563F55E7612D8CBA0EBEA;
        pt_array[437] = 128'hA8C0F5791D24D2849FC3AF50B4C45C0F; ct_expect_array[437] = 128'hFD678528E136979D3338C75E8FE40D46;
        pt_array[438] = 128'h6604ABD528FC7A65FE111DFFF4F3681D; ct_expect_array[438] = 128'h2B1A8B887F1C9983E07D60EBDBAAEF0A;
        pt_array[439] = 128'h2F6AAD9D59E5EC713955A556A835C83B; ct_expect_array[439] = 128'h522294B06F119CD5A77B5BC2CBE15E0A;
        pt_array[440] = 128'hD3CFDEB80D58ADC7158600C2A869D4C7; ct_expect_array[440] = 128'hF7F80DE806FBCFAA0AE31A6E49CB1BC1;
        pt_array[441] = 128'hEE3814CE589C9FC9E619479C539D4E88; ct_expect_array[441] = 128'h606A3689606ECA8032DA3A28811B02A2;
        pt_array[442] = 128'h6988EAE0D9B76AC09E666336EDFCA2ED; ct_expect_array[442] = 128'h4B6E46457D4788AC1B50E7856880535F;
        pt_array[443] = 128'h443A7B59A3292FDF0822574ABFDCB5B5; ct_expect_array[443] = 128'h33DC699AB861740C87A7ACFD3F53457D;
        pt_array[444] = 128'h23568D4EF72ED8B3CD9F22EB1D461044; ct_expect_array[444] = 128'h908353DD8FF080B97DA6BF37000333D7;
        pt_array[445] = 128'h88E2B3FCF41C89D65AF8C7C6458CC502; ct_expect_array[445] = 128'h8A017F258DC60DC2D0280E22F5D268C6;
        pt_array[446] = 128'h1CD3143632ED77E24C402983C748E844; ct_expect_array[446] = 128'h757A0C17C98A2362937F3EBEA029AD2D;
        pt_array[447] = 128'hF3DFD450B40E985E326EEAC3EA70686D; ct_expect_array[447] = 128'h5D2B872162E348265E059B50A84F5F04;
        pt_array[448] = 128'h864F1857BE0C305750672A39293AD7EB; ct_expect_array[448] = 128'h8CCC999C68D5CE0D7EB3D9505FC200BC;
        pt_array[449] = 128'h20376105DE60927294438A33B2B48672; ct_expect_array[449] = 128'h844B8BB354C62DC4EBE88D0AC89781E6;
        pt_array[450] = 128'h68E291E329174A72A3BF7DAEDC0A68A7; ct_expect_array[450] = 128'hEC6F42B3696F1C12AE73F0B52382F62A;
        pt_array[451] = 128'h92B99212B0ED64438D838BCBDD47A187; ct_expect_array[451] = 128'h8482B1D6239F30749F71B1F1F64CE4CB;
        pt_array[452] = 128'h9CD2FCB7209BE808C8D1628F0BE6B798; ct_expect_array[452] = 128'hE014E2D7A099CC3746AAF77B4DB043DA;
        pt_array[453] = 128'hDFA41CC99CBC1E4ACEFBF6001D2074B4; ct_expect_array[453] = 128'h4569565CC598AE66FD0757587CF4BB88;
        pt_array[454] = 128'h689F695193126328DFFBF4143691501F; ct_expect_array[454] = 128'h5209C3920AFEEC53BE5A9215749C6A89;
        pt_array[455] = 128'h4A3D6D4BCB0D5366425C909D66E6BE12; ct_expect_array[455] = 128'h3D8B419695F1D26C271262EBA715667C;
        pt_array[456] = 128'hA3CFF7E650C807E6FDAE0A87B6A7981A; ct_expect_array[456] = 128'hE89CE566A7D426B71A68DC8FC63986C6;
        pt_array[457] = 128'hF213D8698158FBC4E150DFC200F5AE93; ct_expect_array[457] = 128'hECFD86A615C7469D5E84B58F9E586009;
        pt_array[458] = 128'h2FD41E95513E471A819C59C8A1E0DBCD; ct_expect_array[458] = 128'h43DE82081473D8ED8E79181550D5205C;
        pt_array[459] = 128'h0EBB7560675B271EFEA86F629D532096; ct_expect_array[459] = 128'h906D9FD16A92836F12A8438143378605;
        pt_array[460] = 128'h185241890F0B9EF935A86E9D5BA6DF14; ct_expect_array[460] = 128'hEC60CC0B54AA3871D9662546436450F0;
        pt_array[461] = 128'hFA13FF9ED2ACEA000F4FD3A0124F4AB5; ct_expect_array[461] = 128'hC011EEC5D664A732F3A89CE9B3000814;
        pt_array[462] = 128'hE828EDB27BCF311BA74EE136F35F27CE; ct_expect_array[462] = 128'hFC9634AE9BA9488A1358BEDCD2B7CD53;
        pt_array[463] = 128'h0F42EEF8D016EAC1107FA7A0DFEEC452; ct_expect_array[463] = 128'h43807C6CFBD485B32ADEE588EF1FA550;
        pt_array[464] = 128'hA564437E76F252000FD659A00528D8CF; ct_expect_array[464] = 128'hD1174CF86A4D8F4D6EEAE103128F6773;
        pt_array[465] = 128'hA8E74649B44A7DCE7444A22B7F496FBC; ct_expect_array[465] = 128'h662B43272657A7EEF249C946455A94B3;
        pt_array[466] = 128'h616024186BE1E879C0FE2345E9D5B360; ct_expect_array[466] = 128'h12FFF3623BDAF7686DC13ABE63CDB55D;
        pt_array[467] = 128'h0577B454CF367471595A27D20A778370; ct_expect_array[467] = 128'h04B09EAA08014B375E53EC34DA74B616;
        pt_array[468] = 128'hB1F19FF4882E47957F55A457C598237A; ct_expect_array[468] = 128'h34D38F4E4D0BBB7EA1FB00DBD174FC61;
        pt_array[469] = 128'hF51CDCBF06C7CA28F419DD2B8847368D; ct_expect_array[469] = 128'h29649753ED473112A395035768A1342E;
        pt_array[470] = 128'h440C1A082774100C0EF86A39EE548C1B; ct_expect_array[470] = 128'hD3DF372DFEA5F5FEC2BB79D02707C524;
        pt_array[471] = 128'h0365CB4BDEF92A579480546D6918876B; ct_expect_array[471] = 128'hCB877DE018DCE3F05CC18A9F3ECB4CFD;
        pt_array[472] = 128'h7EA28F0D1BD9BB356A687169EFCA41A3; ct_expect_array[472] = 128'h01803FF0477DDC686776C34F4B86FA31;
        pt_array[473] = 128'h07B44F981EF671D609BC538DAE864145; ct_expect_array[473] = 128'h7E192FEC2598808812FB8DF321BB5C2F;
        pt_array[474] = 128'hF281E457ACCC0BCAA4D0F32CDD7D80AF; ct_expect_array[474] = 128'h22FD2A4416313BADDA00BDE412CD4774;
        pt_array[475] = 128'hFFE7DB679B00D380CF54DF24F9D61B1B; ct_expect_array[475] = 128'h7ADA6E6E698129E660F3F3FA400F2237;
        pt_array[476] = 128'h198BF93B4C11573762C1C5327D320620; ct_expect_array[476] = 128'hC232F4DEAFF784AD6467A36E6AA68822;
        pt_array[477] = 128'h205D46023ED8D3371D808354EE2B23B3; ct_expect_array[477] = 128'hE2ADDD4B59AF02AE42E2C90043A57460;
        pt_array[478] = 128'h2D710A2DAB902322C4A55E5E815D0A6A; ct_expect_array[478] = 128'h08C05933840E0931EFC49A7F961051F3;
        pt_array[479] = 128'h5417B62383141E072BBB9FF70BCF1334; ct_expect_array[479] = 128'h0EF8F8580FB505CAD3B5BCD1B1EDF511;
        pt_array[480] = 128'h4D32F08F799785939C367C83338E777E; ct_expect_array[480] = 128'h1DFBEAFDFA0B75011E0D92E6556D8827;
        pt_array[481] = 128'hDDCA7D3D04B0F3D97FC70562DDE73C04; ct_expect_array[481] = 128'h642B958FB15A332E52A5037D86C14A46;
        pt_array[482] = 128'hCE20293073D678EFF6052AF689F0405E; ct_expect_array[482] = 128'h1B19429FE7880CC4E92BC2A3BCDF4515;
        pt_array[483] = 128'hF8924A704A8E88212E88543A94521A9A; ct_expect_array[483] = 128'hDF6F6E76632D716BEAE4E1931ECDCEA6;
        pt_array[484] = 128'h569D2417579CE56184FB477C9BFED9F9; ct_expect_array[484] = 128'hD6804398FC440EBE2E476AF7B0A7E389;
        pt_array[485] = 128'hF5EE2449FCB1C970EE3D3F100A034B7C; ct_expect_array[485] = 128'hAC5487AB7AFF471AA65AF5C5A5805909;
        pt_array[486] = 128'h8540E625575BC827DD25632C5AD5DBBD; ct_expect_array[486] = 128'h02BB3C0721F3D24343A891BA93B607EB;
        pt_array[487] = 128'hA8ECF779EBD312598C314D462424F56E; ct_expect_array[487] = 128'hF71FEC040154FAA239267ED83166987C;
        pt_array[488] = 128'h064D8B0D987A53CC0A8E4D91937F5F35; ct_expect_array[488] = 128'hCF425307065BC473A5E2B85CFF768542;
        pt_array[489] = 128'hE2D325A09B82124326BE9F085A881948; ct_expect_array[489] = 128'hFE6154502031597BF2C3C6490E4861E5;
        pt_array[490] = 128'hE89B0C23D6AEB1D0D722A9A4FA8D515D; ct_expect_array[490] = 128'h4196F2F0819A29E937AA64DB59E3CEE1;
        pt_array[491] = 128'h49C4DC8560D0FE688486D9CBCF56E140; ct_expect_array[491] = 128'hC90B2430007C39AB87D12852ECF8F5D4;
        pt_array[492] = 128'h18C44B0882F97A5C60DBB2863E881263; ct_expect_array[492] = 128'h11755D3D5A328F44F44AABF49D058ECF;
        pt_array[493] = 128'h0908FE927ACA9C4BFE6F4ECD679D378A; ct_expect_array[493] = 128'h0BDDC147DF552B2E694ED42315183361;
        pt_array[494] = 128'h838246B8AB2075F1D4943E6C6222B042; ct_expect_array[494] = 128'h40445D4D38F05C0B04E82FAC0B53B2D6;
        pt_array[495] = 128'hAFCC1CBB8CDB4CD08944EE38A991EF27; ct_expect_array[495] = 128'hD08EEBE8B7FC2B6481E58E03169AEB03;
        pt_array[496] = 128'h76C6FACFB5CFEBCF4A6B94453EC9A8AC; ct_expect_array[496] = 128'hEA3B90EF3689480FF467EC4A46357576;
        pt_array[497] = 128'hA8AEF0FE5CA3E09FEB380C119388ED2A; ct_expect_array[497] = 128'hF03E339D1B51BAE9AF9B9FD36298F591;
        pt_array[498] = 128'hC88D556B626B84DC4E90B68FB7F2A68A; ct_expect_array[498] = 128'hD74FD3F404BE464800A9404E2C3C7F37;
        pt_array[499] = 128'h065BDE9A508A15F2F004C63A6E7DCCF1; ct_expect_array[499] = 128'h67B303EB6D8B1B547BF4FE70971B8731;
        #100 resetn = 1; #50;

        $display("=========================================================");
        $display("     AES-128 ECB  –  500 UNIQUE VECTOR TEST              ");
        $display("     Key: 2b7e151628aed2a6abf7158809cf4f3c               ");
        $display("=========================================================");

        // =====================================================
        // PHASE 1 – Load all 500 plaintext blocks via Port B
        // =====================================================
        $display("[%0t] PHASE 1: Loading %0d plaintext blocks to RAM...", $time, NUM_BLOCKS);
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin
            axi_mem_write((i*16) +  0, pt_array[i][127:96]);
            axi_mem_write((i*16) +  4, pt_array[i][95:64]);
            axi_mem_write((i*16) +  8, pt_array[i][63:32]);
            axi_mem_write((i*16) + 12, pt_array[i][31:0]);
        end
        $display("[%0t] PHASE 1: Done.", $time);

        // =====================================================
        // PHASE 2 – Configure key and block count via sideband
        // =====================================================
        $display("[%0t] PHASE 2: Configuring AES key and block count...", $time);
        aes_key              = AES_KEY;
        num_blocks_to_process = NUM_BLOCKS;
        @(posedge clk);
        aes_key_valid = 1;
        wait(aes_key_ready);
        @(posedge clk);
        aes_key_valid = 0;
        $display("[%0t] PHASE 2: Key accepted.", $time);

        // =====================================================
        // PHASE 3 – Trigger the AES core and wait for DONE
        // =====================================================
        $display("[%0t] PHASE 3: Starting AES encryption run...", $time);
        start_time = $realtime;

        axi_ctrl_write(4'h0, 32'h00000001);  // Assert START
        axi_ctrl_write(4'h0, 32'h00000000);  // Deassert START

        // Poll status register until DONE bit [2] is set
        status_reg_read = 32'h0;
        while (!status_reg_read[2]) begin
            axi_ctrl_read(4'h0, status_reg_read);
        end

        end_time   = $realtime;
        elapsed_ns = end_time - start_time;
        $display("[%0t] PHASE 3: Encryption complete in %.2f ns.", $time, elapsed_ns);

        // =====================================================
        // PHASE 4 – Throughput report
        // =====================================================
        total_bits      = NUM_BLOCKS * 128.0;
        throughput_gbps = total_bits / elapsed_ns;
        throughput_mbps = throughput_gbps * 1000.0;

        $display("\n=========================================================");
        $display("              THROUGHPUT & LATENCY REPORT                ");
        $display("=========================================================");
        $display(" Blocks Processed        : %0d", NUM_BLOCKS);
        $display(" Hardware Execution Time : %.2f ns", elapsed_ns);
        $display(" AES Core Throughput     : %.3f Gbps  (%.1f Mbps)", throughput_gbps, throughput_mbps);
        $display("=========================================================");

        // =====================================================
        // PHASE 5 – Read back results and verify every block
        // =====================================================
        $display("\n=========================================================");
        $display("           AXI PORT-B  RESULT VERIFICATION               ");
        $display("=========================================================");

        #100; // Let signals settle before readback

        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin
            axi_mem_read((i*16) +  0, rw0);
            axi_mem_read((i*16) +  4, rw1);
            axi_mem_read((i*16) +  8, rw2);
            axi_mem_read((i*16) + 12, rw3);

            extracted_ct = {rw0, rw1, rw2, rw3};

            if (extracted_ct === ct_expect_array[i]) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display(" FAIL Block %03d  [ADDR 0x%05h]", i, i*16);
                $display("   PT       : 0x%h", pt_array[i]);
                $display("   Expected : 0x%h", ct_expect_array[i]);
                $display("   Actual   : 0x%h", extracted_ct);
            end
        end

        $display("\n --- FINAL RESULTS ---");
        $display(" PASSED : %0d / %0d", pass_count, NUM_BLOCKS);
        $display(" FAILED : %0d / %0d", fail_count,  NUM_BLOCKS);

        if (fail_count == 0)
            $display(" ALL %0d VECTORS PASSED  *** SUCCESS ***", NUM_BLOCKS);
        else
            $display(" %0d VECTOR(S) FAILED  *** REVIEW FAILURES ABOVE ***", fail_count);

        $display("=========================================================\n");

        #50 $finish;
    end

    // =========================================================
    // 7. CYCLE-ACCURATE LATENCY PROBES
    // =========================================================
    integer core_latency_cycles = 0;
    integer sys_latency_cycles  = 0;
    reg     core_measuring = 0, core_measured = 0;
    reg     sys_measuring  = 0, sys_measured  = 0;

    always @(posedge clk) begin
        if (!resetn) begin
            core_latency_cycles <= 0; sys_latency_cycles  <= 0;
            core_measuring      <= 0; core_measured       <= 0;
            sys_measuring       <= 0; sys_measured        <= 0;
        end else begin

            // Pure AES core latency: input_valid → Done
            if (uut.aes_inst.aes_core_inst.input_valid && !core_measured && !core_measuring) begin
                core_measuring <= 1; core_latency_cycles <= 1;
            end else if (core_measuring) begin
                if (uut.aes_inst.aes_core_inst.Done) begin
                    core_measuring <= 0; core_measured <= 1;
                    $display("\n=========================================================");
                    $display(" [LATENCY PROBE] Pure AES Core Latency : %0d Clock Cycles", core_latency_cycles);
                end else
                    core_latency_cycles <= core_latency_cycles + 1;
            end

            // Total system latency: AXI START → first BRAM write-response
            if (uut.aes_inst.rd_ctrl_inst.start && !sys_measured && !sys_measuring) begin
                sys_measuring <= 1; sys_latency_cycles <= 1;
            end else if (sys_measuring) begin
                if (uut.aes_inst.wr_ctrl_inst.state == 1'b1 &&
                    uut.aes_inst.wr_ctrl_inst.b_resp_valid &&
                    uut.aes_inst.wr_ctrl_inst.b_resp_ready &&
                    uut.aes_inst.wr_ctrl_inst.b_count == 3)
                begin
                    sys_measuring <= 0; sys_measured <= 1;
                    $display(" [LATENCY PROBE] Total System Latency  : %0d Clock Cycles", sys_latency_cycles);
                    $display("=========================================================\n");
                end else
                    sys_latency_cycles <= sys_latency_cycles + 1;
            end
        end
    end

endmodule

