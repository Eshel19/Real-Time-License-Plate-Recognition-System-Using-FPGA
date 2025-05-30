module pio128_out (
    input  logic         clk,
    input  logic         reset_n,
    input  logic [3:0]   burstcount,     // required, not used
    input  logic [15:0]  byteenable,     // required, not used
    input  logic [1:0]   address,        // required by Avalon
    input  logic         avs_s0_write,
    input  logic [127:0] avs_s0_writedata,
    input  logic         block_read,     // external stall

    output logic         avs_s0_waitrequest,
    output logic [127:0] pio_out,
    output logic         data_ready,

    // response interface (write-only)
    output logic [1:0]   response,
    output logic         writeresponsevalid
);

    reg [127:0] data_out;
    reg         reg_data_ready;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            data_out        <= '0;
            reg_data_ready  <= 0;
        end else begin
            if (avs_s0_write)
                data_out <= avs_s0_writedata;

            reg_data_ready <= avs_s0_write;
        end
    end

    assign pio_out             = data_out;
    assign data_ready          = reg_data_ready;
    assign avs_s0_waitrequest  = block_read;

    // Response signals
    assign writeresponsevalid  = avs_s0_write && !block_read;
    assign response            = 2'b00;

endmodule
