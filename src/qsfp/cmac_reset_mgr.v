/*
//=============================================================================
 
 Be sure to set the FREQ_HZ parameter of init_clk_out correctly!!

 If REF_CLK_FREQ is greater 200 million, FREQ_HZ on init_clk_out should be
 set to half of REF_CLK_FREQ.   

 If REF_CLK_FREQ is 200 million or less, FREQ_HZ on init_clk_out should match
 REF_CLK_FREQ.

//=============================================================================
*/

module cmac_reset_mgr# (parameter REF_CLK_FREQ = 322265625)
(
    input   gt_ref_clk_in,
    input   src_aresetn,


    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 init_clk_out CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET init_reset" *)
    (* X_INTERFACE_PARAMETER = "FREQ_HZ 161132812" *)
    output  init_clk_out,

    // Provides reset to the CMAC, synchronous to init_clk
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 init_reset RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    output  init_reset,
    
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 stream_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET stream_resetn" *)
    input   stream_clk,

    // A resetn that is synchronous to the RX and TX stream
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 stream_resetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    output  stream_resetn
);

    //=========================================================================
    // This creates a clock that is half the frequency of gt_ref_clk_in
    //=========================================================================
    reg half_gt_ref_clk;
    always @(posedge gt_ref_clk_in) half_gt_ref_clk <= ~half_gt_ref_clk;
    //=========================================================================

    // Ensure that "init_clk_out" is 200 Mhz or less
    if (REF_CLK_FREQ > 200000000)
        assign init_clk_out = half_gt_ref_clk;
    else 
        assign init_clk_out = gt_ref_clk_in;


    wire init_resetn;


    xpm_cdc_async_rst #
    (
        .DEST_SYNC_FF(4),    
        .INIT_SYNC_FF(0),    
        .RST_ACTIVE_HIGH(1)  
    )
    i_cmac
    (
        .src_arst   (~src_aresetn),   
        .dest_clk   (init_clk_out),   
        .dest_arst  (init_reset  )
    );


    xpm_cdc_async_rst #
    (
        .DEST_SYNC_FF(4),    
        .INIT_SYNC_FF(0),    
        .RST_ACTIVE_HIGH(0)  
    )
    i_stream
    (
        .src_arst   (src_aresetn  ),   
        .dest_clk   (stream_clk   ),   
        .dest_arst  (stream_resetn)
    );

endmodule