`include "defines.v"

module insert_tables(
input RST,
input CLK,
output TABLE_READY,
output TABLE_SENT,
output reg [7:0] DATA_OUT,
output reg ENA_OUT,
input [12:0] pmt_pid,
input [12:0] pcr_pid,
input START,
output reg PSYNC,
output [2:0] state_mon
);

assign state_mon = state;
assign TABLE_READY = pat_ready || pmt_ready || sdt_ready;
assign TABLE_SENT = |table_sent;

reg [7:0] pat [11:0];
reg [7:0] pmt [16:0];
reg [7:0] sdt [47:0];
reg [3:0] cont_counter [2:0];	// 2D register, high dimension is current_table
reg [2:0] table_sent;
integer i;
initial
begin
$readmemh("pat.txt", pat, 0, 11);
$readmemh("pmt.txt", pmt, 0, 16);
$readmemh("sdt.txt", sdt, 0, 47);
for(i=0; i<3; i=i+1)
	cont_counter[i] <= 0;
end

reg [1:0] current_table;
parameter [1:0] type_pat	= 2'h0;
parameter [1:0] type_pmt	= 2'h1;
parameter [1:0] type_sdt	= 2'h2;
reg [13:0] current_pid;
reg [2:0] local_counter;
reg [7:0] payload_counter;
reg crc_32_init;
reg [7:0] current_table_len;

reg [2:0] state;
parameter [2:0] idle				= 3'h0;
parameter [2:0] wait_for_start= 3'h1;
parameter [2:0] insert_header	= 3'h2;
parameter [2:0] insert_table	= 3'h3;
parameter [2:0] insert_crc_32	= 3'h4;
parameter [2:0] insert_zeros	= 3'h5;

always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	state <= idle;
	local_counter <= 0;
	payload_counter <= 0;
	crc_32_init <= 0;
	ENA_OUT <= 0;
	DATA_OUT <= 0;
	current_table_len <= 0;
	PSYNC <= 0;
	current_table <= type_pat;
	current_pid <= 0;
	table_sent <= 0;
	end
else
	case(state)
	idle:
		begin
		table_sent[current_table] <= 0;
		if(TABLE_READY)
			state <= wait_for_start;
		if(pat_ready)
			begin
			current_table <= type_pat;
			current_pid <= 13'h0;
			end
		else if(pmt_ready)
			begin
			current_table <= type_pmt;
			current_pid <= pmt_pid;
			end
		else if(sdt_ready)
			begin
			current_table <= type_sdt;
			current_pid <= 13'h11;
			end
		end
	wait_for_start:
		begin
		if(START)
			state <= insert_header;
		end
	insert_header:
		begin
		if(local_counter < 5)
			begin
			ENA_OUT <= 1;
			local_counter <= local_counter + 1'b1;
			case(local_counter)
			0:	begin
				DATA_OUT <= 8'h47;
				PSYNC <= 1;
				end
			1:	begin
				DATA_OUT[7:5] <= 3'b010;	// transp err indic, payl start unit indic, transp priority
				DATA_OUT[4:0] <= current_pid[12:8];
				PSYNC <= 0;
				end
			2:	DATA_OUT <= current_pid[7:0];
			3:	begin
				DATA_OUT[7:4] <= 4'b0001;	// transp scrambling control, AF control
				DATA_OUT[3:0] <= cont_counter[current_table];
				end
			4:	DATA_OUT <= 0;	// pointer field
			endcase
			end
		else
			begin
			ENA_OUT <= 0;
			state <= insert_table;
			current_table_len <= 8'hFF;	// put here maximum number, until we read the section len
			local_counter <= 0;
			end
		end
	insert_table:
		begin
		if(payload_counter < current_table_len)
			begin
			ENA_OUT <= 1;
			payload_counter <= payload_counter + 1'b1;
			if(payload_counter == 3)						// section len is at table[2], but we read it 1 step later to avoid additional "ifs" or "cases"
				current_table_len <= DATA_OUT - 1'b1;	// current_table_len is [7:0], but full section len is [13:0], so we take the lsb. enough for short sections
			
			if(current_table == type_pat)
				begin
				if(payload_counter == 10)
					begin
					DATA_OUT[7:5] <= 0;
					DATA_OUT[4:0] <= pmt_pid[12:8];
					end
				else if(payload_counter == 11)
					DATA_OUT <= pmt_pid[7:0];
				else
					DATA_OUT <= pat[payload_counter];
				end
			else if(current_table == type_pmt)
				begin
				if(payload_counter == 8)
					begin
					DATA_OUT[7:5] <= 0;
					DATA_OUT[4:0] <= pcr_pid[12:8];
					end
				else if(payload_counter == 9)
					DATA_OUT <= pcr_pid[7:0];
				else
					DATA_OUT <= pmt[payload_counter];
				end
			else
				DATA_OUT <= sdt[payload_counter];
			end
		else
			begin
			ENA_OUT <= 0;
			state <= insert_crc_32;
			end
		end
	insert_crc_32:
		begin
		if(local_counter < 4)
			begin
			ENA_OUT <= 1;
			DATA_OUT <= crc_32_array[local_counter];
			local_counter <= local_counter + 1'b1;
			payload_counter <= payload_counter + 1'b1;
			end
		else
			begin
			ENA_OUT <= 0;
			state <= insert_zeros;
			crc_32_init <= 1;
			local_counter <= 0;
			end
		end
	insert_zeros:
		begin
		crc_32_init <= 0;
		if(payload_counter < 183)
			begin
			payload_counter <= payload_counter + 1'b1;
			ENA_OUT <= 1;
			DATA_OUT <= 0;
			end
		else
			begin
			ENA_OUT <= 0;
			payload_counter <= 0;
			state <= idle;
			table_sent[current_table] <= 1;
			cont_counter[current_table] <= cont_counter[current_table] + 1'b1;
			end
		end
	endcase
end

CRC_32 CRC_32(
.CLK(CLK),
.RST(RST),
.ENA(ENA_OUT && (state == insert_table)),
.INIT(crc_32_init),
.D(DATA_OUT),

.CRC(crc_32)
);
wire [31:0] crc_32;
wire [7:0] crc_32_array [3:0];
assign crc_32_array[0] = crc_32[31:24];
assign crc_32_array[1] = crc_32[23:16];
assign crc_32_array[2] = crc_32[15:8];
assign crc_32_array[3] = crc_32[7:0];

reg pat_ready;
reg pmt_ready;
reg sdt_ready;
always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	pat_ready <= 0;
	pmt_ready <= 0;
	sdt_ready <= 0;
	end
else
	begin
	if(pat_trigger)
		pat_ready <= 1;
	else if(table_sent[0])
		pat_ready <= 0;
		
	if(pmt_trigger)
		pmt_ready <= 1;
	else if(table_sent[1])
		pmt_ready <= 0;
		
	if(sdt_trigger)
		sdt_ready <= 1;
	else if(table_sent[2])
		sdt_ready <= 0;
	end
end

parameter [31:0] cnt_limit_pat = 250*`MAIN_CLK*1000;	// changed from 0.5 to 0.25 s because of pat and pmt period error
reg [31:0] pat_pmt_counter;		// base timer, that triggers every 0.5 s
reg [1:0] sdt_eit_counter;
always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	pat_pmt_counter <= 0;
	sdt_eit_counter <= 0;
	end
else
	begin
	if(pat_pmt_counter < (cnt_limit_pat - 1'b1))
		pat_pmt_counter <= pat_pmt_counter + 1'b1;
	else
		begin
		pat_pmt_counter <= 0;
		sdt_eit_counter <= sdt_eit_counter + 1'b1;
		end
	end
end

// triggers are designed the way to be distributed equally inside the 0.5 s period
wire pat_trigger = (pat_pmt_counter == 0);
wire pmt_trigger = (pat_pmt_counter == cnt_limit_pat*1/3);
wire sdt_trigger = (pat_pmt_counter == cnt_limit_pat*2/3) && (sdt_eit_counter == 0);

endmodule
