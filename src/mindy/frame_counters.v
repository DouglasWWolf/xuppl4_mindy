//=============================================================================
//                   ------->  Revision History  <------
//=============================================================================
//
//   Date     Who   Ver  Changes
//=============================================================================
// 16-Dec-23  DWW     1  Initial creation
//============================================================================

/*
    Every time someone writes a non-zero value to one of the frame counters,
    this module will write a command (either 0 or 1) to the command-FIFO.

    If a zero value is written to a frame counter, both frame counters are set
    to zero, and a reset is asserted to the rest of the module
*/

module frame_counters
(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET resetn:external_resetn" *)
    input   clk,
    input   resetn,
    
    // This resets modules external to this one
    output  external_resetn,

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
    //  The output stream - An entry gets written to this stream every time
    //  one of the frame counters gets updated with a non-zero value
    //=========================================================================
    output [7:0] AXIS_CMD_TDATA,
    output       AXIS_CMD_TVALID,
    input        AXIS_CMD_TREADY
    //=========================================================================    
);  

// Any time the register map of this module changes, this number should
// be bumped
localparam MODULE_VERSION = 1;

//=========================  AXI Register Map  =============================
localparam REG_MODULE_REV       = 0;
localparam REG_FRAME_CTR_0      = 1;
localparam REG_FRAME_CTR_1      = 2;
//==========================================================================


//==========================================================================
// We'll communicate with the AXI4-Lite Slave core with these signals.
//==========================================================================
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
//==========================================================================

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

// This is the AXI stream that feeds an AXI Stream FIFO
reg[7:0] axis_cmd_tdata;
reg      axis_cmd_tvalid;
wire     axis_cmd_tready;

// Thse are frame counters, one for each phase
reg[31:0] frame_counter[0:1];

// External resetn is asserted when this is non-zero
reg[7:0] reset_counter;

// External resetn is asserted under these circucumstances
assign external_resetn = ~((resetn == 0) | (reset_counter != 0));

//==========================================================================
// This state machine handles AXI4-Lite write requests
//
// Drives: frame_counter[0] and frame_counter[1]
//         resetn_counter (and therefore external_resetn)
//         axis_cmd_tdata
//         axis_cmd_tvalid
//==========================================================================
always @(posedge clk) begin

    // This strobe high for a single cycle at a time
    axis_cmd_tvalid <= 0;

    // This controls "external_resetn"
    if (reset_counter) reset_counter <= reset_counter - 1;

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
               
                    REG_FRAME_CTR_0:
                        if (ashi_wdata == 0) begin
                            frame_counter[0] <= 0;
                            frame_counter[1] <= 0;
                            reset_counter    <= 16;
                            ashi_write_state <= 1;
                        end else if (ashi_wdata != frame_counter[0]) begin
                            frame_counter[0] <= ashi_wdata;
                            axis_cmd_tdata   <= 0;
                            axis_cmd_tvalid  <= 1;
                        end      

                    REG_FRAME_CTR_1:
                        if (ashi_wdata == 0) begin
                            frame_counter[0] <= 0;
                            frame_counter[1] <= 0;
                            reset_counter    <= 16;
                            ashi_write_state <= 1;
                        end else if (ashi_wdata != frame_counter[1]) begin
                            frame_counter[1] <= ashi_wdata;
                            axis_cmd_tdata   <= 1;
                            axis_cmd_tvalid  <= 1;
                        end      

                    // Writes to any other register are a decode-error
                    default: ashi_wresp <= DECERR;
                endcase
            end

        // When external reset is complete, return to idle
        1: if (external_resetn == 1) ashi_write_state <= 0;

    endcase
end
//==========================================================================





//==========================================================================
// World's simplest state machine for handling AXI4-Lite read requests
//==========================================================================
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
            REG_MODULE_REV:     ashi_rdata <= MODULE_VERSION;
            REG_FRAME_CTR_0:    ashi_rdata <= frame_counter[0];
            REG_FRAME_CTR_1:    ashi_rdata <= frame_counter[1];
            
            // Reads of any other register are a decode-error
            default: ashi_rresp <= DECERR;
        endcase
    end
end
//==========================================================================



//==========================================================================
// This connects us to an AXI4-Lite slave core
//==========================================================================
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
//==========================================================================


//=============================================================================
// This FIFO holds outgoing commands
//=============================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("common_clock"),
    .PACKET_FIFO        ("false"),
    .FIFO_DEPTH         (16),
    .TDATA_WIDTH        (8),
    .TUSER_WIDTH        (1),
    .FIFO_MEMORY_TYPE   ("auto"),
    .USE_ADV_FEATURES   ("0000")
)
cmd_fifo
(
    // Clock and reset
   .s_aclk          (clk   ),
   .m_aclk          (clk   ),
   .s_aresetn       (resetn),

    // The input bus to the FIFO
   .s_axis_tdata    (axis_cmd_tdata ),
   .s_axis_tvalid   (axis_cmd_tvalid),
   .s_axis_tready   (axis_cmd_tready),
   .s_axis_tuser    (               ),
   .s_axis_tkeep    (               ),
   .s_axis_tlast    (               ),


    // The output bus of the FIFO
   .m_axis_tdata    (AXIS_CMD_TDATA ),
   .m_axis_tvalid   (AXIS_CMD_TVALID),
   .m_axis_tready   (AXIS_CMD_TREADY),
   .m_axis_tuser    (               ),
   .m_axis_tkeep    (               ),
   .m_axis_tlast    (               ),

    // Unused input stream signals
   .s_axis_tdest(),
   .s_axis_tid  (),
   .s_axis_tstrb(),

    // Unused output stream signals
   .m_axis_tdest(),
   .m_axis_tid  (),
   .m_axis_tstrb(),

    // Other unused signals
   .almost_empty_axis(),
   .almost_full_axis(),
   .dbiterr_axis(),
   .prog_empty_axis(),
   .prog_full_axis(),
   .rd_data_count_axis(),
   .sbiterr_axis(),
   .wr_data_count_axis(),
   .injectdbiterr_axis(),
   .injectsbiterr_axis()
);
//=============================================================================




endmodule
