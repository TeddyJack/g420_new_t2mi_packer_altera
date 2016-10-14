module t2mi_over_ts(
input CLK,
input RST,
input [7:0] DATA_IN,
input [7:0] POINTER,
input ENA_IN,
input START,

input [12:0] t2mi_pid,

output reg RD_REQ,
output reg [7:0] DATA_OUT,
output reg ENA_OUT,
output reg PSYNC_OUT,

output [3:0] state_mon
);
assign state_mon = state;

reg [3:0] continuity_counter;
reg [3:0] local_counter;
reg [7:0] payload_counter;
reg [7:0] payload_len;

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
	DATA_OUT <= 0;
	payload_counter <= 0;
	end
else
	begin
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
				DATA_OUT <= 8'h47;
				ENA_OUT <= 1;
				PSYNC_OUT <= 1;
				end
			1:	begin
				DATA_OUT[7] <= 0;	// transport error indicator
				DATA_OUT[6] <= (POINTER < 183) ? 1'b1 : 1'b0;	// payload unit start indicator
				DATA_OUT[5] <= 0;	// transport priority
				DATA_OUT[4:0] <= t2mi_pid[12:8];
				PSYNC_OUT <= 0;
				end
			2:	DATA_OUT <= t2mi_pid[7:0];
			3:	begin
				DATA_OUT[7:6] <= 0;	// transport scrambling control
				DATA_OUT[5:4] <= (POINTER == 183) ? 2'b11 : 2'b01;	// adaptation field control
				DATA_OUT[3:0] <= continuity_counter;
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
				RD_REQ <= 1;
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
				DATA_OUT <= 0;	// AF len
			else
				DATA_OUT <= POINTER;
			local_counter <= local_counter + 1'b1;
			end
		else
			begin
			local_counter <= 0;
			ENA_OUT <= 0;
			state <= insert_payload;
			RD_REQ <= 1;
			end
		end
	insert_payload:
		begin
		if(payload_counter < payload_len)
			begin
			ENA_OUT <= ENA_IN;
			if(ENA_IN)
				begin
				payload_counter <= payload_counter + 1'b1;
				DATA_OUT <= DATA_IN;
				if(payload_counter == (payload_len - 1'b1))
					RD_REQ <= 0;		// moved here from the next step
				end
			end
		else
			begin
			payload_counter <= 0;
			//RD_REQ <= 0;	// moved 1 step back for no errors
			ENA_OUT <= 0;
			state <= insert_header;
			continuity_counter <= continuity_counter + 1'b1;
			end
		end
	endcase
	end
end

endmodule
