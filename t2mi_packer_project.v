`include "defines.v"

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
output PSYNC_OUT,

input SCLK,
input SS,
input MOSI
);
assign RDY_OUT = !dvalid_out;
assign SC_D_OUT = !dvalid_out;
assign DCLK_OUT = BOARD_CLK;

SPI SPI(
.CLK(DCLK),
.RST(BUTTON),
.SCLK(SCLK),
.MOSI(MOSI),
.SS(SS),
.SPI_DATA(spi_data),
.SPI_ADDRESS(spi_address),
.SPI_ENA(spi_ena)
);
wire [7:0] spi_data;
wire [7:0] spi_address;
wire spi_ena;

code_cmd_decoder code_cmd_decoder(
.CLK(DCLK),
.RST(BUTTON),
.DATA(spi_data),
.ADDRESS(spi_address),
.ENA(spi_ena),

.timestamp_type(timestamp_type),
.sframe_len(sframe_len),
.t2mi_pid(t2mi_pid),
.stream_id(stream_id),
.pmt_pid(pmt_pid),
.L1_bus(l1_bus),
.INNER_RST(inner_rst)
);
wire [1:0] timestamp_type;
wire [26:0] sframe_len;
wire [12:0] t2mi_pid;
wire [2:0] stream_id;
wire [12:0] pmt_pid;
wire inner_rst;

// L1 giver replaced with code_cmd_decoder
//L1_giver L1_giver(
//.CLK(DCLK),
//.RST(BUTTON),
//.L1_BUS(l1_bus)
//);
wire [(8*`L1_LEN_BYTES-1):0] l1_bus;

reclock_fifo reclock_fifo(
.data		(DATA),
.rdclk	(BOARD_CLK),
.rdreq	(!empty),
.wrclk	(DCLK),
.wrreq	(!(SC_D | RDY)),
.q			(data),
.rdempty	(empty)
);
wire empty;
wire [7:0] data;

reg dvalid;
always@(posedge BOARD_CLK)
	dvalid <= !empty;

t2mi_packer t2mi_packer(
.RST(BUTTON && (!inner_rst)),
.TS_DATA_IN(data),
.TS_DCLK_IN(BOARD_CLK),
.TS_DVALID_IN(dvalid),

.L1_BUS_IN(l1_bus),

// timestamp
.bandwidth(4'h4),			// 0 = 1.7 MHz, 1 = 5 MHz, 2 = 6 MHz, 3 = 7 MHz, 4 = 8 MHz, 5 = 10 MHz
.timestamp_type(timestamp_type),	// 0 = null, 1 = relative, 2 = absolute
.T_sf_ssu(sframe_len),			// period of superframe in subsecond unit
// other
.t2mi_pid(t2mi_pid),
.t2mi_stream_id(stream_id),
.pmt_pid(pmt_pid),

.T2MI_DATA_OUT(DATA_OUT),
.T2MI_DVALID_OUT(dvalid_out),
.T2MI_PSYNC_OUT(PSYNC_OUT)
);
wire dvalid_out;


endmodule
