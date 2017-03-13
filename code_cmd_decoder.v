`include "defines.v"

module code_cmd_decoder(
input CLK,
input RST,
input [7:0] DATA,
input [7:0] ADDRESS,
input ENA,
// settings for BBandT2MI
output reg [1:0] timestamp_type,			//00 - null, 01 - relative, 10 - absolute 
output reg [26:0] sframe_len,
output reg [12:0] t2mi_pid,
output reg [2:0] stream_id,
output reg [12:0] pmt_pid,
// L1 bus
output [535:0] L1_bus,
output reg INNER_RST
);

reg [7:0] L1_reg [74:0];

always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	timestamp_type	<= 0;
	sframe_len		<= 0;
	t2mi_pid			<= 0;
	stream_id		<= 0;
	pmt_pid			<= 0;
	INNER_RST		<= 0;
	end
else if(ENA)
	case(ADDRESS)
	8'h4D:			t2mi_pid[12:8]				<= DATA[4:0];								
	8'h4E:			t2mi_pid[7:0]				<= DATA;					
	8'h5E:			stream_id					<= DATA[2:0];
	8'h66:			pmt_pid[12:8]				<= DATA[4:0];
	8'h67:			pmt_pid[7:0]				<= DATA;
	8'h7C:			begin
						timestamp_type				<= DATA[4:3];
						sframe_len[26:24]			<= DATA[2:0];
						end
	8'h7D:			sframe_len[23:16]			<= DATA;
	8'h7E:			sframe_len[15:8]			<= DATA;
	8'h7F:			sframe_len[7:0]			<= DATA;
	8'hFE:			INNER_RST					<= 1;
	default:			begin
						L1_reg[ADDRESS-8'd8]		<= DATA;
						end
	endcase
else
	INNER_RST <= 0;
end

genvar i;
generate
for(i=0; i<`L1_LEN_BYTES; i=i+1)
	begin: one_dim_bus
	assign L1_bus[((i*8)+7):(i*8)] = L1_reg[i];
	end
endgenerate

endmodule
