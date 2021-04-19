//
//  GLHelper.cpp
//  GLReadPixelsWithPBO
//
//  Created by forrestlin on 2021/4/1.
//

#include "GLHelper.hpp"
#include <stdio.h>
#include <cstdlib>

#define USE_PBO_CB 0

typedef struct {
    GLfloat position[3];
} Vertex3;

GLHelper::GLHelper(int width, int height, GLuint shareTextureID):mWidth(width), mHeight(height) {
    if (shareTextureID > 0) {
        // use CVOpenGLESTextureRef
        mOffscreenTextureID = shareTextureID;
    } else {
        glGenTextures(1, &mOffscreenTextureID);
    }
    glBindTexture(GL_TEXTURE_2D, mOffscreenTextureID);
    if (shareTextureID <= 0) {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, mWidth, mHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    }
    
    glGenFramebuffers(1, &mFrameBufferID);
    glBindFramebuffer(GL_FRAMEBUFFER, mFrameBufferID);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, mOffscreenTextureID, 0);
    
    InitVBO();
    
    InitProgram();
    
    glViewport(0, 0, width, height);
        
}

void GLHelper::InitVBO() {
    glGenBuffers(1, &mVertexBufferID);
    
    glBindBuffer(GL_ARRAY_BUFFER, mVertexBufferID);
    
    static const Vertex3 vertices[] = {
        {{-0.5f, -0.5f, 0.0}}, // lower left corner
        {{ 0.5f, -0.5f, 0.0}}, // lower right corner
        {{-0.5f,  0.5f, 0.0}}, // upper left corner
    };
    // 创建 资源 ( context )
    glBufferData(GL_ARRAY_BUFFER,   // 缓存块 类型
                 sizeof(vertices),  // 创建的 缓存块 尺寸
                 vertices,          // 要绑定的顶点数据
                 GL_STATIC_DRAW);   // 缓存块 用途
    
    glGenBuffers(PBO_COUNT, mPboIds);
    size_t size = 4 * mWidth * mHeight;
    for (int i = 0; i < PBO_COUNT; ++i) {
        glBindBuffer(GL_PIXEL_PACK_BUFFER, mPboIds[i]);
        glBufferData(GL_PIXEL_PACK_BUFFER, size, 0, GL_STREAM_READ);
    }
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
}

void GLHelper::InitProgram() {
    mVertexShaderID = glCreateShader(GL_VERTEX_SHADER);
    const GLchar *vertexSource = "#version 100 \n"
                                "attribute vec4 v_Position; \n"
                                "void main(void) { \n"
                                    "gl_Position = v_Position;\n"
                                "}";
    glShaderSource(mVertexShaderID,
                   1,
                   &vertexSource,
                   NULL);
    glCompileShader(mVertexShaderID);
    
    mFragmentShaderID = glCreateShader(GL_FRAGMENT_SHADER);
    const GLchar *fragmentSource = "#version 100 \n"
                                    "void main(void) { \n"
                                    "gl_FragColor = vec4(1, 1, 1, 1); \n"
                                    "}";
    glShaderSource(mFragmentShaderID,
                   1,
                   &fragmentSource,
                   NULL);
    glCompileShader(mFragmentShaderID);
    
    mProgramID = glCreateProgram();
    glAttachShader(mProgramID, mVertexShaderID);
    glAttachShader(mProgramID, mFragmentShaderID);
    
    glLinkProgram(mProgramID);
    
    GLint linkStatus;
    glGetProgramiv(mProgramID, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        GLint infoLength;
        
        glGetProgramiv(mProgramID, GL_INFO_LOG_LENGTH, &infoLength);
        if (infoLength > 0) {
            GLchar *infoLog = (GLchar *)malloc(sizeof(GLchar) * infoLength);
            glGetProgramInfoLog(mProgramID, infoLength, NULL, infoLog);
            printf("%s\n", infoLog);
            free(infoLog);
        }
    }
    glDeleteShader(mVertexShaderID);
    glDeleteShader(mFragmentShaderID);
}

void GLHelper::DoRender() {
    glBindTexture(GL_TEXTURE_2D, mOffscreenTextureID);
    glBindFramebuffer(GL_FRAMEBUFFER, mFrameBufferID);
    
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, mOffscreenTextureID, 0);
    
    glClearColor(0.4, 0.7, 0.9, 1.f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glEnableVertexAttribArray(0);
    
    glVertexAttribPointer(0,
                          sizeof(Vertex3) / sizeof(GLfloat),
                          GL_FLOAT,
                          GL_FALSE,
                          sizeof(Vertex3),
                          (const GLvoid *) offsetof(Vertex3, position));
    
    glUseProgram(mProgramID);
    
    glDrawArrays(GL_TRIANGLES,
                 0,
                 3);
#if USE_PBO_CB
    if (mPboEnable) {
        for(auto it = mCb.begin(); it != mCb.end(); ) {
            if(--it->remainFrames <= 0) {
                mTimer.start();
                size_t size = 4 * mWidth * mHeight;
                glBindBuffer(GL_PIXEL_PACK_BUFFER, it->pbo);
                GLchar *pixels = static_cast<GLchar*>(glMapBufferRange(GL_PIXEL_PACK_BUFFER, 0, size, GL_MAP_READ_BIT));
                mTimer.stop();
                it->readTime += mTimer.getElapsedTimeInMilliSec();
                it->cb(mWidth, mHeight, size, pixels, it->readTime);
                glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
                glDeleteBuffers(1, &it->pbo);
                it = mCb.erase(it);
            } else {
                ++it;
            }
        }
    }
#endif
}

void GLHelper::GetPixels(GetPixelsCallback getPixelsCallback) {
    size_t size = 4 * mWidth * mHeight;
    
    if (mPboEnable) {
#if USE_PBO_CB
        mTimer.start();
        GLuint pboBuffer;
        glGenBuffers(1, &pboBuffer);
        glBindBuffer(GL_PIXEL_PACK_BUFFER, pboBuffer);
        glBufferData(GL_PIXEL_PACK_BUFFER, size, 0, GL_STREAM_READ);
        glReadPixels(0, 0, mWidth, mHeight, GL_RGBA, GL_UNSIGNED_BYTE, 0);
        mTimer.stop();
        double readTime = mTimer.getElapsedTimeInMilliSec();
        mCb.emplace_back(2, pboBuffer, std::move(getPixelsCallback), readTime);
#else
        mTimer.start();
        int index = mCurrentPboIndex % PBO_COUNT, nextIndex = (mCurrentPboIndex + 1) % PBO_COUNT;
        glBindBuffer(GL_PIXEL_PACK_BUFFER, mPboIds[index]);
        glReadPixels(0, 0, mWidth, mHeight, GL_RGBA, GL_UNSIGNED_BYTE, 0);
        
        glBindBuffer(GL_PIXEL_PACK_BUFFER, mPboIds[nextIndex]);
        GLchar *pixels = static_cast<GLchar *>(glMapBufferRange(GL_PIXEL_PACK_BUFFER, 0, size, GL_MAP_READ_BIT));
        mTimer.stop();
        double readTime = mTimer.getElapsedTimeInMilliSec();
        getPixelsCallback(mWidth, mHeight, size, pixels, readTime);
        glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
        mCurrentPboIndex = nextIndex;
#endif
        glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
    } else {
        mTimer.start();
        GLchar *pixels = (GLchar *)malloc(size);
        glReadPixels(0, 0, mWidth, mHeight, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid *)pixels);
        mTimer.stop();
        double readTime = mTimer.getElapsedTimeInMilliSec();
        getPixelsCallback(mWidth, mHeight, size, pixels, readTime);
        free(pixels);
    }
}


