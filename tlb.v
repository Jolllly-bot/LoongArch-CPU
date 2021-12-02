module tlb
#(
    parameter TLBNUM = 16
)
(
    input clk,
    input reset,
    // search port 0 (for fetch)
    input  [18:0] s0_vppn,
    input         s0_va_bit12,
    input  [ 9:0] s0_asid,
    output        s0_found,
    output [$clog2(TLBNUM)-1:0] s0_index,
    output [19:0] s0_ppn,
    output [ 5:0] s0_ps,
    output [ 1:0] s0_plv,
    output [ 1:0] s0_mat,
    output        s0_d,
    output        s0_v,
    // search port 1 (for load/store)
    input  [18:0] s1_vppn,
    input         s1_va_bit12,
    input  [ 9:0] s1_asid,
    output        s1_found,
    output [$clog2(TLBNUM)-1:0] s1_index,
    output [19:0] s1_ppn,
    output [ 5:0] s1_ps,
    output [ 1:0] s1_plv,
    output [ 1:0] s1_mat,
    output        s1_d,
    output        s1_v,
    // invtlb opcode
    input  invtlb_valid,
    input  [ 4:0] invtlb_op,
    // write port
    input         we, 
    //w(rite) e(nable)
    input  [$clog2(TLBNUM)-1:0] w_index,
    input         w_e,
    input  [18:0] w_vppn,
    input  [ 5:0] w_ps,
    input  [ 9:0] w_asid,
    input         w_g,
    input  [19:0] w_ppn0,
    input  [ 1:0] w_plv0,
    input  [ 1:0] w_mat0,
    input         w_d0,
    input         w_v0,
    input  [19:0] w_ppn1,
    input  [ 1:0] w_plv1,
    input  [ 1:0] w_mat1,
    input         w_d1,
    input         w_v1,
    // read port
    input [$clog2(TLBNUM)-1:0] r_index,
    output        r_e,
    output [18:0] r_vppn,
    output [ 5:0] r_ps,
    output [ 9:0] r_asid,
    output        r_g,
    output [19:0] r_ppn0,
    output [ 1:0] r_plv0,
    output [ 1:0] r_mat0,
    output        r_d0,
    output        r_v0,
    output [19:0] r_ppn1,
    output [ 1:0] r_plv1,
    output [ 1:0] r_mat1,
    output        r_d1,
    output        r_v1
    );
    
    reg [TLBNUM-1:0] tlb_e;
    reg [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB
    reg [18:0] tlb_vppn [TLBNUM-1:0];
    reg [ 9:0] tlb_asid [TLBNUM-1:0];
    reg tlb_g [TLBNUM-1:0];
    reg [19:0] tlb_ppn0 [TLBNUM-1:0];
    reg [ 1:0] tlb_plv0 [TLBNUM-1:0];
    reg [ 1:0] tlb_mat0 [TLBNUM-1:0];
    reg tlb_d0 [TLBNUM-1:0];
    reg tlb_v0 [TLBNUM-1:0];
    reg [19:0] tlb_ppn1 [TLBNUM-1:0];
    reg [ 1:0] tlb_plv1 [TLBNUM-1:0];
    reg [ 1:0] tlb_mat1 [TLBNUM-1:0];
    reg tlb_d1 [TLBNUM-1:0];
    reg tlb_v1 [TLBNUM-1:0];
    
    wire [3:0] inv_cond [TLBNUM-1:0];
    wire [TLBNUM-1 :0]inv_match;

    
    wire [15:0] match0;
    wire [15:0] match1;

 

    genvar i;
    generate for (i=0; i<TLBNUM; i=i+1) begin: gen_for_tlb_match
        assign match0[i] = (s0_vppn[18:10] == tlb_vppn[i][18:10]) 
                        && (tlb_ps4MB[i] || s0_vppn[9:0]==tlb_vppn[i][9:0]) 
                        && ((s0_asid == tlb_asid[i]) || tlb_g[i])
                        && tlb_e[i];

        assign match1[i] = (s1_vppn[18:10] == tlb_vppn[i][18:10]) 
                        && (tlb_ps4MB[i] || s1_vppn[9:0]==tlb_vppn[i][9:0]) 
                        && ((s1_asid == tlb_asid[i]) || tlb_g[i])
                        && tlb_e[i];
        
        assign inv_cond[i][0] =~tlb_g[i];
        assign inv_cond[i][1] = tlb_g[i];
        assign inv_cond[i][2] = s1_asid == tlb_asid[i];
        assign inv_cond[i][3] = (s1_vppn[18:10]==tlb_vppn[i][18:10]) 
                        && (tlb_ps4MB[i]||s1_vppn[9:0]==tlb_vppn[i][ 9: 0]);
        assign inv_match[i] = ((invtlb_op==5'h0||invtlb_op==5'h1) & (inv_cond[i][0] || inv_cond[i][1]))
                            ||((invtlb_op==5'h2) & (inv_cond[i][1]))
                            ||((invtlb_op==5'h3) & (inv_cond[i][0]))
                            ||((invtlb_op==5'h4) & (inv_cond[i][0]) & (inv_cond[i][2]))
                            ||((invtlb_op==5'h5) & (inv_cond[i][0]) & inv_cond[i][2] & inv_cond[i][3])
                            ||((invtlb_op==5'h6) & (inv_cond[i][1] | inv_cond[i][2]) & inv_cond[i][3]);
       
        always @(posedge clk )begin
            if (reset) begin
                tlb_e    [i] <= 1'b0;
                tlb_ps4MB[i] <= 1'b0;
                tlb_vppn [i] <= 19'b0;
                tlb_asid [i] <= 10'b0;
                tlb_g    [i] <= 1'b0;
                
                tlb_ppn0 [i] <= 20'b0;
                tlb_plv0 [i] <= 2'b0;
                tlb_mat0 [i] <= 2'b0;
                tlb_d0   [i] <= 1'b0;
                tlb_v0   [i] <= 1'b0;
                
                tlb_ppn1 [i] <= 20'b0;
                tlb_plv1 [i] <= 2'b0;
                tlb_mat1 [i] <= 2'b0;
                tlb_d1   [i] <= 1'b0;
                tlb_v1   [i] <= 1'b0;
            end
            else if(we && w_index==i)begin
                tlb_e    [i] <= w_e;
                tlb_ps4MB[i] <= (w_ps==6'd22);
                tlb_vppn [i] <= w_vppn;
                tlb_asid [i] <= w_asid;
                tlb_g    [i] <= w_g;
                
                tlb_ppn0 [i] <= w_ppn0;
                tlb_plv0 [i] <= w_plv0;
                tlb_mat0 [i] <= w_mat0;
                tlb_d0   [i] <= w_d0;
                tlb_v0   [i] <= w_v0;
                
                tlb_ppn1 [i] <= w_ppn1;
                tlb_plv1 [i] <= w_plv1;
                tlb_mat1 [i] <= w_mat1;
                tlb_d1   [i] <= w_d1;
                tlb_v1   [i] <= w_v1;
            end
            else if(inv_match[i] & invtlb_valid)begin
                tlb_e    [i] <= 1'b0;
            end
                
        end
    end endgenerate
    

    assign s0_found = |match0;
    assign s1_found = |match1;

    encoder_16_4 u_enc1(.in(match0), .out(s0_index));
    encoder_16_4 u_enc2(.in(match1), .out(s1_index));

    assign s0_ppn = tlb_ps4MB[s0_index] ? (s0_vppn[9]  ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index])
                                        : (s0_va_bit12 ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index]);

    assign s1_ppn = tlb_ps4MB[s1_index] ? (s1_vppn[9]  ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index])
                                        : (s1_va_bit12 ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index]);

    assign s0_plv = tlb_ps4MB[s0_index] ? (s0_vppn[9]  ? tlb_plv1[s0_index] : tlb_plv0[s0_index])
                                        : (s0_va_bit12 ? tlb_plv1[s0_index] : tlb_plv0[s0_index]);

    assign s1_plv = tlb_ps4MB[s1_index] ? (s1_vppn[9]  ? tlb_plv1[s1_index] : tlb_plv0[s1_index])
                                        : (s1_va_bit12 ? tlb_plv1[s1_index] : tlb_plv0[s1_index]);
    
    assign s0_mat = tlb_ps4MB[s0_index] ? (s0_vppn[9]  ? tlb_mat1[s0_index] : tlb_mat0[s0_index])
                                        : (s0_va_bit12 ? tlb_mat1[s0_index] : tlb_mat0[s0_index]);
    assign s1_mat = tlb_ps4MB[s1_index] ? (s1_vppn[9]  ? tlb_mat1[s1_index] : tlb_mat0[s1_index])
                                        : (s1_va_bit12 ? tlb_mat1[s1_index] : tlb_mat0[s1_index]);

    assign s0_d = tlb_ps4MB[s0_index] ? (s0_vppn[9]  ? tlb_d1[s0_index] : tlb_d0[s0_index])
                                      : (s0_va_bit12 ? tlb_d1[s0_index] : tlb_d0[s0_index]);

    assign s1_d = tlb_ps4MB[s1_index] ? (s1_vppn[9]  ? tlb_d1[s1_index] : tlb_d0[s1_index])
                                      : (s1_va_bit12 ? tlb_d1[s1_index] : tlb_d0[s1_index]);
            
    assign s0_v = tlb_ps4MB[s0_index] ? (s0_vppn[9]  ? tlb_v1[s0_index] : tlb_v0[s0_index])
                                      : (s0_va_bit12 ? tlb_v1[s0_index] : tlb_v0[s0_index]);

    assign s1_v = tlb_ps4MB[s1_index] ? (s1_vppn[9]  ? tlb_v1[s1_index] : tlb_v0[s1_index])
                                      : (s1_va_bit12 ? tlb_v1[s1_index] : tlb_v0[s1_index]);

    assign s0_ps = tlb_ps4MB[s0_index] ? 6'd22 : 6'd12;
    assign s1_ps = tlb_ps4MB[s1_index] ? 6'd22 : 6'd12;
    
    assign r_e    = tlb_e    [r_index];
    assign r_vppn = tlb_vppn [r_index];
    assign r_ps   = tlb_ps4MB[r_index] ? 6'd22 : 6'd12;
    assign r_asid = tlb_asid [r_index];
    assign r_g    = tlb_g    [r_index];
    assign r_ppn0 = tlb_ppn0 [r_index];
    assign r_plv0 = tlb_plv0 [r_index];
    assign r_mat0 = tlb_mat0 [r_index];
    assign r_d0   = tlb_d0   [r_index];
    assign r_v0   = tlb_v0   [r_index];
    assign r_ppn1 = tlb_ppn1 [r_index];
    assign r_plv1 = tlb_plv1 [r_index];
    assign r_mat1 = tlb_mat1 [r_index];
    assign r_d1   = tlb_d1   [r_index];
    assign r_v1   = tlb_v1   [r_index];
    

endmodule