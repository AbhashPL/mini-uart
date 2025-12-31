`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:03:05 12/07/2025 
// Design Name: 
// Module Name:    uart_rx 
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

/*

Use the middle 50-60 percent of bit period

Sample points:   0 1 2 3 4 5 6 7
Use for voting:        ^ ^ ^ ^ ^
                       2 3 4 5 6   (5 samples)
*/

module uart_rx #
(
	parameter CLK_CYCLES = 100_000_000,
	parameter BAUD_RATE = 19200,
	parameter DATA_WIDTH = 8,
	parameter NUM_SAMPLES = 8 // sample 8 times per baud/bit period
)(
	input wire clk_i,
	input wire rx_i,
	output wire is_receiving_o,
	output wire is_rx_data_valid_o,
	output wire recv_err_o,
	output wire [DATA_WIDTH-1:0] rx_data_o
);

`include "math_utils.vh"

localparam one_baud_cycles = CLK_CYCLES/BAUD_RATE - 1;
localparam one_sample_cycles = one_baud_cycles/NUM_SAMPLES - 1;
localparam [2:0] START_BIT = 3'd0,
					  RECV_DATA_START = 3'd1,
					  RECV_DATA_SAMPLE = 3'd2,
					  RECV_DATA_SAMPLE_FINISH = 3'd3,
					  STOP_BIT = 3'd4,
					  RECV_ERR = 3'd5;

reg [DATA_WIDTH-1:0] rx_data_reg = 0;
reg [(log2(one_baud_cycles)+1):0] rx_timer = 0;
reg [2:0] rx_state = START_BIT;
reg recv_err;
reg [2:0] rx_count_ones; // stores the number of times a 1 was samples in the current baud (bit period)
reg is_receiving_reg = 0;
reg recv_err_reg = 0;
reg rx_data_valid_reg = 0;
// We will use only 5 samples for voting.
reg [2:0] actual_num_samples = 3'd0;
reg [3:0] num_data_bits = 4'd0;

assign recv_err_o = recv_err_reg;
assign is_receiving_o = is_receiving_reg;
assign is_rx_data_valid_o = rx_data_valid_reg;
assign rx_data_o = rx_data_reg;

always @(posedge clk_i) begin
	if (rx_timer) begin
		rx_timer <= rx_timer - 1'd1; 
	end

	case (rx_state)
		START_BIT:
			begin
				num_data_bits <= 4'd8;
				if (!rx_i) begin
					// detected the rx line going low, wait for half the baud
					rx_timer <= one_baud_cycles/2;
					rx_state <= RECV_DATA_START;
					is_receiving_reg <= 1'b1;
				end else begin
					rx_state <= START_BIT;
					is_receiving_reg <= 1'b0;
					rx_data_valid_reg <= 1'b0;
					rx_timer <= 0;
				end
			end
		RECV_DATA_START:
			begin
				if (!rx_timer) begin
					if (!rx_i) begin
						// still in start bit as we are half-baud in. Move into the 3rd sample of 1st data bit
						rx_timer <= one_baud_cycles/2 + 3*one_sample_cycles;
						rx_state <= RECV_DATA_SAMPLE;
						actual_num_samples <= 3'd5;
						rx_count_ones <= 0;
					end else begin
						// the rx_i is not low after half a baud, signal an err
						rx_state <= RECV_ERR;
					end
				end
			end
		RECV_DATA_SAMPLE:
			begin
				if (!rx_timer) begin
					// Now we are going to sample data
					actual_num_samples <= actual_num_samples - 1'd1;
					if (rx_i) begin
						// 1 detected, count the number of ones, this will be used in majority voting.
						rx_count_ones <= rx_count_ones + 1'd1;
					end
					rx_timer <= actual_num_samples ? one_sample_cycles : 1'd0;
					rx_state <= actual_num_samples ? RECV_DATA_SAMPLE : RECV_DATA_SAMPLE_FINISH;
				end
			end
		RECV_DATA_SAMPLE_FINISH:
			begin
				if (!rx_timer) begin
					// TODO: Majority vote and push data into the rx_buffer and get the next bit
					rx_data_reg <= {((rx_count_ones > 2'd3)? 1'd1 : 1'd0), rx_data_reg[7:1]};
					num_data_bits <= num_data_bits - 1'd1;
						
					if (num_data_bits > 1) begin
						rx_state <= RECV_DATA_SAMPLE;
						rx_timer <= one_sample_cycles * 3;
						actual_num_samples <= 3'd5;
						rx_count_ones <= 1'd0;
					end else begin
						// move into the middle of the stop bit
						rx_timer <= one_baud_cycles/2;
						rx_state <= STOP_BIT;
						actual_num_samples <= 3'd0;
						rx_count_ones <= 1'd0;
					end
				end
			end
		STOP_BIT:
			begin
				if (!rx_timer) begin
					// check if the 'stop' bit is still there
					if (rx_i) begin
						rx_state <= START_BIT;
						rx_data_valid_reg <= 1'd1;
					end else begin
						rx_state <= RECV_ERR;
						rx_data_valid_reg <= 1'd0;
					end
				end
			end
		RECV_ERR:
			begin
				is_receiving_reg <= 1'b0;
				recv_err_reg <= 1'b1;
			end
	endcase
end

endmodule
