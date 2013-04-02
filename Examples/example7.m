/*
 * x86_64 only example.
 * Adds a logger to a method. The logger prints "[<object_class: object_pointer> selector]"
 * and then calls the method.
 *
 *
 * Example output (when running: sudo ./example7 target1 NSObject 0 dealloc):
 * From target1:
 * Before:
 * 2013-04-03 01:48:36.812 target1[59386:707] <Test: 0x7fca20408a50:>(a=15, b=9999.000000, c=4)
 * some string
 *
 * After:
 * 2013-04-03 01:48:41.976 target1[59386:707] <Test: 0x7fca20408a50:>(a=15, b=9999.000000, c=4)
 * some string
 * 2013-04-03 01:48:41.978 target1[59386:707] [<Test: 0x7fca20408a50> dealloc]
 *
 */

#import <Foundation/Foundation.h>
#import <FeedFace/FeedFace.h>

int main(int argc, char *argv[])
{
    //input argv[1] = process name
    //input argv[2] = class name
    //input argv[3] = 0/1 (whether it's a class method or not)
    //input argv[4] = method
    if (argc != 5) return 0;
    @autoreleasepool {
        FFProcess *Proc = [FFProcess processWithName: [NSString stringWithUTF8String: argv[1]]];
        
        FFClass *StrCls = [Proc classWithName: @"NSString" WantMetaClass: YES];
        uint64_t StrSelector = 0;
        for (FFMethod *method in StrCls.methods)
        {
            if ([method.name isEqualToString: @"stringWithUTF8String:"])
            {
                StrSelector = [Proc addressAtAddress: method.address]; //as the selector is first member in the struct (later will provide methods to receive internal addresses)
            }
        }
        
        if (!StrSelector) return 0;
        
        
        NSString *LogMethod = [NSString stringWithUTF8String: argv[4]];
        FFMethod *TargetMethod = 0;
        for (FFMethod *method in ((FFClass*)[Proc classWithName: [NSString stringWithUTF8String: argv[2]] WantMetaClass: [[NSString stringWithUTF8String: argv[3]] boolValue]]).methods)
        {
            if ([method.name isEqualToString: LogMethod])
            {
                TargetMethod = method;
            }
        }
        
        if (!TargetMethod) return 0;
        
        
        struct {
            uint8_t jump[2];
            
            uint64_t objc_msgSend;
            uint64_t NSLog;
            uint64_t sel_getName;
            uint64_t object_getClassName;
            uint64_t imp;
            
            uint64_t stringWithUTF8String;
            
            uint64_t NSString_class;
            
            char FormatString[14];
            
            uint8_t bytes[297];
        } __attribute__((packed)) LoggerCode = {
            .jump = { 0xeb, 0x46 },
            
            .objc_msgSend = [Proc addressForSymbol: @"_objc_msgSend" InImage: @"libobjc.A.dylib"],
            .NSLog = [Proc addressForSymbol: @"_NSLog" InImage: @"Foundation"],
            .sel_getName = [Proc addressForSymbol: @"_sel_getName" InImage: @"libobjc.A.dylib"],
            .object_getClassName = [Proc addressForSymbol: @"_object_getClassName" InImage: @"libobjc.A.dylib"],
            .imp = TargetMethod.imp,
            
            .stringWithUTF8String = StrSelector,
            
            .NSString_class = ((FFClass*)[Proc classWithName: @"NSString" WantMetaClass: NO]).address,
            
            .FormatString = "[<%s: %p> %s]",
            
            .bytes = {
                0x48, 0x81, 0xec, 0xb8, 0x00, 0x00, 0x00, 0x66, 0x0f, 0x7f, 0x44, 0x24, 0x30, 0x66, 0x0f, 0x7f,
                0x4c, 0x24, 0x40, 0x66, 0x0f, 0x7f, 0x54, 0x24, 0x50, 0x66, 0x0f, 0x7f, 0x5c, 0x24, 0x60, 0x66,
                0x0f, 0x7f, 0x64, 0x24, 0x70, 0x66, 0x0f, 0x7f, 0xac, 0x24, 0x80, 0x00, 0x00, 0x00, 0x66, 0x0f,
                0x7f, 0xb4, 0x24, 0x90, 0x00, 0x00, 0x00, 0x66, 0x0f, 0x7f, 0xbc, 0x24, 0xa0, 0x00, 0x00, 0x00,
                0x48, 0x89, 0x84, 0x24, 0xb0, 0x00, 0x00, 0x00, 0x48, 0x89, 0x3c, 0x24, 0x48, 0x89, 0x74, 0x24,
                0x08, 0x48, 0x89, 0x54, 0x24, 0x10, 0x48, 0x89, 0x4c, 0x24, 0x18, 0x4c, 0x89, 0x44, 0x24, 0x20,
                0x4c, 0x89, 0x4c, 0x24, 0x28, 0x48, 0x83, 0xec, 0x10, 0x48, 0x8b, 0x3d, 0x7a, 0xff, 0xff, 0xff,
                0x48, 0x8b, 0x35, 0x6b, 0xff, 0xff, 0xff, 0x48, 0x8d, 0x15, 0x74, 0xff, 0xff, 0xff, 0xff, 0x15,
                0x36, 0xff, 0xff, 0xff, 0x48, 0x89, 0x44, 0x24, 0x08, 0x48, 0x8b, 0x7c, 0x24, 0x10, 0xff, 0x15,
                0x3e, 0xff, 0xff, 0xff, 0x48, 0x89, 0x04, 0x24, 0x48, 0x8b, 0x7c, 0x24, 0x18, 0xff, 0x15, 0x27,
                0xff, 0xff, 0xff, 0x48, 0x89, 0xc1, 0x48, 0x8b, 0x7c, 0x24, 0x08, 0x48, 0x8b, 0x34, 0x24, 0x48,
                0x8b, 0x54, 0x24, 0x10, 0xff, 0x15, 0x08, 0xff, 0xff, 0xff, 0x48, 0x83, 0xc4, 0x10, 0x66, 0x0f,
                0x6f, 0x44, 0x24, 0x30, 0x66, 0x0f, 0x6f, 0x4c, 0x24, 0x40, 0x66, 0x0f, 0x6f, 0x54, 0x24, 0x50,
                0x66, 0x0f, 0x6f, 0x5c, 0x24, 0x60, 0x66, 0x0f, 0x6f, 0x64, 0x24, 0x70, 0x66, 0x0f, 0x6f, 0xac,
                0x24, 0x80, 0x00, 0x00, 0x00, 0x66, 0x0f, 0x6f, 0xb4, 0x24, 0x90, 0x00, 0x00, 0x00, 0x66, 0x0f,
                0x6f, 0xbc, 0x24, 0xa0, 0x00, 0x00, 0x00, 0x48, 0x8b, 0x84, 0x24, 0xb0, 0x00, 0x00, 0x00, 0x48,
                0x8b, 0x3c, 0x24, 0x48, 0x8b, 0x74, 0x24, 0x08, 0x48, 0x8b, 0x54, 0x24, 0x10, 0x48, 0x8b, 0x4c,
                0x24, 0x18, 0x4c, 0x8b, 0x44, 0x24, 0x20, 0x4c, 0x8b, 0x4c, 0x24, 0x28, 0x48, 0x81, 0xc4, 0xb8,
                0x00, 0x00, 0x00, 0xff, 0x25, 0xb1, 0xfe, 0xff, 0xff
            }
        };
        
        
        /*
         Logger code:
         .macro PushArgumentRegisters
         subq $$0xb8,%rsp
         
         //SSE class and vector count
         movdqa %xmm0,0x30(%rsp)
         movdqa %xmm1,0x40(%rsp)
         movdqa %xmm2,0x50(%rsp)
         movdqa %xmm3,0x60(%rsp)
         movdqa %xmm4,0x70(%rsp)
         movdqa %xmm5,0x80(%rsp)
         movdqa %xmm6,0x90(%rsp)
         movdqa %xmm7,0xa0(%rsp)
         movq %rax,0xb0(%rsp)
         
         //INTEGER class
         movq %rdi,(%rsp)
         movq %rsi,0x8(%rsp)
         movq %rdx,0x10(%rsp)
         movq %rcx,0x18(%rsp)
         movq %r8,0x20(%rsp)
         movq %r9,0x28(%rsp)
         .endmacro
         
         .macro PopArgumentRegisters
         //SSE class and vector count
         movdqa 0x30(%rsp),%xmm0
         movdqa 0x40(%rsp),%xmm1
         movdqa 0x50(%rsp),%xmm2
         movdqa 0x60(%rsp),%xmm3
         movdqa 0x70(%rsp),%xmm4
         movdqa 0x80(%rsp),%xmm5
         movdqa 0x90(%rsp),%xmm6
         movdqa 0xa0(%rsp),%xmm7
         movq 0xb0(%rsp),%rax
         
         //INTEGER class
         movq (%rsp),%rdi
         movq 0x8(%rsp),%rsi
         movq 0x10(%rsp),%rdx
         movq 0x18(%rsp),%rcx
         movq 0x20(%rsp),%r8
         movq 0x28(%rsp),%r9
         
         addq $$0xb8,%rsp
         .endmacro
         
         .text
         .globl _Logger
         _Logger:
         jmp Skip
         //functions
         objc_msgSend:        .quad 0
         NSLog:               .quad 0
         sel_getName:         .quad 0
         object_getClassName: .quad 0
         
         imp:                 .quad 0
         
         //selectors
         stringWithUTF8String:   .quad 0
         
         //classes
         NSString_class: .quad 0
         
         //strings
         FormatString:   .asciz "[<%s: %p> %s]"
         
         Skip:
         PushArgumentRegisters
         subq $0x10,%rsp
         
         //[NSString stringWithUTF8String: "[<%s: %p> %s]"];
         movq NSString_class(%rip),%rdi
         movq stringWithUTF8String(%rip),%rsi
         leaq FormatString(%rip),%rdx
         call *objc_msgSend(%rip)
         movq %rax,0x08(%rsp)
         
         //object_getClassName(self);
         movq 0x10(%rsp),%rdi
         call *object_getClassName(%rip)
         movq %rax,(%rsp)
         
         //sel_getName(_cmd);
         movq 0x18(%rsp),%rdi
         call *sel_getName(%rip)
         
         //NSLog(@"[<%s: %p> %s]", object_getClassName(self), self, sel_getName(_cmd));
         movq %rax,%rcx
         movq 0x08(%rsp),%rdi
         movq (%rsp),%rsi
         movq 0x10(%rsp),%rdx
         call *NSLog(%rip)
         
         addq $0x10,%rsp
         PopArgumentRegisters
         
         
         //Call normal method
         jmp *imp(%rip)
         */
        
        
        //Don't actually need to initialize it like this, as the block's could access all this data directly anyway.
        FFInjector *Logger = [FFInjector inject: [NSData dataWithBytes: &LoggerCode length: sizeof(LoggerCode)] AdditionalInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                                         TargetMethod, @"method",
                                                                                                                         nil] InProcess: Proc];
        
        Logger.enabler = ^(FFInjector *injector){
            NSData *Code = injector.data;
            FFMethod *Method = [injector.additionalInfo objectForKey: @"method"];
            
            FFMemory *Memory = [FFMemory memoryInProcess: injector.process WithSize: [Code length] Flags: VM_FLAGS_ANYWHERE AllocationOptions: FFAllocate | FFFreeWhenDone AtAddress: 0];
            Memory.maxProtection = VM_PROT_ALL;
            Memory.protection = VM_PROT_ALL;
            
            [injector.process write: Code ToAddress: Memory.address];
            
            injector.additionalInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                       Method, @"method",
                                       [NSValue valueWithAddress: Method.imp], @"imp",
                                       Memory, @"memory",
                                       nil];
            
            Method.imp = Memory.address;
        };
        
        Logger.disabler = ^(FFInjector *injector){
            NSDictionary *Info = injector.additionalInfo;
            FFMethod *Method = [Info objectForKey: @"method"];
            Method.imp = [[Info objectForKey: @"imp"] addressValue];
        };
        
        
        [Logger enable];
        printf("Press [enter] to disable logging");
        scanf("%*[^\n]");
        [Logger disable];
    }
    
    return 0;
}
