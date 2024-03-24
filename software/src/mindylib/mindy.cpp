//=========================================================================================================
// mindy.cpp - An API for the Mindy (Laguna --> Indy) RTL design 
//=========================================================================================================
#include <cstdarg>
#include "mindy.h"
#include "PciDevice.h"

using namespace std;

// This is a connection to the PCI bus
static PciDevice PCI;

static const uint32_t BV_BASE = 0;
static const uint32_t REG_BUILD_MAJOR = BV_BASE + 0*4;
static const uint32_t REG_BUILD_MINOR = BV_BASE + 1*4;
static const uint32_t REG_BUILD_REV   = BV_BASE + 2*4;
static const uint32_t REG_BUILD_RC    = BV_BASE + 3*4;
static const uint32_t REG_BUILD_DATE  = BV_BASE + 4*4;

// Addresses of the two frame counters
const uint32_t REG_FC0 = 0x1004;
const uint32_t REG_FC1 = 0x1008;     

// Registers registers in the "data fetch" module
const uint32_t DF_BASE = 0x2000;
const uint32_t REG_HFD00_ADDR_H = DF_BASE +  1*4;
const uint32_t REG_HFD00_ADDR_L = DF_BASE +  2*4;
const uint32_t REG_HFD01_ADDR_H = DF_BASE +  3*4;
const uint32_t REG_HFD01_ADDR_L = DF_BASE +  4*4;
const uint32_t REG_HFD10_ADDR_H = DF_BASE +  5*4;
const uint32_t REG_HFD10_ADDR_L = DF_BASE +  6*4;
const uint32_t REG_HFD11_ADDR_H = DF_BASE +  7*4;
const uint32_t REG_HFD11_ADDR_L = DF_BASE +  8*4;
const uint32_t  REG_HMD0_ADDR_H = DF_BASE +  9*4;
const uint32_t  REG_HMD0_ADDR_L = DF_BASE + 10*4;
const uint32_t  REG_HMD1_ADDR_H = DF_BASE + 11*4;
const uint32_t  REG_HMD1_ADDR_L = DF_BASE + 12*4;
const uint32_t  REG_HFD_BYTES_H = DF_BASE + 13*4;
const uint32_t  REG_HFD_BYTES_L = DF_BASE + 14*4;
const uint32_t  REG_HMD_BYTES_H = DF_BASE + 15*4;
const uint32_t  REG_HMD_BYTES_L = DF_BASE + 16*4;
const uint32_t   REG_ABM_ADDR_H = DF_BASE + 17*4;
const uint32_t   REG_ABM_ADDR_L = DF_BASE + 18*4;


// Registers in the "RDMX shim" module
const uint32_t RS_BASE = 0x4000;
const uint32_t REG_RFD_ADDR_H        = RS_BASE +  0*4;
const uint32_t REG_RFD_ADDR_L        = RS_BASE +  1*4;
const uint32_t REG_RFD_SIZE_H        = RS_BASE +  2*4;
const uint32_t REG_RFD_SIZE_L        = RS_BASE +  3*4;
const uint32_t REG_RMD_ADDR_H        = RS_BASE +  4*4;
const uint32_t REG_RMD_ADDR_L        = RS_BASE +  5*4;
const uint32_t REG_RMD_SIZE_H        = RS_BASE +  6*4;
const uint32_t REG_RMD_SIZE_L        = RS_BASE +  7*4;
const uint32_t REG_RFC_ADDR_H        = RS_BASE +  8*4;
const uint32_t REG_RFC_ADDR_L        = RS_BASE +  9*4;
const uint32_t REG_FRAME_SIZE        = RS_BASE + 10*4;
const uint32_t REG_PACKET_SIZE       = RS_BASE + 11*4;
const uint32_t REG_PACKETS_PER_GROUP = RS_BASE + 12*4;


// Registers in the "status manager" module
const uint32_t SM_BASE = 0x5000;
const uint32_t REG_QSFP_STATUS  = SM_BASE + 0*4;
const uint32_t REG_ERROR_STATUS = SM_BASE + 1*4;


//=================================================================================================
// throwRuntime() - Throws a runtime exception
//=================================================================================================
static void throwRuntime(const char* fmt, ...)
{
    char buffer[1024];
    va_list ap;
    va_start(ap, fmt);
    vsprintf(buffer, fmt, ap);
    va_end(ap);

    throw runtime_error(buffer);
}
//=================================================================================================


//=================================================================================================
// write32() - Write a 32-bit value into the specified register
//=================================================================================================
void CMindy::write32(uint32_t reg, uint32_t value)
{
    // Get a reference to the specified AXI register
    uint32_t& axiReg = *(uint32_t*)(BAR0_ + reg);

    // Store the specified value into the register
    axiReg = value;
}
//=================================================================================================


//=================================================================================================
// read32() - Returns the 32-bit value of the specified register
//=================================================================================================
uint32_t CMindy::read32(uint32_t reg)
{
    // Get a reference to the specified AXI register
    uint32_t& axiReg = *(uint32_t*)(BAR0_ + reg);

    // Return the value stored in that register
    return axiReg;
}
//=================================================================================================


//=================================================================================================
// read64() - Returns the 64-bit value of the specified register
//=================================================================================================
uint64_t CMindy::read64(uint32_t reg)
{
    // Get a reference to the specified AXI registers
    uint32_t& axiRegHi = *(uint32_t*)(BAR0_ + reg + 0);
    uint32_t& axiRegLo = *(uint32_t*)(BAR0_ + reg + 4);

    // Return the 64-bit value to the caller
    return (((uint64_t)axiRegHi) << 32) | axiRegLo;
}
//=================================================================================================

//=================================================================================================
// write64() - Writes a 64-bit value to the specified register
//=================================================================================================
void CMindy::write64(uint32_t reg, uint64_t value)
{
    // Get a reference to the specified AXI registers
    uint32_t& axiRegHi = *(uint32_t*)(BAR0_ + reg + 0);
    uint32_t& axiRegLo = *(uint32_t*)(BAR0_ + reg + 4);

    // Now write the two 32-bit values
    axiRegHi = value >> 32;
    axiRegLo = value & 0xFFFFFFFF;
}
//=================================================================================================



//=================================================================================================
// init() - Creates a connection with the specified PCIe device
//=================================================================================================
void CMindy::init(string pcieID)
{
    // Map the board's BARs into userspace
    PCI.open(pcieID);

    // Fetch the userspace address of the first BAR
    BAR0_ = PCI.resourceList()[0].baseAddr;

    // Fetch the PCI address of the first BAR
    PCI0_ = PCI.resourceList()[0].physAddr;

    // If it looks like we need a hot-reset, do so
    if (read32(REG_BUILD_MAJOR) == 0xFFFFFFFF) PCI.hotReset(pcieID);

    // If we still can't read the module revision after a hot-reset, drop-dead
    if (read32(REG_BUILD_MAJOR) == 0xFFFFFFFF)
        throwRuntime("Can't connect to %s", pcieID.c_str());
}
//=================================================================================================


//=================================================================================================
// setHostFrameDataAddress() - Sets the host-PC RAM address where the frame-data buffers are
//=================================================================================================
void CMindy::setHostFrameDataAddr(uint32_t phase, uint32_t semiphase, uint64_t address)
{
    if      (phase == 0 && semiphase == 0)
        write64(REG_HFD00_ADDR_H, address);
    
    else if (phase == 0 && semiphase == 1)
        write64(REG_HFD01_ADDR_H, address);
    
    else if (phase == 1 && semiphase == 0)
        write64(REG_HFD10_ADDR_H, address);
    
    else if (phase == 1 && semiphase == 1)
        write64(REG_HFD11_ADDR_H, address);
    
    else
        throwRuntime("bad parameter on setHostFrameDataAddr()");
}
//=================================================================================================    


//=================================================================================================
// getHostFrameDataAddress() - Gets the host-PC RAM address where the frame-data buffers are
//=================================================================================================
uint64_t CMindy::getHostFrameDataAddr(uint32_t phase, uint32_t semiphase)
{
    if (phase == 0 && semiphase == 0)
        return read64(REG_HFD00_ADDR_H);
    
    if (phase == 0 && semiphase == 1)
        return read64(REG_HFD01_ADDR_H);
    
    if (phase == 1 && semiphase == 0)
        return read64(REG_HFD10_ADDR_H);
    
    if (phase == 1 && semiphase == 1)
        return read64(REG_HFD11_ADDR_H);
    
    // If we get here, there was an illegal value for phase or semiphase
    throwRuntime("bad parameter on getHostFrameDataAddr()");

    // This is just here to keep the compiler happy
    return 0;
}
//=================================================================================================    



//=================================================================================================
// setHostMetaDataAddr() - Sets the host-PC RAM address where the meta-data buffers are
//=================================================================================================
void CMindy::setHostMetaDataAddr(uint32_t phase, uint64_t address)
{
    if      (phase == 0)
        write64(REG_HMD0_ADDR_H, address);

    else if (phase == 1)
        write64(REG_HMD1_ADDR_H, address);

    else
        throwRuntime("bad parameter on setHostMetaDataAddr()");
}
//=================================================================================================    



//=================================================================================================
// getHostMetaDataAddr() - Gets the host-PC RAM address where the meta-data buffers are
//=================================================================================================
uint64_t CMindy::getHostMetaDataAddr(uint32_t phase)
{
    if (phase == 0)
        return read64(REG_HMD0_ADDR_H);

    if (phase == 1)
        return read64(REG_HMD1_ADDR_H);
    
    // If we get here, there was an illegal value for "phase"
    throwRuntime("bad parameter on getHostMetaDataAddr()");

    // This is just here to keep the compiler happy
    return 0;
}
//=================================================================================================    


//=================================================================================================
// setHostFrameDataSize() - Sets the size of the host-PC RAM frame-data buffers
//=================================================================================================
void CMindy::setHostFrameDataSize(uint64_t size)
{
    write64(REG_HFD_BYTES_H, size);
}
//=================================================================================================    


//=================================================================================================
// getHostFrameDataSize() - Gets the size of the host-PC RAM frame-data buffers
//=================================================================================================
uint64_t CMindy::getHostFrameDataSize()
{
    return read64(REG_HFD_BYTES_H);
}
//=================================================================================================    


//=================================================================================================
// setHostMetaDataSize() - Sets the size of the host-PC RAM meta-data buffers
//=================================================================================================
void CMindy::setHostMetaDataSize(uint64_t size)
{
    write64(REG_HMD_BYTES_H, size);
}
//=================================================================================================    

//=================================================================================================
// getHostFrameDataSize() - Gets the size of the host-PC RAM meta-data buffers
//=================================================================================================
uint64_t CMindy::getHostMetaDataSize()
{
    return read64(REG_HMD_BYTES_H);
}
//=================================================================================================    



//=================================================================================================    
// setFrameSize() - Sets the size of a single frame (which is a single phase)
//=================================================================================================    
void CMindy::setFrameSize(uint32_t size)
{
    write32(REG_FRAME_SIZE, size);
}
//=================================================================================================    

//=================================================================================================    
// getFrameSize() - Returns the size of a single frame (which is a single phase)
//=================================================================================================    
uint32_t CMindy::getFrameSize()
{
    return read32(REG_FRAME_SIZE);
}
//=================================================================================================    


//=================================================================================================    
// setHostAbmAddr() - Sets the address of the ABM in host-RAM
//=================================================================================================
void CMindy::setHostAbmAddr(uint64_t address)
{
    write32(REG_ABM_ADDR_H, address);
}
//=================================================================================================    


//=================================================================================================    
// getHostAbmAddr() - Returns the address of the ABM in host-RAM
//=================================================================================================
uint64_t CMindy::getHostAbmAddr()
{
    return read64(REG_ABM_ADDR_H);
}
//=================================================================================================    



//=================================================================================================    
// setPacketSize() - Sets the size of a the payload in an outgoing RDMX frame-data packet
//=================================================================================================
void CMindy::setPacketSize(uint32_t size)
{
    write32(REG_PACKET_SIZE, size);
}
//=================================================================================================    

//=================================================================================================    
// getPacketSize() - Returns the size of the payload in an outgoing RDMX frame-data packet
//=================================================================================================    
uint32_t CMindy::getPacketSize()
{
    return read32(REG_PACKET_SIZE);
}
//=================================================================================================    


//=================================================================================================    
// setPacketsPerGroup() - Sets the number of packets in a ping-pong group
//=================================================================================================
void CMindy::setPacketsPerGroup(uint32_t count)
{
    write32(REG_PACKETS_PER_GROUP, count);
}
//=================================================================================================    

//=================================================================================================    
// getPacketsPerGroup() - Returns the number of packets in a ping-pong group
//=================================================================================================    
uint32_t CMindy::getPacketsPerGroup()
{
    return read32(REG_PACKETS_PER_GROUP);
}
//=================================================================================================    

//=================================================================================================    
// setRemoteFrameDataAddr() - Sets the address of the frame-data buffer on the receiver
//=================================================================================================    
void CMindy::setRemoteFrameDataAddr(uint64_t address)
{
    write64(REG_RFD_ADDR_H, address);
}
//=================================================================================================    

//=================================================================================================    
// getRemoteFrameDataAddr() - Gets the address of the frame-data buffer on the receiver
//=================================================================================================    
uint64_t CMindy::getRemoteFrameDataAddr()
{
    return read64(REG_RFD_ADDR_H);
}
//=================================================================================================    



//=================================================================================================    
// setRemoteMetaDataAddr() - Sets the address of the meta-data buffer on the receiver
//=================================================================================================    
void CMindy::setRemoteMetaDataAddr(uint64_t address)
{
    write64(REG_RMD_ADDR_H, address);
}
//=================================================================================================    


//=================================================================================================    
// getRemoteMetaDataAddr() - Gets the address of the meta-data buffer on the receiver
//=================================================================================================    
uint64_t CMindy::getRemoteMetaDataAddr()
{
    return read64(REG_RMD_ADDR_H);
}
//=================================================================================================    


//=================================================================================================    
// setRemoteFrameDataSize() - Sets the size of the frame-data buffer on the receiver
//=================================================================================================    
void CMindy::setRemoteFrameDataSize(uint64_t size)
{
    write64(REG_RFD_SIZE_H, size);
}
//=================================================================================================    


//=================================================================================================    
// getRemoteFrameDataSize() - Gets the size of the frame-data buffer on the receiver
//=================================================================================================    
uint64_t CMindy::getRemoteFrameDataSize()
{
    return read64(REG_RFD_SIZE_H);
}
//=================================================================================================    



//=================================================================================================    
// setRemoteMetaDataSize() - Sets the size of the meta-data buffer on the receiver
//=================================================================================================    
void CMindy::setRemoteMetaDataSize(uint64_t size)
{
    write64(REG_RMD_SIZE_H, size);
}
//=================================================================================================    

//=================================================================================================    
// getRemoteMetaDataSize() - Gets the size of the meta-data buffer on the receiver
//=================================================================================================    
uint64_t CMindy::getRemoteMetaDataSize()
{
    return read64(REG_RMD_SIZE_H);
}
//=================================================================================================    


//=================================================================================================    
// setRemoteFrameCounterAddr() - Sets the address of the frame-counter on the receiver
//=================================================================================================    
void CMindy::setRemoteFrameCounterAddr(uint64_t address)
{
    write64(REG_RFC_ADDR_H, address);
}
//=================================================================================================    

//=================================================================================================    
// getRemoteFrameCounterAddr() - Gets the address of the frame-counter on the receiver
//=================================================================================================    
uint64_t CMindy::getRemoteFrameCounterAddr()
{
    return read64(REG_RFC_ADDR_H);
}
//=================================================================================================    


//=================================================================================================    
// clearLocalFrameCounters() - Clears both local frame counters to zero, and resets the Mindy
//                             system back to start
//=================================================================================================    
void CMindy::clearLocalFrameCounters()
{
    // Only need to clear the first one.  The other frame counter will automatically clear
    write32(REG_FC0, 0);    
}
//=================================================================================================    


//=================================================================================================    
// incrementLocalFrameCounter() - Will cause a frame-data, meta-data, and a frame counter to be
//                                transmitted to the receivers
//=================================================================================================    
void CMindy::incrementLocalFrameCounter(uint32_t phase)
{
    uint32_t currentValue = 0;

    if (phase == 0)
        currentValue = read32(REG_FC0);
    else if (phase == 1)
        currentValue = read32(REG_FC1);
    else
        throwRuntime("bad parameter on incrementLocalFrameCounter()");

    if (phase == 0)
        write32(REG_FC0, currentValue + 1);
    else
        write32(REG_FC1, currentValue + 1);
}
//=================================================================================================    


//=================================================================================================    
// getLocalFrameCounter() - Returns the value of one of the local frame counters
//=================================================================================================    
uint32_t CMindy::getLocalFrameCounter(uint32_t phase)
{
    if (phase == 0) return read32(REG_FC0);
    if (phase == 1) return read32(REG_FC1);
    throwRuntime("bad parameter on getLocalFrameCounter()");
    return 0;
}
//=================================================================================================    


//=================================================================================================    
// getFrameCounterPciAddress() - Returns the PCI address of the frame-counter that corresponds to
//                               the specified phase.
//=================================================================================================    
uint64_t CMindy::getFrameCounterPciAddress(uint32_t phase)
{
    if (phase == 0) return PCI0_ + REG_FC0;
    if (phase == 1) return PCI0_ + REG_FC1;
    throwRuntime("bad parameter on getFrameCounterPciAddress()");
    return 0;
}
//=================================================================================================    



//=================================================================================================    
// getQsfpStatus() - Returns the "connected" status of the QSFP network interfaces
//
// Bit 0 : 1 = QSFP_0 is connected, 0 = Not connected
// Bit 1 : 1 = QSFP_1 is connected, 0 = Not connected
//=================================================================================================    
uint32_t CMindy::getQsfpStatus()
{
    return read32(REG_QSFP_STATUS);    
}
//=================================================================================================    


//=================================================================================================    
// getErrorStatus() - Returns an error-status word.  Non-zero indicates a fault
//=================================================================================================    
uint32_t CMindy::getErrorStatus()
{
    return read32(REG_ERROR_STATUS);    
}
//=================================================================================================    


//=================================================================================================    
// getRtlDateStr() - Returns a string containing the RTL build date
//=================================================================================================    
string CMindy::getRtlDateStr()
{
    char buffer[100];
    const char* name[] =
    {
        "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    };

    // Fetch the value of the register that contains the build date
    uint32_t dateBits = read32(REG_BUILD_DATE);

    // Split the dateBits into month, day, year
    int month =(dateBits >> 24) & 0xFF;
    int day   =(dateBits >> 16) & 0xFF;
    int year = (dateBits      ) & 0xFFFF;

    // Ensure that at least the month is legal
    if (month < 1 || month > 12) return "N/A";

    // Format the date like this: "02-Feb-2024"
    sprintf(buffer, "%02i-%s-%i", day, name[month], year);

    // Hand the4 resulting string to the caller
    return buffer;
}
//=================================================================================================    



//=================================================================================================    
// getRtlBuildStr() - Returns a string containing the build version of the RTL
//=================================================================================================    
string CMindy::getRtlBuildStr()
{
    string retVal;
    char buffer[100];

    // Fetch the components of the build version
    int major = read32(REG_BUILD_MAJOR);
    int minor = read32(REG_BUILD_MINOR);
    int rev   = read32(REG_BUILD_REV  );
    int rc    = read32(REG_BUILD_RC   );

    // Format the string
    sprintf(buffer, "%i.%i.%02i", major, minor, rev);

    // Store the buffer we just formatted into our return string
    retVal = buffer;

    // If this is a release candidate, append that to the return string
    if (rc)
    {
        sprintf(buffer, "-rc-%i", rc);
        retVal = retVal + buffer;
    }

    // Hand the caller the resulting build-version string
    return retVal;
}
//=================================================================================================    
