create_clock -name "BOARD_CLK" -period 50MHz [get_ports BOARD_CLK]
derive_pll_clocks
derive_clock_uncertainty