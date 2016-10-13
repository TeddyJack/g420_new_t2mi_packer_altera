`include "defines.v"

module L1_giver(
input CLK,
input RST,
output reg [7:0] L1_DATA,
output reg L1_LOAD
);

reg [7:0] l1_signalling_packet [66:0];
initial $readmemh("l1_signalling_init.txt", l1_signalling_packet, 0, 66);

reg state;
parameter send_l1	= 1'b0;
parameter idle		= 1'b1;

reg [7:0] l1_counter;

always@(posedge CLK or negedge RST)
begin
if(!RST)
	begin
	state <= send_l1;
	l1_counter <= 0;
	L1_LOAD <= 0;
	L1_DATA <= 0;
	end
else
	begin
	case(state)
	send_l1:
		begin
		if(l1_counter < `L1_LEN_BYTES)
			begin
			L1_LOAD <= 1;
			l1_counter <= l1_counter + 1'b1;
			L1_DATA <= l1_signalling_packet[l1_counter];
			end
		else
			begin
			l1_counter <= 0;
			L1_LOAD <= 0;
			state <= idle;
			L1_DATA <= 0;
			end
		end
	idle:
		begin
		end
	endcase
	end
end

endmodule
