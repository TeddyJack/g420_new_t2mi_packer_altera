// Result of calculation is identical to several online calculation services with parameters:
// 1) input reflected = none
// 2) result reflected = none
// 3) polynomial = 0x4C11DB7 or 100000100110000010001110110110111
// 4) initial value = 0xFFFFFFFF
// 5) final xor value = 0x00000000

module CRC_32(
input CLK,
input RST,
input ENA,
input INIT,
input [7:0] D,

output reg [31:0] CRC                               
);

wire [31:0] C = CRC;
wire [31:0] NewCRC;

always@(posedge CLK or negedge RST)
begin
if(!RST)
	CRC [31:0] <= {32{1'b1}};
else
	begin
	if(INIT)
		CRC [31:0] <=  {32{1'b1}};
	else if(ENA)
		CRC <= NewCRC;
	end
end

assign NewCRC[0] = D[6] ^ D[0] ^ C[30] ^ C[24];
assign NewCRC[1] = D[7] ^ D[6] ^ D[1] ^ D[0] ^ C[31] ^ C[30] ^ C[25] ^ C[24];
assign NewCRC[2] = D[7] ^ D[6] ^ D[2] ^ D[1] ^ D[0] ^ C[31] ^ C[30] ^ C[26] ^ C[25] ^ C[24];
assign NewCRC[3] = D[7] ^ D[3] ^ D[2] ^ D[1] ^ C[31] ^ C[27] ^ C[26] ^ C[25];
assign NewCRC[4] = D[6] ^ D[4] ^ D[3] ^ D[2] ^ D[0] ^ C[30] ^ C[28] ^ C[27] ^ C[26] ^ C[24];
assign NewCRC[5] = D[7] ^ D[6] ^ D[5] ^ D[4] ^ D[3] ^ D[1] ^ D[0] ^ C[31] ^ C[30] ^ C[29] ^ C[28] ^ C[27] ^ C[25] ^ C[24];
assign NewCRC[6] = D[7] ^ D[6] ^ D[5] ^ D[4] ^ D[2] ^ D[1] ^ C[31] ^ C[30] ^ C[29] ^ C[28] ^ C[26] ^ C[25];
assign NewCRC[7] = D[7] ^ D[5] ^ D[3] ^ D[2] ^ D[0] ^ C[31] ^ C[29] ^ C[27] ^ C[26] ^ C[24];
assign NewCRC[8] = D[4] ^ D[3] ^ D[1] ^ D[0] ^ C[28] ^ C[27] ^ C[25] ^ C[24] ^ C[0];
assign NewCRC[9] = D[5] ^ D[4] ^ D[2] ^ D[1] ^ C[29] ^ C[28] ^ C[26] ^ C[25] ^ C[1];
assign NewCRC[10] = D[5] ^ D[3] ^ D[2] ^ D[0] ^ C[2] ^ C[29] ^ C[27] ^ C[26] ^ C[24];
assign NewCRC[11] = D[4] ^ D[3] ^ D[1] ^ D[0] ^ C[3] ^ C[28] ^ C[27] ^ C[25] ^ C[24];
assign NewCRC[12] = D[6] ^ D[5] ^ D[4] ^ D[2] ^ D[1] ^ D[0] ^ C[4] ^ C[30] ^ C[29] ^ C[28] ^ C[26] ^ C[25] ^ C[24];
assign NewCRC[13] = D[7] ^ D[6] ^ D[5] ^ D[3] ^ D[2] ^ D[1] ^ C[5] ^ C[31] ^ C[30] ^ C[29] ^ C[27] ^ C[26] ^ C[25];
assign NewCRC[14] = D[7] ^ D[6] ^ D[4] ^ D[3] ^ D[2] ^ C[6] ^ C[31] ^ C[30] ^ C[28] ^ C[27] ^ C[26];
assign NewCRC[15] = D[7] ^ D[5] ^ D[4] ^ D[3] ^ C[7] ^ C[31] ^ C[29] ^ C[28] ^ C[27];
assign NewCRC[16] = D[5] ^ D[4] ^ D[0] ^ C[8] ^ C[29] ^ C[28] ^ C[24];
assign NewCRC[17] = D[6] ^ D[5] ^ D[1] ^ C[9] ^ C[30] ^ C[29] ^ C[25];
assign NewCRC[18] = D[7] ^ D[6] ^ D[2] ^ C[31] ^ C[30] ^ C[26] ^ C[10];
assign NewCRC[19] = D[7] ^ D[3] ^ C[31] ^ C[27] ^ C[11];
assign NewCRC[20] = D[4] ^ C[28] ^ C[12];
assign NewCRC[21] = D[5] ^ C[29] ^ C[13];
assign NewCRC[22] = D[0] ^ C[24] ^ C[14];
assign NewCRC[23] = D[6] ^ D[1] ^ D[0] ^ C[30] ^ C[25] ^ C[24] ^ C[15];
assign NewCRC[24] = D[7] ^ D[2] ^ D[1] ^ C[31] ^ C[26] ^ C[25] ^ C[16];
assign NewCRC[25] = D[3] ^ D[2] ^ C[27] ^ C[26] ^ C[17];
assign NewCRC[26] = D[6] ^ D[4] ^ D[3] ^ D[0] ^ C[30] ^ C[28] ^ C[27] ^ C[24] ^ C[18];
assign NewCRC[27] = D[7] ^ D[5] ^ D[4] ^ D[1] ^ C[31] ^ C[29] ^ C[28] ^ C[25] ^ C[19];
assign NewCRC[28] = D[6] ^ D[5] ^ D[2] ^ C[30] ^ C[29] ^ C[26] ^ C[20];
assign NewCRC[29] = D[7] ^ D[6] ^ D[3] ^ C[31] ^ C[30] ^ C[27] ^ C[21];
assign NewCRC[30] = D[7] ^ D[4] ^ C[31] ^ C[28] ^ C[22];
assign NewCRC[31] = D[5] ^ C[29] ^ C[23];

endmodule
