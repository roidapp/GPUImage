//
//  GPUImageMovieFrameInput.m
//  GPUImage
//
//  Created by Eric Yang on 6/12/14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import "GPUImageMovieFrameInput.h"
#import "GPUImageContext.h"
#import "GLProgram.h"
#import "GPUImageFilter.h"

NSString *const kGPUImageColorSwizzlingFragmentShaderString1 = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate).bgra;
 }
 );

@interface GPUImageMovieFrameInput()
{
    CVPixelBufferRef targetBuffer;
    GPUImageFramebuffer *firstInputFramebuffer;
    
    GLProgram *colorSwizzlingProgram;
    GLint colorSwizzlingPositionAttribute, colorSwizzlingTextureCoordinateAttribute;
    GLint colorSwizzlingInputTextureUniform;
    
    GPUImageContext *_movieWriterContext;
}
@end


@implementation GPUImageMovieFrameInput

- (id)init{
    self = [super init];
    if (self){
        _movieWriterContext = [GPUImageContext sharedImageProcessingContext];
        
        [_movieWriterContext useAsCurrentContext];
        
        if ([GPUImageContext supportsFastTextureUpload])
        {
            colorSwizzlingProgram = [_movieWriterContext programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
        }
        else
        {
            colorSwizzlingProgram = [_movieWriterContext programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageColorSwizzlingFragmentShaderString1];
        }
        
        if (!colorSwizzlingProgram.initialized)
        {
            [colorSwizzlingProgram addAttribute:@"position"];
            [colorSwizzlingProgram addAttribute:@"inputTextureCoordinate"];
            
            if (![colorSwizzlingProgram link])
            {
                NSString *progLog = [colorSwizzlingProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [colorSwizzlingProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [colorSwizzlingProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                colorSwizzlingProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        colorSwizzlingPositionAttribute = [colorSwizzlingProgram attributeIndex:@"position"];
        colorSwizzlingTextureCoordinateAttribute = [colorSwizzlingProgram attributeIndex:@"inputTextureCoordinate"];
        colorSwizzlingInputTextureUniform = [colorSwizzlingProgram uniformIndex:@"inputImageTexture"];
        
        [_movieWriterContext setContextShaderProgram:colorSwizzlingProgram];
        
        glEnableVertexAttribArray(colorSwizzlingPositionAttribute);
        glEnableVertexAttribArray(colorSwizzlingTextureCoordinateAttribute);
    }
    
    return self;
}

- (void)setPixelBuffer:(CVPixelBufferRef)buffer{
    targetBuffer = buffer;
}



- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
//    [newInputFramebuffer lock];
    //    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
    firstInputFramebuffer = newInputFramebuffer;
    //    });
}

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
//    int bufferHeight = (int) CVPixelBufferGetHeight(targetBuffer);
//    int bufferWidth = (int) CVPixelBufferGetWidth(targetBuffer);
//    
//    
//    
//    
//    if ([GPUImageContext supportsFastTextureUpload])
//    {
//        CVOpenGLESTextureRef targetTextureRef = NULL;
//        
//        //        if (captureAsYUV && [GPUImageContext deviceSupportsRedTextures])
//        if (CVPixelBufferGetPlaneCount(targetBuffer) > 0) // Check for YUV planar inputs to do RGB conversion
//        {
//            
//            CVReturn err;
//            // Y-plane
//            glActiveTexture(GL_TEXTURE);
//            if ([GPUImageContext deviceSupportsRedTextures])
//            {
//                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], targetBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &targetTextureRef);
//            }
//            else
//            {
//                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], targetBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &targetTextureRef);
//            }
//            if (err)
//            {
//                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
//            }
//            
//            GLint targetTextureName = CVOpenGLESTextureGetName(targetTextureRef);
//            
//            glBindFramebuffer(GL_FRAMEBUFFER, targetTextureName);
//            glViewport(0, 0, bufferWidth, bufferHeight);
//            
//            glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
//            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
//            
//            static const GLfloat textureCoordinates[] = {
//                0.0f, 0.0f,
//                1.0f, 0.0f,
//                0.0f, 1.0f,
//                1.0f, 1.0f,
//            };
//            
//            glActiveTexture(GL_TEXTURE);
//            glBindTexture(GL_TEXTURE_2D, luminanceTexture);
//            glUniform1i(yuvConversionLuminanceTextureUniform, 4);
//            
//            glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
//            
//            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
//            
//
//            
//            
////            CVPixelBufferUnlockBaseAddress(movieFrame, 0);
//            CFRelease(targetTextureRef);
//
//        }
    
    glFinish();
    
    // Render the frame with swizzled colors, so that they can be uploaded quickly as BGRA frames
//    [_movieWriterContext useAsCurrentContext];
    [self renderAtInternalSizeUsingFramebuffer:firstInputFramebuffer];
    
    glFlush();
}

//- (void)setFilterFBO;
//{
////    if (!movieFramebuffer)
////    {
////        [self createDataFBO];
////    }
////    
////    glBindFramebuffer(GL_FRAMEBUFFER, movieFramebuffer);
////    
////    glViewport(0, 0, (int)videoSize.width, (int)videoSize.height);
//    
//    
//    glBindFramebuffer(GL_FRAMEBUFFER, movieFramebuffer);
//    
//    glViewport(0, 0, (int)videoSize.width, (int)videoSize.height);
//}

- (CVOpenGLESTextureRef)createDataFBO;
{
//    glActiveTexture(GL_TEXTURE1);
//    glGenFramebuffers(1, &movieFramebuffer);
//    glBindFramebuffer(GL_FRAMEBUFFER, movieFramebuffer);
    
    CVOpenGLESTextureRef renderTexture = nil;
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/
        
        
//        CVPixelBufferPoolCreatePixelBuffer (NULL, [assetWriterPixelBufferInput pixelBufferPool], &targetBuffer);
        
        /* AVAssetWriter will use BT.601 conversion matrix for RGB to YCbCr conversion
         * regardless of the kCVImageBufferYCbCrMatrixKey value.
         * Tagging the resulting video file as BT.601, is the best option right now.
         * Creating a proper BT.709 video is not possible at the moment.
         */
        CVBufferSetAttachment(targetBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
        CVBufferSetAttachment(targetBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVAttachmentMode_ShouldPropagate);
        CVBufferSetAttachment(targetBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
        
        CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache],
                                                      targetBuffer,
                                                      NULL, // texture attributes
                                                      GL_TEXTURE_2D,
                                                      GL_RGBA, // opengl format
                                                      (int)CVPixelBufferGetWidth(targetBuffer),
                                                      (int)CVPixelBufferGetHeight(targetBuffer),
                                                      GL_BGRA, // native iOS format
                                                      GL_UNSIGNED_BYTE,
                                                      0,
                                                      &renderTexture);
        
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
    }
    else
    {
//        glGenRenderbuffers(1, &movieRenderbuffer);
//        glBindRenderbuffer(GL_RENDERBUFFER, movieRenderbuffer);
//        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, (int)videoSize.width, (int)videoSize.height);
//        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, movieRenderbuffer);
    }
    
	
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);
    
    return renderTexture;
}

- (void)renderAtInternalSizeUsingFramebuffer:(GPUImageFramebuffer *)inputFramebufferToUse;
{
//    [_movieWriterContext useAsCurrentContext];
//    [self setFilterFBO];
    
    CVOpenGLESTextureRef renderTexture = [self createDataFBO];
    
    [_movieWriterContext setContextShaderProgram:colorSwizzlingProgram];
    
    glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // This needs to be flipped to write out to video correctly
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    const GLfloat *textureCoordinates = [GPUImageFilter textureCoordinatesForRotation:kGPUImageNoRotation];
    
	glActiveTexture(GL_TEXTURE4);
	glBindTexture(GL_TEXTURE_2D, [inputFramebufferToUse texture]);
	glUniform1i(colorSwizzlingInputTextureUniform, 4);
    
    NSLog(@"Movie writer framebuffer: %@", inputFramebufferToUse);
    
    glVertexAttribPointer(colorSwizzlingPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
	glVertexAttribPointer(colorSwizzlingTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    CVPixelBufferRef destPixelBuffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault,
                        640,
                        360,
                        kCVPixelFormatType_32BGRA,
                        NULL,
                        &destPixelBuffer);
    
    CVPixelBufferLockBaseAddress(destPixelBuffer, 0);
    GLubyte *pixelData = (GLubyte *)CVPixelBufferGetBaseAddress(destPixelBuffer);
    glReadPixels(0, 0, 640, 360, GL_BGRA, GL_UNSIGNED_BYTE, pixelData);
    
    [self dumpBuffer:destPixelBuffer time:CFAbsoluteTimeGetCurrent()];
    
    glFinish();
    CFRelease(renderTexture);
}



- (NSInteger)nextAvailableTextureIndex{
    return 0;
}
- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex{
    
}
- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex{
    
}
- (CGSize)maximumOutputSize{
    return  CGSizeMake(480, 480);
}

- (void)endProcessing{
    
}
- (BOOL)shouldIgnoreUpdatesToThisTarget{
    return NO;
}
- (BOOL)enabled{
    return YES;
}
- (BOOL)wantsMonochromeInput{
    return NO;
}
- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue{
    
}

- (void)dumpBuffer:(CVPixelBufferRef)resultPixels time:(double)time {
    int w = CVPixelBufferGetWidth(resultPixels);
    int h = CVPixelBufferGetHeight(resultPixels);
    int r = CVPixelBufferGetBytesPerRow(resultPixels);
    int bytesPerPixel = r/w;
    
    static int i = 0;
    
    CVPixelBufferLockBaseAddress(resultPixels, 0);
    unsigned char *buffer = CVPixelBufferGetBaseAddress(resultPixels);
    CVPixelBufferUnlockBaseAddress(resultPixels, 0);
    if (buffer != NULL) {
        UIGraphicsBeginImageContext(CGSizeMake(w, h));
        
        CGContextRef c = UIGraphicsGetCurrentContext();
        
        unsigned char* data = CGBitmapContextGetData(c);
        if (data != NULL) {
            int maxY = h;
            for(int y = 0; y<maxY; y++) {
                for(int x = 0; x<w; x++) {
                    int offset = bytesPerPixel*((w*y)+x);
                    data[offset] = buffer[offset];     // R
                    data[offset+1] = buffer[offset+1]; // G
                    data[offset+2] = buffer[offset+2]; // B
                    data[offset+3] = buffer[offset+3]; // A
                }
            }
        }
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
        NSString *path = paths[0];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *name = [path stringByAppendingFormat:@"/frame_%lx_%d.jpg", (intptr_t)self,i++];
            [UIImageJPEGRepresentation(img, 0.5) writeToFile:name atomically:YES];
        });
        
        UIGraphicsEndImageContext();
    }
}


@end
