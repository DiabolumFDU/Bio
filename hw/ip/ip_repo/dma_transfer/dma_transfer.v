
`timescale 1 ns / 1 ps

	module dma_transfer #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// The master requires a target slave base address.
    // The master will initiate read and write transactions on the slave with base address specified here as a parameter.
		parameter  DMA_BASE_ADDR	= 32'h40000000,
		// Width of M_AXI address bus. 
    // The master generates the read and write addresses of width specified as ADDR_WIDTH.
		parameter integer ADDR_WIDTH	= 32,
		// Width of M_AXI data bus. 
    // The master issues write data and accept read data where the width of the data bus is DATA_WIDTH
		parameter integer DATA_WIDTH	= 32
	)
	(
		// Users to add ports here
		input wire isRX,
		input wire [ADDR_WIDTH-1 : 0] ADDR_TO_TRANSFER,
		input wire [22 : 0] LENGTH_TO_TRANSFER,
		output wire ACK,
		output wire [2:0] DEBUG_STATE,
		// User ports ends
		// Do not modify the ports beyond this line

		// Initiate AXI transactions
		input wire  START_TRANSFER,
		// Asserts when ERROR is detected
		output wire  ERROR,
		// Asserts when AXI transactions is complete
		output wire  DONE_TRANSFER,
		// AXI clock signal
		input wire  M_AXI_ACLK,
		// AXI active low reset signal
		input wire  M_AXI_ARESETN,
		// Master Interface Write Address Channel ports. Write address (issued by master)
		output wire [ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		// Write channel Protection type.
    // This signal indicates the privilege and security level of the transaction,
    // and whether the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_AWPROT,
		// Write address valid. 
    // This signal indicates that the master signaling valid write address and control information.
		output wire  M_AXI_AWVALID,
		// Write address ready. 
    // This signal indicates that the slave is ready to accept an address and associated control signals.
		input wire  M_AXI_AWREADY,
		// Master Interface Write Data Channel ports. Write data (issued by master)
		output wire [DATA_WIDTH-1 : 0] M_AXI_WDATA,
		// Write strobes. 
    // This signal indicates which byte lanes hold valid data.
    // There is one write strobe bit for each eight bits of the write data bus.
		output wire [DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		// Write valid. This signal indicates that valid write data and strobes are available.
		output wire  M_AXI_WVALID,
		// Write ready. This signal indicates that the slave can accept the write data.
		input wire  M_AXI_WREADY,
		// Master Interface Write Response Channel ports. 
    // This signal indicates the status of the write transaction.
		input wire [1 : 0] M_AXI_BRESP,
		// Write response valid. 
    // This signal indicates that the channel is signaling a valid write response
		input wire  M_AXI_BVALID,
		// Response ready. This signal indicates that the master can accept a write response.
		output wire  M_AXI_BREADY,
		// Master Interface Read Address Channel ports. Read address (issued by master)
		output wire [ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		// Protection type. 
    // This signal indicates the privilege and security level of the transaction, 
    // and whether the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_ARPROT,
		// Read address valid. 
    // This signal indicates that the channel is signaling valid read address and control information.
		output wire  M_AXI_ARVALID,
		// Read address ready. 
    // This signal indicates that the slave is ready to accept an address and associated control signals.
		input wire  M_AXI_ARREADY,
		// Master Interface Read Data Channel ports. Read data (issued by slave)
		input wire [DATA_WIDTH-1 : 0] M_AXI_RDATA,
		// Read response. This signal indicates the status of the read transfer.
		input wire [1 : 0] M_AXI_RRESP,
		// Read valid. This signal indicates that the channel is signaling the required read data.
		input wire  M_AXI_RVALID,
		// Read ready. This signal indicates that the master can accept the read data and response information.
		output wire  M_AXI_RREADY
	);

	parameter [2:0] IDLE = 3'b000, 
			READ_SR = 3'b001, 
			WRITE_ADDR = 3'b011, 
			READ_CR = 3'b010, 
			WRITE_START = 3'b110, 
			WRITE_LENGTH = 3'b111, 
			WAIT = 3'b101,
			DONE = 3'b100; 

	reg [2:0] current_state, next_state;

	parameter [31 : 0] DMA_REG_CR_OFFSET = 'h00;
	parameter [31 : 0] DMA_REG_SR_OFFSET = 'h04;
	parameter [31 : 0] DMA_REG_SRCADDR_OFFSET = 'h18;
	parameter [31 : 0] DMA_REG_LENGTH_OFFSET = 'h28;
	parameter [31 : 0] DMA_REG_OFFSET_FOR_RX = 'h30;
			

	// AXI4LITE signals
	//write address valid
	reg  	axi_awvalid;
	//write data valid
	reg  	axi_wvalid;
	//read address valid
	reg  	axi_arvalid;
	//read data acceptance
	reg  	axi_rready;
	//write response acceptance
	reg  	axi_bready;
	//write address
	reg [ADDR_WIDTH-1 : 0] 	axi_awaddr;
	//write data
	reg [DATA_WIDTH-1 : 0] 	axi_wdata;
	//read addresss
	reg [ADDR_WIDTH-1 : 0] 	axi_araddr;
	//Asserts when there is a write response error
	wire  	write_resp_error;
	//Asserts when there is a read response error
	wire  	read_resp_error;

	reg  	start_ff;
	reg  	start_ff2;
	wire  	start_pulse;

	//ymc: flags for FSM
	reg	   DMAisIDLE;
	reg  	read_done;
	reg  	write_done;
	

	reg    read_issued;
	reg 	write_issued;


	reg  	start_single_write;
	reg  	start_single_read;
	reg  	transfer_done;
	reg  	error_reg;

	reg 	[31 : 0]	dma_reg_read_data;



	// I/O Connections assignments

	//Adding the offset address to the base addr of the slave
	assign M_AXI_AWADDR	= DMA_BASE_ADDR + axi_awaddr + (isRX? DMA_REG_OFFSET_FOR_RX : 0);
	//AXI 4 write data
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_AWPROT	= 3'b000;
	assign M_AXI_AWVALID	= axi_awvalid;
	//Write Data(W)
	assign M_AXI_WVALID	= axi_wvalid;
	//Set all byte strobes in this example
	assign M_AXI_WSTRB	= 4'b1111;
	//Write Response (B)
	assign M_AXI_BREADY	= axi_bready;
	//Read Address (AR)
	assign M_AXI_ARADDR	= DMA_BASE_ADDR + axi_araddr + (isRX? DMA_REG_OFFSET_FOR_RX : 0);
	assign M_AXI_ARVALID	= axi_arvalid;
	assign M_AXI_ARPROT	= 3'b001;
	//Read and Read Response (R)
	assign M_AXI_RREADY	= axi_rready;
	//Example design I/O
	assign DONE_TRANSFER	= transfer_done;
	assign start_pulse	= (!start_ff2) && start_ff;
	assign ERROR		= error_reg;
	assign DEBUG_STATE = next_state;
	assign ACK = (next_state == WAIT);


	//Generate a pulse to initiate AXI transaction.
	always @(posedge M_AXI_ACLK)						      
	  begin                                                                        
	    // Initiates AXI transaction delay    
	    if (M_AXI_ARESETN == 0 )                                                   
	      begin                                                                    
	        start_ff <= 1'b0;                                                   
	        start_ff2 <= 1'b0;                                                   
	      end                                                                               
	    else                                                                       
	      begin  
	        start_ff <= START_TRANSFER;
	        start_ff2 <= start_ff;                                                                 
	      end                                                                      
	  end     


	//--------------------
	//Write Address Channel
	//--------------------

	// The purpose of the write address channel is to request the address and 
	// command information for the entire transaction.  It is a single beat
	// of information.

	// Note for this example the axi_awvalid/axi_wvalid are asserted at the same
	// time, and then each is deasserted independent from each other.
	// This is a lower-performance, but simplier control scheme.

	// AXI VALID signals must be held active until accepted by the partner.

	// A data transfer is accepted by the slave when a master has
	// VALID data and the slave acknoledges it is also READY. While the master
	// is allowed to generated multiple, back-to-back requests by not 
	// deasserting VALID, this design will add rest cycle for
	// simplicity.

	// Since only one outstanding transaction is issued by the user design,
	// there will not be a collision between a new request and an accepted
	// request on the same clock cycle. 

	  always @(posedge M_AXI_ACLK)										      
	  begin                                                                        
	    //Only VALID signals must be deasserted during reset per AXI spec          
	    //Consider inverting then registering active-low reset for higher fmax     
	    if (M_AXI_ARESETN == 0 || start_pulse == 1'b1)                                                   
	      begin                                                                    
	        axi_awvalid <= 1'b0;                                                   
	      end                                                                      
	      //Signal a new address/data command is available by user logic           
	    else                                                                       
	      begin                                                                    
	        if (start_single_write)                                                
	          begin                                                                
	            axi_awvalid <= 1'b1;                                               
	          end                                                                  
	     //Address accepted by interconnect/slave (issue of M_AXI_AWREADY by slave)
	        else if (M_AXI_AWREADY && axi_awvalid)                                 
	          begin                                                                
	            axi_awvalid <= 1'b0;                                               
	          end                                                                  
	      end                                                                      
	  end                                                                          
	                                                                               
	                                                                               


	//--------------------
	//Write Data Channel
	//--------------------

	//The write data channel is for transfering the actual data.
	//The data generation is speific to the example design, and 
	//so only the WVALID/WREADY handshake is shown here

	   always @(posedge M_AXI_ACLK)                                        
	   begin                                                                         
	     if (M_AXI_ARESETN == 0  || start_pulse == 1'b1)                                               
	       begin                                                                     
	         axi_wvalid <= 1'b0;                                                     
	       end                                                                       
	     //Signal a new address/data command is available by user logic              
	     else if (start_single_write)                                                
	       begin                                                                     
	         axi_wvalid <= 1'b1;                                                     
	       end                                                                       
	     //Data accepted by interconnect/slave (issue of M_AXI_WREADY by slave)      
	     else if (M_AXI_WREADY && axi_wvalid)                                        
	       begin                                                                     
	        axi_wvalid <= 1'b0;                                                      
	       end                                                                       
	   end                                                                           


	//----------------------------
	//Write Response (B) Channel
	//----------------------------

	//The write response channel provides feedback that the write has committed
	//to memory. BREADY will occur after both the data and the write address
	//has arrived and been accepted by the slave, and can guarantee that no
	//other accesses launched afterwards will be able to be reordered before it.

	//The BRESP bit [1] is used indicate any errors from the interconnect or
	//slave for the entire write burst. This example will capture the error.

	//While not necessary per spec, it is advisable to reset READY signals in
	//case of differing reset latencies between master/slave.

	  always @(posedge M_AXI_ACLK)                                    
	  begin                                                                
	    if (M_AXI_ARESETN == 0 || start_pulse == 1'b1)                                           
	      begin                                                            
	        axi_bready <= 1'b0;                                            
	      end                                                              
	    // accept/acknowledge bresp with axi_bready by the master          
	    // when M_AXI_BVALID is asserted by slave                          
	    else if (M_AXI_BVALID && ~axi_bready)                              
	      begin                                                            
	        axi_bready <= 1'b1;                                            
	      end                                                              
	    // deassert after one clock cycle                                  
	    else if (axi_bready)                                               
	      begin                                                            
	        axi_bready <= 1'b0;                                            
	      end                                                              
	    // retain the previous value                                       
	    else                                                               
	      axi_bready <= axi_bready;                                        
	  end                                                                  
	                                                                       
	//Flag write errors                                                    
	assign write_resp_error = (axi_bready & M_AXI_BVALID & M_AXI_BRESP[1]);


	//----------------------------
	//Read Address Channel
	//----------------------------
	                                                                                   
	  // A new axi_arvalid is asserted when there is a valid read address              
	  // available by the master. start_single_read triggers a new read                
	  // transaction                                                                   
	  always @(posedge M_AXI_ACLK)                                                     
	  begin                                                                            
	    if (M_AXI_ARESETN == 0 || start_pulse == 1'b1)                                                       
	      begin                                                                        
	        axi_arvalid <= 1'b0;                                                       
	      end                                                                          
	    //Signal a new read address command is available by user logic                 
	    else if (start_single_read)                                                    
	      begin                                                                        
	        axi_arvalid <= 1'b1;                                                       
	      end                                                                          
	    //RAddress accepted by interconnect/slave (issue of M_AXI_ARREADY by slave)    
	    else if (M_AXI_ARREADY && axi_arvalid)                                         
	      begin                                                                        
	        axi_arvalid <= 1'b0;                                                       
	      end                                                                          
	    // retain the previous value                                                   
	  end                                                                              


	//--------------------------------
	//Read Data (and Response) Channel
	//--------------------------------

	//The Read Data channel returns the results of the read request 
	//The master will accept the read data by asserting axi_rready
	//when there is a valid read data available.
	//While not necessary per spec, it is advisable to reset READY signals in
	//case of differing reset latencies between master/slave.

	  always @(posedge M_AXI_ACLK)                                    
	  begin                                                                 
	    if (M_AXI_ARESETN == 0 || start_pulse == 1'b1)                                            
	      begin                                                             
	        axi_rready <= 1'b0;                                             
	      end                                                               
	    // accept/acknowledge rdata/rresp with axi_rready by the master     
	    // when M_AXI_RVALID is asserted by slave                           
	    else if (M_AXI_RVALID && ~axi_rready)                               
	      begin                                                             
	        axi_rready <= 1'b1;                                             
	      end                                                               
	    // deassert after one clock cycle                                   
	    else if (axi_rready)                                                
	      begin                                                             
	        axi_rready <= 1'b0;                                             
	      end                                                               
	    // retain the previous value                                        
	  end                                                                   
	                                                                        
	//Flag write errors                                                     
	assign read_resp_error = (axi_rready & M_AXI_RVALID & M_AXI_RRESP[1]);  


	//--------------------------------
	//User Logic
	//--------------------------------
	
	//state transfer
	always @ ( posedge M_AXI_ACLK)                                                    
	begin
		if(M_AXI_ARESETN == 0)
			current_state <= IDLE;
		else
			current_state <= next_state;
	end
	                                                                
	//state transfer rules
	always @ (M_AXI_ARESETN, current_state, start_pulse, DMAisIDLE, read_done, write_done, transfer_done, LENGTH_TO_TRANSFER)
	begin                                                                             
		if (M_AXI_ARESETN == 1'b0)                                                     
			next_state = IDLE;
		else                                                                            
		begin                                                                         
			case (current_state)                                                       
				IDLE:       
				begin					
					if ( start_pulse == 1'b1 )     
					begin
					   if( LENGTH_TO_TRANSFER == 0)
					       next_state = DONE;
					   else                   
						   next_state = READ_SR;
				    end
					else
						next_state = IDLE;
				end

				READ_SR:
				begin
					if ( DMAisIDLE )
						next_state = WRITE_ADDR;
					else
						next_state = READ_SR;
				end

				WRITE_ADDR:
				begin
					if ( write_done )
						next_state = READ_CR;
					else
						next_state = WRITE_ADDR;
				end

				READ_CR:
				begin
					if ( read_done )
						next_state = WRITE_START;
					else
						next_state = READ_CR;
				end

				WRITE_START:
				begin
					if ( write_done )
						next_state = WRITE_LENGTH;
					else
						next_state = WRITE_START;
				end

				WRITE_LENGTH:
				begin
					if ( write_done )
						next_state = WAIT;
					else
						next_state = WRITE_LENGTH;
				end

				WAIT:
				begin
					if ( transfer_done )
						next_state = DONE;
					else
						next_state = WAIT;
				end

				DONE:
				begin
						next_state = IDLE;
				end

				default:
				begin
					next_state = IDLE;
				end
			endcase
		end
	end


	//state output
	always @ (posedge M_AXI_ACLK)
	begin
		if (M_AXI_ARESETN == 1'b0)                                                     
		begin
			start_single_read <= 0;
			start_single_write <= 0;
			axi_awaddr <= 0;
			axi_araddr <= 0;
			axi_wdata <= 0;
			error_reg <= 0;
			write_issued <= 0;
			read_issued <= 0;
		end
		else                                                                            
		begin                                                                         
			case (current_state)
				IDLE:
				begin
					start_single_read <= 0;
					start_single_write <= 0;
					axi_awaddr <= 0;
					axi_araddr <= 0;
					axi_wdata <= 0;
				end

				READ_SR:
				begin
					if (~axi_arvalid && ~M_AXI_RVALID && ~start_single_read && ~read_issued && ~DMAisIDLE)
					begin
						start_single_read <= 1;
						read_issued <= 1;
						axi_araddr <= DMA_REG_SR_OFFSET;
					end
					else if (axi_rready)
					begin
						read_issued <= 0;
					end
					else 
					begin
						start_single_read <= 0;
					end
				end

				WRITE_ADDR:
				begin
					if (~axi_awvalid && ~axi_wvalid && ~M_AXI_BVALID && ~start_single_write && ~write_issued && ~error_reg && (next_state == current_state))
					begin
						start_single_write <= 1;
						write_issued <= 1;
						axi_awaddr <= DMA_REG_SRCADDR_OFFSET;
						axi_wdata <= ADDR_TO_TRANSFER;
					end
					else if (axi_bready)
					begin
						write_issued <= 0;
						error_reg <= write_resp_error;
					end
					else
					begin
						start_single_write <= 0;
					end
				end

				READ_CR:
				begin
					if (~axi_arvalid && ~M_AXI_RVALID && ~start_single_read && ~read_issued && ~error_reg && (next_state == current_state))
					begin
						start_single_read <= 1;
						read_issued <= 1;
						axi_araddr <= DMA_REG_CR_OFFSET;
					end
					else if (axi_rready)
					begin
						read_issued <= 0;
						dma_reg_read_data <= M_AXI_RDATA;
						error_reg <= read_resp_error;

					end
					else 
					begin
						start_single_read <= 0;
					end
				end

				WRITE_START:
				begin
					if (~axi_awvalid && ~axi_wvalid && ~M_AXI_BVALID && ~start_single_write && ~write_issued && ~error_reg && (next_state == current_state))
					begin
						start_single_write <= 1;
						write_issued <= 1;
						axi_awaddr <= DMA_REG_CR_OFFSET;
						axi_wdata <= (dma_reg_read_data | 'h1);
					end
					else if (axi_bready)
					begin
						write_issued <= 0;
						error_reg <= write_resp_error;
					end
					else
					begin
						start_single_write <= 0;
					end
				end

				WRITE_LENGTH:
				begin
					if (~axi_awvalid && ~axi_wvalid && ~M_AXI_BVALID && ~start_single_write && ~write_issued && ~error_reg && (next_state == current_state))
					begin
						start_single_write <= 1;
						write_issued <= 1;
						axi_awaddr <= DMA_REG_LENGTH_OFFSET;
						axi_wdata <= LENGTH_TO_TRANSFER;
					end
					else if (axi_bready)
					begin
						write_issued <= 0;
						error_reg <= write_resp_error;
					end
					else
					begin
						start_single_write <= 0;
					end
				end

				WAIT:
				begin
					if (~axi_arvalid && ~M_AXI_RVALID && ~start_single_read && ~read_issued && ~transfer_done)
					begin
						start_single_read <= 1;
						read_issued <= 1;
						axi_araddr <= DMA_REG_SR_OFFSET;
					end
					else if (axi_rready)
					begin
						read_issued <= 0;
					end
					else 
					begin
						start_single_read <= 0;
					end
				end

				DONE:
				begin
				end
			endcase
		end
	end
				

	always @ (posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0 )                                            
        begin
            DMAisIDLE <= 0;
        end
        else if ( (current_state == READ_SR) && axi_rready && M_AXI_RVALID && ((M_AXI_RDATA[1] == 1) || (M_AXI_RDATA[0] == 1))) 
            DMAisIDLE <= 1;
        else
            DMAisIDLE <= 0;
    end



	always @ (posedge M_AXI_ACLK)
	begin
		if (M_AXI_ARESETN == 0 )                                            
		begin
			write_done <= 0;
		end
		else if (axi_bready & M_AXI_BVALID) 
			write_done <= 1;
		else
			write_done <= 0;
	end
			
	always @ (posedge M_AXI_ACLK)
	begin
		if (M_AXI_ARESETN == 0 )                                            
		begin
			read_done <= 0;
		end
		else if (axi_rready & M_AXI_RVALID) 
			read_done <= 1;
		else
			read_done <= 0;
	end
			
	always @ (posedge M_AXI_ACLK)
	begin
		if (M_AXI_ARESETN == 0 )                                            
		begin
			transfer_done <= 0;
		end
		else if  ((current_state == WAIT) && axi_rready && M_AXI_RVALID && (M_AXI_RDATA[1] == 1) )
			transfer_done <= 1;
	    else if (current_state == DONE)
	        transfer_done <= 1;
		else if (current_state == READ_SR)
			transfer_done <= 0;
		else
			transfer_done <= transfer_done;
	end
			
			
		


	endmodule
