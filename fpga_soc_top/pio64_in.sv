module pio64_in (
  input logic clk,
  input logic reset,

  input logic avs_s0_read,
  output logic [63:0] avs_s0_readdata,

  input logic [63:0] pio_in
);

always_comb begin
  if (avs_s0_read) begin
    avs_s0_readdata = pio_in;
  end else begin
    avs_s0_readdata = 'x;
  end
end

endmodule