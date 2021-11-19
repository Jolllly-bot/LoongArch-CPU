module tlb
#(
    parameter TLBNUM = 16
)
(
    input clk,
    // search port 0 (for fetch)
    input [18:0] s0_vppn,
    input s0_va_bit12,
    input [9:0] s0_asid,
    output s0_found,
    output [$clog2(TLBNUM)-1:0] s0_index,
    output [19:0] s0_ppn,
    output [5:0] s0_ps,
    output [1:0] s0_plv,
    output [1:0] s0_mat,
    output s0_d,
    output s0_v,

    // search port 1 (for load/store)
    input [18:0] s1_vppn,
    input s1_va_bit12,
    input [9:0] s1_asid,
    output s1_found,
    output [$clog2(TLBNUM)-1:0] s1_index,
    output [19:0] s1_ppn,
    output [5:0] s1_ps,
    output [1:0] s1_plv,
    output [1:0] s1_mat,
    output s1_d,
    output s1_v,
    // invtlb opcode
    input [4:0] invtlb_op,
    // write port
    input we, 
    //w(rite) e(nable)
    input [$clog2(TLBNUM)-1:0] w_index,
    input w_e,
    input [18:0] w_vppn,
    input [5:0]  w_ps,
    input [9:0] w_asid,
    input w_g,
    input [19:0] w_ppn0,
    input [1:0] w_plv0,
    input [1:0] w_mat0,
    input w_d0,
    input w_v0,
    input [19:0] w_ppn1,
    input [1:0] w_plv1,
    input [1:0] w_mat1,
    input w_d1,
    input w_v1,
    // read port
    input [$clog2(TLBNUM)-1:0] r_index,
    output r_e,
    output [18:0] r_vppn,
    output [5:0] r_ps,
    output [9:0] r_asid,
    output r_g,
    output [19:0] r_ppn0,
    output [1:0] r_plv0,
    output [1:0] r_mat0,
    output r_d0,
    output r_v0,
    output [19:0] r_ppn1,
    output [1:0] r_plv1,
    output [1:0] r_mat1,
    output r_d1,
    output r_v1
    );
    
    reg [TLBNUM-1:0] tlb_e;
    reg [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB
    reg [18:0] tlb_vppn [TLBNUM-1:0];
    reg [9:0] tlb_asid [TLBNUM-1:0];
    reg tlb_g [TLBNUM-1:0];
    reg [19:0] tlb_ppn0 [TLBNUM-1:0];
    reg [1:0] tlb_plv0 [TLBNUM-1:0];
    reg [1:0] tlb_mat0 [TLBNUM-1:0];
    reg tlb_d0 [TLBNUM-1:0];
    reg tlb_v0 [TLBNUM-1:0];
    reg [19:0] tlb_ppn1 [TLBNUM-1:0];
    reg [1:0] tlb_plv1 [TLBNUM-1:0];
    reg [1:0] tlb_mat1 [TLBNUM-1:0];
    reg tlb_d1 [TLBNUM-1:0];
    reg tlb_v1 [TLBNUM-1:0];
    
    
    wire [15:0] match0;
    wire [15:0] match1;
        
    assign match0[0] = (s0_vppn[18:10]==tlb_vppn[0][18:10]) 
                    && (tlb_ps4MB[0] || s0_vppn[9:0]==tlb_vppn[0][9:0]) 
                    && ((s0_asid==tlb_asid[0]) || tlb_g[0]);
    assign match0[1] = (s0_vppn[18:10]==tlb_vppn[1][18:10]) 
                    && (tlb_ps4MB[1] || s0_vppn[9:0]==tlb_vppn[1][9:0])
                    && ((s0_asid==tlb_asid[1]) || tlb_g[1]);
    assign match0[2] = (s0_vppn[18:10]==tlb_vppn[2][18:10]) 
                    && (tlb_ps4MB[2] || s0_vppn[9:0]==tlb_vppn[2][9:0])
                    && ((s0_asid==tlb_asid[2]) || tlb_g[2]);
    assign match0[3] = (s0_vppn[18:10]==tlb_vppn[3][18:10]) 
                    && (tlb_ps4MB[3] || s0_vppn[9:0]==tlb_vppn[3][9:0])
                    && ((s0_asid==tlb_asid[3]) || tlb_g[3]);
    assign match0[4] = (s0_vppn[18:10]==tlb_vppn[4][18:10]) 
                    && (tlb_ps4MB[4] || s0_vppn[9:0]==tlb_vppn[4][9:0])
                    && ((s0_asid==tlb_asid[4]) || tlb_g[4]);
    assign match0[5] = (s0_vppn[18:10]==tlb_vppn[5][18:10]) 
                    && (tlb_ps4MB[5] || s0_vppn[9:0]==tlb_vppn[5][9:0])
                    && ((s0_asid==tlb_asid[5]) || tlb_g[5]);
    assign match0[6] = (s0_vppn[18:10]==tlb_vppn[6][18:10]) 
                    && (tlb_ps4MB[6] || s0_vppn[9:0]==tlb_vppn[6][9:0])
                    && ((s0_asid==tlb_asid[6]) || tlb_g[6]);
    assign match0[7] = (s0_vppn[18:10]==tlb_vppn[7][18:10]) 
                    && (tlb_ps4MB[7] || s0_vppn[9:0]==tlb_vppn[7][9:0])
                    && ((s0_asid==tlb_asid[7]) || tlb_g[7]);
    assign match0[8] = (s0_vppn[18:10]==tlb_vppn[8][18:10]) 
                    && (tlb_ps4MB[8] || s0_vppn[9:0]==tlb_vppn[8][9:0])
                    && ((s0_asid==tlb_asid[8]) || tlb_g[8]);
    assign match0[9] = (s0_vppn[18:10]==tlb_vppn[9][18:10]) 
                    && (tlb_ps4MB[9] || s0_vppn[9:0]==tlb_vppn[9][9:0])
                    && ((s0_asid==tlb_asid[9]) || tlb_g[9]);
    assign match0[10] = (s0_vppn[18:10]==tlb_vppn[10][18:10]) 
                    && (tlb_ps4MB[10] || s0_vppn[9:0]==tlb_vppn[10][9:0])
                    && ((s0_asid==tlb_asid[10]) || tlb_g[10]);
    assign match0[11] = (s0_vppn[18:10]==tlb_vppn[11][18:10]) 
                    && (tlb_ps4MB[11] || s0_vppn[9:0]==tlb_vppn[11][9:0])
                    && ((s0_asid==tlb_asid[11]) || tlb_g[11]);
    assign match0[12] = (s0_vppn[18:10]==tlb_vppn[12][18:10]) 
                    && (tlb_ps4MB[12] || s0_vppn[9:0]==tlb_vppn[12][9:0])
                    && ((s0_asid==tlb_asid[12]) || tlb_g[12]);
    assign match0[13] = (s0_vppn[18:10]==tlb_vppn[13][18:10]) 
                    && (tlb_ps4MB[13] || s0_vppn[9:0]==tlb_vppn[13][9:0])
                    && ((s0_asid==tlb_asid[13]) || tlb_g[13]);
    assign match0[14] = (s0_vppn[18:10]==tlb_vppn[14][18:10]) 
                    && (tlb_ps4MB[14] || s0_vppn[9:0]==tlb_vppn[14][9:0])
                    && ((s0_asid==tlb_asid[14]) || tlb_g[14]);
    assign match0[15] = (s0_vppn[18:10]==tlb_vppn[15][18:10]) 
                    && (tlb_ps4MB[15] || s0_vppn[9:0]==tlb_vppn[15][9:0]) 
                    && ((s0_asid==tlb_asid[15]) || tlb_g[15]);


    assign match1[0] = (s1_vppn[18:10]==tlb_vppn[0][18:10]) 
                    && (tlb_ps4MB[0] || s1_vppn[9:0]==tlb_vppn[0][9:0]) 
                    && ((s1_asid==tlb_asid[0]) || tlb_g[0]);
    assign match1[1] = (s1_vppn[18:10]==tlb_vppn[1][18:10]) 
                    && (tlb_ps4MB[1] || s1_vppn[9:0]==tlb_vppn[1][9:0])
                    && ((s1_asid==tlb_asid[1]) || tlb_g[1]);
    assign match1[2] = (s1_vppn[18:10]==tlb_vppn[2][18:10]) 
                    && (tlb_ps4MB[2] || s1_vppn[9:0]==tlb_vppn[2][9:0])
                    && ((s1_asid==tlb_asid[2]) || tlb_g[2]);
    assign match1[3] = (s1_vppn[18:10]==tlb_vppn[3][18:10]) 
                    && (tlb_ps4MB[3] || s1_vppn[9:0]==tlb_vppn[3][9:0])
                    && ((s1_asid==tlb_asid[3]) || tlb_g[3]);
    assign match1[4] = (s1_vppn[18:10]==tlb_vppn[4][18:10]) 
                    && (tlb_ps4MB[4] || s1_vppn[9:0]==tlb_vppn[4][9:0])
                    && ((s1_asid==tlb_asid[4]) || tlb_g[4]);
    assign match1[5] = (s1_vppn[18:10]==tlb_vppn[5][18:10]) 
                    && (tlb_ps4MB[5] || s1_vppn[9:0]==tlb_vppn[5][9:0])
                    && ((s1_asid==tlb_asid[5]) || tlb_g[5]);
    assign match1[6] = (s1_vppn[18:10]==tlb_vppn[6][18:10]) 
                    && (tlb_ps4MB[6] || s1_vppn[9:0]==tlb_vppn[6][9:0])
                    && ((s1_asid==tlb_asid[6]) || tlb_g[6]);
    assign match1[7] = (s1_vppn[18:10]==tlb_vppn[7][18:10]) 
                    && (tlb_ps4MB[7] || s1_vppn[9:0]==tlb_vppn[7][9:0])
                    && ((s1_asid==tlb_asid[7]) || tlb_g[7]);
    assign match1[8] = (s1_vppn[18:10]==tlb_vppn[8][18:10]) 
                    && (tlb_ps4MB[8] || s1_vppn[9:0]==tlb_vppn[8][9:0])
                    && ((s1_asid==tlb_asid[8]) || tlb_g[8]);
    assign match1[9] = (s1_vppn[18:10]==tlb_vppn[9][18:10]) 
                    && (tlb_ps4MB[9] || s1_vppn[9:0]==tlb_vppn[9][9:0])
                    && ((s1_asid==tlb_asid[9]) || tlb_g[9]);
    assign match1[10] = (s1_vppn[18:10]==tlb_vppn[10][18:10]) 
                    && (tlb_ps4MB[10] || s1_vppn[9:0]==tlb_vppn[10][9:0])
                    && ((s1_asid==tlb_asid[10]) || tlb_g[10]);
    assign match1[11] = (s1_vppn[18:10]==tlb_vppn[11][18:10]) 
                    && (tlb_ps4MB[11] || s1_vppn[9:0]==tlb_vppn[11][9:0])
                    && ((s1_asid==tlb_asid[11]) || tlb_g[11]);
    assign match1[12] = (s1_vppn[18:10]==tlb_vppn[12][18:10]) 
                    && (tlb_ps4MB[12] || s1_vppn[9:0]==tlb_vppn[12][9:0])
                    && ((s1_asid==tlb_asid[12]) || tlb_g[12]);
    assign match1[13] = (s1_vppn[18:10]==tlb_vppn[13][18:10]) 
                    && (tlb_ps4MB[13] || s1_vppn[9:0]==tlb_vppn[13][9:0])
                    && ((s1_asid==tlb_asid[13]) || tlb_g[13]);
    assign match1[14] = (s1_vppn[18:10]==tlb_vppn[14][18:10]) 
                    && (tlb_ps4MB[14] || s1_vppn[9:0]==tlb_vppn[14][9:0])
                    && ((s1_asid==tlb_asid[14]) || tlb_g[14]);
    assign match1[15] = (s1_vppn[18:10]==tlb_vppn[15][18:10]) 
                    && (tlb_ps4MB[15] || s1_vppn[9:0]==tlb_vppn[15][9:0]) 
                    && ((s1_asid==tlb_asid[15]) || tlb_g[15]);
    
    assign s0_found = match0 ? 1'b1 : 1'b0;
    assign s1_found = match1 ? 1'b1 : 1'b0;

    assign s0_index = ({4{match0 == 16'b0000_0000_0000_0001}} & 4'd0)
                | ({4{match0 == 16'b0000_0000_0000_0010}} & 4'd1)
                | ({4{match0 == 16'b0000_0000_0000_0100}} & 4'd2)
                | ({4{match0 == 16'b0000_0000_0000_1000}} & 4'd3)
                | ({4{match0 == 16'b0000_0000_0001_0000}} & 4'd4)
                | ({4{match0 == 16'b0000_0000_0010_0000}} & 4'd5)
                | ({4{match0 == 16'b0000_0000_0100_0000}} & 4'd6)
                | ({4{match0 == 16'b0000_0000_1000_0000}} & 4'd7)
                | ({4{match0 == 16'b0000_0001_0000_0000}} & 4'd8)
                | ({4{match0 == 16'b0000_0010_0000_0000}} & 4'd9)
                | ({4{match0 == 16'b0000_0100_0000_0000}} & 4'd10)
                | ({4{match0 == 16'b0000_1000_0000_0000}} & 4'd11)
                | ({4{match0 == 16'b0001_0000_0000_0000}} & 4'd12)
                | ({4{match0 == 16'b0010_0000_0000_0000}} & 4'd13)
                | ({4{match0 == 16'b0100_0000_0000_0000}} & 4'd14)
                | ({4{match0 == 16'b1000_0000_0000_0000}} & 4'd15);

    assign s1_index = ({4{match1 == 16'b0000_0000_0000_0001}} & 4'd0)
                | ({4{match1 == 16'b0000_0000_0000_0010}} & 4'd1)
                | ({4{match1 == 16'b0000_0000_0000_0100}} & 4'd2)
                | ({4{match1 == 16'b0000_0000_0000_1000}} & 4'd3)
                | ({4{match1 == 16'b0000_0000_0001_0000}} & 4'd4)
                | ({4{match1 == 16'b0000_0000_0010_0000}} & 4'd5)
                | ({4{match1 == 16'b0000_0000_0100_0000}} & 4'd6)
                | ({4{match1 == 16'b0000_0000_1000_0000}} & 4'd7)
                | ({4{match1 == 16'b0000_0001_0000_0000}} & 4'd8)
                | ({4{match1 == 16'b0000_0010_0000_0000}} & 4'd9)
                | ({4{match1 == 16'b0000_0100_0000_0000}} & 4'd10)
                | ({4{match1 == 16'b0000_1000_0000_0000}} & 4'd11)
                | ({4{match1 == 16'b0001_0000_0000_0000}} & 4'd12)
                | ({4{match1 == 16'b0010_0000_0000_0000}} & 4'd13)
                | ({4{match1 == 16'b0100_0000_0000_0000}} & 4'd14)
                | ({4{match1 == 16'b1000_0000_0000_0000}} & 4'd15);

    assign s0_ppn = tlb_ps4MB[s0_index] ? (s0_vppn[9] ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index])
                                        : (s0_va_bit12 ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index]);
    assign s1_ppn = tlb_ps4MB[s1_index] ? (s1_vppn[9] ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index])
                                        : (s1_va_bit12 ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index]);

    assign s0_plv = tlb_ps4MB[s0_index] ? (s0_vppn[9] ? tlb_plv1[s0_index] : tlb_plv0[s0_index])
                                        : (s0_va_bit12 ? tlb_plv1[s0_index] : tlb_plv0[s0_index]);
    assign s1_plv = tlb_ps4MB[s1_index] ? (s1_vppn[9] ? tlb_plv1[s1_index] : tlb_plv0[s1_index])
                                        : (s1_va_bit12 ? tlb_plv1[s1_index] : tlb_plv0[s1_index]);
    
    assign s0_mat = tlb_ps4MB[s0_index] ? (s0_vppn[9] ? tlb_mat1[s0_index] : tlb_mat0[s0_index])
                                        : (s0_va_bit12 ? tlb_mat1[s0_index] : tlb_mat0[s0_index]);
    assign s1_mat = tlb_ps4MB[s1_index] ? (s1_vppn[9] ? tlb_mat1[s1_index] : tlb_mat0[s1_index])
                                        : (s1_va_bit12 ? tlb_mat1[s1_index] : tlb_mat0[s1_index]);

    assign s0_d = tlb_ps4MB[s0_index] ? (s0_vppn[9] ? tlb_d1[s0_index] : tlb_d0[s0_index])
                                        : (s0_va_bit12 ? tlb_d1[s0_index] : tlb_d0[s0_index]);
    assign s1_d = tlb_ps4MB[s1_index] ? (s1_vppn[9] ? tlb_d1[s1_index] : tlb_d0[s1_index])
                                        : (s1_va_bit12 ? tlb_d1[s1_index] : tlb_d0[s1_index]);
            
    assign s0_v = tlb_ps4MB[s0_index] ? (s0_vppn[9] ? tlb_v1[s0_index] : tlb_v0[s0_index])
                                        : (s0_va_bit12 ? tlb_v1[s0_index] : tlb_v0[s0_index]);
    assign s1_v = tlb_ps4MB[s1_index] ? (s1_vppn[9] ? tlb_v1[s1_index] : tlb_v0[s1_index])
                                        : (s1_va_bit12 ? tlb_v1[s1_index] : tlb_v0[s1_index]);

    assign s0_ps = tlb_ps4MB[s0_index] ? 6'd22 : 6'd12;
    assign s1_ps = tlb_ps4MB[s1_index] ? 6'd22 : 6'd12;
    
    assign r_e = tlb_e[r_index];
    assign r_vppn = tlb_vppn[r_index];
    assign r_ps = tlb_ps4MB[r_index] ? 6'd22 : 6'd12;
    assign r_asid = tlb_asid[r_index];
    assign r_g = tlb_g[r_index];
    assign r_ppn0 = tlb_ppn0[r_index];
    assign r_plv0 = tlb_plv0[r_index];
    assign r_mat0 = tlb_mat0[r_index];
    assign r_d0 = tlb_d0[r_index];
    assign r_v0 = tlb_v0[r_index];
    assign r_ppn1 = tlb_ppn1[r_index];
    assign r_plv1 = tlb_plv1[r_index];
    assign r_mat1 = tlb_mat1[r_index];
    assign r_d1 = tlb_d1[r_index];
    assign r_v1 = tlb_v1[r_index];
    
always @(posedge clk) 
begin
    if (we) 
    begin
        tlb_e[w_index] <= w_e;
        tlb_vppn[w_index] <= w_vppn;

        if(w_ps == 6'd22)begin
            tlb_ps4MB[w_index] <= 1'b1;
        end
        else begin
            tlb_ps4MB[w_index] <= 1'b0;
        end

        tlb_asid[w_index] <= w_asid;
        tlb_g[w_index] <= w_g;
        tlb_ppn0[w_index] <= w_ppn0;
        tlb_plv0[w_index] <= w_plv0;
        tlb_mat0[w_index] <= w_mat0;
        tlb_d0[w_index] <= w_d0;
        tlb_v0[w_index] <= w_v0;
        tlb_ppn1[w_index] <= w_ppn1;
        tlb_plv1[w_index] <= w_plv1;
        tlb_mat1[w_index] <= w_mat1;
        tlb_d1[w_index] <= w_d1;
        tlb_v1[w_index] <= w_v1;
 
    end
end
endmodule