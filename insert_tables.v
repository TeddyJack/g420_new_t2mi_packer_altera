`include "defines.v"

module insert_tables(
input RST,
input CLK,
output TABLE_READY,
output reg TABLE_SENT,
output reg [7:0] DATA_OUT,
output reg ENA_OUT,
input [12:0] pmt_pid,
input [12:0] t2mi_pid,
input START,
output reg PSYNC,
output [2:0] state_mon
);

assign state_mon = state;
assign TABLE_READY = pat_ready || pmt_ready || sdt_ready;

reg [7:0] pat [11:0];
reg [7:0] pmt [16:0];
reg [7:0] sdt [47:0];
initial $readmemh("pat.txt", pat, 0, 11);
initial $readmemh("pmt.txt", pmt, 0, 16);
initial $readmemh("sdt.txt", sdt, 0, 47);

reg [2:0] state;
parameter [2:0] idle				= 3'h0;
parameter [2:0] insert_header	= 3'h1;
parameter [2:0] insert_table	= 3'h2;
parameter [2:0] insert_crc_32	= 3'h3;
parameter [2:0] insert_zeros	= 3'h4;

reg [7:0] counter;
reg crc_32_init;
reg [7:0] current_table_len;

always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	state <= idle;
	counter <= 0;
	crc_32_init <= 0;
	TABLE_SENT <= 0;
	ENA_OUT <= 0;
	DATA_OUT <= 0;
	current_table_len <= 0;
	PSYNC <= 0;
	end
else
	case(state)
	idle:
		begin
		TABLE_SENT <= 0;
		if(START)
			state <= insert_header;
		end
	insert_header:
		begin
		if(counter < 5)
			begin
			ENA_OUT <= 1;
			counter <= counter + 1'b1;
			case(counter)
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
				DATA_OUT[3:0] <= current_cont_counter;
				end
			4:	DATA_OUT <= 0;	// pointer field
			endcase
			end
		else
			begin
			ENA_OUT <= 0;
			state <= insert_table;
			current_table_len <= 8'hFF;	// put here maximum number, until we read the section len
			counter <= 0;
			end
		end
	insert_table:
		begin
		if(counter < current_table_len)
			begin
			ENA_OUT <= 1;
			counter <= counter + 1'b1;
			if(counter == 3)
				current_table_len <= DATA_OUT - 1'b1;	// section len is at table[2], but we read it 1 step later to avoid additional "cases"
			case(current_table)								// current_table_len is 8 bits-wide, but full section len is 13 bits-wide, so we take the lsb. enough for short sections
				type_pat:	case(counter)
								10:		begin
											DATA_OUT[7:5] <= 0;
											DATA_OUT[4:0] <= pmt_pid[12:8];
											end
								11:		DATA_OUT <= pmt_pid[7:0];
								default:	DATA_OUT <= pat[counter];
								endcase
				type_pmt:	case(counter)
								8:			begin
											DATA_OUT[7:5] <= 0;
											DATA_OUT[4:0] <= t2mi_pid[12:8];
											end
								9:			DATA_OUT <= t2mi_pid[7:0];
								default:	DATA_OUT <= pmt[counter];
								endcase
				type_sdt:	DATA_OUT <= sdt[counter];
			endcase
			end
		else
			begin
			ENA_OUT <= 0;
			state <= insert_crc_32;
			end
		end
	insert_crc_32:
		begin
		if(counter < (current_table_len + 3'd4))
			begin
			ENA_OUT <= 1;
			DATA_OUT <= crc_32_array[counter - current_table_len];
			counter <= counter + 1'b1;
			end
		else
			begin
			ENA_OUT <= 0;
			state <= insert_zeros;
			crc_32_init <= 1;
			end
		end
	insert_zeros:
		begin
		crc_32_init <= 0;
		if(counter < 183)
			begin
			counter <= counter + 1'b1;
			ENA_OUT <= 1;
			DATA_OUT <= 0;
			end
		else
			begin
			ENA_OUT <= 0;
			counter <= 0;
			state <= idle;
			TABLE_SENT <= 1;
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

reg [1:0] current_table;
parameter [1:0] type_pat	= 2'h0;
parameter [1:0] type_pmt	= 2'h1;
parameter [1:0] type_sdt	= 2'h2;
reg [13:0] current_pid;
reg [3:0] current_cont_counter;
always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	current_table <= type_pat;
	current_pid <= 0;
	current_cont_counter <= 0;
	end
else
	begin
	if(pat_ready)
		begin
		current_table <= type_pat;
		current_pid <= 13'h0;
		current_cont_counter <= cont_counter_pat;
		end
	else if(pmt_ready)
		begin
		current_table <= type_pmt;
		current_pid <= pmt_pid;
		current_cont_counter <= cont_counter_pmt;
		end
	else if(sdt_ready)
		begin
		current_table <= type_sdt;
		current_pid <= 13'h11;
		current_cont_counter <= cont_counter_sdt;
		end
	end
end


reg [3:0] cont_counter_pat;
reg [3:0] cont_counter_pmt;
reg [3:0] cont_counter_sdt;
always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	cont_counter_pat <= 0;
	cont_counter_pmt <= 0;
	cont_counter_sdt <= 0;
	end
else
	begin
	if(pat_sent)
		cont_counter_pat <= cont_counter_pat + 1'b1;
	if(pmt_sent)
		cont_counter_pmt <= cont_counter_pmt + 1'b1;
	if(sdt_sent)
		cont_counter_sdt <= cont_counter_sdt + 1'b1;
	end
end

wire pat_sent = (current_table == type_pat) && TABLE_SENT;
wire pmt_sent = (current_table == type_pmt) && TABLE_SENT;
wire sdt_sent = (current_table == type_sdt) && TABLE_SENT;

reg pat_ready;
reg pmt_ready;
reg sdt_ready;
reg [2:0] ready;
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
	else if(pat_sent)
		pat_ready <= 0;
		
	if(pmt_trigger)
		pmt_ready <= 1;
	else if(pmt_sent)
		pmt_ready <= 0;
		
	if(sdt_trigger)
		sdt_ready <= 1;
	else if(sdt_sent)
		sdt_ready <= 0;
	end
end

parameter [31:0] cnt_limit_pat = 500*`MAIN_CLK*1000-1;
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
	if(pat_pmt_counter < cnt_limit_pat)
		pat_pmt_counter <= pat_pmt_counter + 1'b1;
	else
		begin
		pat_pmt_counter <= 0;
		sdt_eit_counter <= sdt_eit_counter + 1'b1;
		end
	end
end

wire pat_trigger = (pat_pmt_counter == 0);
// next 2 lines are written this way to distribute table triggers equally inside the 0.5 s period
wire pmt_trigger = (pat_pmt_counter == (cnt_limit_pat+1)/3);
wire sdt_trigger = (pat_pmt_counter == (cnt_limit_pat+1)*2/3) && (sdt_eit_counter == 0);

endmodule
