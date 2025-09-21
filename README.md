# Reproduction of memory leak in AVAudioConverter
This project demonstrates a memory leak when using `AVAudioConverter` in Objective-C with ARC enabled. The issue arises when input buffers are not released until the outer autorelease pool drains, leading to increased memory usage over time.

## MRE (Minimal Reproducible Example)
The core of the issue can be found in the `repro2.mm` file. This file contains a simple loop that creates input buffers and uses previously inicialized `AVAudioConverter` to convert them. After running the script with:
```bash
make repro2
```
you will observe that deallocations happen only when the outer autorelease pool drains, causing memory to pile up.

## Why does this happen?
These are only my assumptions because the code of `AVAudioConverter` is not open source, but based on the behavior observed:
1. `AVAudioConverter` seems to retain the input buffer returned from the input block. Or what is more likely, it creates temporary objects that retain the input buffer and autoreleases them.
2. These temporary objects are not deallocated until the next conversion call or until the outer autorelease pool drains. (suggesting that they are autoreleased)
3. This means that if you are creating many input buffers in a loop, they will pile up in memory until the outer autorelease pool drains.
4. Wrapping the conversion call in an inner `@autoreleasepool` forces these temporary objects to be deallocated immediately after the conversion, preventing memory buildup. But they are deallocated only after the next conversion call, not immediately after the conversion call. (which suggests that they are kept in converter internal state until next conversion call)

## Why is it an issue?
To understand why this is problematic you can review a broader example in `repro1.mm` which showcases more complex usage of the converter in realtime processing scenario. 
1. This behaviour is not even mentioned in the official documentation or any comments in header files of the framework.
2. The issue is in my opinion quite severe because in apple documentation we can see many recomendations to use `AVAudioConverter` and to avoid memory allocations and dealocations in processing loop. But these two recommendations are in conflict because we can clearly see that converter allocates the memory and expects autoreleasepool.
3. So even with reusing the same input buffer those temporary objects are still retained in the memory of higher level autorelease pool and they will pile up until the outer autorelease pool drains. (which can still cause memory leak but less noticable)
