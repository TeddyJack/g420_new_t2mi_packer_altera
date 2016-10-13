module t2mi_packer_project(
input BOARD_CLK,
input BUTTON,
output [7:0] DATA_OUT,
output DCLK_OUT,
output DVALID_OUT,
output PSYNC_OUT
);

pll_for_ts_gen pll_1(
.inclk0(BOARD_CLK),
.c0(clk_27)
);
wire clk_27;

ts_generator ts_gen_1(
.CLK_IN(clk_27),
.RST(BUTTON),
.PID(13'h044C),
.kBpS(18'd3200),

.DATA(data),
.DCLK(dclk),
.DVALID(dvalid)
);
wire [7:0] data;
wire dclk;
wire dvalid;

L1_giver L1_giver(
.CLK(clk_27),
.RST(BUTTON),
.L1_DATA(l1_data),
.L1_LOAD(l1_load)
);
wire [7:0] l1_data;
wire l1_load;

t2mi_packer t2mi_packer(
.RST(BUTTON),
.TS_DATA_IN(data),
.TS_DCLK_IN(dclk),
.TS_DVALID_IN(dvalid),

.L1_DATA_IN(l1_data),
.L1_LOAD(l1_load),

// timestamp
.bandwidth(4'h4),			// 0 = 1.7 MHz, 1 = 5 MHz, 2 = 6 MHz, 3 = 7 MHz, 4 = 8 MHz, 5 = 10 MHz
.timestamp_type(2'h1),	// 0 = null, 1 = relative, 2 = absolute
.T_sf_ssu(27'h0),			// period of superframe in subsecond unit
// other
.t2mi_pid(13'd4096),
.t2mi_stream_id(3'd6),

.T2MI_DATA_OUT(DATA_OUT),
.T2MI_DCLK_OUT(DCLK_OUT),
.T2MI_DVALID_OUT(DVALID_OUT),
.T2MI_PSYNC_OUT(PSYNC_OUT)
);

endmodule
