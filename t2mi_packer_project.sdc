create_clock -name "BOARD_CLK" -period 27MHz [get_ports BOARD_CLK]
create_clock -name "DCLK" -period 27MHz [get_ports DCLK]
derive_pll_clocks
derive_clock_uncertainty