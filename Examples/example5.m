/*
 * x86_64 only example.
 * Stops it from printing the description.
 *
 * From:
 * NSLog(@"%@", [a description]);
 *
 * 0000000100001c30	callq	0x100001c94 ## symbol stub for: _objc_msgSend
 * to
 * xorq %rax,%rax ; nop ; nop (nops will be automatically added by the framework)
 *
 * so it instead passes nil.
 * NSLog(@"%@", nil);
 *
 *
 * Example output (when running: sudo ./example1 target1):
 * From target1:
 * Before:
 * 2013-03-31 16:09:05.767 target1[53148:707] <Test: 0x7fafa1c029f0:>(a=15, b=9999.000000, c=4)
 * some string
 *
 * After:
 * 2013-03-31 16:09:09.035 target1[53148:707] (null)
 * some string
 */

#import <Foundation/Foundation.h>
#import <FeedFace/FeedFace.h>

int main(int argc, char *argv[])
{
    //input argv[1] = process name
    if (argc != 2) return 0;
    @autoreleasepool {
        FFProcess *Proc = [FFProcess processWithName: [NSString stringWithUTF8String: argv[1]]];
        
        FFCodeInjector *InjectedCode = [FFCodeInjector injectCode: [NSData dataWithBytes: (uint8_t[]){
            0x48, 0x31, 0xc0 //xorq %rax,%rax
        } length: 3] ToAddress: [Proc relocateAddress: 0x100001c30] InProcess: Proc];
        
        [InjectedCode enable];
    }
    
    return 0;
}
