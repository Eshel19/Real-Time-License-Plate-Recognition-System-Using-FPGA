module irq_controller_minimal (
    input  logic clk,
    input  logic reset,

    input  logic event_ready,       // Internal FPGA event trigger
    input  logic clear_irq_from_hps, // HPS write or signal to clear

    output logic irq_to_hps          // Output IRQ to HPS
);

	logic irq_flag;

	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			irq_flag <= 0;
		end else begin
			if (event_ready) begin
				irq_flag <= 1; // Raise interrupt
			end else if (clear_irq_from_hps) begin
				irq_flag <= 0; // Clear interrupt
			end
		end
	end

	assign irq_to_hps = irq_flag;


endmodule
