module t2mi_packer_project(
input BOARD_CLK,
input BUTTON,

input [7:0] DATA,
input DCLK,
input RDY,
input SC_D,

output [7:0] DATA_OUT,
output DCLK_OUT,
output RDY_OUT,
output SC_D_OUT,
output PSYNC_OUT
);
assign RDY_OUT = !dvalid_out;
assign SC_D_OUT = !dvalid_out;

L1_giver L1_giver(
.CLK(DCLK),
.RST(BUTTON),
.L1_DATA(l1_data),
.L1_LOAD(l1_load)
);
wire [7:0] l1_data;
wire l1_load;

t2mi_packer t2mi_packer(
.RST(BUTTON),
.TS_DATA_IN(DATA),
.TS_DCLK_IN(DCLK),
.TS_DVALID_IN(!(SC_D || RDY)),

.L1_DATA_IN(l1_data),
.L1_LOAD(l1_load),

// timestamp
.bandwidth(4'h4),			// 0 = 1.7 MHz, 1 = 5 MHz, 2 = 6 MHz, 3 = 7 MHz, 4 = 8 MHz, 5 = 10 MHz
.timestamp_type(2'h0),	// 0 = null, 1 = relative, 2 = absolute
.T_sf_ssu(27'h0),			// period of superframe in subsecond unit
// other
.t2mi_pid(13'd4096),
.t2mi_stream_id(3'd0),

.T2MI_DATA_OUT(DATA_OUT),
.T2MI_DCLK_OUT(DCLK_OUT),
.T2MI_DVALID_OUT(dvalid_out),
.T2MI_PSYNC_OUT(PSYNC_OUT)
);
wire dvalid_out;

endmodule
