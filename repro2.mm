#import <Foundation/Foundation.h>
#include <Foundation/NSObjCRuntime.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

@interface LoggedPCMBuffer : AVAudioPCMBuffer
@property (nonatomic, strong) NSString *bufferName;
- (instancetype)initWithPCMFormat:(AVAudioFormat *)format frameCapacity:(AVAudioFrameCount)frameCapacity bufferName:(NSString *)name;
@end

@implementation LoggedPCMBuffer
- (instancetype)initWithPCMFormat:(AVAudioFormat *)format frameCapacity:(AVAudioFrameCount)frameCapacity bufferName:(NSString *)name {
    self = [super initWithPCMFormat:format frameCapacity:frameCapacity];
    if (self) {
        _bufferName = name;
        NSLog(@"🟢 %@", name);
    }
    return self;
}

- (void)dealloc {
    NSLog(@"🔴 %@", self.bufferName);
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"Testing AVAudioConverter memory leak\n");
        
        AVAudioFormat *inputFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                      sampleRate:44100.0f
                                                                        channels:1
                                                                     interleaved:NO];
        
        AVAudioFormat *outputFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                       sampleRate:48000.0f
                                                                         channels:1
                                                                      interleaved:NO];
        
        AVAudioConverter *converter = [[AVAudioConverter alloc] initFromFormat:inputFormat toFormat:outputFormat];
        
        // Test multiple conversions with the SAME converter
        for (int i = 0; i < 5; i++) {
            NSLog(@"Conversion %d:", i + 1);
            
            LoggedPCMBuffer *inputBuffer = [[LoggedPCMBuffer alloc] initWithPCMFormat:inputFormat
                                                                        frameCapacity:512
                                                                           bufferName:[NSString stringWithFormat:@"Input-%d", i + 1]];

            NSLog(@"Retain count before: %lu", (unsigned long)CFGetRetainCount((__bridge CFTypeRef)inputBuffer));
            // Scope to ensure inputBuffer is not retained outside this block
            {
                inputBuffer.frameLength = 512;

                int outputFrameCount = 557;
                LoggedPCMBuffer *outputBuffer = [[LoggedPCMBuffer alloc] initWithPCMFormat:outputFormat
                                                                            frameCapacity:outputFrameCount
                                                                                bufferName:[NSString stringWithFormat:@"Output-%d", i + 1]];
                
                NSLog(@"Retain count before in scope: %lu", (unsigned long)CFGetRetainCount((__bridge CFTypeRef)inputBuffer));
                
                AVAudioConverterInputBlock inputBlock = ^AVAudioBuffer *_Nullable(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus *outStatus) {
                    *outStatus = AVAudioConverterInputStatus_HaveData;
                    return inputBuffer;
                };
                
                NSError *error = nil;

                // Autorelease here partially mitigates the leak
                // means that converter creates temporary objects that retain inputBuffer
                // AND keeps at least one of them alive until next conversion call which causes slight delay in inputBuffer deallocation
                // When not using autoreleasepool here, inputBuffer is never deallocated and they pile up in memory until outer autoreleasepool drains
                // @autoreleasepool { // Uncomment to see this weird behavior
                    [converter convertToBuffer:outputBuffer error:&error withInputFromBlock:inputBlock];
                // }

            }
            
            NSLog(@"Retain count after: %lu", (unsigned long)CFGetRetainCount((__bridge CFTypeRef)inputBuffer));
        }
        NSLog(@"\nTest complete. Watch for deallocation logs...");
        
    }
    
    return 0;
}