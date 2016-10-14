module t2mi_over_ts(
input CLK,
input RST,
input [7:0] DATA_IN,
input [7:0] POINTER,
input EMPTY,
input START,

input [12:0] t2mi_pid,

output reg RD_REQ,
output [7:0] DATA_OUT,
output reg ENA_OUT,
output reg PSYNC_OUT,

output [3:0] state_mon
);
assign state_mon = state;

assign DATA_OUT = (state == insert_payload) ? DATA_IN : data_out;

reg [3:0] continuity_counter;
reg [3:0] local_counter;
reg [7:0] payload_counter;
reg [7:0] payload_len;
reg [7:0] data_out;

reg [3:0] state;
parameter [3:0] wait_for_start		= 4'h0;
parameter [3:0] insert_header			= 4'h1;
parameter [3:0] insert_af_or_pointer= 4'h2;
parameter [3:0] insert_payload		= 4'h3;

always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	state <= wait_for_start;
	ENA_OUT <= 0;
	continuity_counter <= 0;
	local_counter <= 0;
	PSYNC_OUT <= 0;
	RD_REQ <= 0;
	payload_len <= 0;
	data_out <= 0;
	payload_counter <= 0;
	end
else
	case(state)
	wait_for_start:
		begin
		if(START)
			state <= insert_header;
		end
	insert_header:
		begin
		if(local_counter < 4)
			begin
			local_counter <= local_counter + 1'b1;
			case(local_counter)
			0:	begin
				data_out <= 8'h47;
				ENA_OUT <= 1;
				PSYNC_OUT <= 1;
				end
			1:	begin
				data_out[7] <= 0;	// transport error indicator
				data_out[6] <= (POINTER < 183) ? 1'b1 : 1'b0;	// payload unit start indicator
				data_out[5] <= 0;	// transport priority
				data_out[4:0] <= t2mi_pid[12:8];
				PSYNC_OUT <= 0;
				end
			2:	data_out <= t2mi_pid[7:0];
			3:	begin
				data_out[7:6] <= 0;	// transport scrambling control
				data_out[5:4] <= (POINTER == 183) ? 2'b11 : 2'b01;	// adaptation field control
				data_out[3:0] <= continuity_counter;
				end
			endcase
			end
		else
			begin
			ENA_OUT <= 0;
			local_counter <= 0;
			if(POINTER > 183)
				begin
				state <= insert_payload;
				payload_len <= 184;
				end
			else
				begin
				state <= insert_af_or_pointer;
				payload_len <= 183;
				end
			end
		end
	insert_af_or_pointer:
		begin
		if(local_counter < 1)
			begin
			ENA_OUT <= 1;
			if(POINTER == 183)
				data_out <= 0;	// AF len
			else
				data_out <= POINTER;
			local_counter <= local_counter + 1'b1;
			end
		else
			begin
			local_counter <= 0;
			ENA_OUT <= 0;
			state <= insert_payload;
			end
		end
	insert_payload:
		begin
		ENA_OUT <= RD_REQ && (!EMPTY);
		if(payload_counter < (payload_len + 1'b1))	// due to FIFO delay, this counter counts from 2 to (payload_len + 1)
			begin
			if(!EMPTY)
				begin
				payload_counter <= payload_counter + 1'b1;
				if(payload_counter < payload_len)
					RD_REQ <= !EMPTY;
				else
					RD_REQ <= 0;
				end
			end
		else
			begin
			payload_counter <= 0;
			state <= insert_header;
			continuity_counter <= continuity_counter + 1'b1;
			end
		end
	endcase
end

endmodule
