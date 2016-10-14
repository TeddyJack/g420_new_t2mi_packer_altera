module t2mi_packer(
input RST,
input [7:0] TS_DATA_IN,
input TS_DCLK_IN,
input TS_DVALID_IN,

input [7:0] L1_DATA_IN,
input L1_LOAD,
// timestamp
input [3:0] bandwidth,			// 0 = 1.7 MHz, 1 = 5 MHz, 2 = 6 MHz, 3 = 7 MHz, 4 = 8 MHz, 5 = 10 MHz
input [1:0] timestamp_type,	// 0 = null, 1 = relative, 2 = absolute
input [26:0] T_sf_ssu,			// period of superframe in subsecond unit
// other
input [12:0] t2mi_pid,
input [2:0] t2mi_stream_id,

output [7:0] T2MI_DATA_OUT,
output T2MI_DCLK_OUT,
output T2MI_DVALID_OUT,
output T2MI_PSYNC_OUT
);

assign T2MI_DCLK_OUT = TS_DCLK_IN;
wire reset = RST & (!L1_LOAD);

parameters parameters(
.CLK(TS_DCLK_IN),
.RST(RST),

.L1_DATA_IN(L1_DATA_IN),
.L1_LOAD(L1_LOAD),
.L1_SHIFT(l1_shift),
.L1_DATA_OUT(l1_data_out),

.plp_id(plp_id),
.nm_or_hem(NM_or_HEM),
.plp_num_blocks(plp_num_blocks),
.num_t2_frames(num_t2_frames),
.k_bch(k_bch)
);
wire [7:0] plp_id;
wire NM_or_HEM;
wire [15:0] k_bch;
wire [9:0] plp_num_blocks;
wire [7:0] l1_data_out;
wire [7:0] num_t2_frames;

input_ts_prepare input_ts_prepare(
.RST(reset),
.DATA_IN(TS_DATA_IN),
.DCLK_IN(TS_DCLK_IN),
.DVALID_IN(TS_DVALID_IN),
.RD_REQ(rd_req_in),
.NM_or_HEM(NM_or_HEM),

.DATA_OUT(data_out),
.BYTE_INDEX(byte_index),
.SYNC_FOUND(sync_found),
.EMPTY(empty_in)
);
wire [7:0] data_out;
wire [7:0] byte_index;
wire sync_found;
wire empty_in;

ts_to_t2mi_packets ts_to_t2mi_packets(
.CLK(TS_DCLK_IN),
.RST(reset),
.DATA(data_out),
.BYTE_INDEX(byte_index),
.SYNC_FOUND(sync_found),
.EMPTY(empty_in),

.SHIFT_L1(l1_shift),
.L1_current_byte(l1_data_out),

.plp_id(plp_id),
.t2mi_stream_id(t2mi_stream_id),
.NM_or_HEM(NM_or_HEM),
.k_bch(k_bch),
.plp_num_blocks(plp_num_blocks),
.num_t2_frames(num_t2_frames),

.timestamp_type(timestamp_type),
.bandwidth(bandwidth),
.T_sf_ssu(T_sf_ssu),

.RD_REQ(rd_req_in),
.DATA_OUT(t2mi_packets),
.ENA_OUT(t2mi_packets_ena),
.POINTER(pointer)
);
wire rd_req_in;
wire l1_shift;
wire [7:0] t2mi_packets;
wire t2mi_packets_ena;
wire [7:0] pointer;

output_fifo output_fifo(
.aclr(!reset),
.clock(TS_DCLK_IN),
.data({pointer,t2mi_packets}),
.rdreq(rd_req_out),
.wrreq(t2mi_packets_ena),
.empty(empty_out),
.q({pointer_out,t2mi_packets_out})
);
wire empty_out;
wire [7:0] pointer_out;
wire [7:0] t2mi_packets_out;

t2mi_over_ts t2mi_over_ts(
.CLK(TS_DCLK_IN),
.RST(reset),
.DATA_IN(t2mi_packets_out),
.POINTER(pointer_out),
.EMPTY(empty_out),
.START(sync_found),

.t2mi_pid(t2mi_pid),

.RD_REQ(rd_req_out),
.DATA_OUT(T2MI_DATA_OUT),
.ENA_OUT(T2MI_DVALID_OUT),
.PSYNC_OUT(T2MI_PSYNC_OUT)
);
wire rd_req_out;

endmodule
