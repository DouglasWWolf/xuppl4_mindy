//=========================================================================================================
// mindy.h - An API for the Mindy (Laguna --> Indy) RTL design 
//=========================================================================================================
#pragma once
#include <string>
#include <vector>
#include <map>

// Throughout this header file:
//    Valid values for "phase" are 0 or 1
//    Valid values for "semiphase" are 0 or 1
class CMindy
{
public:

    // Call this once to connect to Mindy over PCIe
    void        init(std::string pcieID = "10EE:903F");

    // Returns a string containing the version of the RTL build
    std::string getRtlBuildStr();
    
    // Returns a string containing the date of the RTL build
    std::string getRtlDateStr();

    // Fetch the "connected" status of the two QSFP interfaces.
    //   Bit 0 : 1 = QSFP_0 is connected, 0 = not connected.
    //   Bit 1 : 1 = QSFP_1 is connected, 0 = not connected.
    uint32_t    getQsfpStatus();

    // Returns a non-zero code to report a latched error state
    uint32_t    getErrorStatus();

    // Call this to fetch the PCI address of a frame counter
    uint64_t    getFrameCounterPciAddress(uint32_t phase);

    // Get and set the address of the data-frame buffers on the host PC
    void        setHostFrameDataAddr(uint32_t phase, uint32_t semiphase, uint64_t address);
    uint64_t    getHostFrameDataAddr(uint32_t phase, uint32_t semiphase);

    // Get and set the size of the data-frame buffers on the host PC
    // Must be a multiple of half the frame size
    void        setHostFrameDataSize(uint64_t size);
    uint64_t    getHostFrameDataSize();

    // Get and set the address of the meta-data buffers on the host PC
    void        setHostMetaDataAddr(uint32_t phase, uint64_t address);
    uint64_t    getHostMetaDataAddr(uint32_t phase);

    // Get and set the size of the meta-data buffers on the host PC
    // Must be a multiple of 128
    void        setHostMetaDataSize(uint64_t size);
    uint64_t    getHostMetaDataSize();

    // Get and set the size of a data-frame.  This is typically 4 * 1024 * 1024
    // Must be a power of 2 and not less than 4096
    void        setFrameSize(uint32_t size);
    uint32_t    getFrameSize();

    // Get and set the the size of the RDMX packet payloads
    void        setPacketSize(uint32_t size);
    uint32_t    getPacketSize();

    // Get and set the number of packets in a ping-pong group
    void        setPacketsPerGroup(uint32_t count);
    uint32_t    getPacketsPerGroup();

    // Get and set the address of the frame-data buffer on the receiver
    void        setRemoteFrameDataAddr(uint64_t address);
    uint64_t    getRemoteFrameDataAddr();

    // Get and set the size of the frame-data buffer on the receiver
    void        setRemoteFrameDataSize(uint64_t size);
    uint64_t    getRemoteFrameDataSize();

    // Get and set the address of the meta-data buffer on the receiver
    void        setRemoteMetaDataAddr(uint64_t address);
    uint64_t    getRemoteMetaDataAddr();

    // Get and set the size of the meta-data buffer on the receiver
    void        setRemoteMetaDataSize(uint64_t size);
    uint64_t    getRemoteMetaDataSize();

    // Get and set the address of the frame counter on the receiver
    void        setRemoteFrameCounterAddr(uint64_t address);
    uint64_t    getRemoteFrameCounterAddr();

    // Clear the local frame counters and reset Mindy
    void        clearLocalFrameCounters();
    
    // Increments one of the local frame counters
    void        incrementLocalFrameCounter(uint32_t phase);
    
    // Returns the value of one of the local frame counters
    uint32_t    getLocalFrameCounter(uint32_t phase);

protected:

    uint32_t read32 (uint32_t reg);
    uint64_t read64 (uint32_t reg);
    void     write32(uint32_t reg, uint32_t value);
    void     write64(uint32_t reg, uint64_t value);


    // The userspace address of Mindy's BAR 0
    unsigned char* BAR0_;

    // The physical address of Mindy's BAR 0;
    uint64_t       PCI0_;
};

