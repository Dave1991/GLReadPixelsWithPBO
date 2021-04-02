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

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

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
};

#endif /* GLHelper_hpp */
