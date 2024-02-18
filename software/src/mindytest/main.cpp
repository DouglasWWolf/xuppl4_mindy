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
