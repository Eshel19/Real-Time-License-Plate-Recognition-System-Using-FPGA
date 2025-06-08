`timescale 1ns / 1ps

import ocr_bridge_config_pkg::*;

module tb_TX_UNIT;

    // Clock and Reset
    logic clk_in = 0;
    logic rst_n = 0;
    logic reset;

    // Testbench signals
    logic Clear_buff;
    logic tx_en;
    logic read;
    logic [PIO_DATA_WIDTH-1:0] filo_q;
    logic [TX_WD_DEPTH-1:0] watchdog_tx_conf;
    logic [UINT8_WIDTH-1:0] headcount;
    logic [PIO_DATA_WIDTH-1:0] data_in;
    logic filo_wren;
    logic tx_done;

    // PIO signals
    logic block_read;
    logic avs_s0_read;
    logic waitrequest;
    logic [PIO_DATA_WIDTH-1:0] avs_s0_readdata;
    logic read_request;

    // TX outputs
    logic waitrequest_in;
    logic watchdog_tx_trigger;
    logic pop;
    logic [PIO_DATA_WIDTH-1:0] PIO_IN;

    // Clock generation
    always #5 clk_in = ~clk_in; // 100 MHz clock

    // Instantiate Result_FILO
    Result_FILO filo_inst (
        .data_in(data_in),
        .Clear_buff(Clear_buff),
        .clk_in(clk_in),
        .rst_n(rst_n),
        .pop(pop),
        .push(filo_wren),
        .Result_FILO_error(),
        .filo_q(filo_q)
    );

    // Instantiate TX_UNIT
    TX_UNIT dut (
        .Clear_buff(Clear_buff),
        .clk_in(clk_in),
        .rst_n(rst_n),
        .tx_en(tx_en),
        .read(avs_s0_read),
        .filo_q(filo_q),
        .watchdog_tx_conf(watchdog_tx_conf),
        .headcount(headcount),
        .waitrequest_in(waitrequest_in),
        .watchdog_tx_trigger(watchdog_tx_trigger),
        .pop(pop),
        .PIO_IN(PIO_IN),
        .tx_done(tx_done)
    );

    // Instantiate PIO128 input simulation block
    pio128_in pio_sim (
        .clk(clk_in),
        .reset(reset),
        .block_read(waitrequest_in),
        .avs_s0_read(avs_s0_read),
        .waitrequest(waitrequest),
        .avs_s0_readdata(avs_s0_readdata),
        .read_request(read_request),
        .pio_in(PIO_IN)
    );

    // Push data task
    task push_to_filo(input int count);
        begin
            for (int i = 0; i < count; i++) begin
                data_in = {120'hDEADBEEFDEADBEEFDEAD, i[7:0]};
                filo_wren = 1;
                @(posedge clk_in);
                filo_wren = 0;
                @(posedge clk_in);
            end
        end
    endtask

    initial begin
        // Initial states
        clk_in = 0;
        rst_n = 0;
        reset = 0;
        Clear_buff = 0;
        tx_en = 0;
        read = 0;
        headcount = 8'd20;
        watchdog_tx_conf = 8'd20;
        filo_wren = 0;
        data_in = '0;
        block_read = 0;
        avs_s0_read = 0;

        // Apply reset
        #20;
        rst_n = 1;
        reset = 1;
        #10;

        // Preload FILO
        push_to_filo(8);
			push_to_filo(8);
			push_to_filo(8);
        // Start TX
        @(posedge clk_in);
        tx_en = 1;
        repeat (8) @(posedge clk_in);

        // Simulate read bursts
//        repeat (2) begin
//            avs_s0_read = 1;
//            read = 1;
//            @(posedge clk_in);
//            avs_s0_read = 0;
//            read = 0;
//            @(posedge clk_in);
//        end
			avs_s0_read = 1;
			repeat (2) @(posedge clk_in);
			avs_s0_read = 0;
			@(posedge clk_in);
		   repeat (2) @(posedge clk_in);
			avs_s0_read = 1;
			repeat (11)@(posedge clk_in);
			avs_s0_read = 0;
			repeat (2) @(posedge clk_in);
			avs_s0_read = 0;
			@(posedge clk_in);
		   repeat (2) @(posedge clk_in);
			avs_s0_read = 1;
			repeat (11)@(posedge clk_in);
			avs_s0_read = 0;
			repeat (2) @(posedge clk_in);
			avs_s0_read = 0;
			@(posedge clk_in);
		   repeat (2) @(posedge clk_in);
			avs_s0_read = 1;
			repeat (11)@(posedge clk_in);
			avs_s0_read = 0;

			@(posedge clk_in);
        #50;
        $display("Simulation complete. Final PIO_IN = %h", PIO_IN);
    end

	 task automatic do_avalon_burst(input int burst_length);
    int burst_count = 0;
    avs_s0_read = 1;

    while (burst_count < burst_length) begin
        @(posedge clk_in);
        if (!waitrequest) begin
            burst_count++;
        end
    end

    avs_s0_read = 0;
endtask

	 
endmodule
