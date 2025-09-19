#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface ExampleClass : NSObject
@property (nonatomic, strong) NSString *name;
- (instancetype)initWithName:(NSString *)name;
@end

@implementation ExampleClass
- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        _name = name;
        NSLog(@"✅ %@ created", name);
    }
    return self;
}
- (void)dealloc {
    NSLog(@"🗑️ %@ deallocated", self.name);
}
@end

typedef void(^AudioReceiverBlock)(const AudioBufferList *bufferList, AVAudioFrameCount frameCount, AVAudioTime *timestamp);

@interface MinimalRecorder : NSObject
@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) AVAudioSinkNode *sinkNode;
@property (nonatomic, copy) AudioReceiverBlock receiverBlock;
@end

@implementation MinimalRecorder

- (instancetype)initWithReceiverBlock:(AudioReceiverBlock)receiverBlock {
    if (self = [super init]) {
        self.receiverBlock = receiverBlock;
        self.engine = [[AVAudioEngine alloc] init];
        
        self.sinkNode = [[AVAudioSinkNode alloc] initWithReceiverBlock:^OSStatus(const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, const AudioBufferList *inputData) {
            
            AVAudioTime *time = [[AVAudioTime alloc] initWithAudioTimeStamp:timestamp sampleRate:44100];
            self.receiverBlock(inputData, frameCount, time);
            
            return noErr;
        }];
        
        [self.engine attachNode:self.sinkNode];
        [self.engine connect:self.engine.inputNode to:self.sinkNode format:nil];
    }
    return self;
}

- (void)start {
    NSError *error;
    if (![self.engine startAndReturnError:&error]) {
        NSLog(@"Failed to start engine: %@", error);
    }
}

- (void)stop {
    [self.engine stop];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        MinimalRecorder *recorder = [[MinimalRecorder alloc] initWithReceiverBlock:^(const AudioBufferList *bufferList, AVAudioFrameCount frameCount, AVAudioTime *timestamp) {

            /// 1. Scoped autorelease pool - object will be released immediately after this block
            @autoreleasepool {
                ExampleClass *obj1 = [[ExampleClass alloc] initWithName:@"Object#1"];
                [obj1 autorelease];

                /// 1.5 - object that is NOT autoreleased, will leak
                ExampleClass *obj1b = [[ExampleClass alloc] initWithName:@"Object#1b"];
                // obj1b is NOT autoreleased, so it will leak
            }

            /// 2. Autorelease - object will be released when pool drains
            /// As we can see it never gets deallocated which might imply that 
            /// audio thread does not have an autorelease pool
            ExampleClass *obj2 = [[ExampleClass alloc] initWithName:@"Object#2"];
            [obj2 autorelease];

            /// 3. No autorelease pool - object will obviosly leak
            ExampleClass *obj3 = [[ExampleClass alloc] initWithName:@"Object#3"];

            /// 4. Manual release
            ExampleClass *obj4 = [[ExampleClass alloc] initWithName:@"Object#4"];
            [obj4 release];
        }];
        
        NSLog(@"Starting recorder...");
        [recorder start];
        sleep(1);
        NSLog(@"Stopping recorder...");
        [recorder stop];
        
    }
    return 0;
}
