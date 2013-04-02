/*
 * x86_64 only example.
 * Codecaves from (and removes) the printf("After: \n") and injects code to set the
 * object's property (a) to 1234. 
 *
 *
 * Example output (when running: sudo ./example6 target1):
 * From target1:
 * Before:
 * 2013-04-01 22:43:35.075 target1[57374:707] <Test: 0x7f97ca40a400:>(a=15, b=9999.000000, c=4)
 * some string
 *
 * 2013-04-01 22:43:39.672 target1[57374:707] <Test: 0x7f97ca40a400:>(a=1234, b=9999.000000, c=4)
 * some string
 *
 */

#import <Foundation/Foundation.h>
#import <FeedFace/FeedFace.h>

int main(int argc, char *argv[])
{
    //input argv[1] = process name
    if (argc != 2) return 0;
    @autoreleasepool {
        FFProcess *Proc = [FFProcess processWithName: [NSString stringWithUTF8String: argv[1]]];
        
        FFClass *Cls = [Proc classWithName: @"Test" WantMetaClass: NO];
        uint64_t SetASelector = 0;
        for (FFMethod *method in Cls.methods)
        {
            if ([method.name isEqualToString: @"setA:"])
            {
                SetASelector = [Proc addressAtAddress: method.address]; //as the selector is first member in the struct (later will provide methods to receive internal addresses of members to make it simpler)
            }
        }
        
        if (!SetASelector) return 0;
        
        struct {
            uint8_t jump[2];
            uint64_t objc_msgSend;
            uint64_t setA;
            uint8_t bytes[24];
        } __attribute__((packed)) ModifierCode = {
            .jump = { 0xeb, 0x10 },
            .objc_msgSend = [Proc addressForSymbol: @"_objc_msgSend" InImage: @"libobjc.A.dylib"],
            .setA = SetASelector,
            .bytes = {
                0x48, 0x8b, 0x7d, 0xe8, 0x48, 0x8b, 0x35, 0xed, 0xff, 0xff, 0xff, 0x48, 0xc7, 0xc2, 0xd2, 0x04,
                0x00, 0x00, 0xff, 0x15, 0xd8, 0xff, 0xff, 0xff
            }
        };
        
        /*
         ModifierCode:
         jmp Skip
         objc_msgSend: .quad 0
         setA:         .quad 0
         Skip:
         
         //-[Test setA: 1234];
         movq -24(%rbp),%rdi //Test*a held at -24(%rbp)
         movq setA(%rip),%rsi
         movq $1234,%rdx
         call *objc_msgSend(%rip)
         */
        
        /*
         Codecave here:
         0000000100001bfb	leaq	478(%rip), %rdi ## literal pool for: After:
         0000000100001c02	movl	%eax, -88(%rbp)
         0000000100001c05	movb	$0, %al
         0000000100001c07	callq	0x100001c70 ## symbol stub for: _printf
         */
        
        FFCodeInjector *InjectedCode = [FFCodeInjector injectCodecaveToCode: [NSData dataWithBytes: &ModifierCode length: sizeof(ModifierCode)] FromAddress: [Proc relocateAddress: 0x100001bfb] InProcess: Proc];
        
        [InjectedCode enable];
    }
    
    return 0;
}
