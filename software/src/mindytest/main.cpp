#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include <cstring>
#include <fcntl.h>
#include <sys/mman.h>
#include <errno.h>
#include "mindy.h"


using namespace std;

CMindy Mindy;

void execute();
void parseCommandLine(const char** argv);


//=================================================================================================
// main() - Execution starts here
//=================================================================================================
int main(int argc, const char** argv)
{
    parseCommandLine(argv);

    try
    {
        execute();
    }
    catch(const std::exception& e)
    {
        printf("%s\n", e.what());
        exit(1);
    }
}
//=================================================================================================


//=================================================================================================
// parseCommandLine() - Parses the command line looking for switches
//
// On Exit: if "-ecd"  switch was used, "loadEcdFPGA" is 'true'
//          If "-ecdm" switch was used, "loadMasterFPGA" is 'true'
//=================================================================================================
void parseCommandLine(const char** argv)
{
/*
    while (*++argv)
    {
        const char* arg = *argv;

        if (strcmp(arg, "-ecd") == 0)
        {
            loadEcdFPGA = true;
            continue;
        }        

        if (strcmp(arg, "-ecdm") == 0)
        {
            loadMasterFPGA = true;
            continue;
        }        

        cerr << "Unknown command line switch " << arg << "\n";
        exit(1);
    }    
*/
}
//=================================================================================================


//=================================================================================================
// execute() - Does everything neccessary to begin a data transfer
//
// This routine assumes the run data has already been loaded into the contiguous RAM buffer
//=================================================================================================
void execute()
{

    Mindy.init("10ee:903f");

    string dateStr = Mindy.getRtlDateStr();
    printf("RTL Date: %s\n", dateStr.c_str());
    
    string versionStr = Mindy.getRtlBuildStr();
    printf("RTL Build: %s\n", versionStr.c_str());
    exit(1);

    // Ensure that both QSFP cables are connected
    if (Mindy.getQsfpStatus() != 3)
    {
        printf("One or both QSFP cables are disconnected.\n");
        exit(1);        
    }


    Mindy.setHostFrameDataAddr(0,0,0x100000000LL);
    Mindy.setHostFrameDataAddr(0,1,0x110000000LL);
    Mindy.setHostFrameDataAddr(1,0,0x120000000LL);
    Mindy.setHostFrameDataAddr(1,1,0x130000000LL);

    // Frame data buffers are 64K
    Mindy.setHostFrameDataSize(0x10000);

    Mindy.setHostMetaDataAddr(0, 0x1A0000000);
    Mindy.setHostMetaDataAddr(1, 0x1B0000000);

    // Meta data buffers are 512 bytes
    Mindy.setHostMetaDataSize(512);

    // A data frame is 64K
    Mindy.setFrameSize(0x10000);

    // Packet size is 4K
    Mindy.setPacketSize(4096);

    // 1 packet per ping-pong group
    Mindy.setPacketsPerGroup(1);

    // Remote frame data buffer
    Mindy.setRemoteFrameDataAddr(0xAAAA0000);
    Mindy.setRemoteFrameDataSize(0x10000);

    // Remote meta data buffer
    Mindy.setRemoteMetaDataAddr(0xBBBB0000);
    Mindy.setRemoteMetaDataSize(0x10000);

    // Remote frame counter
    Mindy.setRemoteFrameCounterAddr(0xDCCCC1234);

    Mindy.clearLocalFrameCounters();

    // Do nothing for a few milliseconds
    usleep(100000);

    for (int i=0; i<1000000000; i++)
    {
        Mindy.incrementLocalFrameCounter(0);
        usleep(350);
    }

    printf("Done!\n");
/*    
    
    bool ok;
   
    // Initialize ecdproxy interface
    cout << "Initializing ECDProxy\n";
    proxy.init("ecd_proxy.conf");

    // If the user wants to load the ECD bitstream into the FPGA...
    if (loadEcdFPGA)
    {
        cout << "Loading ECD bitstream \n";    
        ok = proxy.loadEcdBitstream();
        if (!ok)
        {
            printf("%s\n", proxy.getLoadError().c_str());
            exit(1);
        }
    }

    // If the user wants to load the master bitstream into the FPGA...
    if (loadMasterFPGA)
    {
        cout << "Loading Master bitstream \n";    
        ok = proxy.loadMasterBitstream();
        if (!ok)
        {
            printf("%s\n", proxy.getLoadError().c_str());
            exit(1);
        }
    }

    // Perform hot-reset, map PCI device resources, init UIO subsystem, etc.
    printf("startPCI the first time\n");
    proxy.startPCI();


    // Query the RTL design for revision information and display it
    string version = proxy.getMasterBitstreamVersion();
    cout << "RTL version is " << version << "\n";
    string date = proxy.getMasterBitstreamDate();
    cout << "RTL date: " << date << "\n";

    // Check to make sure that both QSFP channels are up
    proxy.checkQsfpStatus(0, true);
    cout << "QSFP Channel 0 is up\n";
    proxy.checkQsfpStatus(1, true);
    cout << "QSFP Channel 1 is up\n";

    // Start the data transfer
    proxy.prepareDataTransfer(CONTIG_BUFFER, CONTIG_BLOCKS);

    // And sleep forever
    cout << "Waiting for interrupts\n";
    while(1) sleep(999999);
*/
}
//=================================================================================================
