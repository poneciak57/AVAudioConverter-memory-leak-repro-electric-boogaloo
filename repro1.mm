#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LoggedPCMBuffer : AVAudioPCMBuffer
@property (nonatomic, strong) NSString *bufferName;
- (instancetype)initWithPCMFormat:(AVAudioFormat *)format frameCapacity:(AVAudioFrameCount)frameCapacity bufferName:(NSString *)name;
@end

@implementation LoggedPCMBuffer
- (instancetype)initWithPCMFormat:(AVAudioFormat *)format frameCapacity:(AVAudioFrameCount)frameCapacity bufferName:(NSString *)name {
    self = [super initWithPCMFormat:format frameCapacity:frameCapacity];
    if (self) {
        _bufferName = name;
        NSLog(@"🟢 PCM Buffer '%@' allocated (capacity: %u frames)", name, frameCapacity);
    }
    return self;
}

- (void)dealloc {
    NSLog(@"🔴 PCM Buffer '%@' deallocated", self.bufferName);
}
@end

typedef void(^AudioReceiverBlock)(const AudioBufferList *bufferList, AVAudioFrameCount frameCount, AVAudioTime *timestamp);

@interface MinimalRecorder : NSObject
@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) AVAudioSinkNode *sinkNode;
@property (nonatomic, strong) AVAudioConverter *audioConverter;
@property (nonatomic, strong) AVAudioFormat *inputFormat;
@property (nonatomic, strong) AVAudioFormat *outputFormat;
@property (nonatomic, copy) AudioReceiverBlock receiverBlock;
@end

@implementation MinimalRecorder

- (instancetype)initWithReceiverBlock:(AudioReceiverBlock)receiverBlock {
    if (self = [super init]) {
        self.receiverBlock = receiverBlock;
        self.engine = [[AVAudioEngine alloc] init];
        
        // Create formats (mimicking NativeAudioRecorder)
        float deviceSampleRate = 44100.0f;
        float outputSampleRate = 48000.0f; // Different to trigger conversion path
        
        self.inputFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                            sampleRate:deviceSampleRate
                                                            channels:1
                                                        interleaved:NO];
        self.outputFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                            sampleRate:outputSampleRate
                                                            channels:1
                                                        interleaved:NO];
        self.audioConverter = [[AVAudioConverter alloc] initFromFormat:self.inputFormat toFormat:self.outputFormat];
        
        __weak MinimalRecorder *weakSelf = self;
        self.sinkNode = [[AVAudioSinkNode alloc] initWithReceiverBlock:^OSStatus(const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, const AudioBufferList *inputData) {
            return [weakSelf processAudioInput:inputData withFrameCount:frameCount atTimestamp:timestamp];
        }];
        
        [self.engine attachNode:self.sinkNode];
        [self.engine connect:self.engine.inputNode to:self.sinkNode format:nil];
    }
    return self;
}

- (OSStatus)processAudioInput:(const AudioBufferList *)inputData
               withFrameCount:(AVAudioFrameCount)frameCount
                  atTimestamp:(const AudioTimeStamp *)timestamp {
    
    float inputSampleRate = self.inputFormat.sampleRate;
    float outputSampleRate = self.outputFormat.sampleRate;
    
    AVAudioTime *time = [[AVAudioTime alloc] initWithAudioTimeStamp:timestamp sampleRate:outputSampleRate];
    
    // This is the critical part from NativeAudioRecorder that creates inputBuffer
    if (inputSampleRate != outputSampleRate) {
        // Create inputBuffer - this is where the memory issue occurs
        LoggedPCMBuffer *inputBuffer = [[LoggedPCMBuffer alloc] initWithPCMFormat:self.inputFormat
                                                                      frameCapacity:frameCount
                                                                         bufferName:[NSString stringWithFormat:@"InputBuffer-%u", frameCount]];
        
        
        int outputFrameCount = frameCount * outputSampleRate / inputSampleRate;
        
        LoggedPCMBuffer *outputBuffer = [[LoggedPCMBuffer alloc] initWithPCMFormat:self.audioConverter.outputFormat
                                                                       frameCapacity:outputFrameCount
                                                                          bufferName:[NSString stringWithFormat:@"OutputBuffer-%u", frameCount]];
        
        NSError *error = nil;
        
        // This lambda captures inputBuffer - potential memory issue here
        AVAudioConverterInputBlock inputBlock = ^AVAudioBuffer *_Nullable(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus *outStatus) {
            NSLog(@"🔄 Lambda called with inputBuffer: %@", inputBuffer.bufferName);
            *outStatus = AVAudioConverterInputStatus_HaveData;
            return inputBuffer; // inputBuffer is captured by the block
        };
        
        /// ERROR: This line causes the issue
        [self.audioConverter convertToBuffer:outputBuffer error:&error withInputFromBlock:inputBlock];
        
        self.receiverBlock(outputBuffer.audioBufferList, outputBuffer.frameLength, time);
        
        return kAudioServicesNoError;
    }
    
    // Direct path (no conversion needed)
    self.receiverBlock(inputData, frameCount, time);
    return kAudioServicesNoError;
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
            NSLog(@"ReceiverBlock: %u frames", frameCount);
        }];
        
        NSLog(@"Starting recorder to reproduce inputBuffer memory issue...");
        [recorder start];
        sleep(1); // Let it run for 1 second to see multiple conversions
        NSLog(@"Stopping recorder...");
        [recorder stop];
        
        NSLog(@"Recording stopped. Watch for buffer deallocation logs...");
        
    }
    return 0;
}
