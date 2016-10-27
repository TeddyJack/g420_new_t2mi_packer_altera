module input_ts_prepare(
input RST,
input [7:0] DATA_IN,
input DCLK_IN,
input DVALID_IN,
input RD_REQ,
input nm_or_hem,

output [7:0] DATA_OUT,
output reg [7:0] BYTE_INDEX_A,	// byte index adapted
output SYNC_FOUND,
output EMPTY
);
assign SYNC_FOUND = sync_found;

find_sync find_sync(
.RST(RST),
.DATA_IN(DATA_IN),
.DCLK(DCLK_IN),
.DVALID(DVALID_IN),

.SYNC_FOUND(sync_found),
.PSYNC(psync_out),
.DATA_OUT(data_out),
.DVALID_OUT(dvalid_out),
.BYTE_INDEX(byte_index)
);
wire sync_found;
wire psync_out;
wire [7:0] data_out;
wire dvalid_out;
wire [7:0] byte_index;

wire [7:0] fifo_input = ((!nm_or_hem) && crc_8_init) ? crc_8_reg : data_out;
// It was found while testing: when (input TS bitrate = 53 Mbps), FIFO is filled with (<= 33) words
input_ts_fifo input_ts_fifo(
.aclr((!RST) || (!sync_found)),
.clock(DCLK_IN),
.data(fifo_input),
.rdreq(RD_REQ),		
.wrreq(dvalid_out && sync_found && (!(psync_out && nm_or_hem))),	// in HEM syncbyte should be skipped, but in NM we put CRC-8 of previous UP instead

.empty(EMPTY),
.q(DATA_OUT)
);

reg crc_8_ena;
reg crc_8_init;
always@(posedge DCLK_IN or negedge RST)
begin
if(!RST)
	begin
	crc_8_ena <= 0;
	crc_8_init <= 0;
	end
else
	begin
	if(byte_index == 8'd1)
		begin
		crc_8_ena <= 1;
		crc_8_init <= 0;
		end
	else if(byte_index == 8'd188)
		begin
		crc_8_ena <= 0;
		crc_8_init <= 1;
		end
	end
end

CRC_8 CRC_8(
.CLK(DCLK_IN),
.RST(RST),
.ENA(crc_8_ena & dvalid_out),
.INIT(crc_8_init),
.d(data_out),

.CRC(crc_8)
);
wire [7:0] crc_8;

reg [7:0] crc_8_reg;
always@(posedge DCLK_IN or negedge RST)
begin
if(!RST)
	crc_8_reg <= 0;
else
	begin
	if(crc_8_ena & dvalid_out)
		crc_8_reg <= crc_8;
	end
end

wire [7:0] upl_bytes = 8'd188 - nm_or_hem;	// NM = 188 bytes, HEM = 187 bytes	// this calculation is repeated in ts_to_t2mi_packets. when adding ISSY, optimize

always@(posedge DCLK_IN or negedge RST)
begin
if(!RST)
	begin
	BYTE_INDEX_A <= 0;
	end
else
	begin
	if(!SYNC_FOUND)
		BYTE_INDEX_A <= 0;
	else if(RD_REQ & (!EMPTY))
		begin
		if(BYTE_INDEX_A < upl_bytes)
			BYTE_INDEX_A <= BYTE_INDEX_A + 1'b1;
		else
			BYTE_INDEX_A <= 1;
		end
	end
end

endmodule
