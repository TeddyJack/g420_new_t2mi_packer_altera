`include "defines.v"

module parameters(
input [(8*`L1_LEN_BYTES-1):0] L1_BUS_IN,
input [6:0] L1_ADDRESS,
output [7:0] L1_DATA_OUT,

output [7:0] plp_id,
output nm_or_hem,
output [9:0] plp_num_blocks,
output [7:0] num_t2_frames,
output [15:0] k_bch
);

assign L1_DATA_OUT = l1_array[L1_ADDRESS];

wire [7:0] l1_array [(`L1_LEN_BYTES-1):0];
genvar i;
generate
for(i=0; i<`L1_LEN_BYTES; i=i+1)
	begin: some_name
	assign l1_array[i] = L1_BUS_IN[(i*8+7):(i*8)];
	end
endgenerate

assign num_t2_frames = l1_array[16];
assign plp_id = {l1_array[31][1:0], l1_array[32][7:2]};
wire [2:0] plp_cod = l1_array[36][5:3];
wire [1:0] plp_fec_type = l1_array[37][6:5];
assign nm_or_hem = l1_array[42][4];		// In L1: 01 = NM, 10 = HEM. But in BB frames there is another coding: 0 = NM, 1 = HEM. So I take the msb
assign plp_num_blocks = {l1_array[61][2:0], l1_array[62][7:1]};

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
