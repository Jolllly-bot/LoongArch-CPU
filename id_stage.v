`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //from ms & es
    input  [`ES_FWD_BUS_WD   -1:0] es_fwd_bus    ,
    input  [`MS_FWD_BUS_WD   -1:0] ms_fwd_bus    ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //exception
    input        ds_flush_pipe
);

reg         ds_valid   ;
wire        ds_ready_go;

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
wire        fs_ex;
wire [ 5:0] fs_csr_ecode;
assign {fs_csr_ecode,
        fs_ex,
        ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
wire        ws_csr_re;
wire        ms_csr_re;
wire        es_csr_re;
assign {ds_has_int,
        ws_csr_re,
        rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire        br_taken_cancel;
wire [31:0] br_target;
wire        br_stall;

wire [ 4:0] load_op;
wire [ 2:0] store_op;
wire [11:0] alu_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] ds_imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
  
wire        inst_add_w; 
wire        inst_sub_w;  
wire        inst_slt;    
wire        inst_sltu;   
wire        inst_nor;    
wire        inst_and;    
wire        inst_or;     
wire        inst_xor;    
wire        inst_slli_w;  
wire        inst_srli_w;  
wire        inst_srai_w;  
wire        inst_addi_w; 
wire        inst_ld_w;  
wire        inst_st_w;   
wire        inst_jirl;   
wire        inst_b;      
wire        inst_bl;     
wire        inst_beq;    
wire        inst_bne;    
wire        inst_lu12i_w;


wire inst_slti;
wire inst_sltui;
wire inst_andi;
wire inst_ori;
wire inst_xori;
wire inst_sll_w;
wire inst_srl_w;
wire inst_sra_w;
wire inst_pcaddu12i;

wire inst_mul_w;
wire inst_mulh_w;
wire inst_mulh_wu;
wire inst_div_w;
wire inst_mod_w;
wire inst_div_wu;
wire inst_mod_wu;

wire inst_blt;
wire inst_bge;
wire inst_bltu;
wire inst_bgeu;

wire inst_ld_b;
wire inst_ld_h;
wire inst_ld_bu;
wire inst_ld_hu;
wire inst_st_b;
wire inst_st_h;

wire inst_csrrd;
wire inst_csrwr;
wire inst_csrxchg;
wire inst_syscall;
wire inst_break;
wire inst_ertn; 

wire inst_rdcntvl_w;
wire inst_rdcntvh_w;
wire inst_rdcntid_w;

wire inst_tlb_srch;
wire inst_tlb_rd;
wire inst_tlb_wr;
wire inst_tlb_fill;
wire inst_invtlb;

wire mul_signed;
wire mul_unsigned;
wire mul_high;
wire div_signed;
wire div_unsigned;
wire div_mod;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20_lu12i;
wire        need_si20_pcaddu12i;
wire        need_si26;  
wire        src2_is_4;
wire        need_ui12;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rj_eq_rd;
wire [32:0] rj_sub_rd;
wire        rj_lt_rd;
wire        rj_ltu_rd;

//forward
wire        es_fwd_valid;
wire [4:0]  es_dest;
wire [31:0] es_data;
wire        es_blk_valid;
wire        ms_fwd_valid;
wire [4:0]  ms_dest;
wire [31:0] ms_data;
wire        es_rf_eq;
wire        ms_rf_eq;
wire        wb_rf_eq;

//exception
wire        ds_ex;
wire [13:0] ds_csr_num;
wire        ds_csr_we;
wire        ds_csr_re;
wire [31:0] ds_csr_wmask;
wire [ 5:0] ds_csr_ecode;
wire [ 8:0] ds_csr_esubcode;
wire        csr_blk;
wire        ds_has_int;

wire        ds_ex_ine;
wire [1:0]  cnt_op;

wire [4:0]  tlb_op;
wire [4:0]  invtlb_op;
wire        csr_refetch;

assign ds_to_es_bus = {ds_refetch  ,
                       tlb_op      ,
                       invtlb_op   ,
                       cnt_op      ,
                       ds_csr_esubcode,
                       ds_ex       ,
                       inst_ertn   ,
                       ds_csr_ecode,
                       ds_csr_re   ,
                       ds_csr_we   ,
                       ds_csr_num  ,
                       ds_csr_wmask,
                       load_op     ,
                       store_op    ,
                       mul_signed  ,
                       mul_unsigned,
                       mul_high    ,
                       div_signed  ,
                       div_unsigned,
                       div_mod     ,
                       alu_op      ,  //149:138
                       res_from_mem,  //137:137
                       src1_is_pc  ,  //136:136
                       src2_is_imm ,  //135:135
                       gr_we       ,  //134:134
                       mem_we      ,  //133:133
                       dest        ,  //132:128
                       ds_imm      ,  //127:96
                       rj_value    ,  //95 :64
                       rkd_value   ,  //63 :32
                       ds_pc          //31 :0
                      };


assign csr_blk = (ws_csr_re && ((rf_waddr == rf_raddr1) || (rf_waddr == rf_raddr2)))
                | (es_csr_re && ((es_dest == rf_raddr1) || (es_dest == rf_raddr2)))
                | (ms_csr_re && ((ms_dest == rf_raddr1) || (ms_dest == rf_raddr2)));

assign {es_csr_re   ,
        es_fwd_valid,
        es_blk_valid,
        es_dest     ,
        es_data
       } = es_fwd_bus;
       
assign {ms_csr_re    ,
        ms_fwd_valid,
        ms_dest     ,
        ms_data     
        } = ms_fwd_bus;


assign ds_ready_go    = ds_flush_pipe ||  ( (!(es_blk_valid && (es_dest == rf_raddr1  || es_dest == rf_raddr2))) && !csr_blk);
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go && ~ds_flush_pipe;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (br_taken_cancel || ds_flush_pipe) begin
        ds_valid <= 1'b0;

    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
    
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r  <= fs_to_ds_bus;
    end
end

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};



decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];

assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];

assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_blt    = op_31_26_d[6'h18] ;
assign inst_bge    = op_31_26_d[6'h19] ;
assign inst_bltu   = op_31_26_d[6'h1a] ;
assign inst_bgeu   = op_31_26_d[6'h1b] ;
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];

assign inst_slti  = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi  = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori   = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori  = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ds_inst[25];

assign inst_mul_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

assign inst_csrrd   = op_31_26_d[6'h01] & ~ds_inst[25] & ~ds_inst[24] & (rj == 5'h00);
assign inst_csrwr   = op_31_26_d[6'h01] & ~ds_inst[25] & ~ds_inst[24] & (rj == 5'h01);
assign inst_csrxchg = op_31_26_d[6'h01] & ~ds_inst[25] & ~ds_inst[24] & (rj != 5'h01) & (rj != 5'h00);
assign inst_ertn    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'b01110) & (rj == 5'h0) & (rd == 5'h0);
assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_break   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];

assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & (rk == 5'b11000) & (rj == 5'h0);
assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & (rk == 5'b11001) & (rj == 5'h0);
assign inst_rdcntid_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & (rk == 5'b11000) & (rd == 5'h0);

assign inst_tlb_srch = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'b01010) & (rj == 5'h0) & (rd == 5'h0);
assign inst_tlb_rd   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'b01011) & (rj == 5'h0) & (rd == 5'h0);
assign inst_tlb_wr   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'b01100) & (rj == 5'h0) & (rd == 5'h0);
assign inst_tlb_fill = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'b01101) & (rj == 5'h0) & (rd == 5'h0);
assign inst_invtlb   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];


assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_st_w 
                    | inst_st_b | inst_st_h | res_from_mem
                    | inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu| inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor| inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;

assign load_op[0] = inst_ld_b;
assign load_op[1] = inst_ld_h;
assign load_op[2] = inst_ld_w;
assign load_op[3] = inst_ld_bu;
assign load_op[4] = inst_ld_hu;

assign store_op[0] = inst_st_b;
assign store_op[1] = inst_st_h;
assign store_op[2] = inst_st_w;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_slti | inst_sltui | inst_st_w | inst_st_b | inst_st_h | res_from_mem;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20_lu12i  =  inst_lu12i_w;
assign need_si20_pcaddu12i = inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;
assign need_ui12  =  inst_andi | inst_ori  | inst_xori;


assign ds_imm =  need_si20_pcaddu12i ? {i20,12'b0}:
                 src2_is_4           ? 32'h4 :
                 need_si20_lu12i     ? {12'b0,i20[4:0],i20[19:5]} :  //i20[16:5]==i12[11:0]
                 need_ui12           ? {20'b0,i12[11:0]} :
             /*need_ui5 || need_si12*/ {{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} : 
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};


assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu 
                     | inst_st_w | inst_st_b | inst_st_h | inst_csrwr | inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w | 
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_st_w   |
                       inst_st_b   |
                       inst_st_h   |
                       inst_lu12i_w|
                       inst_pcaddu12i|
                       inst_jirl   |
                       inst_bl     |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       res_from_mem;


assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_st_b & ~inst_st_h 
                     & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_invtlb;
assign mem_we        = inst_st_w | inst_st_b | inst_st_h;
assign dest          = dst_is_r1 ? 5'd1 
                     : inst_rdcntid_w ? rj 
                     : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

//-----------forward----------------
assign rj_value  = es_fwd_valid && es_dest  == rf_raddr1 ? es_data
                 : ms_fwd_valid && ms_dest  == rf_raddr1 ? ms_data
                 : rf_we        && rf_waddr == rf_raddr1 ? rf_wdata
                 : rf_rdata1; 
assign rkd_value = es_fwd_valid && es_dest == rf_raddr2 ? es_data
                 : ms_fwd_valid && ms_dest == rf_raddr2 ? ms_data
                 : rf_we        && rf_waddr == rf_raddr2 ? rf_wdata
                 : rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);


assign rj_sub_rd = {1'b0,rj_value} + {1'b0,~rkd_value} + 1'b1;

assign rj_lt_rd = (rj_value[31] & ~rkd_value[31])
                | ((rj_value[31] ~^ rkd_value[31]) & rj_sub_rd[31]);

assign rj_ltu_rd = ~rj_sub_rd[32];


assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                   || inst_blt && rj_lt_rd
                   || inst_bge && !rj_lt_rd
                   || inst_bltu && rj_ltu_rd
                   || inst_bgeu && !rj_ltu_rd
                  ) && ds_to_es_valid && !br_stall; 
                  
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign br_taken_cancel = br_taken && ds_ready_go && es_allowin;

assign br_stall = ((es_blk_valid && (es_dest == rf_raddr1  || es_dest == rf_raddr2)) || csr_blk) && (inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu); //??

assign br_bus       = {br_stall, 
                       br_taken,
                       br_taken_cancel,
                       br_target};

//--------------mul&div----------------
assign mul_signed   = inst_mul_w  | inst_mulh_w;
assign mul_unsigned = inst_mulh_wu;
assign mul_high     = inst_mulh_w | inst_mulh_wu;
assign div_signed   = inst_div_w  | inst_mod_w;
assign div_unsigned = inst_div_wu | inst_mod_wu;
assign div_mod      = inst_div_w  | inst_div_wu;

//-------------Exception-----------------
assign cnt_op = {inst_rdcntvh_w, inst_rdcntvl_w};

assign ds_ex = (inst_syscall || inst_break || ds_ex_ine || ds_has_int || fs_ex) && ds_valid;

assign ds_ex_ine = !(inst_add_w     | inst_sub_w   | inst_slt     | inst_sltu   | inst_nor    | inst_and     | inst_or   
                    | inst_xor       | inst_slli_w  | inst_srli_w  | inst_srai_w | inst_addi_w | inst_ld_w    | inst_st_w   
                    | inst_jirl      | inst_b       | inst_bl      | inst_beq    | inst_bne    | inst_lu12i_w | inst_slti   
                    | inst_sltui     | inst_andi    | inst_ori     | inst_xori   | inst_sll_w  | inst_srl_w   | inst_sra_w  
                    | inst_mul_w     | inst_mulh_w  | inst_mulh_wu | inst_div_w  | inst_mod_w  | inst_div_wu  | inst_mod_wu
                    | inst_pcaddu12i | inst_blt     | inst_bge     | inst_bltu   | inst_bgeu   | inst_ld_b    | inst_ld_h 
                    | inst_ld_bu     | inst_ld_hu   | inst_st_b    | inst_st_h   | inst_csrrd  | inst_csrwr   | inst_csrxchg
                    | inst_ertn      | inst_syscall | inst_break   |inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid_w
                    | inst_tlb_srch  | inst_tlb_rd  | inst_tlb_wr  | inst_tlb_fill | inst_invtlb) || (inst_invtlb && (invtlb_op[3] || invtlb_op[4] || (invtlb_op == 5'h7)) );

assign ds_csr_num = inst_ertn ? `CSR_ERA 
                  : (inst_syscall || inst_break || ds_ex_ine || ds_has_int) ? `CSR_EENTRY
                  : (fs_csr_ecode == `ECODE_TLBR) ? `CSR_TLBRENTRY
                  : (fs_csr_ecode != 6'h0) ? `CSR_EENTRY
                  : inst_rdcntid_w  ? `CSR_TID
                  : ds_inst[23:10];

assign ds_csr_ecode = ds_has_int   ? `ECODE_INT
                    : fs_ex        ?  fs_csr_ecode
                    : ds_ex_ine    ? `ECODE_INE
                    : inst_syscall ? `ECODE_SYS
                    : inst_break   ? `ECODE_BRK
                    : 6'h0;

assign ds_csr_esubcode = (fs_csr_ecode == `ECODE_ADE) ? `ESUBCODE_ADEF : 9'h0;
assign ds_csr_re = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid_w;
assign ds_csr_we = inst_csrwr | inst_csrxchg;
assign ds_csr_wmask = inst_csrxchg ? rj_value : {32{1'b1}};

//-----------------TLB----------------------
assign tlb_op    = {inst_invtlb, inst_tlb_fill, inst_tlb_wr, inst_tlb_rd, inst_tlb_srch};
assign invtlb_op = inst_invtlb ? ds_inst[4:0] : 5'b0;
assign csr_refetch = ds_csr_we &&
                    (ds_csr_num == `CSR_CRMD && (ds_csr_wmask[`CSR_CRMD_DA] || ds_csr_wmask[`CSR_CRMD_PG])
                  || ds_csr_num == `CSR_DMW0 || ds_csr_num == `CSR_DMW1 || ds_csr_num == `CSR_ASID);


reg ds_refetch;
always @(posedge clk) begin
    if (reset) begin
        ds_refetch <= 1'b0;
    end
    else if (ds_flush_pipe) begin
        ds_refetch <= 1'b0;
    end
    else if (ds_valid && ds_allowin && (inst_tlb_rd || inst_tlb_fill || inst_tlb_wr || inst_invtlb || csr_refetch)) begin
        ds_refetch <= 1'b1;
    end
end

endmodule
