package ocr_bridge_config_pkg;


	// Interface & protocol config
	parameter int PIO_DATA_WIDTH    = 128;
	parameter int MAX_OUT_L     = 10;
	parameter int BURST_SIZE_WIDTH =8;
	parameter int BURST_SIZE =8;
	parameter int UINT8_WIDTH =8;
	parameter int RESULT_COUNT_WIDTH   = UINT8_WIDTH;
	parameter int WD_DEAPH_PAYLOAD = 4;
	parameter int RX_WD_SHIFT =8;
	parameter int TX_WD_SHIFT =8;
	
	
	//RAM CONFIG
	parameter int BREAKPOINT_RAM_DEPTH = 32;
	parameter int IMAGE_RAM_DEPTH = 1000000/PIO_DATA_WIDTH;
	parameter int RESULT_RAM_DEPTH = 32;
	
	
	//DEFINE 
	parameter int BREAKPOINT_RAM_WIDTH = $clog2(BREAKPOINT_RAM_DEPTH);
	parameter int IMAGE_RAM_WIDTH = $clog2(IMAGE_RAM_DEPTH);
	parameter int RESULT_RAM_WIDTH = $clog2(RESULT_RAM_DEPTH);
	parameter int CHAR_WIDTH        = 8;
	parameter int RX_WD_DEPTH =WD_DEAPH_PAYLOAD+RX_WD_SHIFT;
	parameter int TX_WD_DEPTH =WD_DEAPH_PAYLOAD+TX_WD_SHIFT;
	parameter logic unsigned [UINT8_WIDTH-1:0] NULL_CHAR = 8'h00;

	// Derived types
	typedef logic [CHAR_WIDTH-1:0]       char_t;
	typedef logic [PIO_DATA_WIDTH-1:0]   pio_word;
	typedef logic [RESULT_COUNT_WIDTH-1:0]  result_id_t;

	//functions
	


	
endpackage
