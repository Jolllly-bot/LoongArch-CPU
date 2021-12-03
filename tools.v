module decoder_2_4(
    input  [ 1:0] in,
    output [ 3:0] out
);

genvar i;
generate for (i=0; i<4; i=i+1) begin : gen_for_dec_2_4
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_4_16(
    input  [ 3:0] in,
    output [15:0] out
);

genvar i;
generate for (i=0; i<16; i=i+1) begin : gen_for_dec_4_16
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_5_32(
    input  [ 4:0] in,
    output [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  [ 5:0] in,
    output [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64
    assign out[i] = (in == i);
end endgenerate

endmodule


module encoder_16_4(
    input  [15:0] in,
    output [ 3:0] out
    );
    
/* assign out = ({4{in[ 0]}} & 4'd0 )
           | ({4{in[ 1]}} & 4'd1 )
           | ({4{in[ 2]}} & 4'd2 )
           | ({4{in[ 3]}} & 4'd3 )
           | ({4{in[ 4]}} & 4'd4 )
           | ({4{in[ 5]}} & 4'd5 )
           | ({4{in[ 6]}} & 4'd6 )
           | ({4{in[ 7]}} & 4'd7 )
           | ({4{in[ 8]}} & 4'd8 )
           | ({4{in[ 9]}} & 4'd9 )
           | ({4{in[10]}} & 4'd10)
           | ({4{in[11]}} & 4'd11)
           | ({4{in[12]}} & 4'd12)
           | ({4{in[13]}} & 4'd13)
           | ({4{in[14]}} & 4'd14)
           | ({4{in[15]}} & 4'd15); */
assign out = in[0] ? 4'd0
           : in[1] ? 4'd1
           : in[2] ? 4'd2
           : in[3] ? 4'd3
           : in[4] ? 4'd4
           : in[5] ? 4'd5
           : in[6] ? 4'd6
           : in[7] ? 4'd7
           : in[8] ? 4'd8
           : in[9] ? 4'd9
           : in[10]? 4'd10
           : in[11]? 4'd11
           : in[12]? 4'd12
           : in[13]? 4'd13
           : in[14]? 4'd14
           : in[15]? 4'd15
           : 4'd0;

endmodule



