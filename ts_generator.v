module ts_generator(
input CLK_IN,
input RST,
input [13:0] PID,
input [17:0] kBpS,

output reg [7:0] DATA,
output DCLK,
output reg DVALID,
output reg PSYNC
);

assign DCLK = CLK_IN;
reg [3:0] continuity_counter;
reg [7:0] byte_counter;
reg [15:0] bitrate_counter;
wire [17:0] bitrate_cnt_limit = (18'd216000 / kBpS) - 18'b1;

always@(negedge CLK_IN or negedge RST)
begin
if(!RST)
	begin
	continuity_counter <= 0;
	byte_counter <= 0;
	DVALID <= 0;
	end
else
	begin
	if(bitrate_counter < bitrate_cnt_limit)
		begin
		bitrate_counter <= bitrate_counter + 1'b1;
		DVALID <= 0;
		end
	else
		begin
		bitrate_counter <= 0;
		DVALID <= 1;
		if((byte_counter == 188) || (byte_counter == 0))
			begin
			byte_counter <= 1;
			continuity_counter <= continuity_counter + 1'b1;
			end
		else
			byte_counter <= byte_counter + 1'b1;
		//==
		case(byte_counter)
		188:	begin
				DATA <= 8'h47;
				PSYNC <= 1;
				end
		1:		begin
				PSYNC <= 0;
				DATA[7:5] <= 0;
				DATA[4:0] <= PID[12:8];
				end
		2:		DATA <= PID[7:0];
		3:		begin
				DATA[7:4] <= 0;
				DATA[3:0] <= continuity_counter;
				end
		default:	DATA <= /*byte_counter*/continuity_counter;
		endcase		
		end	
	end
end

endmodule
