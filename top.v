module top(
	input pixclk,  // 25MHz
	input reset,
	output [2:0] TMDSp, TMDSn,
	// output [5:0] led,
	output TMDSp_clock, TMDSn_clock
);
// assign led = {TMDSp,TMDSn};
////////////////////////////////////////////////////////////////////////
reg [10:0] CounterX=0, CounterY=0;
reg hSync, vSync, DrawArea;
always @(posedge pixclk) DrawArea <= (CounterX<1920) && (CounterY<1080);

always @(posedge pixclk) CounterX <= (CounterX==1919) ? 0 : CounterX+1;
always @(posedge pixclk) if(CounterX==1919) CounterY <= (CounterY==1079) ? 0 : CounterY+1;

always @(posedge pixclk) hSync <= 1;//(CounterX>=656) && (CounterX<752);
always @(posedge pixclk) vSync <= 1;//(CounterY>=490) && (CounterY<492);

////////////////
// wire [7:0] W = {8{CounterX[7:0]==CounterY[7:0]}};
// wire [7:0] A = {8{CounterX[7:5]==3'h2 && CounterY[7:5]==3'h2}};
reg [7:0] red, green, blue;
always @(posedge pixclk) red <= 1;//({CounterX[5:0] & {6{CounterY[4:3]==~CounterX[4:3]}}, 2'b00} | W) & ~A;
always @(posedge pixclk) green <= 1;//(CounterX[7:0] & {8{CounterY[6]}} | W) & ~A;
always @(posedge pixclk) blue <= 1;//CounterY[7:0] | W | A;

////////////////////////////////////////////////////////////////////////
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
svo_tmds encode_R(.clk(pixclk), .resetn(reset), .din(red  ), .ctrl(2'b00)        , .de(DrawArea), .dout(TMDS_red));
svo_tmds encode_G(.clk(pixclk), .resetn(reset), .din(green), .ctrl(2'b00)        , .de(DrawArea), .dout(TMDS_green));
svo_tmds encode_B(.clk(pixclk), .resetn(reset), .din(blue ), .ctrl(2'b00/*{vSync,hSync}*/), .de(DrawArea), .dout(TMDS_blue));
// TMDS_encoder encode_R(.clk(pixclk), /*.resetn(reset),*/ .VD(red  ), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_red));
// TMDS_encoder encode_G(.clk(pixclk), /*.resetn(reset),*/ .VD(green), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_green));
// TMDS_encoder encode_B(.clk(pixclk), /*.resetn(reset),*/ .VD(blue ), .CD({vSync,hSync}), .VDE(DrawArea), .TMDS(TMDS_blue));
////////////////////////////////////////////////////////////////////////
wire clk_TMDS;// DCM_TMDS_CLKFX;  // 25MHz x 10 = 250MHz
Gowin_rPLL pll(.clkin(pixclk),.clkout(clk_TMDS));
// ClockDivider divider (.clk_in(pixclk), .clk_out(clk_TMDS));
// DCM_SP #(.CLKFX_MULTIPLY(10)) DCM_TMDS_inst(.CLKIN(pixclk), .CLKFX(DCM_TMDS_CLKFX), .RST(1'b0));
// BUFG BUFG_TMDSp(.I(DCM_TMDS_CLKFX), .O(clk_TMDS));

////////////////////////////////////////////////////////////////////////
reg [3:0] TMDS_mod10=0;  // modulus 10 counter
reg [9:0] TMDS_shift_red=0, TMDS_shift_green=0, TMDS_shift_blue=0;
reg TMDS_shift_load=0;
always @(posedge clk_TMDS) TMDS_shift_load <= (TMDS_mod10==4'd9);

always @(posedge clk_TMDS)
begin
	TMDS_shift_red   <= TMDS_shift_load ? TMDS_red   : TMDS_shift_red  ;
	TMDS_shift_green <= TMDS_shift_load ? TMDS_green : TMDS_shift_green;
	TMDS_shift_blue  <= TMDS_shift_load ? TMDS_blue  : TMDS_shift_blue ;	
	TMDS_mod10 <= (TMDS_mod10==4'd9) ? 4'd0 : TMDS_mod10+4'd1;
end

OBUFDS #(1) OBUFDS_red  (.I(TMDS_shift_red  [0]), .O(TMDSp[2]), .OB(TMDSn[2]));
OBUFDS #(1) OBUFDS_green(.I(TMDS_shift_green[0]), .O(TMDSp[1]), .OB(TMDSn[1]));
OBUFDS #(1) OBUFDS_blue (.I(TMDS_shift_blue [0]), .O(TMDSp[0]), .OB(TMDSn[0]));
OBUFDS #(1) OBUFDS_clock(.I(pixclk), .O(TMDSp_clock), .OB(TMDSn_clock));
endmodule


////////////////////////////////////////////////////////////////////////
// module TMDS_encoder(
// 	input clk,
// 	input [7:0] VD,  // video data (red, green or blue)
// 	input [1:0] CD,  // control data
// 	input VDE,  // video data enable, to choose between CD (when VDE=0) and VD (when VDE=1)
// 	output reg [9:0] TMDS = 0
// );

// wire [3:0] Nb1s = VD[0] + VD[1] + VD[2] + VD[3] + VD[4] + VD[5] + VD[6] + VD[7];
// wire XNOR = (Nb1s>4'd4) || (Nb1s==4'd4 && VD[0]==1'b0);
// wire [8:0] q_m = {~XNOR, q_m[6:0] ^ VD[7:1] ^ {7{XNOR}}, VD[0]};

// reg [3:0] balance_acc = 0;
// wire [3:0] balance = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7] - 4'd4;
// wire balance_sign_eq = (balance[3] == balance_acc[3]);
// wire invert_q_m = (balance==0 || balance_acc==0) ? ~q_m[8] : balance_sign_eq;
// wire [3:0] balance_acc_inc = balance - ({q_m[8] ^ ~balance_sign_eq} & ~(balance==0 || balance_acc==0));
// wire [3:0] balance_acc_new = invert_q_m ? balance_acc-balance_acc_inc : balance_acc+balance_acc_inc;
// wire [9:0] TMDS_data = {invert_q_m, q_m[8], q_m[7:0] ^ {8{invert_q_m}}};
// wire [9:0] TMDS_code = CD[1] ? (CD[0] ? 10'b1010101011 : 10'b0101010100) : (CD[0] ? 10'b0010101011 : 10'b1101010100);

// always @(posedge clk) TMDS <= VDE ? TMDS_data : TMDS_code;
// always @(posedge clk) balance_acc <= VDE ? balance_acc_new : 4'h0;
// endmodule



module OBUFDS #( parameter BW = 0)(
    input [BW-1:0] I,
    output reg [BW-1:0] O,
    output reg [BW-1:0] OB
);
always @(*) begin
	O = I;
	OB = ~I;
end
// assign O <= I;
// assign OB <= ~I;

endmodule

module ClockDivider (
    input clk_in,
    output  clk_out
);

reg [31:0] counter = 0;

always @(posedge clk_in) begin
    if (counter == 0) begin
        clk_out <= ~clk_out;
        counter <= 200; // Change this value to adjust the frequency division ratio
    end
    else begin
        counter <= counter - 1;
    end
end

endmodule
////////////////////////////////////////////////////////////////////////
