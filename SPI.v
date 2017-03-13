module SPI(
input CLK,
input RST,
input SCLK,
input MOSI,
input SS,

output [7:0] SPI_DATA,
output [7:0] SPI_ADDRESS,
output SPI_ENA
);
assign SPI_DATA		= shift_reg_in[15:8];
assign SPI_ADDRESS	= shift_reg_in[7:0];

reg [15:0] shift_reg_in;
always@(posedge SCLK or negedge RST)
begin
if(!RST)
	begin
	shift_reg_in <= 0;
	end
else
	begin
	shift_reg_in[0]		<= MOSI;
	shift_reg_in[15:1]	<= shift_reg_in[14:0];
	end
end

rising_edge_detect spi_ena(
.CLOCK(CLK),
.RESET(RST),
.LONG_SIGNAL(SS),
.RISING_EDGE_PULSE(SPI_ENA)
);

endmodule
