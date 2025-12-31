`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:03:23 12/05/2025 
// Design Name: 
// Module Name:    uart_top 
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

module uart_top(
	input CLK_100MHz,
	input RX,
	output TX
	
);

localparam twenty_ns = 1;

reg transmit = 1'b0;
reg [2:0] local_timer = 1'd0;
reg [7:0] tx_data = 8'd109; // the letter 'm'

wire recv_err;
wire tx_err;
wire is_receiving;
wire is_transmitting;
wire is_rx_data_valid;
wire [7:0] rx_data;

uart_tx my_uart_tx(
	.clk_i(CLK_100MHz),
	.tx_byte_i(tx_data),
	.transmit_i(transmit),
	.tx_o(TX),
	.tx_err_o(tx_err),
	.is_transmitting_o(is_transmitting)
);

uart_rx #(
	.CLK_CYCLES(100_000_000),
	.BAUD_RATE(19200),
	.DATA_WIDTH(8),
	.NUM_SAMPLES(8) // sample 8 times per baud/bit period
) my_uart_rx(
	.clk_i(CLK_100MHz),
	.rx_i(RX),
	.is_receiving_o(is_receiving),
	.recv_err_o(recv_err_tb),
	.is_rx_data_valid_o(is_rx_data_valid),
	.rx_data_o(rx_data)
);

always @(posedge CLK_100MHz) begin
	// If timer is loaded, start downcounting
	if (local_timer) begin
		local_timer <= local_timer - 1'b1;
	end

	// If 'data' is valid and Transmitter is ready
	if (is_rx_data_valid && !is_transmitting) begin
		tx_data <= rx_data;
		transmit <= 1'b1; // assert transmit
		local_timer <= twenty_ns;
	end else begin
		// deassert transmit after some time
		// 20 ns
		if (!local_timer) begin
			transmit <= 1'b0;
			local_timer <= 1'd0;
		end
	end

end

endmodule
