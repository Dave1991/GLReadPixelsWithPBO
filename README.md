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
![image](https://user-images.githubusercontent.com/12179044/113651047-e03fd180-96c3-11eb-84ca-401202d0b8c2.png)
![image](https://user-images.githubusercontent.com/12179044/113651059-e5048580-96c3-11eb-9674-822268cacf4b.png)
