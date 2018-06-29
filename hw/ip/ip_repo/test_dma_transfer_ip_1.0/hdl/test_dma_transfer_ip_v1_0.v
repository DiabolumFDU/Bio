
`timescale 1 ns / 1 ps

	module test_dma_transfer_ip_v1_0 #
	(
		// Users to add parameters here
        parameter  DMA_BASE_ADDR    = 32'h40000000,
		// User parameters ends
		// Do not modify the parameters beyond this line

		// Parameters of Axi Slave Bus Interface S_AXI
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		parameter integer C_S_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S_AXI
		input wire  s_axi_aclk,
		input wire  s_axi_aresetn,
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
		input wire [2 : 0] s_axi_awprot,
		input wire  s_axi_awvalid,
		output wire  s_axi_awready,
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
		input wire  s_axi_wvalid,
		output wire  s_axi_wready,
		output wire [1 : 0] s_axi_bresp,
		output wire  s_axi_bvalid,
		input wire  s_axi_bready,
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
		input wire [2 : 0] s_axi_arprot,
		input wire  s_axi_arvalid,
		output wire  s_axi_arready,
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
		output wire [1 : 0] s_axi_rresp,
		output wire  s_axi_rvalid,
		input wire  s_axi_rready,
		
		//for M_AXI of dma_transfer
                input wire M_AXI_ACLK,
                input wire M_AXI_ARESETN,
                output wire [31 : 0] M_AXI_AWADDR,
                output wire [2 : 0] M_AXI_AWPROT,
                output wire M_AXI_AWVALID,
                input wire M_AXI_AWREADY,
                output wire [31 : 0] M_AXI_WDATA,
                output wire [3 : 0] M_AXI_WSTRB,
                output wire M_AXI_WVALID,
                input wire M_AXI_WREADY,
                input wire [1 : 0] M_AXI_BRESP,
                input wire M_AXI_BVALID,
                output wire M_AXI_BREADY,
                output wire [31 : 0] M_AXI_ARADDR,
                output wire [2 : 0] M_AXI_ARPROT,
                output wire M_AXI_ARVALID,
                input wire M_AXI_ARREADY,
                input wire [31 : 0] M_AXI_RDATA,
                input wire [1 : 0] M_AXI_RRESP,
                input wire M_AXI_RVALID,
                output wire M_AXI_RREADY
		
	);
// Instantiation of Axi Bus Interface S_AXI
	test_dma_transfer_ip_v1_0_S_AXI # ( 
	    .DMA_BASE_ADDR(DMA_BASE_ADDR),
		.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
	) test_dma_transfer_ip_v1_0_S_AXI_inst (
		.S_AXI_ACLK(s_axi_aclk),
		.S_AXI_ARESETN(s_axi_aresetn),
		.S_AXI_AWADDR(s_axi_awaddr),
		.S_AXI_AWPROT(s_axi_awprot),
		.S_AXI_AWVALID(s_axi_awvalid),
		.S_AXI_AWREADY(s_axi_awready),
		.S_AXI_WDATA(s_axi_wdata),
		.S_AXI_WSTRB(s_axi_wstrb),
		.S_AXI_WVALID(s_axi_wvalid),
		.S_AXI_WREADY(s_axi_wready),
		.S_AXI_BRESP(s_axi_bresp),
		.S_AXI_BVALID(s_axi_bvalid),
		.S_AXI_BREADY(s_axi_bready),
		.S_AXI_ARADDR(s_axi_araddr),
		.S_AXI_ARPROT(s_axi_arprot),
		.S_AXI_ARVALID(s_axi_arvalid),
		.S_AXI_ARREADY(s_axi_arready),
		.S_AXI_RDATA(s_axi_rdata),
		.S_AXI_RRESP(s_axi_rresp),
		.S_AXI_RVALID(s_axi_rvalid),
		.S_AXI_RREADY(s_axi_rready),
		
		.M_AXI_ACLK(M_AXI_ACLK),                  // input wire M_AXI_ACLK
        .M_AXI_ARESETN(M_AXI_ARESETN),            // input wire M_AXI_ARESETN
        .M_AXI_AWADDR(M_AXI_AWADDR),              // output wire [31 : 0] M_AXI_AWADDR
        .M_AXI_AWPROT(M_AXI_AWPROT),              // output wire [2 : 0] M_AXI_AWPROT
        .M_AXI_AWVALID(M_AXI_AWVALID),            // output wire M_AXI_AWVALID
        .M_AXI_AWREADY(M_AXI_AWREADY),            // input wire M_AXI_AWREADY
        .M_AXI_WDATA(M_AXI_WDATA),                // output wire [31 : 0] M_AXI_WDATA
        .M_AXI_WSTRB(M_AXI_WSTRB),                // output wire [3 : 0] M_AXI_WSTRB
        .M_AXI_WVALID(M_AXI_WVALID),              // output wire M_AXI_WVALID
        .M_AXI_WREADY(M_AXI_WREADY),              // input wire M_AXI_WREADY
        .M_AXI_BRESP(M_AXI_BRESP),                // input wire [1 : 0] M_AXI_BRESP
        .M_AXI_BVALID(M_AXI_BVALID),              // input wire M_AXI_BVALID
        .M_AXI_BREADY(M_AXI_BREADY),              // output wire M_AXI_BREADY
        .M_AXI_ARADDR(M_AXI_ARADDR),              // output wire [31 : 0] M_AXI_ARADDR
        .M_AXI_ARPROT(M_AXI_ARPROT),              // output wire [2 : 0] M_AXI_ARPROT
        .M_AXI_ARVALID(M_AXI_ARVALID),            // output wire M_AXI_ARVALID
        .M_AXI_ARREADY(M_AXI_ARREADY),            // input wire M_AXI_ARREADY
        .M_AXI_RDATA(M_AXI_RDATA),                // input wire [31 : 0] M_AXI_RDATA
        .M_AXI_RRESP(M_AXI_RRESP),                // input wire [1 : 0] M_AXI_RRESP
        .M_AXI_RVALID(M_AXI_RVALID),              // input wire M_AXI_RVALID
        .M_AXI_RREADY(M_AXI_RREADY)              // output wire M_AXI_RREADY
	);

	// Add user logic here

	// User logic ends

	endmodule
