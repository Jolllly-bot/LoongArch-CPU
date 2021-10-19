`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       33
    `define FS_TO_DS_BUS_WD 64
    `define DS_TO_ES_BUS_WD 214
    `define ES_TO_MS_BUS_WD 158
    `define MS_TO_WS_BUS_WD 152
    `define WS_TO_RF_BUS_WD 38
    `define ES_FWD_BUS_WD   39
    `define MS_FWD_BUS_WD   38

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
   

    `define CSR_CRMD_PLV      1:0  
    `define CSR_CRMD_PIE        2
    `define CSR_PRMD_PPLV     1:0
    `define CSR_PRMD_PIE        2
    `define CSR_ECFG_LIE     12:0
    `define CSR_ESTAT_IS10    1:0
    `define CSR_ERA_PC       31:0
    `define CSR_EENTRY_VA    31:6
    `define CSR_SAVE_DATA    31:0
    `define CSR_TCFG_INITVAL 31:2
    `define CSR_TCFG_EN 0
    `define CSR_TICLR_CLR 0
    
    `define ECODE_SYS  6'hb

    

`endif