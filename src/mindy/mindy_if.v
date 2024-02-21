//=============================================================================
//                ------->  Revision History  <------
//=============================================================================
//
//   Date     Who   Ver  Changes
//=============================================================================
// 15-Feb-24  DWW     1  Initial creation
//=============================================================================


module mindy_if #
(
    parameter DATA_WBITS     = 512,
    parameter FD_FIFO_DEPTH  = 512,
    parameter FD_FIFO_TYPE   = "auto"
)
(
    input clk, resetn,

    //==========================================================================
    //                   Input stream of frame data and meta data
    //==========================================================================
    input  [DATA_WBITS-1:0] AXIS_IN_TDATA,
    input                   AXIS_IN_TVALID,
    output                  AXIS_IN_TREADY,
    //==========================================================================


    //==========================================================================
    // Meta-data gets emitted on both of these streams simultaneously
    //==========================================================================
    output [DATA_WBITS-1:0] AXIS_MD0_TDATA,    AXIS_MD1_TDATA,
    output                  AXIS_MD0_TVALID,   AXIS_MD1_TVALID,
    input                   AXIS_MD0_TREADY,   AXIS_MD1_TREADY,
    //==========================================================================


    //==========================================================================
    // Frame-data gets emitted on this stream
    //==========================================================================
    output [DATA_WBITS-1:0] AXIS_FD_TDATA,
    output                  AXIS_FD_TVALID,
    input                   AXIS_FD_TREADY,
    //==========================================================================

    // The number of bytes in a full-frame
    input [31:0] FRAME_SIZE
);  

// Number of bytes in a metdata-record (i.e., 2 clock cycles worth)
localparam METADATA_BYTES = 128;

//=============================================================================
// This state machine receives data from the input stream
//=============================================================================
reg[31:0] recv_counter;

// Number of clock cycles per phase.  This represents one set of metadata, plus
// one set of frame-data (i.e., one phase or two semi-phases)
wire[31:0] cycles_per_phase = (METADATA_BYTES + FRAME_SIZE)/DATA_WBITS;

// Define on which clock-cycles we'll write to the meta-data output FIFOs
wire md_fifo_tvalid = (resetn == 1)
                    & (AXIS_IN_TREADY & AXIS_IN_TVALID)
                    & (recv_counter <= 2);

// Define on which clock-cycles we'll write to the frame-data FIFO
wire fd_fifo_tvalid = (resetn == 1)
                    & (AXIS_IN_TREADY & AXIS_IN_TVALID)
                    & (recv_counter > 2);

//----------------------------------------------------------------------------
always @(posedge clk) begin
    if (resetn == 0) begin
        recv_counter <= 1;

    end else if (AXIS_IN_TREADY & AXIS_IN_TVALID) begin
        if (recv_counter == cycles_per_phase)
            recv_counter <= 1;
        else
            recv_counter <= recv_counter + 1;
    end
   
end
//=============================================================================


//=============================================================================
// This FIFO holds outgoing meta-data
//=============================================================================
xpm_fifo_axis #
(
    .CLOCKING_MODE      ("common_clock"),
    .PACKET_FIFO        ("false"),
    .FIFO_DEPTH         (16),
    .TDATA_WIDTH        (DATA_WBITS),
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
   .s_axis_tdata    (AXIS_IN_TDATA ),
   .s_axis_tvalid   (md_fifo_tvalid),
   .s_axis_tready   (              ),
   .s_axis_tuser    (              ),
   .s_axis_tkeep    (              ),
   .s_axis_tlast    (              ),


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
    .TDATA_WIDTH        (DATA_WBITS),
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
   .s_axis_tdata    (AXIS_IN_TDATA ),
   .s_axis_tvalid   (md_fifo_tvalid),
   .s_axis_tready   (              ),
   .s_axis_tuser    (              ),
   .s_axis_tkeep    (              ),
   .s_axis_tlast    (              ),


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
    .TDATA_WIDTH        (DATA_WBITS),
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
   .s_axis_tdata    (AXIS_IN_TDATA ),
   .s_axis_tvalid   (fd_fifo_tvalid),
   .s_axis_tready   (AXIS_IN_TREADY),
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
