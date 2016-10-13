`define BYTES_TO_FIND_SYNC 3'd5
`define BYTES_TO_LOSE_SYNC 2'd2

module find_sync(
input RST,
input [7:0] DATA_IN,
input DCLK,
input DVALID,

output reg SYNC_FOUND,
output reg PSYNC,
output reg [7:0] DATA_OUT,
output reg DVALID_OUT,
output [7:0] BYTE_INDEX
);

assign BYTE_INDEX = byte_counter;

reg state;
parameter wait_for_sync_byte	= 1'b0;
parameter count_bytes			= 1'b1;

reg [7:0] byte_counter;
reg [2:0] sync_found_counter;
reg [1:0] sync_lost_counter;

always@(posedge DCLK or negedge RST)
begin
if(!RST)
	begin
	state <= wait_for_sync_byte;
	byte_counter <= 0;
	sync_found_counter <= 0;
	sync_lost_counter <= 0;
	SYNC_FOUND <= 0;
	PSYNC <= 0;
	end
else if(DVALID)
	case(state)
	wait_for_sync_byte:
		if(DATA_IN == 8'h47)
			begin
			state <= count_bytes;
			byte_counter <= 1;
			sync_found_counter <= 1;
			end
	count_bytes:
		begin
		if(byte_counter < 8'd188)
			begin
			byte_counter <= byte_counter + 1'b1;
			PSYNC <= 0;
			end
		else
			begin
			byte_counter <= 1;
			//==
			if(SYNC_FOUND)
				begin
				if(DATA_IN == 8'h47)
					begin
					sync_lost_counter <= 0;
					PSYNC <= 1;
					end
				else
					begin
					if(sync_lost_counter < (`BYTES_TO_LOSE_SYNC - 1'b1))
						begin
						sync_lost_counter <= sync_lost_counter + 1'b1;
						PSYNC <= 1;
						end
					else
						begin
						SYNC_FOUND <= 0;
						sync_lost_counter <= 0;
						state <= wait_for_sync_byte;
						sync_found_counter <= 0;
						end
					end
				end
			else
				begin
				if(DATA_IN == 8'h47)
					begin
					sync_found_counter <= sync_found_counter + 1'b1;
					if(sync_found_counter == (`BYTES_TO_FIND_SYNC - 1'b1))
						begin
						SYNC_FOUND <= 1;
						PSYNC <= 1;
						end
					end
				else
					begin
					sync_found_counter <= 0;
					state <= wait_for_sync_byte;
					end
				end
			end
		end
	endcase
end

always@(posedge DCLK or negedge RST)
begin
if(!RST)
	begin
	DVALID_OUT	<= 0;
	DATA_OUT		<= 0;
	end
else
	begin
	DVALID_OUT <= DVALID;
	DATA_OUT <= DATA_IN;
	end
end

endmodule
