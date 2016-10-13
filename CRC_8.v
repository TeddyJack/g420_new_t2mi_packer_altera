// Result of calculation is identical to several online calculation services with parameters:
// 1) input reflected = none
// 2) result reflected = none
// 3) polynomial = 0xD5 or 111010101
// 4) initial value = 0x00
// 5) final xor value = 0x00

module CRC_8(
input CLK,
input RST,
input ENA,
input INIT,
input [7:0] d,

output reg [7:0] CRC
);

wire [7:0] c = CRC;
wire [7:0] newcrc;

always@(negedge CLK or negedge RST)
begin
if(!RST)
	CRC [7:0] <= {8{1'b0}};
else
	begin
	if(INIT) 
		CRC [7:0] <= {8{1'b0}};
   else if(ENA)
		CRC <= newcrc;
	end
end

assign newcrc[0] = d[7] ^ d[6] ^ d[3] ^ d[1] ^ d[0] ^ c[0] ^ c[1] ^ c[3] ^ c[6] ^ c[7];
assign newcrc[1] = d[7] ^ d[4] ^ d[2] ^ d[1] ^ c[1] ^ c[2] ^ c[4] ^ c[7];
assign newcrc[2] = d[7] ^ d[6] ^ d[5] ^ d[2] ^ d[1] ^ d[0] ^ c[0] ^ c[1] ^ c[2] ^ c[5] ^ c[6] ^ c[7];
assign newcrc[3] = d[7] ^ d[6] ^ d[3] ^ d[2] ^ d[1] ^ c[1] ^ c[2] ^ c[3] ^ c[6] ^ c[7];
assign newcrc[4] = d[6] ^ d[4] ^ d[2] ^ d[1] ^ d[0] ^ c[0] ^ c[1] ^ c[2] ^ c[4] ^ c[6];
assign newcrc[5] = d[7] ^ d[5] ^ d[3] ^ d[2] ^ d[1] ^ c[1] ^ c[2] ^ c[3] ^ c[5] ^ c[7];
assign newcrc[6] = d[7] ^ d[4] ^ d[2] ^ d[1] ^ d[0] ^ c[0] ^ c[1] ^ c[2] ^ c[4] ^ c[7];
assign newcrc[7] = d[7] ^ d[6] ^ d[5] ^ d[2] ^ d[0] ^ c[0] ^ c[2] ^ c[5] ^ c[6] ^ c[7];

endmodule
