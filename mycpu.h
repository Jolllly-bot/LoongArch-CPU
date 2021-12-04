`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       35
    `define FS_TO_DS_BUS_WD 71
    `define DS_TO_ES_BUS_WD 242
    `define ES_TO_MS_BUS_WD 217
    `define MS_TO_WS_BUS_WD 210
    `define WS_TO_RF_BUS_WD 40
    `define ES_FWD_BUS_WD   40
    `define MS_FWD_BUS_WD   39

    `define CSR_CRMD   32'h0
    `define CSR_PRMD   32'h1
    `define CSR_ECFG   32'h4
    `define CSR_ESTAT  32'h5
    `define CSR_ERA    32'h6
    `define CSR_BADV   32'h7
    `define CSR_EENTRY 32'hc
    `define CSR_SAVE0  32'h30
    `define CSR_SAVE1  32'h31
    `define CSR_SAVE2  32'h32
    `define CSR_SAVE3  32'h33
    `define CSR_TID    32'h40
    `define CSR_TCFG   32'h41
    `define CSR_TVAL   32'h42
    `define CSR_TICLR  32'h44

    `define CSR_TLBIDX    32'h10
    `define CSR_TLBEHI    32'h11
    `define CSR_TLBELO0   32'h12
    `define CSR_TLBELO1   32'h13
    `define CSR_ASID      32'h18
    `define CSR_TLBRENTRY 32'h88
    `define CSR_DMW0      32'h180
    `define CSR_DMW1      32'h181



    `define CSR_CRMD_PLV      1:0  
    `define CSR_CRMD_PIE        2
    `define CSR_CRMD_DA         3
    `define CSR_CRMD_PG         4

    `define CSR_PRMD_PPLV     1:0
    `define CSR_PRMD_PIE        2

    `define CSR_ECFG_LIE     12:0

    `define CSR_ESTAT_IS10    1:0

    `define CSR_ERA_PC       31:0

    `define CSR_EENTRY_VA    31:6

    `define CSR_SAVE_DATA    31:0

    `define CSR_TCFG_INITVAL 31:2
    `define CSR_TCFG_EN         0
    `define CSR_TCFG_PERIODIC   1

    `define CSR_TID_TID      31:0

    `define CSR_TICLR_CLR       0

    `define CSR_TLBIDX_INDEX  3 :0
    `define CSR_TLBIDX_PS     29:24
    `define CSR_TLBIDX_NE     31

    `define CSR_TLBEHI_VPPN   31:13

    `define CSR_TLBELO_V      0
    `define CSR_TLBELO_D      1
    `define CSR_TLBELO_PLV    3 :2
    `define CSR_TLBELO_MAT    5 :4
    `define CSR_TLBELO_G      6
    `define CSR_TLBELO_PPN    31:8

    `define CSR_TLBRENTRY_PA   31:6

    `define CSR_ASID_ASID     9 :0
    `define CSR_ASID_ASIDBITS 23:16

    `define CSR_DMW_PLV0      0
    `define CSR_DMW_PLV3      3
    `define CSR_DMW_MAT       5 :4
    `define CSR_DMW_PSEG      27:25
    `define CSR_DMW_VSEG      31:29
    
    `define ECODE_INT  6'h0
    `define ECODE_PIL  6'h1
    `define ECODE_PIS  6'h2
    `define ECODE_PIF  6'h3
    `define ECODE_PME  6'h4
    `define ECODE_PPI  6'h7
    `define ECODE_ADE  6'h8
    `define ECODE_ALE  6'h9
    `define ECODE_SYS  6'hb
    `define ECODE_BRK  6'hc
    `define ECODE_INE  6'hd
    `define ECODE_IPE  6'he
    `define ECODE_FPD  6'hf
    `define ECODE_FPE  6'h12
    `define ECODE_TLBR 6'h3f
    
    
    `define ESUBCODE_ADEF 9'h0
    `define ESUBCODE_ADEM 9'h31
    
    `define TLB_SRCH 5'b00001
    `define TLB_RD   5'b00010
    `define TLB_WR   5'b00100
    `define TLB_FILL 5'b01000
    `define TLB_INV  5'b10000

`endif