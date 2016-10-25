`include "defines.v"

module parameters(
input CLK,
input RST,

input [7:0] L1_DATA_IN,
input L1_LOAD,
input L1_SHIFT,
output [7:0] L1_DATA_OUT,

output reg [7:0] plp_id,
output reg nm_or_hem,
output reg [9:0] plp_num_blocks,
output reg [7:0] num_t2_frames,
output [15:0] k_bch
);

(* ramstyle = "logic" *) reg [7:0] l1_signalling_packet [66:0];
assign L1_DATA_OUT = l1_signalling_packet[0];

integer i;
always@(posedge CLK)
begin
if(L1_LOAD || L1_SHIFT)
	begin
	for(i=0; i<(`L1_LEN_BYTES-1'b1); i=i+1)
		l1_signalling_packet[i] <= l1_signalling_packet[i+1];
	if(L1_LOAD)
		l1_signalling_packet[`L1_LEN_BYTES-1'b1] <= L1_DATA_IN;
	else if(L1_SHIFT)
		l1_signalling_packet[`L1_LEN_BYTES-1'b1] <= l1_signalling_packet[0];
	end
end

reg [2:0] plp_cod;
reg [1:0] plp_fec_type;
reg [7:0] l1_counter;
always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	l1_counter <= 0;
	plp_id <= 0;
	plp_cod <= 0;
	plp_fec_type <= 0;
	nm_or_hem <= 0;
	num_t2_frames <= 0;
	plp_num_blocks <= 0;
	end
else
	begin
	if(L1_LOAD)
		begin
		l1_counter <= l1_counter + 1'b1;
		case(l1_counter)
		16:	num_t2_frames			<= L1_DATA_IN;
		31:	plp_id[7:6]				<= L1_DATA_IN[1:0];
		32:	plp_id[5:0]				<= L1_DATA_IN[7:2];
		36:	plp_cod					<= L1_DATA_IN[5:3];
		37:	plp_fec_type			<= L1_DATA_IN[6:5];
		42:	nm_or_hem				<= L1_DATA_IN[4];		// In L1: 01 = NM, 10 = HEM. But in BB frames there is another coding: 0 = NM, 1 = HEM. So I take the msb
		61:	plp_num_blocks[9:7]	<= L1_DATA_IN[2:0];
		62:	plp_num_blocks[6:0]	<= L1_DATA_IN[7:1];
		endcase
		end
	else
		l1_counter <= 0;
	end
end


assign k_bch = k_bch_memory[6*plp_fec_type+plp_cod];
reg [15:0] k_bch_memory [11:0];
initial
	begin
	k_bch_memory [0] <= 16'd7032;		// [0][0]
	k_bch_memory [1] <= 16'd9552;		// [0][1]
	k_bch_memory [2] <= 16'd10632;	// [0][2]
	k_bch_memory [3] <= 16'd11712;	// [0][3]
	k_bch_memory [4] <= 16'd12432;	// [0][4]
	k_bch_memory [5] <= 16'd13152;	// [0][5]
	k_bch_memory [6] <= 16'd32208;	// [1][0]
	k_bch_memory [7] <= 16'd38688;	// [1][1]
	k_bch_memory [8] <= 16'd43040;	// [1][2]
	k_bch_memory [9] <= 16'd48408;	// [1][3]
	k_bch_memory [10] <= 16'd51648;	// [1][4]
	k_bch_memory [11] <= 16'd53840;	// [1][5]
	end

endmodule
