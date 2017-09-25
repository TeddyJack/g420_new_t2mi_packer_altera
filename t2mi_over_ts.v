`define bb			2'h0
`define tstamp		2'h1
`define l1			2'h2
`define last_bb	2'h3

`define af_and_payl	2'b11
`define payl_only		2'b01

module t2mi_over_ts(
input CLK,
input RST,
input START,
input ENA_IN,
input [7:0] DATA_IN,
input [7:0] POINTER_IN,
input [1:0] t2mi_packet_type,

input [12:0] t2mi_pid,
input [12:0] pmt_pid,

output [7:0] DATA_OUT,
output reg ENA_OUT,
output PSYNC_OUT,

output reg ENA_TS2T2MI,

output [2:0] state_mon
);
assign state_mon = state;

assign DATA_OUT = header_out;
assign PSYNC_OUT = (state == insert_table) ? table_psync : psync_out;

reg [3:0] continuity_counter;
reg [3:0] local_counter;
reg [7:0] payload_counter;
reg [7:0] payload_len;
reg [7:0] header_out;
reg start_table;
reg psync_out;
reg [7:0] af_len;

reg [2:0] state;
parameter [3:0] wait_for_start		= 4'h0;
parameter [3:0] insert_header			= 4'h1;
parameter [3:0] insert_af				= 4'h2;
parameter [3:0] insert_pointer		= 4'h3;
parameter [3:0] insert_payload		= 4'h4;
parameter [3:0] insert_table			= 4'h5;

always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	state <= wait_for_start;
	ENA_OUT <= 0;
	continuity_counter <= 0;
	local_counter <= 0;
	psync_out <= 0;
	payload_len <= 0;
	header_out <= 0;
	payload_counter <= 0;
	start_table <= 0;
	ENA_TS2T2MI <= 0;
	af_len <= 0;
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
			ENA_OUT <= 1;
			case(local_counter)
			0:	begin
				header_out <= 8'h47;
				psync_out <= 1;
				end
			1:	begin
				header_out[7] <= 0;	// transport error indicator
				header_out[6] <= ((POINTER_IN > 182) | ((t2mi_packet_type == `l1) & (POINTER_IN > 0))) ? 1'b0 : 1'b1;	// payload unit start indicator
				header_out[5] <= 0;	// transport priority
				header_out[4:0] <= t2mi_pid[12:8];
				psync_out <= 0;
				end
			2:	header_out <= t2mi_pid[7:0];
			3:	begin
				header_out[7:6] <= 0;	// transport scrambling control
				if(((t2mi_packet_type == `last_bb) & (POINTER_IN < 83)) | ((t2mi_packet_type == `tstamp) & (POINTER_IN == 0)))	// adaptation field control
					begin
					header_out[5:4] <= `af_and_payl;
					af_len <= 8'd82 - POINTER_IN;
					end
				else if((t2mi_packet_type == `tstamp) | ((t2mi_packet_type == `l1) & (POINTER_IN == 0)))
					begin
					header_out[5:4] <= `af_and_payl;
					af_len <= 8'd103 - POINTER_IN;
					end
				else if(t2mi_packet_type == `l1)
					begin
					header_out[5:4] <= `af_and_payl;
					af_len <= 8'd183 - POINTER_IN;
					end
				else if(POINTER_IN == 183)
					begin
					header_out[5:4] <= `af_and_payl;
					af_len <= 0;
					end
				else
					header_out[5:4] <= `payl_only;
				header_out[3:0] <= continuity_counter;
				end
			endcase
			end
		else
			begin
			ENA_OUT <= 0;
			local_counter <= 0;
			payload_len <= 184;
			if(POINTER_IN > 183)
				begin
				state <= insert_payload;
				ENA_TS2T2MI <= 1;
				end
			else
				begin
				if((POINTER_IN < 183) & (header_out[5:4] == `payl_only))
					state <= insert_pointer;
				else	// if (POINTER_IN == 183) | ((POINTER_IN < 183) & (header_out[5:4] == `af_and_payl))
					state <= insert_af;
				end
			end
		end
	insert_af:
		begin
		if(payload_counter < (af_len + 1'b1))
			begin
			case(payload_counter)
			8'd0:	header_out <= af_len;
			8'd1:	header_out <= 8'h00;
			default: header_out <= 8'hFF;
			endcase
			ENA_OUT <= 1;
			payload_counter <= payload_counter + 1'b1;
			end
		else
			begin
			payload_counter <= 0;
			ENA_OUT <= 0;
			payload_len <= 8'd183 - af_len;
			if((POINTER_IN == 183) | ((t2mi_packet_type == `l1) & (POINTER_IN > 0)))
				begin
				state <= insert_payload;
				ENA_TS2T2MI <= 1;
				end
			else
				state <= insert_pointer;
			end
		end
	insert_pointer:
		begin
		if(local_counter < 1)
			begin
			ENA_OUT <= 1;
			header_out <= POINTER_IN;
			local_counter <= local_counter + 1'b1;
			end
		else
			begin
			local_counter <= 0;
			ENA_OUT <= 0;
			state <= insert_payload;
			payload_len <= payload_len - 1'b1;
			ENA_TS2T2MI <= 1;
			end
		end
	insert_payload:
		begin
		ENA_OUT <= ENA_IN;
		if(payload_counter < payload_len)
			begin
			if(ENA_IN)
				begin
				header_out <= DATA_IN;
				payload_counter <= payload_counter + 1'b1;
				if(payload_counter == (payload_len - 1'b1))
				ENA_TS2T2MI <= 0;
				end
			end
		else
			begin
			ENA_OUT <= 0;
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

insert_tables insert_tables(
.RST(RST),
.CLK(CLK),
.TABLE_READY(table_ready),
.TABLE_SENT(table_sent),
.DATA_OUT(table_out),
.ENA_OUT(table_ena),
.pmt_pid(pmt_pid),
.pcr_pid(13'h1FFF),
.START(start_table),
.PSYNC(table_psync)
);
wire table_ready;
wire table_sent;
wire [7:0] table_out;
wire table_ena;
wire table_psync;
endmodule
