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
            @autoreleasepool {
                ExampleClass *obj = [[ExampleClass alloc] initWithName:@"AudioFrame"];

            }
        }];
        
        NSLog(@"Starting recorder...");
        [recorder start];
        sleep(5);
        NSLog(@"Stopping recorder...");
        [recorder stop];
        
    }
    return 0;
}
