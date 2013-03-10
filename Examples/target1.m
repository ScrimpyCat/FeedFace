#import <Foundation/Foundation.h>

@interface Test : NSObject
{
    int a;
    float b;
    NSNumber *c;
}

@property int a;
@property float b;
@property (copy) NSNumber *c;

@end

@implementation Test
@synthesize a, b, c;

-(id) init
{
    if ((self = [super init]))
    {
        a = 10;
        b = 0.2f;
        c = [NSNumber numberWithInt: 4];
    }
    
    return self;
}

-(NSString*) description
{
    return [NSString stringWithFormat: @"<%@: %p:>(a=%d, b=%f, c=%@)", [self class], self, self.a, self.b, self.c];
}

@end


const char Something[] = "some string";

int main(int argc, char *argv[])
{
    @autoreleasepool {
        Test *a = [[Test new] autorelease];
        a.a = 15;
        a.b = 9999.0f;
        
        printf("Before: \n");
        
        NSLog(@"%@", [a description]);
        puts(Something);
        
        scanf("%*[^\n]");
        printf("After: \n");
        
        NSLog(@"%@", [a description]);
        puts(Something);
    }
    
    return 0;
}
