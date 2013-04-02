/*
 * Removes the instance method from a class so instances are then forced to use
 * the method from a super (if it's an overriden method).
 *
 *
 * Example output (when running: sudo ./example4 target1 Test description):
 * From target1:
 * Before:
 * 2013-03-09 15:25:00.148 target1[13281:707] <Test: 0x7f8ccb40a3e0:>(a=15, b=9999.000000, c=4)
 * some string
 *
 * After:
 * 2013-03-09 15:25:20.731 target1[13281:707] <Test: 0x7f8ccb40a3e0>
 * some string
 */

#import <Foundation/Foundation.h>
#import <FeedFace/FeedFace.h>


int main(int argc, char *argv[])
{
    //input argv[1] = process name
    //input argv[2] = class name
    //input argv[3] = method name
    if (argc != 4) return 0;
    @autoreleasepool {
        FFProcess *Proc = [FFProcess processWithName: [NSString stringWithUTF8String: argv[1]]];
        
        FFClass *Cls = [Proc classWithName: [NSString stringWithUTF8String: argv[2]] WantMetaClass: NO];
        NSMutableArray *Methods = [[Cls.methods mutableCopy] autorelease];
        
        
        NSString *MethodName = [NSString stringWithUTF8String: argv[3]];
        
        //Remove method from class
        __block NSUInteger Index = NSUIntegerMax;
        [Methods enumerateObjectsUsingBlock: ^(FFMethod *obj, NSUInteger idx, BOOL *stop){
            if ([obj.name isEqualToString: MethodName])
            {
                Index = idx;
                *stop = YES;
            }
        }];
        
        if (Index != NSUIntegerMax)
        {
            [Methods removeObjectAtIndex: Index];
            Cls.methods = Methods;
            
            //Remove method from cache (if needed)
            Index = NSUIntegerMax;
            NSMutableArray *Methods = [[Cls.cache.buckets mutableCopy] autorelease];
            [Methods enumerateObjectsUsingBlock: ^(FFMethod *obj, NSUInteger idx, BOOL *stop){
                if ([obj.name isEqualToString: MethodName])
                {
                    Index = idx;
                    *stop = YES;
                }
            }];
            
            if (Index != NSUIntegerMax)
            {
                [Methods replaceObjectAtIndex: Index withObject: Index == 0 ? [Methods lastObject] : [Methods objectAtIndex: 0]];
                
                Cls.cache.buckets = Methods;
            }
        }
    }
    
    return 0;
}
