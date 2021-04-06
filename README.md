# GLReadPixelsWithPBO
GLReadPixels with PBO demo for iOS

# Issue:
Using a pbo to read back the texture is slower than not using pbo, which is not in line with common sense.

# Reproduce:
1. Switch on USE_PBO macro in GLHelper.hpp
2. Use Time Profiler to profile.
3. Switch off USE_PBO macro.
4. Use Time Profiler to profile.
5. Compare the two traces and you will find glReadPixels spend more time when using pbo.
