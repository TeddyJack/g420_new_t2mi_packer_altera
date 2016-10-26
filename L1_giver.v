`include "defines.v"

module L1_giver(
input CLK,
input RST,
output [(8*`L1_LEN_BYTES-1):0] L1_BUS
);

reg [7:0] l1_signalling_packet [(`L1_LEN_BYTES-1):0];
initial $readmemh("l1_signalling_init.txt", l1_signalling_packet, 0, `L1_LEN_BYTES-1);

genvar i;
generate
for(i=0; i<`L1_LEN_BYTES; i=i+1)
	begin: some_name
	assign L1_BUS[(i*8+7):(i*8)] = l1_signalling_packet[i];
	end
endgenerate

endmodule
