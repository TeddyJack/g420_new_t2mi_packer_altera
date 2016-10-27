`include "defines.v"

module ts_to_t2mi_packets(
input CLK,
input RST,
input [7:0] DATA,
input [7:0] BYTE_INDEX,
input ENA_TS2T2MI,
input EMPTY,
output RD_REQ,

input [7:0] plp_id,
input [2:0] t2mi_stream_id,
input nm_or_hem,
input [15:0] k_bch,
input [9:0] plp_num_blocks,
input [7:0] num_t2_frames,

input [1:0] timestamp_type,
input [3:0] bandwidth,
input [26:0] T_sf_ssu,

output [6:0] L1_address,
input [7:0] L1_current_byte,

output [7:0] DATA_OUT,
output [7:0] POINTER,
output reg ENA_OUT,

output [3:0] state_mon
);
assign state_mon = state;

assign DATA_OUT = (state == insert_up) ? DATA : data_out;
assign L1_address = payload_byte_counter[6:0];		// actual when (state == insert_L1). though the output is not restricted when other states
assign RD_REQ = rd_req && ENA_TS2T2MI;

// parameters that depend on k_bch
wire [12:0] k_bch_bytes = k_bch[15:3];
wire [12:0] dfl_bytes = k_bch_bytes - 13'd10;
reg [12:0] payload_len_bytes;
wire [12:0] t2mi_packet_len_bytes = 13'd6 + payload_len_bytes + 13'd4;	// t2mi header + payload_len_bytes + crc_32
wire [12:0] bytes_till_end_of_pkt = t2mi_packet_len_bytes - t2mi_byte_count + 1'b1;	// +1'b1 was added after optimization to 1 FIFO
assign POINTER = (bytes_till_end_of_pkt > 13'hFF) ? 8'hFF : bytes_till_end_of_pkt[7:0];
wire [15:0] dfl = dfl_bytes << 3;
wire [15:0] payload_len = payload_len_bytes << 3;

// parameter that depend on nm_or_hem and ISSY (but ISSY is not considered). Change this in case of multi-PLP
wire [7:0] upl_bytes = 8'd188 - nm_or_hem;	// NM = 188 bytes, HEM = 187 bytes	// this calculation is repeated in ts_to_t2mi_packets. when adding ISSY, optimize
wire [15:0] upl = upl_bytes << 3;				// multiply by 8
wire [15:0] syncd = (upl_bytes - BYTE_INDEX) << 3;		// upl depends on NM/HEM and ISSY len, but ISSY is not used. it was +1'b1 inside the brackets before optimizing

// parameters that depend on type_timestamp type
wire [39:0] seconds_since_2000 = ~|timestamp_type ? {40{1'b1}} : {40{1'b0}};					// null : relative
wire [26:0] subseconds = ~|timestamp_type ? {27{1'b1}} : subseconds_reg;
wire [12:0] utco = ~|timestamp_type ? {13{1'b1}} : 13'h2;											// UTC offset: for February 2009 the value is 2

// helpful regs
reg crc_8_ena;
reg crc_8_init;
reg crc_32_init;
reg [3:0] local_counter;
reg [12:0] payload_byte_counter;
reg [12:0] t2mi_byte_count;				// byte counter in t2mi packet
reg [7:0] packet_count;						// t2mi packet counter
reg [7:0] frame_idx;							// t2 frame counter
reg [3:0] superframe_idx;					// superframe counter;
reg [9:0] bb_frame_count;
reg [26:0] subseconds_reg;
reg [7:0] data_out;
reg rd_req;

reg [1:0] current_t2mi_packet_type;
parameter [1:0] type_bb_frame		= 2'h0;
parameter [1:0] type_timestamp	= 2'h1;
parameter [1:0] type_l1				= 2'h2;

reg [3:0] state;		// main state machine
parameter [3:0] insert_t2mi_header				= 4'h0;
parameter [3:0] insert_bb_header_1				= 4'h1;
parameter [3:0] insert_bb_header_2				= 4'h2;
parameter [3:0] insert_up							= 4'h3;
parameter [3:0] insert_timestamp					= 4'h4;
parameter [3:0] insert_L1_header					= 4'h5;
parameter [3:0] insert_L1							= 4'h6;
parameter [3:0] insert_crc_32_of_t2mi_packet	= 4'h7;



always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	data_out <= 0;
	local_counter <= 0;
	crc_8_ena <= 0;
	crc_8_init <= 0;
	rd_req <= 0;
	payload_byte_counter <= 0;
	state <= insert_t2mi_header;
	ENA_OUT <= 0;
	packet_count <= 0;
	crc_32_init <= 0;
	current_t2mi_packet_type <= type_bb_frame;
	bb_frame_count <= 0;
	frame_idx <= 0;
	superframe_idx <= 0;
	subseconds_reg <= 0;
	payload_len_bytes <= 0;
	end
else if(ENA_TS2T2MI)
	case(state)
	insert_t2mi_header:
		begin
		if(local_counter < 6)
			begin
			local_counter <= local_counter + 1'b1;
			ENA_OUT <= 1;
			case(local_counter)
			0:	begin
				crc_32_init <= 0;
				case(current_t2mi_packet_type)
				type_bb_frame:		data_out <= 8'h00;	// packet type
				type_timestamp:	data_out <= 8'h20;
				type_l1:				data_out <= 8'h10;
				endcase
				end
			1:	data_out <= packet_count;					// packet count
			2:	begin
				data_out[7:4] <= superframe_idx;			// superframe idx
				data_out[3:0] <= 0;							// rfu
				end
			3:	begin
				data_out[7:3] <= 0;							// rfu
				data_out[2:0] <= t2mi_stream_id;			// t2mi stream id
				end
			4:	data_out <= payload_len[15:8];			// payload len
			5: data_out <= payload_len[7:0];
			endcase
			end
		else
			begin
			local_counter <= 0;
			ENA_OUT <= 0;
			case(current_t2mi_packet_type)
			type_bb_frame:			state <= insert_bb_header_1;
			type_timestamp:		state <= insert_timestamp;
			type_l1:					state <= insert_L1_header;
			endcase
			end
		end
	insert_bb_header_1:
		begin
		if(local_counter < 3)
			begin
			local_counter <= local_counter + 1'b1;
			ENA_OUT <= 1;
			case(local_counter)
			0:	data_out <= frame_idx;						// frame idx
			1: data_out <= plp_id;							// plp_id
			2: begin
				data_out[7] <= ~|bb_frame_count;		// interleaving frame start (if bb_frame_count == 0 then 1, else 0)
				data_out[6:0] <= 0;							// rfu
				end
			endcase
			end
		else
			begin
			local_counter <= 0;
			ENA_OUT <= 0;
			state <= insert_bb_header_2;
			end
		end
	insert_bb_header_2:
		begin
		if(local_counter < 10)
			begin
			local_counter <= local_counter + 1'b1;
			ENA_OUT <= 1;
			case(local_counter)
			0:	begin										// MATYPE-1
				data_out[7:6]	<= 2'b11;			// input stream format: GFPS/GCS/GSE/TS
				data_out[5]		<= 1'b1;				// (MIS/SIS) multiple/single input stream (referred to the global signal, not to each PLP)
				data_out[4]		<= 1'b1;				// ACM/CCM (different/same coding and modulation parameters for each PLP)
				data_out[3]		<= 1'b0;				// ISSY not-active/active. For single PLP, ISSY is not required
				data_out[2]		<= 1'b0;				// null-packet deletion not-active/active
				data_out[1:0]	<= 2'b0;				// rfu
				crc_8_ena <= 1;
				end
			1:	data_out <= 0;									// MATYPE-2, for detailed info visit [en_302755v010401p, page 27]
			2:	data_out <= nm_or_hem ? 8'h0 : upl[15:8];	// if HEM then issy_value[23:16], else UPL (user packet length in bits) msb
			3: data_out <= nm_or_hem ? 8'h0 : upl[7:0];	// if HEM then issy_value[15:8], else UPL lsb
			4:	data_out <= dfl[15:8];						// DFL (data field length) msb
			5:	data_out <= dfl[7:0];						// DFL lsb
			6:	data_out <= nm_or_hem ? 8'h0 : 8'h47;		// if HEM then issy_value[7:0], else sync byte
			7:	data_out <= syncd[15:8];					// syncd
			8:	data_out <= syncd[7:0];
			9:	begin
				crc_8_ena <= 0;
				crc_8_init <= 1;
				data_out <= crc_8 ^ nm_or_hem;	// CRC-8 xor MODE	// CRC module works on negedge to calculate CRC on time without delays. Be careful with that
				end
			endcase
			end
		else
			begin
			local_counter <= 0;
			ENA_OUT <= 0;
			state <= insert_up;
			ENA_OUT <= 0;
			crc_8_init <= 0;
			end
		end
	insert_up:
		begin
		ENA_OUT <= rd_req && (!EMPTY);
		if(payload_byte_counter < dfl_bytes)
			begin
			if(!EMPTY)
				begin
				if(rd_req)
					payload_byte_counter <= payload_byte_counter + 1'b1;
				if(payload_byte_counter < (dfl_bytes - 1'b1))
					rd_req <= !EMPTY;
				else
					rd_req <= 0;
				end
			end
		else
			begin
			payload_byte_counter <= 0;
			state <= insert_crc_32_of_t2mi_packet;
			end
		end
	insert_timestamp:
		begin
		if(local_counter < 11)
			begin
			local_counter <= local_counter + 1'b1;
			ENA_OUT <= 1;
			case(local_counter)
			0:	begin
				data_out[7:4] <= 0;				// rfu
				data_out[3:0] <= bandwidth;
				end
			1: data_out <= seconds_since_2000[39:32];
			2: data_out <= seconds_since_2000[31:24];
			3: data_out <= seconds_since_2000[23:16];
			4: data_out <= seconds_since_2000[15:8];
			5: data_out <= seconds_since_2000[7:0];
			6: data_out <= subseconds[26:19];
			7: data_out <= subseconds[18:11];
			8: data_out <= subseconds[10:3];
			9: begin
				data_out[7:5] <= subseconds[2:0];
				data_out[4:0] <= utco[12:8];
				end
			10:data_out <= utco[7:0];
			endcase
			end
		else
			begin
			local_counter <= 0;
			ENA_OUT <= 0;
			state <= insert_crc_32_of_t2mi_packet;
			end
		end
	insert_L1_header:
		begin
		if(local_counter < 2)
			begin
			local_counter <= local_counter + 1'b1;
			ENA_OUT <= 1;
			case(local_counter)
			0:	data_out <= frame_idx;		// frame idx
			1: begin
				data_out[7:6] <= 0;			// freq source: 0 = L1 frequency field; 1 = individual adressing function; 3 = manually set at modulator
				data_out[5:0] <= 0;			// rfu
				end
			endcase
			end
		else
			begin
			local_counter <= 0;
			ENA_OUT <= 0;
			state <= insert_L1;
			end
		end
	insert_L1:
		begin
		if(payload_byte_counter < `L1_LEN_BYTES)
			begin
			payload_byte_counter <= payload_byte_counter + 1'b1;
			if(payload_byte_counter == 16'd49)		// because l1_signalling[49] is frame idx
				data_out <= frame_idx;
			else
				data_out <= L1_current_byte;
			ENA_OUT <= 1;
			end
		else
			begin
			payload_byte_counter <= 0;
			state <= insert_crc_32_of_t2mi_packet;
			ENA_OUT <= 0;
			if(frame_idx < (num_t2_frames - 1'b1))
				frame_idx <= frame_idx + 1'b1;
			else
				begin
				frame_idx <= 0;
				superframe_idx <= superframe_idx + 1'b1;
				subseconds_reg <= subseconds_reg + T_sf_ssu;
				end
			end
		end
	insert_crc_32_of_t2mi_packet:
		begin
		if(local_counter < 4)
			begin
			local_counter <= local_counter + 1'b1;
			data_out <= crc_32_array[local_counter];
			ENA_OUT <= 1;
			end
		else
			begin
			local_counter <= 0;
			ENA_OUT <= 0;
			packet_count <= packet_count + 1'b1;
			crc_32_init <= 1;
			state <= insert_t2mi_header;
			case(current_t2mi_packet_type)
			type_bb_frame:
				begin
				if(bb_frame_count < (plp_num_blocks - 1'b1))
					bb_frame_count <= bb_frame_count + 1'b1;
				else
					begin
					current_t2mi_packet_type <= type_timestamp;
					payload_len_bytes <= 13'd11;					// len of timestamp
					end
				end
			type_timestamp:
				begin
				current_t2mi_packet_type <= type_l1;
				payload_len_bytes <= 13'd2 + `L1_LEN_BYTES;// L1 header + L1 len bytes

				end
			type_l1:
				begin
				current_t2mi_packet_type <= type_bb_frame;
				bb_frame_count <= 0;
				payload_len_bytes <= 13'd3 + k_bch_bytes;	// bb header 1 + k_bch_bytes
				end
			endcase
			end
		end
	endcase
end

CRC_8 CRC_8(
.CLK(CLK),
.RST(RST),
.ENA(crc_8_ena && ENA_TS2T2MI),
.INIT(crc_8_init && ENA_TS2T2MI),
.d(DATA_OUT),

.CRC(crc_8)
);
wire [7:0] crc_8;

CRC_32 CRC_32(
.CLK(CLK),
.RST(RST),
.ENA(ENA_OUT && (state != insert_crc_32_of_t2mi_packet) && ENA_TS2T2MI),
.INIT(crc_32_init && ENA_TS2T2MI),
.D(DATA_OUT),

.CRC(crc_32)
);
wire [31:0] crc_32;

wire [7:0] crc_32_array [3:0];
assign crc_32_array[0] = crc_32[31:24];
assign crc_32_array[1] = crc_32[23:16];
assign crc_32_array[2] = crc_32[15:8];
assign crc_32_array[3] = crc_32[7:0];

always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	t2mi_byte_count <= 0;
	end
else if(ENA_TS2T2MI)
	begin
	if(crc_32_init)
		t2mi_byte_count <= 1;
	else if(ENA_OUT)
		t2mi_byte_count <= t2mi_byte_count + 1'b1;
	end
end

endmodule
