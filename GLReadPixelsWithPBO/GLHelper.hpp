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

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#define USE_PBO 0

using GetPixelsCallback = std::function<void(int width, int height, uint64_t byteSize, GLchar *pixels)>;
class GLHelper {
public:
    GLHelper(int width, int height);
    void DoRender();
    void GetPixels(GetPixelsCallback getPixelsCallback);
    
private:
    GLuint mRenderBufferID = 0;
    GLuint mFrameBufferID = 0;
    GLuint mVertexBufferID = 0;
    GLuint mVertexShaderID = 0;
    GLuint mFragmentShaderID = 0;
    GLuint mProgramID = 0;
    int mWidth = 0;
    int mHeight = 0;
    
    void InitVBO();
    void InitProgram();
    
    struct ReadBackCbs
    {
        ReadBackCbs(int remainFrames, GLuint pbo, GetPixelsCallback cb)
            : remainFrames(remainFrames), pbo(pbo), cb(std::move(cb)) {}
        int remainFrames;
        GLuint pbo;
        GetPixelsCallback cb;
    };
    std::list<ReadBackCbs> mCb;
};

#endif /* GLHelper_hpp */
