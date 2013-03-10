/*
 * Displays a log of all the classes that belong to the process.
 *
 *
 * Example output (when running: sudo ./example1 target1):
 * 2013-03-09 12:24:02.456 example1[11903:707] 0x1021722f0 : Test
 */

#import <Foundation/Foundation.h>
#import <FeedFace/FeedFace.h>


int main(int argc, char *argv[])
{
    //input argv[1] = process name
    if (argc != 2) return 0;
    @autoreleasepool {
        FFProcess *Proc = [FFProcess processWithName: [NSString stringWithUTF8String: argv[1]]];
        [Proc logOwnClasses];
    }
    
    return 0;
}
