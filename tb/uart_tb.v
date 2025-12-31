`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:05:10 12/30/2025 
// Design Name: 
// Module Name:    uart_tb 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module uart_tb();

localparam [15:0] one_baud_period= 52084; // 1/19200 in ns

reg clk_tb = 1'b0;
reg [7:0] tx_byte_i_tb = 0;
reg transmit_tb = 0;
wire tx_o_tb;
wire tx_err_o_tb;
wire is_transmitting_o_tb;

reg rx_i_tb;
wire is_receiving_tb;
wire recv_err_tb;
wire is_rx_data_valid_tb;
wire [7:0] rx_data_tb;

uart_tx DUT_tx(
	.clk_i(clk_tb),
	.tx_byte_i(tx_byte_i_tb),
	.transmit_i(transmit_tb),
	.tx_o(tx_o_tb),
	.tx_err_o(tx_err_o_tb),
	.is_transmitting_o(is_transmitting_o_tb)
);

uart_rx #(
	.CLK_CYCLES(100_000_000),
	.BAUD_RATE(19200),
	.DATA_WIDTH(8),
	.NUM_SAMPLES(8) // sample 8 times per baud/bit period
)DUT_rx(
	.clk_i(clk_tb),
	.rx_i(tx_o_tb),
	.is_receiving_o(is_receiving_tb),
	.recv_err_o(recv_err_tb),
	.is_rx_data_valid_o(is_rx_data_valid_tb),
	.rx_data_o(rx_data_tb)
);

reg [7:0] data_tb;
reg data_valid;

// generate 100Mhz clk
always begin
	#5;
	clk_tb = ~clk_tb;
end

task automatic send_byte(reg [7:0] data_to_send);
begin
	tx_byte_i_tb = data_to_send;
	transmit_tb = 1;
	#10000;
	transmit_tb = 0;
	#1000;
	wait(is_transmitting_o_tb == 0);
	wait(data_valid == 1);
	
	if (data_to_send == data_tb) begin
		$display("Success: Transmit successful! data_to_send = %h, data_tb = %h", data_to_send, data_tb);
	end else begin
		$display("Failure: Transmit unsuccessful? data_to_send = %h, data_tb = %h", data_to_send, data_tb);
	end
end
endtask

task automatic recv_byte(reg [7:0] test_vector);
begin
	@(posedge is_transmitting_o_tb);
	#20;
	wait(is_receiving_tb == 0);
	if (test_vector == rx_data_tb) begin
		$display("Success: Receive successful! test_vector = %h, rx_data_tb = %h", test_vector, rx_data_tb);
	end else begin
		$display("Failure: Receive unsuccessful? test_vector = %h, rx_data_tb = %h", test_vector, rx_data_tb);
	end
end
endtask

task automatic read_tx_line();
reg [3:0] counter;
reg invalid_frame;
begin
	counter = 0;
	invalid_frame = 0;
	data_tb = 0;
	data_valid = 0;
	// Wait for transmission to start
	@(posedge is_transmitting_o_tb);
	while(is_transmitting_o_tb && (counter < 10)) begin
		if (counter == 0) begin
			// Start bit case

			// Wait to go to the middle of the start bit
			#(one_baud_period/2);
			if (!tx_o_tb) begin
				invalid_frame = 0;
				$display("Start bit found");
			end else begin
				invalid_frame = 1;
				$display("Failed: Start bit not found");
			end
			#(one_baud_period);
		end else if (counter == 9) begin
			// Stop bit case
			if (tx_o_tb) begin
				invalid_frame = 0;
				$display("Stop bit found");
			end else begin
				invalid_frame = 1;
				$display("Failed: Stop bit not found");
			end
		end else begin
			// Data bits
			data_tb = {tx_o_tb, data_tb[7:1]};
			#(one_baud_period);
		end

		counter = counter + 1;
	end

	if (!invalid_frame) begin
		data_valid = 1;
	end else begin
		data_valid = 0;
	end
end
endtask

initial begin
	$display("Begin simulation");
	#100;
	// initialize
	transmit_tb = 0;
	#1000

	// verifed tx first, once tx can toggle tx_o correctly, we hooked it up to rx_i
	
	$display("\n$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n");
	fork
		begin
			read_tx_line();
		end
		
		begin
			send_byte(8'hA7);
		end
		
		begin
			recv_byte(8'hA7);
		end
	join
	
	$display("\n$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n");
	fork
		begin
			read_tx_line();
		end
		
		begin
			send_byte(8'h82);
		end
		
		begin
			recv_byte(8'h82);
		end
	join

	$display("\n$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n");
	fork
		begin
			read_tx_line();
		end
		
		begin
			send_byte(8'h10);
		end
		
		begin
			recv_byte(8'h10);
		end
	join
	
	$display("\n$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n");
	fork
		begin
			read_tx_line();
		end
		
		begin
			send_byte(8'h0F);
		end
		
		begin
			recv_byte(8'h0F);
		end
	join
	#1000;

	$display("End simulation");
	$finish;
end

endmodule
