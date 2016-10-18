`include "defines.v"

module insert_tables(
input RST,
input CLK,
output TABLE_READY,
input TABLE_SENT,
input [7:0] PAYLOAD_CNT,
output reg [7:0] DATA_OUT
);

assign TABLE_READY = pat_ready || pmt_ready || sdt_ready;

reg [7:0] pat [183:0];
reg [7:0] pmt [183:0];
reg [7:0] sdt [183:0];
initial $readmemh("pat.txt", pat, 0, 183);
initial $readmemh("pmt.txt", pmt, 0, 183);
initial $readmemh("sdt.txt", sdt, 0, 183);

always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	DATA_OUT <= 0;
	end
else
	begin
	case(PAYLOAD_CNT)
		3:	begin
			DATA_OUT[7:6] <= 0;	// transport scrambling control
			DATA_OUT[5:4] <= 2'b01;	// adaptation field control
			case(current_table)
			type_pat:	DATA_OUT[3:0] <= cont_counter_pat;
			type_pmt:	DATA_OUT[3:0] <= cont_counter_pmt;
			type_sdt:	DATA_OUT[3:0] <= cont_counter_sdt;
			endcase
			end
		default:
			case(current_table)
			type_pat:	DATA_OUT <= pat[PAYLOAD_CNT];
			type_pmt:	DATA_OUT <= pmt[PAYLOAD_CNT];
			type_sdt:	DATA_OUT <= sdt[PAYLOAD_CNT];
			endcase
	endcase
	end
end

reg [1:0] current_table;
parameter [1:0] type_pat	= 2'h0;
parameter [1:0] type_pmt	= 2'h1;
parameter [1:0] type_sdt	= 2'h2;

always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	current_table <= type_pat;
	end
else
	begin
	if(pat_ready)
		current_table <= type_pat;
	else if(pmt_ready)
		current_table <= type_pmt;
	else if(sdt_ready)
		current_table <= type_sdt;
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
wire pmt_trigger = (pat_pmt_counter == (cnt_limit_pat+1)/3);
wire sdt_trigger = (pat_pmt_counter == (cnt_limit_pat+1)*2/3) && (sdt_eit_counter == 0);

endmodule
