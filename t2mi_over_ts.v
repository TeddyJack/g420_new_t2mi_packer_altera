module t2mi_over_ts(
input CLK,
input RST,
input START,
input ENA_IN,
input [7:0] DATA_IN,
input [7:0] POINTER_IN,

input [12:0] t2mi_pid,
input [12:0] pmt_pid,

output [7:0] DATA_OUT,
output reg ENA_OUT,
output reg PSYNC_OUT,

output [3:0] state_mon
);
assign state_mon = state;

assign DATA_OUT = (state == insert_payload) ? payload_out : header_out;

reg [3:0] continuity_counter;
reg [3:0] local_counter;
reg [7:0] payload_counter;
reg [7:0] payload_len;
reg [7:0] header_out;
reg rd_req;
reg start_table;

reg [3:0] state;
parameter [3:0] wait_for_start		= 4'h0;
parameter [3:0] insert_header			= 4'h1;
parameter [3:0] insert_af_or_pointer= 4'h2;
parameter [3:0] insert_payload		= 4'h3;
parameter [3:0] insert_table			= 4'h4;

always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	state <= wait_for_start;
	ENA_OUT <= 0;
	continuity_counter <= 0;
	local_counter <= 0;
	PSYNC_OUT <= 0;
	rd_req <= 0;
	payload_len <= 0;
	header_out <= 0;
	payload_counter <= 0;
	start_table <= 0;
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
				header_out <= 8'h47;
				ENA_OUT <= 1;
				PSYNC_OUT <= 1;
				end
			1:	begin
				header_out[7] <= 0;	// transport error indicator
				header_out[6] <= (pointer_out < 183) ? 1'b1 : 1'b0;	// payload unit start indicator
				header_out[5] <= 0;	// transport priority
				header_out[4:0] <= t2mi_pid[12:8];
				PSYNC_OUT <= 0;
				end
			2:	header_out <= t2mi_pid[7:0];
			3:	begin
				header_out[7:6] <= 0;	// transport scrambling control
				header_out[5:4] <= (pointer_out == 183) ? 2'b11 : 2'b01;	// adaptation field control
				header_out[3:0] <= continuity_counter;
				end
			endcase
			end
		else
			begin
			ENA_OUT <= 0;
			local_counter <= 0;
			if(pointer_out > 183)
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
			if(pointer_out == 183)
				header_out <= 0;	// AF len
			else
				header_out <= pointer_out;
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
		ENA_OUT <= rd_req && (!empty);
		if(payload_counter < (payload_len + 1'b1))	// due to FIFO delay(), this counter counts from 2 to (payload_len + 1)
			begin
			if(!empty)
				begin
				payload_counter <= payload_counter + 1'b1;
				if(payload_counter < payload_len)
					rd_req <= !empty;
				else
					rd_req <= 0;
				end
			end
		else
			begin
			payload_counter <= 0;
			if(table_ready)
				begin
				state <= insert_table;
				start_table <= 1;
				end
			else
				state <= insert_header;
			continuity_counter <= continuity_counter + 1'b1;
			end
		end
	insert_table:
		begin
		start_table <= 0;
		header_out <= table_out;
		ENA_OUT <= table_ena;
		if(table_sent)
			state <= insert_header;
		end
	endcase
end

// It was found while testing: when (bitrate = 54 Mbps) and (PAT, PMT and SDT are inserted), FIFO is filled with (<= 72) words 
output_fifo output_fifo(
.aclr(!RST),
.clock(CLK),
.data({POINTER_IN,DATA_IN}),
.rdreq(rd_req),
.wrreq(ENA_IN),
.empty(empty),
.q({pointer_out,payload_out})
);
wire empty;
wire [7:0] pointer_out;
wire [7:0] payload_out;

insert_tables insert_tables(
.RST(RST),
.CLK(CLK),
.TABLE_READY(table_ready),
.TABLE_SENT(table_sent),
.DATA_OUT(table_out),
.ENA_OUT(table_ena),
.pmt_pid(pmt_pid),
.t2mi_pid(t2mi_pid),
.START(start_table)
);
wire table_ready;
wire table_sent;
wire [7:0] table_out;
wire table_ena;

endmodule
