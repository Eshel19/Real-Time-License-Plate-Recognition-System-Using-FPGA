

package ocr_rx_pkg;
import ahim_config_pkg::*;
	//Unpack the OCR output and add \0
	function automatic void unpack_ocr_output_vector(
		input  logic [MAX_OUT_L*CHAR_WIDTH-1:0] packed_input,
		output char_t char_array [MAX_OUT_L:0]
	);
		for (int i = 1; i <MAX_OUT_L+1; i++) begin
			char_array[i] = packed_input[(i-1)*CHAR_WIDTH +: CHAR_WIDTH];
		end
		char_array[0]=NULL_CHAR;
	endfunction

	
	//Pack to FILO logic
	function automatic logic [PIO_DATA_WIDTH-1:0] pack_char_vector(
		input  char_t char_array [(PIO_DATA_WIDTH/CHAR_WIDTH)-1:0]
	);
		logic [PIO_DATA_WIDTH-1:0] packed_output;
		for (int i=PIO_DATA_WIDTH/CHAR_WIDTH-1 ; i>=0;i--) begin
			packed_output[PIO_DATA_WIDTH - (i+1)*CHAR_WIDTH +: CHAR_WIDTH] = char_array[i];
		end
		return packed_output;
	endfunction 
  

endpackage 