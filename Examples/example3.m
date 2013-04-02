/*
 * Locates the string "some string" and replaces it with "new string".
 *
 *
 * Example output (when running: sudo ./example3 target1):
 * From target1:
 * Before:
 * 2013-03-09 12:31:36.783 target1[12005:707] <Test: 0x7b622a30:>(a=15, b=9999.000000, c=4)
 * some string
 *
 * After:
 * 2013-03-09 12:40:18.654 target1[12005:707] <Test: 0x7b622a30:>(a=15, b=9999.000000, c=4)
 * new string
 */

#import <Foundation/Foundation.h>
#import <FeedFace/FeedFace.h>


int main(int argc, char *argv[])
{
    //input argv[1] = process name
    if (argc != 2) return 0;
    @autoreleasepool {
        FFProcess *Proc = [FFProcess processWithName: [NSString stringWithUTF8String: argv[1]]];
        
        const mach_vm_address_t Addr = [[[Proc findCString: "some string"] objectAtIndex: 0] addressValue];
        [Proc writeData: "new string" OfSize: 11 ToAddress: Addr];
    }
    
    return 0;
}
