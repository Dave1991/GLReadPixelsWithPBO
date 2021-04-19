//
//  GLHelper.hpp
//  GLReadPixelsWithPBO
//
//  Created by forrestlin on 2021/4/1.
//

#ifndef GLHelper_hpp
#define GLHelper_hpp

#include <stdio.h>
#include <functional>
#include <list>
#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>

#include "Timer.h"

using GetPixelsCallback = std::function<void(int width, int height, uint64_t byteSize, GLchar *pixels, double readTime)>;
const int PBO_COUNT = 2;
class GLHelper {
public:
    GLHelper(int width, int height, GLuint shareTextureID = 0);
    void DoRender();
    void GetPixels(GetPixelsCallback getPixelsCallback);
    void SetPBOEnable(bool pboEnable) { mPboEnable = pboEnable; }
    
private:
    GLuint mRenderBufferID = 0;
    GLuint mFrameBufferID = 0;
    GLuint mVertexBufferID = 0;
    GLuint mVertexShaderID = 0;
    GLuint mFragmentShaderID = 0;
    GLuint mProgramID = 0;
    GLuint mOffscreenTextureID = 0;
    int mWidth = 0;
    int mHeight = 0;
    bool mPboEnable = false;
    GLuint mPboIds[PBO_COUNT];
    int mCurrentPboIndex = 0;
    Timer mTimer;
    
    void InitVBO();
    void InitProgram();
    
    struct ReadBackCbs
    {
        ReadBackCbs(int remainFrames, GLuint pbo, GetPixelsCallback cb, double readTime)
            : remainFrames(remainFrames), pbo(pbo), cb(std::move(cb)), readTime(readTime) {}
        int remainFrames;
        GLuint pbo;
        GetPixelsCallback cb;
        double readTime;
    };
    std::list<ReadBackCbs> mCb;
};

#endif /* GLHelper_hpp */
