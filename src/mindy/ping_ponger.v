//=============================================================================
//                     ------->  Revision History  <------
//=============================================================================
//
//   Date     Who   Ver  Changes
//=============================================================================
// 15-Feb-24  DWW     1  Initial creation
//=============================================================================

/*
    The packetizes an incoming data-stream, and writes groups of packets to the
    output streams in a ping-pong fashion
*/


module ping_ponger
(
    input clk, resetn,

    //================== This is an AXI4-Lite slave interface =================
        
    // "Specify write address"              -- Master --    -- Slave --
    input[31:0]                             S_AXI_AWADDR,   
    input                                   S_AXI_AWVALID,  
    output                                                  S_AXI_AWREADY,
    input[2:0]                              S_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    input[31:0]                             S_AXI_WDATA,      
    input                                   S_AXI_WVALID,
    input[3:0]                              S_AXI_WSTRB,
    output                                                  S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output[1:0]                                             S_AXI_BRESP,
    output                                                  S_AXI_BVALID,
    input                                   S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input[31:0]                             S_AXI_ARADDR,     
    input                                   S_AXI_ARVALID,
    input[2:0]                              S_AXI_ARPROT,     
    output                                                  S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output[31:0]                                            S_AXI_RDATA,
    output                                                  S_AXI_RVALID,
    output[1:0]                                             S_AXI_RRESP,
    input                                   S_AXI_RREADY,
    //=========================================================================


    //=========================================================================
    // Input stream of frame data
    //=========================================================================
    input[511:0]   AXIS_IN_TDATA,
    input          AXIS_IN_TVALID,
    output         AXIS_IN_TREADY,
    //=========================================================================


    //=========================================================================
    // Two output data streams to carry frame data
    //=========================================================================
    output[511:0]   AXIS_OUT0_TDATA,    AXIS_OUT1_TDATA,
    output          AXIS_OUT0_TLAST,    AXIS_OUT1_TLAST,
    output          AXIS_OUT0_TVALID,   AXIS_OUT1_TVALID,
    input           AXIS_OUT0_TREADY,   AXIS_OUT1_TREADY,
    //=========================================================================

    // The outgoing packet size, in bytes
    output reg [15:0] PACKET_SIZE
);  

//=========================  AXI Register Map  ================================
localparam REG_PACKET_SIZE       = 0;
localparam REG_PACKETS_PER_GROUP = 1;
//=============================================================================


//=============================================================================
// We'll communicate with the AXI4-Lite Slave core with these signals.
//=============================================================================
// AXI Slave Handler Interface for write requests
wire[31:0]  ashi_windx;     // Input   Write register-index
wire[31:0]  ashi_waddr;     // Input:  Write-address
wire[31:0]  ashi_wdata;     // Input:  Write-data
wire        ashi_write;     // Input:  1 = Handle a write request
reg[1:0]    ashi_wresp;     // Output: Write-response (OKAY, DECERR, SLVERR)
wire        ashi_widle;     // Output: 1 = Write state machine is idle

// AXI Slave Handler Interface for read requests
wire[31:0]  ashi_rindx;     // Input   Read register-index
wire[31:0]  ashi_raddr;     // Input:  Read-address
wire        ashi_read;      // Input:  1 = Handle a read request
reg[31:0]   ashi_rdata;     // Output: Read data
reg[1:0]    ashi_rresp;     // Output: Read-response (OKAY, DECERR, SLVERR);
wire        ashi_ridle;     // Output: 1 = Read state machine is idle
//=============================================================================

// The state of the state-machines that handle AXI4-Lite read and AXI4-Lite write
reg ashi_write_state, ashi_read_state;

// The AXI4 slave state machines are idle when in state 0 and their "start" signals are low
assign ashi_widle = (ashi_write == 0) && (ashi_write_state == 0);
assign ashi_ridle = (ashi_read  == 0) && (ashi_read_state  == 0);
   
// These are the valid values for ashi_rresp and ashi_wresp
localparam OKAY   = 0;
localparam SLVERR = 2;
localparam DECERR = 3;

// An AXI slave is gauranteed a minimum of 128 bytes of address space
// (128 bytes is 32 32-bit registers)
localparam ADDR_MASK = 7'h7F;

// Packet size (in bytes), and number of packets output before switching outputs
reg[31:0] packets_per_group;

// Number of data-cycles that comprise an outgoing packet
wire[7:0] cycles_per_packet = PACKET_SIZE / 64;

// The current data-cycle number being output.  Runs from 1 to "cycles_per_packet"
reg[7:0] data_cycle_count;

// This is asserted on the last clock cycle of every outgoing packet
wire last_cycle = (data_cycle_count == cycles_per_packet);

// This selects which output stream we're writing to
reg output_select;

// The output TDATA is driven directly from the input stream
assign AXIS_OUT0_TDATA = (output_select == 0) ? AXIS_IN_TDATA : 0;
assign AXIS_OUT1_TDATA = (output_select == 1) ? AXIS_IN_TDATA : 0;

// The output TVALID is driven by the input TVALID, gated by "output_select"
assign AXIS_OUT0_TVALID = AXIS_IN_TVALID & (output_select == 0);
assign AXIS_OUT1_TVALID = AXIS_IN_TVALID & (output_select == 1);

// The output TLAST signals are asserted on the last cycle of every packet
assign AXIS_OUT0_TLAST = last_cycle & AXIS_OUT0_TVALID;
assign AXIS_OUT1_TLAST = last_cycle & AXIS_OUT1_TVALID;

// The TREADY signal on the input stream is driven by one of the output streams
assign AXIS_IN_TREADY = (output_select == 0) ? AXIS_OUT0_TREADY : AXIS_OUT1_TREADY;

// Create some convenient shortcuts to the output TVALID, TLAST, and TREADY
wire axis_out_tvalid = (output_select == 0) ? AXIS_OUT0_TVALID : AXIS_OUT1_TVALID;
wire axis_out_tlast  = (output_select == 0) ? AXIS_OUT0_TLAST  : AXIS_OUT1_TLAST;
wire axis_out_tready = (output_select == 0) ? AXIS_OUT0_TREADY : AXIS_OUT1_TREADY;

//=============================================================================
// This block watches for the handshake on the last data-cycle of outgoing
// packets.  Every "packets_per_group" packets, it switches the "output_select"
// register from 0 to 1 (or vice-versa)
//=============================================================================
reg[15:0] packet_counter;
//-----------------------------------------------------------------------------
always @(posedge clk) begin
    if (resetn == 0) begin
        packet_counter <= 1;
        output_select  <= 0;
    end
    
    else if (axis_out_tvalid & axis_out_tready & axis_out_tlast) begin
        if (packet_counter < packets_per_group)
            packet_counter <= packet_counter + 1;
        else begin
            packet_counter <= 1;
            output_select  <= ~output_select;
        end
    end

end
//=============================================================================


//=============================================================================
// This block counts data-cycles on the output stream to ensure that TLAST
// is asserted on the last data-cycle of every outgoing packet
//=============================================================================
always @(posedge clk) begin

    // If we're in reset, clear the data-cycle count to 1
    if (resetn == 0) begin
        data_cycle_count <= 1;
    
    // Otherwise, we're not in reset, so...
    end else begin

        // If a data-cycle was just transferred from input to output,
        // count the number of data-cycles that have gone out in this
        // packet
        if (axis_out_tvalid & axis_out_tready) begin
            if (data_cycle_count < cycles_per_packet)            
                data_cycle_count <= data_cycle_count + 1;
            else
                data_cycle_count <= 1;
        end
    end
end
//=============================================================================



//=============================================================================
// This state machine handles AXI4-Lite write requests
//
// Drives:
//=============================================================================
always @(posedge clk) begin

    // If we're in reset, initialize important registers
    if (resetn == 0) begin
        ashi_write_state  <= 0;

    // If we're not in reset, and a write-request has occured...        
    end else case (ashi_write_state)
        
        0:  if (ashi_write) begin
       
                // Assume for the moment that the result will be OKAY
                ashi_wresp <= OKAY;              
            
                // Convert the byte address into a register index
                case (ashi_windx)
               
                    REG_PACKET_SIZE:        PACKET_SIZE       <= ashi_wdata;
                    REG_PACKETS_PER_GROUP:  packets_per_group <= ashi_wdata;

                    // Writes to any other register are a decode-error
                    default: ashi_wresp <= DECERR;
                endcase
            end

        // Dummy state, doesn't do anything
        1: ashi_write_state <= 0;

    endcase
end
//=============================================================================





//=============================================================================
// World's simplest state machine for handling AXI4-Lite read requests
//=============================================================================
always @(posedge clk) begin
    // If we're in reset, initialize important registers
    if (resetn == 0) begin
        ashi_read_state <= 0;
    
    // If we're not in reset, and a read-request has occured...        
    end else if (ashi_read) begin
   
        // Assume for the moment that the result will be OKAY
        ashi_rresp <= OKAY;              
        
        // Convert the byte address into a register index
        case (ashi_rindx)
            
            // Allow a read from any valid register                
            REG_PACKET_SIZE:       ashi_rdata <= PACKET_SIZE;
            REG_PACKETS_PER_GROUP: ashi_rdata <= packets_per_group;
            
            // Reads of any other register are a decode-error
            default: ashi_rresp <= DECERR;
        endcase
    end
end
//=============================================================================



//=============================================================================
// This connects us to an AXI4-Lite slave core
//=============================================================================
axi4_lite_slave#(ADDR_MASK) axil_slave
(
    .clk            (clk),
    .resetn         (resetn),
    
    // AXI AW channel
    .AXI_AWADDR     (S_AXI_AWADDR),
    .AXI_AWVALID    (S_AXI_AWVALID),   
    .AXI_AWREADY    (S_AXI_AWREADY),
    
    // AXI W channel
    .AXI_WDATA      (S_AXI_WDATA),
    .AXI_WVALID     (S_AXI_WVALID),
    .AXI_WSTRB      (S_AXI_WSTRB),
    .AXI_WREADY     (S_AXI_WREADY),

    // AXI B channel
    .AXI_BRESP      (S_AXI_BRESP),
    .AXI_BVALID     (S_AXI_BVALID),
    .AXI_BREADY     (S_AXI_BREADY),

    // AXI AR channel
    .AXI_ARADDR     (S_AXI_ARADDR), 
    .AXI_ARVALID    (S_AXI_ARVALID),
    .AXI_ARREADY    (S_AXI_ARREADY),

    // AXI R channel
    .AXI_RDATA      (S_AXI_RDATA),
    .AXI_RVALID     (S_AXI_RVALID),
    .AXI_RRESP      (S_AXI_RRESP),
    .AXI_RREADY     (S_AXI_RREADY),

    // ASHI write-request registers
    .ASHI_WADDR     (ashi_waddr),
    .ASHI_WINDX     (ashi_windx),
    .ASHI_WDATA     (ashi_wdata),
    .ASHI_WRITE     (ashi_write),
    .ASHI_WRESP     (ashi_wresp),
    .ASHI_WIDLE     (ashi_widle),

    // ASHI read registers
    .ASHI_RADDR     (ashi_raddr),
    .ASHI_RINDX     (ashi_rindx),
    .ASHI_RDATA     (ashi_rdata),
    .ASHI_READ      (ashi_read ),
    .ASHI_RRESP     (ashi_rresp),
    .ASHI_RIDLE     (ashi_ridle)
);
//=============================================================================

endmodule
