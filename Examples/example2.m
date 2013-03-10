/*
 * Displays a log of all the classes a process references.
 *
 *
 * Example output (when running: sudo ./example1 target1):
 * 2013-03-09 12:26:49.192 example2[11940:a07] 0x7fff7ba2ef68 : NSNumber
 * 2013-03-09 12:26:49.193 example2[11940:a07] 0x7fff7ba2daf0 : NSString
 * 2013-03-09 12:26:49.194 example2[11940:a07] 0x1021722f0 : Test
 */

#import <Foundation/Foundation.h>
#import <FeedFace/FeedFace.h>


int main(int argc, char *argv[])
{
    //input argv[1] = process name
    if (argc != 2) return 0;
    @autoreleasepool {
        FFProcess *Proc = [FFProcess processWithName: [NSString stringWithUTF8String: argv[1]]];
        [Proc logReferencedClasses];
    }
    
    return 0;
}
