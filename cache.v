module cache (
    input          clk_g,
    input          resetn,
    input          valid,
    input          op,
    input  [  7:0] index,
    input  [ 19:0] tag,
    input  [  3:0] offset,
    input  [  3:0] wstrb,
    input  [ 31:0] wdata,
    output         addr_ok,
    output         data_ok,
    output [ 31:0] rdata,
    output         rd_req,
    output [  2:0] rd_type,
    output [ 31:0] rd_addr,
    input          rd_rdy,
    input          ret_valid,
    input          ret_last,
    input  [ 31:0] ret_data,
    output         wr_req,
    output [  2:0] wr_type,
    output [ 31:0] wr_addr,
    output [  3:0] wr_wstrb,
    output [127:0] wr_data,
    input          wr_rdy
);

localparam IDLE   = 5'b00001;
localparam LOOKUP = 5'b00010;
localparam MISS   = 5'b00100;
localparam REPLACE= 5'b01000;
localparam REFILL = 5'b10000;
localparam IDLE_W  = 2'b01;
localparam WRITE_W = 2'b10;
reg [ 4:0] curr_state;
reg [ 4:0] next_state;
reg [ 1:0] curr_state_w;
reg [ 1:0] next_state_w;

wire       lookup;
wire       refill;
wire       hitwrite;

reg         op_r;
reg  [ 7:0] index_r;
reg  [19:0] tag_r;
reg  [ 3:0] offset_r;
reg  [ 3:0] wstrb_r;
reg  [31:0] wdata_r;

wire        hit0;
wire        hit1;
wire        cache_hit;

wire [31:0] load_word0;
wire [31:0] load_word1;
wire [31:0] load_res;

reg  [31:0] lfsr;
reg         replace_way; //0: way0; 1: way1
reg  [1:0]  ret_cnt;

reg  [48:0] write_buffer;
wire        wb_way;
wire [ 7:0] wb_index;
wire [ 3:0] wb_offset;
wire [ 3:0] wb_wstrb;
wire [31:0] wb_wdata;
wire        conflict;

//TAGV
wire [ 19:0] tag0;
wire [ 19:0] tag1;
wire         v0;
wire         v1;
wire [128:0] data0;
wire [128:0] data1;

wire [ 7:0] tagv_addr;
wire [20:0] tagv_wdata0;
wire [20:0] tagv_wdata1;
wire [20:0] tagv_rdata0;
wire [20:0] tagv_rdata1;
wire        tagv_wen0;
wire        tagv_wen1;

//DATA
wire [ 7:0] bank_addr;
wire [31:0] bank_wdata;

wire [31:0] bank0_way0_wdata;
wire [31:0] bank1_way0_wdata;
wire [31:0] bank2_way0_wdata;
wire [31:0] bank3_way0_wdata;
wire [31:0] bank0_way1_wdata;
wire [31:0] bank1_way1_wdata;
wire [31:0] bank2_way1_wdata;
wire [31:0] bank3_way1_wdata;

wire [31:0] bank0_way0_rdata;
wire [31:0] bank1_way0_rdata;
wire [31:0] bank2_way0_rdata;
wire [31:0] bank3_way0_rdata;
wire [31:0] bank0_way1_rdata;
wire [31:0] bank1_way1_rdata;
wire [31:0] bank2_way1_rdata;
wire [31:0] bank3_way1_rdata;

wire [ 3:0] bank0_way0_wen;
wire [ 3:0] bank1_way0_wen;
wire [ 3:0] bank2_way0_wen;
wire [ 3:0] bank3_way0_wen;
wire [ 3:0] bank0_way1_wen;
wire [ 3:0] bank1_way1_wen;
wire [ 3:0] bank2_way1_wen;
wire [ 3:0] bank3_way1_wen;

reg          wr_req_r;
wire [  7:0] dirty_index;
reg  [255:0] dirty_way0;
reg  [255:0] dirty_way1;


/* FSM */
always @(posedge clk_g) begin
    if (!resetn) begin
        curr_state <= IDLE;
    end 
    else begin
        curr_state <= next_state;
    end
end

always @(*) begin
    case (curr_state)
        IDLE: begin
            if (valid && ~conflict)
                next_state = LOOKUP;
            else
                next_state = IDLE;
        end
        LOOKUP: begin
            if (cache_hit && !valid || valid && conflict)
                next_state = IDLE;
            else if(cache_hit && valid)
                next_state = LOOKUP;
            else if(!cache_hit)
                next_state = MISS;
        end
        MISS: begin
            if(wr_rdy)
                next_state = REPLACE;
            else 
                next_state = MISS;
        end
        REPLACE: begin
            if(rd_rdy)
                next_state = REFILL;
            else 
                next_state = REPLACE;
        end
        REFILL: begin
            if(ret_valid && ret_last)
                next_state = IDLE;
            else
                next_state = REFILL;
        end
        default: begin
            next_state = curr_state;
        end
    endcase
end

assign lookup = curr_state == LOOKUP;
assign refill = curr_state == REFILL;

/* Request buffer */
always @ (posedge clk_g) begin 
   if(curr_state == IDLE   && next_state == LOOKUP
   || curr_state == LOOKUP && next_state == LOOKUP) begin
        op_r     <= op;
        index_r  <= index;
        tag_r    <= tag;
        offset_r <= offset;
        wstrb_r  <= wstrb;
        wdata_r  <= wdata;
    end
end

/* Tag Compare */
assign hit0 = v0 && (tag0 == tag_r);
assign hit1 = v1 && (tag1 == tag_r);
assign cache_hit = hit0 || hit1;

/* Data Select */
assign load_word0 = data0[offset_r[3:2]*32 +: 32];
assign load_word1 = data1[offset_r[3:2]*32 +: 32];
assign load_res = {32{hit0}} & load_word0
               |  {32{hit1}} & load_word1;


/* Miss Buffer */
always@(posedge clk_g) begin
    if(!resetn)begin
        lfsr <= 32'h1;
    end
    else begin
        lfsr <= {lfsr[0], lfsr[31:23], lfsr[22]^lfsr[0], lfsr[21:3], lfsr[2]^lfsr[0], lfsr[1]^lfsr[0]};
    end
end

always @(posedge clk_g) begin
    if (!resetn) begin
        replace_way <= 1'b0;
    end
    else if (curr_state == LOOKUP && next_state == MISS) begin
        replace_way <= lfsr[0];
    end
end

always @(posedge clk_g) begin
    if (!resetn || rd_rdy) begin
        ret_cnt <= 2'b00;
    end
    else if (ret_valid) begin
        ret_cnt <= ret_cnt + 2'b01;
    end
end

/* Write Buffer */
assign hitwrite = lookup && op_r && cache_hit;
assign conflict = hitwrite && valid && ~op && tag == tag_r
               || curr_state_w == WRITE_W && ~op && tag == tag_r && wb_offset == offset[3:2];

always @(posedge clk_g) begin
    if (!resetn) begin
        write_buffer <= 49'h0;
    end
    else if(hitwrite) begin
        write_buffer <= {hit0? 1'b0: 1'b1, //48:48
                         offset_r,         //47:44
                         index_r,          //43:36
                         wstrb_r,          //35:32
                         wdata_r           //31: 0
                        };
    end
end

always @(posedge clk_g) begin
    if(!resetn) begin
        curr_state_w <= IDLE_W;
    end
    else begin
        curr_state_w <= next_state_w;
    end
end

always @(*) begin
    case(curr_state_w)
        IDLE_W: begin
            if(hitwrite) begin
                next_state_w <= WRITE_W;
            end
            else begin
                next_state_w <= IDLE_W;
            end
        end
        WRITE_W: begin
            if(hitwrite) begin
                next_state_w <= WRITE_W;
            end
            else begin
                next_state_w <= IDLE_W;
            end
        end
    endcase
end



/* TAGV RAM */
assign tagv_addr   = (curr_state == IDLE) ? index : index_r;
assign tagv_wen0   = refill & ~replace_way;
assign tagv_wen1   = refill &  replace_way;
assign tagv_wdata0 = {tag_r, 1'b1};
assign tagv_wdata1 = {tag_r, 1'b1};
assign {tag0, v0}  = tagv_rdata0;
assign {tag1, v1}  = tagv_rdata1;


/* DATA Bank RAM */
assign {wb_way, wb_offset, wb_index, wb_wstrb, wb_wdata} = write_buffer;

assign bank_wdata = {{8{ wstrb_r[3]}}, {8{ wstrb_r[2]}}, {8{ wstrb_r[1]}}, {8{ wstrb_r[0]}}} & wdata_r
                  | {{8{~wstrb_r[3]}}, {8{~wstrb_r[2]}}, {8{~wstrb_r[1]}}, {8{~wstrb_r[0]}}} & ret_data;

assign bank_addr = (curr_state == IDLE) ? index : index_r;

assign bank0_way0_wen = {4{curr_state_w == WRITE_W & ~wb_way & (wb_offset[3:2] == 2'd0)}} & wb_wstrb
                      | {4{refill & ~replace_way & ret_valid & (       ret_cnt == 2'd0)}} & 4'b1111;
assign bank1_way0_wen = {4{curr_state_w == WRITE_W & ~wb_way & (wb_offset[3:2] == 2'd1)}} & wb_wstrb
                      | {4{refill & ~replace_way & ret_valid & (       ret_cnt == 2'd1)}} & 4'b1111;
assign bank2_way0_wen = {4{curr_state_w == WRITE_W & ~wb_way & (wb_offset[3:2] == 2'd2)}} & wb_wstrb
                      | {4{refill & ~replace_way & ret_valid & (       ret_cnt == 2'd2)}} & 4'b1111;
assign bank3_way0_wen = {4{curr_state_w == WRITE_W & ~wb_way & (wb_offset[3:2] == 2'd3)}} & wb_wstrb
                      | {4{refill & ~replace_way & ret_valid & (       ret_cnt == 2'd3)}} & 4'b1111;

assign bank0_way1_wen = {4{curr_state_w == WRITE_W & wb_way  & (wb_offset[3:2] == 2'd0)}} & wb_wstrb
                      | {4{refill &  replace_way & ret_valid & (       ret_cnt == 2'd0)}} & 4'b1111;
assign bank1_way1_wen = {4{curr_state_w == WRITE_W & wb_way  & (wb_offset[3:2] == 2'd1)}} & wb_wstrb
                      | {4{refill &  replace_way & ret_valid & (       ret_cnt == 2'd1)}} & 4'b1111;
assign bank2_way1_wen = {4{curr_state_w == WRITE_W & wb_way  & (wb_offset[3:2] == 2'd2)}} & wb_wstrb
                      | {4{refill &  replace_way & ret_valid & (       ret_cnt == 2'd2)}} & 4'b1111;
assign bank3_way1_wen = {4{curr_state_w == WRITE_W & wb_way  & (wb_offset[3:2] == 2'd3)}} & wb_wstrb
                      | {4{refill &  replace_way & ret_valid & (       ret_cnt == 2'd3)}} & 4'b1111;

assign bank0_way0_wdata = {32{curr_state_w == WRITE_W}}          & wb_wdata
                        | {32{refill & (offset_r[3:2] == 2'd0)}} & bank_wdata
                        | {32{refill & (offset_r[3:2] != 2'd0)}} & ret_data;
assign bank1_way0_wdata = {32{curr_state_w == WRITE_W}}          & wb_wdata
                        | {32{refill & (offset_r[3:2] == 2'd1)}} & bank_wdata
                        | {32{refill & (offset_r[3:2] != 2'd1)}} & ret_data;
assign bank2_way0_wdata = {32{curr_state_w == WRITE_W}}          & wb_wdata
                        | {32{refill & (offset_r[3:2] == 2'd2)}} & bank_wdata
                        | {32{refill & (offset_r[3:2] != 2'd2)}} & ret_data;
assign bank3_way0_wdata = {32{curr_state_w == WRITE_W}}          & wb_wdata
                        | {32{refill & (offset_r[3:2] == 2'd3)}} & bank_wdata
                        | {32{refill & (offset_r[3:2] != 2'd3)}} & ret_data;

assign bank0_way1_wdata = bank0_way0_wdata;
assign bank1_way1_wdata = bank1_way0_wdata;
assign bank2_way1_wdata = bank2_way0_wdata;
assign bank3_way1_wdata = bank3_way0_wdata;

assign data0 = {bank3_way0_rdata, bank2_way0_rdata, bank1_way0_rdata, bank0_way0_rdata};
assign data1 = {bank3_way1_rdata, bank2_way1_rdata, bank1_way1_rdata, bank0_way1_rdata};


/* Dirty Regfile*/
assign dirty_index = tagv_addr;

always @ (posedge clk_g) begin
    if (!resetn) begin
        dirty_way0 <= 256'b0;
        dirty_way1 <= 256'b0;
    end
    else if (curr_state_w == WRITE_W && ~wb_way)
        dirty_way0[dirty_index] <= 1'b1;
    else if (curr_state_w == WRITE_W &&  wb_way)
        dirty_way1[dirty_index] <= 1'b1;
    else if (refill && !replace_way && op_r) 
        dirty_way0[dirty_index] <= 1'b1;
    else if (refill && replace_way && op_r)
        dirty_way1[dirty_index] <= 1'b1;
end


/* output control */
always @(posedge clk_g) begin
    if (!resetn) begin
        wr_req_r <= 1'b0;
    end
    else if ((curr_state == MISS)  && (next_state == REPLACE) 
          && (dirty_way0[dirty_index] && ~replace_way || dirty_way1[dirty_index] &&  replace_way)) begin
        wr_req_r <= 1'b1;
    end
    else if (wr_req && wr_rdy) begin
        wr_req_r <= 1'b0;
    end
end

assign wr_req   = wr_req_r;
assign wr_data  = replace_way ? data1 : data0;
assign wr_wstrb = 4'hf;
assign wr_addr  = {replace_way ? tag1 : tag0, index_r, 4'b00};
assign wr_type  = 3'b100;

assign rd_req   = (curr_state == REPLACE);
assign rd_type  = 3'b100;
assign rd_addr  = {tag_r, index_r, 4'b00};
assign rdata    = {32{lookup}} & load_res
                | {32{refill}} & bank_wdata;

assign addr_ok  = (curr_state == IDLE   && next_state == LOOKUP)
               || (curr_state == LOOKUP && next_state == LOOKUP);
assign data_ok  = (curr_state == LOOKUP && next_state == IDLE) 
               || (curr_state == LOOKUP && next_state == LOOKUP) 
               || (curr_state == REFILL && ret_valid && ret_last);


tag_v_ram tag_v_way0(
    .clka(clk_g),
    .addra(tagv_addr),
    .dina(tagv_wdata0),
    .douta(tagv_rdata0),
    .wea(tagv_wen0),
    .ena(1'b1)
);
tag_v_ram tag_v_way1(
    .clka(clk_g),
    .addra(tagv_addr),
    .dina(tagv_wdata1),
    .douta(tagv_rdata1),
    .wea(tagv_wen1),
    .ena(1'b1)
);

data_bank_ram bank0_way0(
    .addra(bank_addr),
    .clka(clk_g),
    .dina(bank0_way0_wdata),
    .douta(bank0_way0_rdata),
    .wea(bank0_way0_wen),
    .ena(1'b1)
);
data_bank_ram bank1_way0(
    .addra(bank_addr),
    .clka(clk_g),
    .dina(bank1_way0_wdata),
    .douta(bank1_way0_rdata),
    .wea(bank1_way0_wen),
    .ena(1'b1)
);
data_bank_ram bank2_way0(
    .addra(bank_addr),
    .clka(clk_g),
    .dina(bank2_way0_wdata),
    .douta(bank2_way0_rdata),
    .wea(bank2_way0_wen),
    .ena(1'b1)
);
data_bank_ram bank3_way0(
    .addra(bank_addr),
    .clka(clk_g),
    .dina(bank3_way0_wdata),
    .douta(bank3_way0_rdata),
    .wea(bank3_way0_wen),
    .ena(1'b1)
);

data_bank_ram bank0_way1(
    .addra(bank_addr),
    .clka(clk_g),
    .dina(bank0_way1_wdata),
    .douta(bank0_way1_rdata),
    .wea(bank0_way1_wen),
    .ena(1'b1)
);
data_bank_ram bank1_way1(
    .addra(bank_addr),
    .clka(clk_g),
    .dina(bank1_way1_wdata),
    .douta(bank1_way1_rdata),
    .wea(bank1_way1_wen),
    .ena(1'b1)
);
data_bank_ram bank2_way1(
    .addra(bank_addr),
    .clka(clk_g),
    .dina(bank2_way1_wdata),
    .douta(bank2_way1_rdata),
    .wea(bank2_way1_wen),
    .ena(1'b1)
);
data_bank_ram bank3_way1(
    .addra(bank_addr),
    .clka(clk_g),
    .dina(bank3_way1_wdata),
    .douta(bank3_way1_rdata),
    .wea(bank3_way1_wen),
    .ena(1'b1)
);


endmodule