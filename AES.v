
module aes_round(
    input  [127:0] state_in,
    input  [127:0] round_key,
    output [127:0] state_out
);
    wire [7:0] s [0:15];
    assign {s[0], s[1], s[2], s[3],
            s[4], s[5], s[6], s[7],
            s[8], s[9], s[10], s[11],
            s[12], s[13], s[14], s[15]} = state_in;

    wire [7:0] sb [0:15];
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : sbox_gen
            aes_sbox sb_inst (.in_byte(s[i]), .out_byte(sb[i]));
        end
    endgenerate

    wire [7:0] sr [0:15];
    assign sr[0] = sb[0];  assign sr[4] = sb[4];  assign sr[8] = sb[8];   assign sr[12] = sb[12]; 
    assign sr[1] = sb[5];  assign sr[5] = sb[9];  assign sr[9] = sb[13];  assign sr[13] = sb[1];  
    assign sr[2] = sb[10]; assign sr[6] = sb[14]; assign sr[10] = sb[2];  assign sr[14] = sb[6];  
    assign sr[3] = sb[15]; assign sr[7] = sb[3];  assign sr[11] = sb[7];  assign sr[15] = sb[11]; 

    function [7:0] xtime(input [7:0] b);
        xtime = (b[7]) ? ((b << 1) ^ 8'h1b) : (b << 1);
    endfunction

    wire [7:0] mc [0:15];
    generate
        for (i = 0; i < 4; i = i + 1) begin : mix_gen
            assign mc[i*4+0] = xtime(sr[i*4+0]) ^ (xtime(sr[i*4+1]) ^ sr[i*4+1]) ^ sr[i*4+2] ^ sr[i*4+3];
            assign mc[i*4+1] = sr[i*4+0] ^ xtime(sr[i*4+1]) ^ (xtime(sr[i*4+2]) ^ sr[i*4+2]) ^ sr[i*4+3];
            assign mc[i*4+2] = sr[i*4+0] ^ sr[i*4+1] ^ xtime(sr[i*4+2]) ^ (xtime(sr[i*4+3]) ^ sr[i*4+3]);
            assign mc[i*4+3] = (xtime(sr[i*4+0]) ^ sr[i*4+0]) ^ sr[i*4+1] ^ sr[i*4+2] ^ xtime(sr[i*4+3]);
        end
    endgenerate

    wire [127:0] mixed_state;
    assign mixed_state = {mc[0], mc[1], mc[2], mc[3],
                          mc[4], mc[5], mc[6], mc[7],
                          mc[8], mc[9], mc[10], mc[11],
                          mc[12], mc[13], mc[14], mc[15]};

    assign state_out = mixed_state ^ round_key;

endmodule

module aes_final_round(
    input  [127:0] state_in,
    input  [127:0] round_key,
    output [127:0] state_out
);

    wire [7:0] s [0:15];
    assign {s[0], s[1], s[2], s[3],
            s[4], s[5], s[6], s[7],
            s[8], s[9], s[10], s[11],
            s[12], s[13], s[14], s[15]} = state_in;


    wire [7:0] sb [0:15];
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : sbox_gen
            aes_sbox sb_inst (.in_byte(s[i]), .out_byte(sb[i]));
        end
    endgenerate

    wire [7:0] sr [0:15];
    assign sr[0] = sb[0];  assign sr[4] = sb[4];  assign sr[8] = sb[8];   assign sr[12] = sb[12]; 
    assign sr[1] = sb[5];  assign sr[5] = sb[9];  assign sr[9] = sb[13];  assign sr[13] = sb[1];  
    assign sr[2] = sb[10]; assign sr[6] = sb[14]; assign sr[10] = sb[2];  assign sr[14] = sb[6];  
    assign sr[3] = sb[15]; assign sr[7] = sb[3];  assign sr[11] = sb[7];  assign sr[15] = sb[11]; 

 wire [127:0] shifted;
 assign shifted = {sr[0],sr[1],sr[2],sr[3],sr[4],sr[5],sr[6],sr[7],sr[8],sr[9],sr[10],sr[11],sr[12],sr[13],sr[14],sr[15]};

    assign state_out = shifted ^ round_key;

endmodule

module aes_sbox(input [7:0]in_byte, output reg[7:0]out_byte);
always @(*) begin
    case (in_byte)
        8'h00: out_byte = 8'h63; 8'h01: out_byte = 8'h7c; 8'h02: out_byte = 8'h77; 8'h03: out_byte = 8'h7b;
        8'h04: out_byte = 8'hf2; 8'h05: out_byte = 8'h6b; 8'h06: out_byte = 8'h6f; 8'h07: out_byte = 8'hc5;
        8'h08: out_byte = 8'h30; 8'h09: out_byte = 8'h01; 8'h0a: out_byte = 8'h67; 8'h0b: out_byte = 8'h2b;
        8'h0c: out_byte = 8'hfe; 8'h0d: out_byte = 8'hd7; 8'h0e: out_byte = 8'hab; 8'h0f: out_byte = 8'h76;

        8'h10: out_byte = 8'hca; 8'h11: out_byte = 8'h82; 8'h12: out_byte = 8'hc9; 8'h13: out_byte = 8'h7d;
        8'h14: out_byte = 8'hfa; 8'h15: out_byte = 8'h59; 8'h16: out_byte = 8'h47; 8'h17: out_byte = 8'hf0;
        8'h18: out_byte = 8'had; 8'h19: out_byte = 8'hd4; 8'h1a: out_byte = 8'ha2; 8'h1b: out_byte = 8'haf;
        8'h1c: out_byte = 8'h9c; 8'h1d: out_byte = 8'ha4; 8'h1e: out_byte = 8'h72; 8'h1f: out_byte = 8'hc0;

        8'h20: out_byte = 8'hb7; 8'h21: out_byte = 8'hfd; 8'h22: out_byte = 8'h93; 8'h23: out_byte = 8'h26;
        8'h24: out_byte = 8'h36; 8'h25: out_byte = 8'h3f; 8'h26: out_byte = 8'hf7; 8'h27: out_byte = 8'hcc;
        8'h28: out_byte = 8'h34; 8'h29: out_byte = 8'ha5; 8'h2a: out_byte = 8'he5; 8'h2b: out_byte = 8'hf1;
        8'h2c: out_byte = 8'h71; 8'h2d: out_byte = 8'hd8; 8'h2e: out_byte = 8'h31; 8'h2f: out_byte = 8'h15;

        8'h30: out_byte = 8'h04; 8'h31: out_byte = 8'hc7; 8'h32: out_byte = 8'h23; 8'h33: out_byte = 8'hc3;
        8'h34: out_byte = 8'h18; 8'h35: out_byte = 8'h96; 8'h36: out_byte = 8'h05; 8'h37: out_byte = 8'h9a;
        8'h38: out_byte = 8'h07; 8'h39: out_byte = 8'h12; 8'h3a: out_byte = 8'h80; 8'h3b: out_byte = 8'he2;
        8'h3c: out_byte = 8'heb; 8'h3d: out_byte = 8'h27; 8'h3e: out_byte = 8'hb2; 8'h3f: out_byte = 8'h75;

        8'h40: out_byte = 8'h09; 8'h41: out_byte = 8'h83; 8'h42: out_byte = 8'h2c; 8'h43: out_byte = 8'h1a;
        8'h44: out_byte = 8'h1b; 8'h45: out_byte = 8'h6e; 8'h46: out_byte = 8'h5a; 8'h47: out_byte = 8'ha0;
        8'h48: out_byte = 8'h52; 8'h49: out_byte = 8'h3b; 8'h4a: out_byte = 8'hd6; 8'h4b: out_byte = 8'hb3;
        8'h4c: out_byte = 8'h29; 8'h4d: out_byte = 8'he3; 8'h4e: out_byte = 8'h2f; 8'h4f: out_byte = 8'h84;

        8'h50: out_byte = 8'h53; 8'h51: out_byte = 8'hd1; 8'h52: out_byte = 8'h00; 8'h53: out_byte = 8'hed;
        8'h54: out_byte = 8'h20; 8'h55: out_byte = 8'hfc; 8'h56: out_byte = 8'hb1; 8'h57: out_byte = 8'h5b;
        8'h58: out_byte = 8'h6a; 8'h59: out_byte = 8'hcb; 8'h5a: out_byte = 8'hbe; 8'h5b: out_byte = 8'h39;
        8'h5c: out_byte = 8'h4a; 8'h5d: out_byte = 8'h4c; 8'h5e: out_byte = 8'h58; 8'h5f: out_byte = 8'hcf;

        8'h60: out_byte = 8'hd0; 8'h61: out_byte = 8'hef; 8'h62: out_byte = 8'haa; 8'h63: out_byte = 8'hfb;
        8'h64: out_byte = 8'h43; 8'h65: out_byte = 8'h4d; 8'h66: out_byte = 8'h33; 8'h67: out_byte = 8'h85;
        8'h68: out_byte = 8'h45; 8'h69: out_byte = 8'hf9; 8'h6a: out_byte = 8'h02; 8'h6b: out_byte = 8'h7f;
        8'h6c: out_byte = 8'h50; 8'h6d: out_byte = 8'h3c; 8'h6e: out_byte = 8'h9f; 8'h6f: out_byte = 8'ha8;

        8'h70: out_byte = 8'h51; 8'h71: out_byte = 8'ha3; 8'h72: out_byte = 8'h40; 8'h73: out_byte = 8'h8f;
        8'h74: out_byte = 8'h92; 8'h75: out_byte = 8'h9d; 8'h76: out_byte = 8'h38; 8'h77: out_byte = 8'hf5;
        8'h78: out_byte = 8'hbc; 8'h79: out_byte = 8'hb6; 8'h7a: out_byte = 8'hda; 8'h7b: out_byte = 8'h21;
        8'h7c: out_byte = 8'h10; 8'h7d: out_byte = 8'hff; 8'h7e: out_byte = 8'hf3; 8'h7f: out_byte = 8'hd2;

        8'h80: out_byte = 8'hcd; 8'h81: out_byte = 8'h0c; 8'h82: out_byte = 8'h13; 8'h83: out_byte = 8'hec;
        8'h84: out_byte = 8'h5f; 8'h85: out_byte = 8'h97; 8'h86: out_byte = 8'h44; 8'h87: out_byte = 8'h17;
        8'h88: out_byte = 8'hc4; 8'h89: out_byte = 8'ha7; 8'h8a: out_byte = 8'h7e; 8'h8b: out_byte = 8'h3d;
        8'h8c: out_byte = 8'h64; 8'h8d: out_byte = 8'h5d; 8'h8e: out_byte = 8'h19; 8'h8f: out_byte = 8'h73;

        8'h90: out_byte = 8'h60; 8'h91: out_byte = 8'h81; 8'h92: out_byte = 8'h4f; 8'h93: out_byte = 8'hdc;
        8'h94: out_byte = 8'h22; 8'h95: out_byte = 8'h2a; 8'h96: out_byte = 8'h90; 8'h97: out_byte = 8'h88;
        8'h98: out_byte = 8'h46; 8'h99: out_byte = 8'hee; 8'h9a: out_byte = 8'hb8; 8'h9b: out_byte = 8'h14;
        8'h9c: out_byte = 8'hde; 8'h9d: out_byte = 8'h5e; 8'h9e: out_byte = 8'h0b; 8'h9f: out_byte = 8'hdb;

        8'ha0: out_byte = 8'he0; 8'ha1: out_byte = 8'h32; 8'ha2: out_byte = 8'h3a; 8'ha3: out_byte = 8'h0a;
        8'ha4: out_byte = 8'h49; 8'ha5: out_byte = 8'h06; 8'ha6: out_byte = 8'h24; 8'ha7: out_byte = 8'h5c;
        8'ha8: out_byte = 8'hc2; 8'ha9: out_byte = 8'hd3; 8'haa: out_byte = 8'hac; 8'hab: out_byte = 8'h62;
        8'hac: out_byte = 8'h91; 8'had: out_byte = 8'h95; 8'hae: out_byte = 8'he4; 8'haf: out_byte = 8'h79;

        8'hb0: out_byte = 8'he7; 8'hb1: out_byte = 8'hc8; 8'hb2: out_byte = 8'h37; 8'hb3: out_byte = 8'h6d;
        8'hb4: out_byte = 8'h8d; 8'hb5: out_byte = 8'hd5; 8'hb6: out_byte = 8'h4e; 8'hb7: out_byte = 8'ha9;
        8'hb8: out_byte = 8'h6c; 8'hb9: out_byte = 8'h56; 8'hba: out_byte = 8'hf4; 8'hbb: out_byte = 8'hea;
        8'hbc: out_byte = 8'h65; 8'hbd: out_byte = 8'h7a; 8'hbe: out_byte = 8'hae; 8'hbf: out_byte = 8'h08;

        8'hc0: out_byte = 8'hba; 8'hc1: out_byte = 8'h78; 8'hc2: out_byte = 8'h25; 8'hc3: out_byte = 8'h2e;
        8'hc4: out_byte = 8'h1c; 8'hc5: out_byte = 8'ha6; 8'hc6: out_byte = 8'hb4; 8'hc7: out_byte = 8'hc6;
        8'hc8: out_byte = 8'he8; 8'hc9: out_byte = 8'hdd; 8'hca: out_byte = 8'h74; 8'hcb: out_byte = 8'h1f;
        8'hcc: out_byte = 8'h4b; 8'hcd: out_byte = 8'hbd; 8'hce: out_byte = 8'h8b; 8'hcf: out_byte = 8'h8a;

        8'hd0: out_byte = 8'h70; 8'hd1: out_byte = 8'h3e; 8'hd2: out_byte = 8'hb5; 8'hd3: out_byte = 8'h66;
        8'hd4: out_byte = 8'h48; 8'hd5: out_byte = 8'h03; 8'hd6: out_byte = 8'hf6; 8'hd7: out_byte = 8'h0e;
        8'hd8: out_byte = 8'h61; 8'hd9: out_byte = 8'h35; 8'hda: out_byte = 8'h57; 8'hdb: out_byte = 8'hb9;
        8'hdc: out_byte = 8'h86; 8'hdd: out_byte = 8'hc1; 8'hde: out_byte = 8'h1d; 8'hdf: out_byte = 8'h9e;

        8'he0: out_byte = 8'he1; 8'he1: out_byte = 8'hf8; 8'he2: out_byte = 8'h98; 8'he3: out_byte = 8'h11;
        8'he4: out_byte = 8'h69; 8'he5: out_byte = 8'hd9; 8'he6: out_byte = 8'h8e; 8'he7: out_byte = 8'h94;
        8'he8: out_byte = 8'h9b; 8'he9: out_byte = 8'h1e; 8'hea: out_byte = 8'h87; 8'heb: out_byte = 8'he9;
        8'hec: out_byte = 8'hce; 8'hed: out_byte = 8'h55; 8'hee: out_byte = 8'h28; 8'hef: out_byte = 8'hdf;

        8'hf0: out_byte = 8'h8c; 8'hf1: out_byte = 8'ha1; 8'hf2: out_byte = 8'h89; 8'hf3: out_byte = 8'h0d;
        8'hf4: out_byte = 8'hbf; 8'hf5: out_byte = 8'he6; 8'hf6: out_byte = 8'h42; 8'hf7: out_byte = 8'h68;
        8'hf8: out_byte = 8'h41; 8'hf9: out_byte = 8'h99; 8'hfa: out_byte = 8'h2d; 8'hfb: out_byte = 8'h0f;
        8'hfc: out_byte = 8'hb0; 8'hfd: out_byte = 8'h54; 8'hfe: out_byte = 8'hbb; 8'hff: out_byte = 8'h16;

        default: out_byte = 8'h00;
    endcase
end
endmodule


module func_g(
    input  [31:0] w,
    input  [31:0] R_CON,
    output [31:0] G_w
);

    wire [7:0] B [0:3];
    assign {B[0], B[1], B[2], B[3]} = w;

    wire [7:0] RB [0:3];
    assign RB[0] = B[1];
    assign RB[1] = B[2];
    assign RB[2] = B[3];
    assign RB[3] = B[0];

    wire [7:0] SB [0:3];

    aes_sbox s0 (.in_byte(RB[0]), .out_byte(SB[0]));
    aes_sbox s1 (.in_byte(RB[1]), .out_byte(SB[1]));
    aes_sbox s2 (.in_byte(RB[2]), .out_byte(SB[2]));
    aes_sbox s3 (.in_byte(RB[3]), .out_byte(SB[3]));

    wire [31:0] Sub_B;
    assign Sub_B = {SB[0], SB[1], SB[2], SB[3]};

    assign G_w = Sub_B ^ R_CON;

endmodule

module Round_key_gen(input [127:0] Key,
input [31:0]R_CON,
output [127:0]Round_key
 );
 wire [31:0]w[0:3];
 wire [31:0]G_w;
 assign {w[0],w[1],w[2],w[3]} = Key;
 func_g g(w[3],R_CON,G_w);
 wire [31:0]R[0:3];
 assign R[0] = w[0] ^ G_w;
 assign R[1] = R[0] ^ w[1];
 assign R[2] = R[1] ^ w[2];
 assign R[3] = R[2] ^ w[3];
 assign Round_key = {R[0],R[1],R[2],R[3]};
endmodule


module AES #(
    parameter DATA_WIDTH = 128,
    parameter KEY_WIDTH = 128,
    parameter AXI_ADDR_WIDTH = 16
)
(
    input clk,
    input reset,
    input input_valid,// from the read buffer
    input stop,
    input empty, // from the write buffer
    input key_valid,
    input [DATA_WIDTH-1:0] Plain_Text,
    input [KEY_WIDTH-1:0] Key,
    input [AXI_ADDR_WIDTH-1:0] Addr_in, 
    output reg [DATA_WIDTH-1:0] Cipher_Text,
    output reg [AXI_ADDR_WIDTH-1:0] Addr_out, 
    output Busy, Done,
    output AES_ready,
    output key_ready
);
    reg [127:0] Round_Text [0:9];
    reg [127:0] R_key  [0:9];
    reg [AXI_ADDR_WIDTH-1:0] stage_addr [0:9]; 
    reg [10:0]  stage_valid;
    wire pipeline_stall; // for backpressure handling

    wire [127:0] round_out [1:10];
    wire [127:0] round_key [1:10];

    localparam [31:0] R1=32'h01000000, R2=32'h02000000, R3=32'h04000000, R4=32'h08000000, R5=32'h10000000,
                      R6=32'h20000000, R7=32'h40000000, R8=32'h80000000, R9=32'h1B000000, R10=32'h36000000;
    
    assign key_ready = 1'b1;
    reg [127:0]Key_reg;
    reg Key_reg_valid;
  
    Round_key_gen rk1(R_key[0],  R1,  round_key[1]);
    Round_key_gen rk2(R_key[1],  R2,  round_key[2]);
    Round_key_gen rk3(R_key[2],  R3,  round_key[3]);
    Round_key_gen rk4(R_key[3],  R4,  round_key[4]);
    Round_key_gen rk5(R_key[4],  R5,  round_key[5]);
    Round_key_gen rk6(R_key[5],  R6,  round_key[6]);
    Round_key_gen rk7(R_key[6],  R7,  round_key[7]);
    Round_key_gen rk8(R_key[7],  R8,  round_key[8]);
    Round_key_gen rk9(R_key[8],  R9,  round_key[9]);
    Round_key_gen rk10(R_key[9], R10, round_key[10]);

  
    aes_round u1(Round_Text[0], round_key[1], round_out[1]);
    aes_round u2(Round_Text[1], round_key[2], round_out[2]);
    aes_round u3(Round_Text[2], round_key[3], round_out[3]);
    aes_round u4(Round_Text[3], round_key[4], round_out[4]);
    aes_round u5(Round_Text[4], round_key[5], round_out[5]);
    aes_round u6(Round_Text[5], round_key[6], round_out[6]);
    aes_round u7(Round_Text[6], round_key[7], round_out[7]);
    aes_round u8(Round_Text[7], round_key[8], round_out[8]);
    aes_round u9(Round_Text[8], round_key[9], round_out[9]);
    aes_final_round u10(Round_Text[9], round_key[10], round_out[10]);

    always@(posedge clk or negedge reset)
    begin
        if(!reset)
        begin
            Key_reg <= 0;
            Key_reg_valid <= 0;
        end
        else
        begin
        if(key_valid && key_ready)
        begin
            Key_reg <= Key;
            Key_reg_valid <= 1'b1;
        end
        end
    end
integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            stage_valid <= 11'b0;
            Cipher_Text <= 128'b0;
            Addr_out    <= 0;
            for(i =0 ;i < 10;i=i+1)
            begin
            Round_Text[i] <=0;
            stage_addr[i] <= 0;
            end
        end
        else if(stop)
        begin
            stage_valid <= 11'b0;
            Cipher_Text <= 128'b0;
            Addr_out    <= 0;
            for(i =0 ;i < 10;i=i+1)
            begin
            Round_Text[i] <=0;
            stage_addr[i] <= 0;
            end // for software abort.
        end
         else begin
            if(!pipeline_stall)
            begin
            stage_valid[0] <= input_valid;
            if (input_valid) begin
                Round_Text[0] <= Plain_Text ^ Key_reg;
                R_key[0]  <= Key_reg;
                stage_addr[0] <= Addr_in;
            end

                      
            stage_valid[1] <= stage_valid[0];
            if (stage_valid[0]) begin
                Round_Text[1] <= round_out[1];
                R_key[1]  <= round_key[1];
                stage_addr[1] <= stage_addr[0];
            end

                      
            stage_valid[2] <= stage_valid[1];
            if (stage_valid[1]) begin
                Round_Text[2] <= round_out[2];
                R_key[2]  <= round_key[2];
                stage_addr[2] <= stage_addr[1];
            end

                      
            stage_valid[3] <= stage_valid[2];
            if (stage_valid[2]) begin
                Round_Text[3] <= round_out[3];
                R_key[3]  <= round_key[3];
                stage_addr[3] <= stage_addr[2];
            end

                      
            stage_valid[4] <= stage_valid[3];
            if (stage_valid[3]) begin
                Round_Text[4] <= round_out[4];
                R_key[4]  <= round_key[4];
                stage_addr[4] <= stage_addr[3];
            end

                      
            stage_valid[5] <= stage_valid[4];
            if (stage_valid[4]) begin
                Round_Text[5] <= round_out[5];
                R_key[5]  <= round_key[5];
                stage_addr[5] <= stage_addr[4];
            end

                      
            stage_valid[6] <= stage_valid[5];
            if (stage_valid[5]) begin
                Round_Text[6] <= round_out[6];
                R_key[6]  <= round_key[6];
                stage_addr[6] <= stage_addr[5];
            end

                      
            stage_valid[7] <= stage_valid[6];
            if (stage_valid[6]) begin
                Round_Text[7] <= round_out[7];
                R_key[7]  <= round_key[7];
                stage_addr[7] <= stage_addr[6];
            end

                      
            stage_valid[8] <= stage_valid[7];
            if (stage_valid[7]) begin
                Round_Text[8] <= round_out[8];
                R_key[8]  <= round_key[8];
                stage_addr[8] <= stage_addr[7];
            end

                      
            stage_valid[9] <= stage_valid[8];
            if (stage_valid[8]) begin
                Round_Text[9] <= round_out[9];
                R_key[9]  <= round_key[9];
                stage_addr[9] <= stage_addr[8];
            end
            
            stage_valid[10] <= stage_valid[9];
            if (stage_valid[9]) begin
                Cipher_Text <= round_out[10];
                Addr_out    <= stage_addr[9]; 
            end
        end
         end 
         end

    assign Busy = |stage_valid;
    assign Done = stage_valid[10];

    assign AES_ready = (!pipeline_stall);
    assign pipeline_stall = (Done && (~(empty))) || (!Key_reg_valid);

endmodule