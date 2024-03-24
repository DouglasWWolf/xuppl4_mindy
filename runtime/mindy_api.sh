#==============================================================================
# AXI register definitions
#==============================================================================

# Frame counters
FC0=0x1000
FC1=0x1004        

DF_BASE=0x2000
   REG_HFD00_ADDR_H=$((DF_BASE +  1*4))
   REG_HFD00_ADDR_L=$((DF_BASE +  2*4))
   REG_HFD01_ADDR_H=$((DF_BASE +  3*4))
   REG_HFD01_ADDR_L=$((DF_BASE +  4*4))
   REG_HFD10_ADDR_H=$((DF_BASE +  5*4))
   REG_HFD10_ADDR_L=$((DF_BASE +  6*4))
   REG_HFD11_ADDR_H=$((DF_BASE +  7*4))
   REG_HFD11_ADDR_L=$((DF_BASE +  8*4))
    REG_HMD0_ADDR_H=$((DF_BASE +  9*4))
    REG_HMD0_ADDR_L=$((DF_BASE + 10*4))
    REG_HMD1_ADDR_H=$((DF_BASE + 11*4))
    REG_HMD1_ADDR_L=$((DF_BASE + 12*4))
    REG_HFD_BYTES_H=$((DF_BASE + 13*4))
    REG_HFD_BYTES_L=$((DF_BASE + 14*4))
    REG_HMD_BYTES_H=$((DF_BASE + 15*4))
    REG_HMD_BYTES_L=$((DF_BASE + 16*4))
     REG_ABM_ADDR_H=$((DF_BASE + 17*4))
     REG_ABM_ADDR_L=$((DF_BASE + 18*4))



RS_BASE=0x4000
       REG_RFD_ADDR_H=$((RS_BASE +  0*4))
       REG_RFD_ADDR_L=$((RS_BASE +  1*4))
       REG_RFD_SIZE_H=$((RS_BASE +  2*4))
       REG_RFD_SIZE_L=$((RS_BASE +  3*4))
       REG_RMD_ADDR_H=$((RS_BASE +  4*4))
       REG_RMD_ADDR_L=$((RS_BASE +  5*4))
       REG_RMD_SIZE_H=$((RS_BASE +  6*4))
       REG_RMD_SIZE_L=$((RS_BASE +  7*4))
       REG_RFC_ADDR_H=$((RS_BASE +  8*4))
       REG_RFC_ADDR_L=$((RS_BASE +  9*4))
       REG_FRAME_SIZE=$((RS_BASE + 10*4))
      REG_PACKET_SIZE=$((RS_BASE + 11*4))
REG_PACKETS_PER_GROUP=$((RS_BASE + 12*4))


#==============================================================================
# This strips underscores from a string and converts it to decimal
#==============================================================================
strip_underscores()
{
    local stripped=$(echo $1 | sed 's/_//g')
    echo $((stripped))
}
#==============================================================================


#==============================================================================
# This displays the upper 32 bits of an integer
#==============================================================================
upper32()
{
    local value=$(strip_underscores $1)
    echo $(((value >> 32) & 0xFFFFFFFF))
}
#==============================================================================


#==============================================================================
# This displays the lower 32 bits of an integer
#==============================================================================
lower32()
{
    local value=$(strip_underscores $1)
    echo $((value & 0xFFFFFFFF))
}
#==============================================================================


#==============================================================================
# This calls the local copy of pcireg
#==============================================================================
xpcireg()
{
    axireg $1 $2 $3 $4 $5 $6
}
#==============================================================================


#==============================================================================
# Writes a 64-bit value to a pair of 32-bit registers
#==============================================================================
write_reg64()
{
    local addr=$(strip_underscores $1)
    local valu=$(strip_underscores $2)
    echo "Writing $2 to $1"

    pcireg $((addr + 0)) $(upper32 $valu)
    pcireg $((addr + 4)) $(lower32 $valu)    
}
#==============================================================================

