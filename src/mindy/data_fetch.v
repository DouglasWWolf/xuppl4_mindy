//=============================================================================
//                ------->  Revision History  <------
//=============================================================================
//
//   Date     Who   Ver  Changes
//=============================================================================
// 15-Feb-24  DWW     1  Initial creation
//=============================================================================

/*
    In the code below, the following abbreviations are found:
         "addr" = Address
         "ptr"  = Pointer
         "offs" = Offset
         "hmd"  = Host Meta Data
         "hfd"  = Host Frame Data

    Some Notes:  

    The overall flow of this design is:

    (1) Wait to receive a command on the AXIS_CMD stream.  That command will
        be a 0 or a 1 (meaning that we should read a frame data and meta-data
        from host RAM for phase 0 or phase 1 of the sensor chip)

    (2) Issue the appropriate read-requests to the PCIe bus to satisfy that
        command

    (3) When the requested data arrives, push the frame data out the AXIS_FD
        stream, and the meta-data out the two AXIS_MD streams.  Those two
        AXIS_MD streams carry identical output data.

    When data is fetched from the PCIe bus and written to the AXIS_FD, it is
    intentionally stripped of its RLAST/TLAST bits.   The downstream module
    that receives this data will re-packetize it as neccessary
*/

module data_fetch #
(
    parameter PCIE_BITS      = 512,
    parameter AXI_BURST_SIZE = 2048,
    parameter FD_FIFO_DEPTH  = 1024,
    parameter FD_FIFO_TYPE   = "auto"
)
(
    input clk, resetn,

    //================== This is an AXI4-Lite slave interface ==================
        
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
    //==========================================================================


    //======================  An AXI Master Interface  =========================

    // "Specify write address"         -- Master --    -- Slave --
    output     [63:0]                  M_AXI_AWADDR,
    output                             M_AXI_AWVALID,
    output     [2:0]                   M_AXI_AWPROT,
    output     [3:0]                   M_AXI_AWID,
    output     [7:0]                   M_AXI_AWLEN,
    output     [2:0]                   M_AXI_AWSIZE,
    output     [1:0]                   M_AXI_AWBURST,
    output                             M_AXI_AWLOCK,
    output     [3:0]                   M_AXI_AWCACHE,
    output     [3:0]                   M_AXI_AWQOS,
    input                                              M_AXI_AWREADY,


    // "Write Data"                    -- Master --    -- Slave --
    output     [PCIE_BITS-1:0]         M_AXI_WDATA,
    output                             M_AXI_WVALID,
    output     [63:0]                  M_AXI_WSTRB,
    output                             M_AXI_WLAST,
    input                                              M_AXI_WREADY,


    // "Send Write Response"           -- Master --    -- Slave --
    input      [1:0]                                   M_AXI_BRESP,
    input                                              M_AXI_BVALID,
    output                             M_AXI_BREADY,

    // "Specify read address"          -- Master --    -- Slave --
    output reg [63:0]                  M_AXI_ARADDR,
    output                             M_AXI_ARVALID,
    output     [2:0]                   M_AXI_ARPROT,
    output                             M_AXI_ARLOCK,
    output     [3:0]                   M_AXI_ARID,
    output reg [7:0]                   M_AXI_ARLEN,
    output     [2:0]                   M_AXI_ARSIZE,
    output     [1:0]                   M_AXI_ARBURST,
    output     [3:0]                   M_AXI_ARCACHE,
    output     [3:0]                   M_AXI_ARQOS,
    input                                              M_AXI_ARREADY,

    // "Read data back to master"      -- Master --    -- Slave --
    input      [PCIE_BITS-1:0]                         M_AXI_RDATA,
    input                                              M_AXI_RVALID,
    input      [1:0]                                   M_AXI_RRESP,
    input                                              M_AXI_RLAST,
    output                             M_AXI_RREADY,
    //==========================================================================


    //==========================================================================
    //                     Input stream of commands
    //==========================================================================
    input      [7:0] AXIS_CMD_TDATA,
    input            AXIS_CMD_TVALID,
    output           AXIS_CMD_TREADY,
    //==========================================================================


    //==========================================================================
    // Meta-data gets emitted on both of these streams simultaneously
    //==========================================================================
    output [PCIE_BITS-1:0] AXIS_MD0_TDATA,    AXIS_MD1_TDATA,
    output                 AXIS_MD0_TVALID,   AXIS_MD1_TVALID,
    input                  AXIS_MD0_TREADY,   AXIS_MD1_TREADY,
    //==========================================================================


    //==========================================================================
    // Frame-data gets emitted on this stream
    //==========================================================================
    output [PCIE_BITS-1:0] AXIS_FD_TDATA,
    output                 AXIS_FD_TVALID,
    input                  AXIS_FD_TREADY,
    //==========================================================================

    // The number of bytes in a full-frame
    output reg [31:0] FRAME_SIZE
);  

// Any time the register map of this module changes, this number should
// be bumped
localparam MODULE_VERSION = 1;

// Width of the PCIe bus, in bytes
localparam PCIE_WIDTH = PCIE_BITS / 8;

// Number of bytes in a single metadata record
localparam METADATA_BYTES = 128;

// Number of data cycles in an AXI burst
localparam AXI_BURST_CYCLES = AXI_BURST_SIZE / PCIE_WIDTH;

//=========================  AXI Register Map  ================================
localparam REG_MODULE_REV   =  0;
localparam REG_HFD00_ADDR_H =  1;  // Host frame data, phase 0, semi-phase 0
localparam REG_HFD00_ADDR_L =  2;
localparam REG_HFD01_ADDR_H =  3;  // Host frame data, phase 0, semi-phase 1
localparam REG_HFD01_ADDR_L =  4;
localparam REG_HFD10_ADDR_H =  5;  // Host frame data, phase 1, semi-phase 0
localparam REG_HFD10_ADDR_L =  6;
localparam REG_HFD11_ADDR_H =  7;  // Host frame data, phase 1, semi-phase 1
localparam REG_HFD11_ADDR_L =  8;
localparam REG_HMD0_ADDR_H  =  9;  // Host metadata, phase 0
localparam REG_HMD0_ADDR_L  = 10;
localparam REG_HMD1_ADDR_H  = 11;  // Host metadata, phase 1
localparam REG_HMD1_ADDR_L  = 12;
localparam REG_HFD_BYTES_H  = 13;  // Host frame-data buffer, size in bytes
localparam REG_HFD_BYTES_L  = 14;
localparam REG_HMD_BYTES_H  = 15;  // Host meta-data buffer, size in bytes
localparam REG_HMD_BYTES_L  = 16;
localparam REG_FRAME_SIZE   = 17;  // # of bytes in a semiphase
//=============================================================================


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

// Input-command state machine
reg[2:0] icsm_state;
localparam ICSM_WAIT_CMD     = 0;
localparam ICSM_REQ_METADATA = 1;
localparam ICSM_REQ_FD_SP0   = 2;
localparam ICSM_REQ_FD_SP1   = 3;

// Addresses of host frame data buffers, 2 phases, 2 buffers per phase
reg[63:0] host_fd_addr[0:1][0:1], host_fd_bytes;

// Addresses of host meta-data buffers, 2 phases
reg[63:0] host_md_addr[0:1], host_md_bytes;

// Number of bytes in a semi-phase
wire[31:0] semiphase_bytes = FRAME_SIZE / 2;

// Determine which phase (0 or 1) we are issuing read requests for
reg phase_select_reg;
wire phase_select = (icsm_state == ICSM_WAIT_CMD) ? AXIS_CMD_TDATA[0] : phase_select_reg;

// Offsets into the two host-side metadata buffers, one per phase
reg[63:0] hmd_offs[0:1];

// Offsets into the four host-side frame-data buffers
// Order of the indices is [phase][semiphase]
reg[63:0] hfd_offs[0:1][0:1];

// Current pointers into the semiphase frame buffers in host RAM
wire[63:0] hfd_ptr[0:1][0:1];
assign hfd_ptr[0][0] = host_fd_addr[0][0] + hfd_offs[0][0];
assign hfd_ptr[0][1] = host_fd_addr[0][1] + hfd_offs[0][1];
assign hfd_ptr[1][0] = host_fd_addr[1][0] + hfd_offs[1][0];
assign hfd_ptr[1][1] = host_fd_addr[1][1] + hfd_offs[1][1];

// Current pointers to the metadata frame buffers in host RAM
// One pointer for each phase
wire[63:0] hmd_ptr[0:1];
assign hmd_ptr[0] = host_md_addr[0] + hmd_offs[0];
assign hmd_ptr[1] = host_md_addr[1] + hmd_offs[1];

// How many AXI transactions will it take to fetch an entire semiphase?
wire[31:0] bursts_per_semiphase = semiphase_bytes / AXI_BURST_SIZE;

//=============================================================================
// This block provides a mechanism for incrementing the host RAM pointers
// for meta-data, frame-data semiphase 0, and frame-data semiphase 1
//
// On any clock cycle where "inc_pointer" is one of the INC_xxx constants
// in the code below, the associated data pointer will be incremented and 
// wrapped back to the start of the buffer as neccessary
//
// Drives:
//     incr_hmd_offs
//     incr hfd0_offs
//     incr hfd1_offs
//     hfd_offs[][]
//     hmd_offs[]
//=============================================================================
reg[1:0] inc_pointer;
localparam INC_MD_PTR  = 1;
localparam INC_FD0_PTR = 2;
localparam INC_FD1_PTR = 3;

wire[63:0] incr_hmd_offs  = hmd_offs[phase_select]    + METADATA_BYTES;
wire[63:0] incr_hfd0_offs = hfd_offs[phase_select][0] + semiphase_bytes;
wire[63:0] incr_hfd1_offs = hfd_offs[phase_select][1] + semiphase_bytes;
//-----------------------------------------------------------------------------

always @(posedge clk) begin
    if (resetn == 0) begin
        hfd_offs[0][0] <= 0;
        hfd_offs[0][1] <= 0;  
        hfd_offs[1][0] <= 0;
        hfd_offs[1][1] <= 0;
        hmd_offs[0]    <= 0;
        hmd_offs[1]    <= 0;
    end else case(inc_pointer)

        INC_MD_PTR:
            if (incr_hmd_offs < host_md_bytes)
                hmd_offs[phase_select] <= incr_hmd_offs;
            else
                hmd_offs[phase_select] <= 0;

        INC_FD0_PTR:
            if (incr_hfd0_offs < host_fd_bytes)
                hfd_offs[phase_select][0] <= incr_hfd0_offs;
            else
                hfd_offs[phase_select][0] <= 0;

        INC_FD1_PTR:
            if (incr_hfd1_offs < host_fd_bytes)
                hfd_offs[phase_select][1] <= incr_hfd1_offs;
            else
                hfd_offs[phase_select][1] <= 0;
    endcase

end

//=============================================================================



//=============================================================================
// This machine reads commands from the command stream and executes them.
//
// A command is either: "read metadata and frame data from phase 0" 
//                  or: "read metadata and frame data from phase 1"
//=============================================================================

// Number of bursts we've requested so far
reg[31:0] burst_counter;

// Assert AXIS_CMD_TREADY whenever we're waiting for a command to arrive
assign AXIS_CMD_TREADY = (resetn == 1 && icsm_state == ICSM_WAIT_CMD);

// Tell ARSIZE how wide our data bus is
assign M_AXI_ARSIZE = $clog2(PCIE_WIDTH);

// Make the burst type "auto-increment address"
assign M_AXI_ARBURST = 1;

// We're outputting a valid read request most of the time
assign M_AXI_ARVALID = (resetn == 1) & icsm_state != ICSM_WAIT_CMD;

//-----------------------------------------------------------------------------

always @(posedge clk) begin

    // We will strobe this for one clock-cycle at a time
    inc_pointer <= 0;

    if (resetn == 0) begin
        icsm_state    <= 0;
    end else case (icsm_state)

    // We wait for a command to arrive.  When it arrives, we save the phase
    // number and begin an AXI request to obtain the metadata
    ICSM_WAIT_CMD:
        if (AXIS_CMD_TVALID & AXIS_CMD_TREADY) begin
            phase_select_reg <= AXIS_CMD_TDATA[0];
            M_AXI_ARADDR     <= hmd_ptr[phase_select];
            M_AXI_ARLEN      <= 2-1;
            inc_pointer      <= INC_MD_PTR;
            icsm_state       <= ICSM_REQ_METADATA;
        end

    // Wait for meta-data request to be accepted, then 
    // issue the first request for frame data (from semiphase 0)
    ICSM_REQ_METADATA:
        if (M_AXI_ARVALID & M_AXI_ARREADY) begin
            burst_counter <= 1;
            M_AXI_ARADDR  <= hfd_ptr[phase_select][0];
            M_AXI_ARLEN   <= AXI_BURST_CYCLES - 1;
            inc_pointer   <= INC_FD0_PTR;
            icsm_state    <= ICSM_REQ_FD_SP0;
        end

    // Wait for our frame-data request to be accepted.
    // Once all semiphase 0 frame-data requests have been accepted,
    // generate the first request for semiphase 1 frame data
    ICSM_REQ_FD_SP0:
        if (M_AXI_ARVALID & M_AXI_ARREADY) begin
            if (burst_counter < bursts_per_semiphase) begin
                burst_counter <= burst_counter + 1;
                M_AXI_ARADDR  <= M_AXI_ARADDR + AXI_BURST_SIZE;
            end else begin
                burst_counter <= 1;
                M_AXI_ARADDR  <= hfd_ptr[phase_select][1];
                inc_pointer   <= INC_FD1_PTR;
                icsm_state    <= ICSM_REQ_FD_SP1;
            end
        end

    // Wait for our frame-data request to be accepted.
    // Once all semiphase 1 frame-data requests have been accepted,
    // we're done executing the current command
    ICSM_REQ_FD_SP1:
        if (M_AXI_ARVALID & M_AXI_ARREADY) begin
            if (burst_counter < bursts_per_semiphase) begin
                burst_counter <= burst_counter + 1;
                M_AXI_ARADDR  <= M_AXI_ARADDR + AXI_BURST_SIZE;
            end else begin
                icsm_state    <= ICSM_WAIT_CMD;
            end
        end

    endcase
end
//=============================================================================




//=============================================================================
// This state machine receives data from the PCIe bus
//=============================================================================
reg[31:0] recv_counter;

// Number of clock cycles per phase.  This represents one set of metadata, plus
// frame data from two semi-phases
wire[31:0] cycles_per_phase = (METADATA_BYTES + 2*semiphase_bytes)/PCIE_WIDTH;


// Define on which clock-cycles we'll write to the meta-data output FIFOs
wire axis_md_tvalid = (resetn == 1)
                    & (M_AXI_RREADY & M_AXI_RVALID)
                    & (recv_counter <= 2);

wire axis_fd_tvalid = (resetn == 1)
                    & (M_AXI_RREADY & M_AXI_RVALID)
                    & (recv_counter > 2);

// This is driven by the frame data FIFO
wire axis_fd_tready;

// We're always ready to receive data when the FIFO is ready to receive
assign M_AXI_RREADY = (resetn == 1) & axis_fd_tready;
//----------------------------------------------------------------------------
always @(posedge clk) begin
    if (resetn == 0) begin
        recv_counter <= 1;

    end else if (M_AXI_RREADY & M_AXI_RVALID) begin
        if (recv_counter == cycles_per_phase)
            recv_counter <= 1;
        else
            recv_counter <= recv_counter + 1;
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
               
                    // Phase 0 frame-data ring buffer addresses
                    REG_HFD00_ADDR_H:   host_fd_addr[0][0][63:32] <= ashi_wdata;
                    REG_HFD00_ADDR_L:   host_fd_addr[0][0][31:00] <= ashi_wdata;
                    REG_HFD01_ADDR_H:   host_fd_addr[0][1][63:32] <= ashi_wdata;
                    REG_HFD01_ADDR_L:   host_fd_addr[0][1][31:00] <= ashi_wdata;

                    // Phase 1 frame-data ring buffer addresses
                    REG_HFD10_ADDR_H:   host_fd_addr[1][0][63:32] <= ashi_wdata;
                    REG_HFD10_ADDR_L:   host_fd_addr[1][0][31:00] <= ashi_wdata;
                    REG_HFD11_ADDR_H:   host_fd_addr[1][1][63:32] <= ashi_wdata;
                    REG_HFD11_ADDR_L:   host_fd_addr[1][1][31:00] <= ashi_wdata;

                    // Meta-data ring buffers addresses for both phases
                    REG_HMD0_ADDR_H:    host_md_addr[0][63:32] <= ashi_wdata;
                    REG_HMD0_ADDR_L:    host_md_addr[0][31:00] <= ashi_wdata;
                    REG_HMD1_ADDR_H:    host_md_addr[1][63:32] <= ashi_wdata;
                    REG_HMD1_ADDR_L:    host_md_addr[1][31:00] <= ashi_wdata;

                    // Frame-data ring-buffer size in bytes
                    REG_HFD_BYTES_H:    host_fd_bytes[63:32] <= ashi_wdata;
                    REG_HFD_BYTES_L:    host_fd_bytes[31:00] <= ashi_wdata;

                    // Meta-data ring-buffer size in bytes
                    REG_HMD_BYTES_H:    host_md_bytes[63:32] <= ashi_wdata;
                    REG_HMD_BYTES_L:    host_md_bytes[31:00] <= ashi_wdata;

                    // Length of a frame (i.e., 2 semiphases), in bytes
                    REG_FRAME_SIZE:     FRAME_SIZE <= ashi_wdata;

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
           
            REG_MODULE_REV:     ashi_rdata <= MODULE_VERSION;
            REG_HFD00_ADDR_H:   ashi_rdata <= host_fd_addr[0][0][63:32];
            REG_HFD00_ADDR_L:   ashi_rdata <= host_fd_addr[0][0][31:00];
            REG_HFD01_ADDR_H:   ashi_rdata <= host_fd_addr[0][1][63:32];
            REG_HFD01_ADDR_L:   ashi_rdata <= host_fd_addr[0][1][31:00];
            REG_HFD10_ADDR_H:   ashi_rdata <= host_fd_addr[1][0][63:32];
            REG_HFD10_ADDR_L:   ashi_rdata <= host_fd_addr[1][0][31:00];
            REG_HFD11_ADDR_H:   ashi_rdata <= host_fd_addr[1][1][63:32];
            REG_HFD11_ADDR_L:   ashi_rdata <= host_fd_addr[1][1][31:00];

            REG_HMD0_ADDR_H:    ashi_rdata <= host_md_addr[0][63:32];
            REG_HMD0_ADDR_L:    ashi_rdata <= host_md_addr[0][31:00];
            REG_HMD1_ADDR_H:    ashi_rdata <= host_md_addr[1][63:32];
            REG_HMD1_ADDR_L:    ashi_rdata <= host_md_addr[1][31:00];

            REG_HFD_BYTES_H:    ashi_rdata <= host_fd_bytes[63:32];
            REG_HFD_BYTES_L:    ashi_rdata <= host_fd_bytes[31:00];
            REG_HMD_BYTES_H:    ashi_rdata <= host_md_bytes[63:32];
            REG_HMD_BYTES_L:    ashi_rdata <= host_md_bytes[31:00];

            REG_FRAME_SIZE:     ashi_rdata <= FRAME_SIZE;

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

//=============================================================================
// This FIFO holds outgoing meta-data
//=============================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("common_clock"),
    .PACKET_FIFO        ("false"),
    .FIFO_DEPTH         (16),
    .TDATA_WIDTH        (PCIE_BITS),
    .TUSER_WIDTH        (1),
    .FIFO_MEMORY_TYPE   ("distributed"),
    .USE_ADV_FEATURES   ("0000")
)
md0_fifo
(
    // Clock and reset
   .s_aclk          (clk   ),
   .m_aclk          (clk   ),
   .s_aresetn       (resetn),

    // The input bus to the FIFO
   .s_axis_tdata    (M_AXI_RDATA    ),
   .s_axis_tvalid   (axis_md_tvalid ),
   .s_axis_tready   (               ),
   .s_axis_tuser    (               ),
   .s_axis_tkeep    (               ),
   .s_axis_tlast    (               ),


    // The output bus of the FIFO
   .m_axis_tdata    (AXIS_MD0_TDATA ),
   .m_axis_tvalid   (AXIS_MD0_TVALID),
   .m_axis_tready   (AXIS_MD0_TREADY),
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


//=============================================================================
// This FIFO holds outgoing meta-data
//=============================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("common_clock"),
    .PACKET_FIFO        ("false"),
    .FIFO_DEPTH         (16),
    .TDATA_WIDTH        (PCIE_BITS),
    .TUSER_WIDTH        (1),
    .FIFO_MEMORY_TYPE   ("distributed"),
    .USE_ADV_FEATURES   ("0000")
)
md1_fifo
(
    // Clock and reset
   .s_aclk          (clk   ),
   .m_aclk          (clk   ),
   .s_aresetn       (resetn),

    // The input bus to the FIFO
   .s_axis_tdata    (M_AXI_RDATA    ),
   .s_axis_tvalid   (axis_md_tvalid ),
   .s_axis_tready   (               ),
   .s_axis_tuser    (               ),
   .s_axis_tkeep    (               ),
   .s_axis_tlast    (               ),


    // The output bus of the FIFO
   .m_axis_tdata    (AXIS_MD1_TDATA ),
   .m_axis_tvalid   (AXIS_MD1_TVALID),
   .m_axis_tready   (AXIS_MD1_TREADY),
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

 
//=============================================================================
// This FIFO holds outgoing frame data
//=============================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("common_clock"),
    .PACKET_FIFO        ("false"),
    .FIFO_DEPTH         (FD_FIFO_DEPTH),
    .TDATA_WIDTH        (PCIE_BITS),
    .TUSER_WIDTH        (1),
    .FIFO_MEMORY_TYPE   (FD_FIFO_TYPE),
    .USE_ADV_FEATURES   ("0000")
)
fd_fifo
(
    // Clock and reset
   .s_aclk          (clk   ),
   .m_aclk          (clk   ),
   .s_aresetn       (resetn),

    // The input bus to the FIFO
   .s_axis_tdata    (M_AXI_RDATA   ),
   .s_axis_tvalid   (axis_fd_tvalid),
   .s_axis_tready   (axis_fd_tready),
   .s_axis_tuser    (              ),
   .s_axis_tkeep    (              ),
   .s_axis_tlast    (              ),


    // The output bus of the FIFO
   .m_axis_tdata    (AXIS_FD_TDATA ),
   .m_axis_tvalid   (AXIS_FD_TVALID),
   .m_axis_tready   (AXIS_FD_TREADY),
   .m_axis_tuser    (              ),
   .m_axis_tkeep    (              ),
   .m_axis_tlast    (              ),

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
