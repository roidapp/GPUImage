//
//  GPUImageMovieFrameOutput.m
//  GPUImage
//
//  Created by Eric Yang on 6/12/14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import "GPUImageMovieFrameOutput.h"
#import "GPUImageVideoCamera.h"
#import "GPUImageFilter.h"

@interface GPUImageMovieFrameOutput() {
    GLuint luminanceTexture, chrominanceTexture;
    
    GLProgram *yuvConversionProgram;
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
    const GLfloat *_preferredConversion;
    
    BOOL isFullYUVRange;
    
    int imageBufferWidth, imageBufferHeight;
}

@end

@implementation GPUImageMovieFrameOutput

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self yuvConversionSetup];
    }
    
    return self;
}

- (void)processPixelBuffer:(CVPixelBufferRef)movieFrame withSampleTime:(CMTime)currentSampleTime
{
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        
        int bufferHeight = (int) CVPixelBufferGetHeight(movieFrame);
        int bufferWidth = (int) CVPixelBufferGetWidth(movieFrame);
        
        CFTypeRef colorAttachments = CVBufferGetAttachment(movieFrame, kCVImageBufferYCbCrMatrixKey, NULL);
        if (colorAttachments != NULL)
        {
            if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo)
            {
                if (isFullYUVRange)
                {
                    _preferredConversion = kColorConversion601FullRange;
                }
                else
                {
                    _preferredConversion = kColorConversion601;
                }
            }
            else
            {
                _preferredConversion = kColorConversion709;
            }
        }
        else
        {
            if (isFullYUVRange)
            {
                _preferredConversion = kColorConversion601FullRange;
            }
            else
            {
                _preferredConversion = kColorConversion601;
            }
            
        }
        
        if ([GPUImageContext supportsFastTextureUpload])
        {
            CVOpenGLESTextureRef luminanceTextureRef = NULL;
            CVOpenGLESTextureRef chrominanceTextureRef = NULL;
            
            //        if (captureAsYUV && [GPUImageContext deviceSupportsRedTextures])
            if (CVPixelBufferGetPlaneCount(movieFrame) > 0) // Check for YUV planar inputs to do RGB conversion
            {
                
                if ( (imageBufferWidth != bufferWidth) && (imageBufferHeight != bufferHeight) )
                {
                    imageBufferWidth = bufferWidth;
                    imageBufferHeight = bufferHeight;
                }
                
                CVReturn err;
                // Y-plane
                glActiveTexture(GL_TEXTURE4);
                if ([GPUImageContext deviceSupportsRedTextures])
                {
                    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
                }
                else
                {
                    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
                }
                if (err)
                {
                    NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
                }
                
                luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
                glBindTexture(GL_TEXTURE_2D, luminanceTexture);
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                
                // UV-plane
                glActiveTexture(GL_TEXTURE5);
                if ([GPUImageContext deviceSupportsRedTextures])
                {
                    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
                }
                else
                {
                    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
                }
                if (err)
                {
                    NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
                }
                
                chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
                glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                
                //            if (!allTargetsWantMonochromeData)
                //            {
                [self convertYUVToRGBOutput];
                //            }
                
                for (id<GPUImageInput> currentTarget in targets)
                {
                    NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                    NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                    [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
                    [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
                }
                
                [outputFramebuffer unlock];
                
                for (id<GPUImageInput> currentTarget in targets)
                {
                    NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                    NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                    [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
                }
                
                CVPixelBufferUnlockBaseAddress(movieFrame, 0);
                [[GPUImageContext sharedImageProcessingContext] CVOpenGLESTextureRelease:luminanceTextureRef];
                [[GPUImageContext sharedImageProcessingContext] CVOpenGLESTextureRelease:chrominanceTextureRef];
            }
            else
            {
                // TODO: Mesh this with the new framebuffer cache
                //            CVPixelBufferLockBaseAddress(movieFrame, 0);
                //
                //            CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, coreVideoTextureCache, movieFrame, NULL, GL_TEXTURE_2D, GL_RGBA, bufferWidth, bufferHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &texture);
                //
                //            if (!texture || err) {
                //                NSLog(@"Movie CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);
                //                NSAssert(NO, @"Camera failure");
                //                return;
                //            }
                //
                //            outputTexture = CVOpenGLESTextureGetName(texture);
                //            //        glBindTexture(CVOpenGLESTextureGetTarget(texture), outputTexture);
                //            glBindTexture(GL_TEXTURE_2D, outputTexture);
                //            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                //            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                //            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                //            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                //
                //            for (id<GPUImageInput> currentTarget in targets)
                //            {
                //                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                //                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                //
                //                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
                //                [currentTarget setInputTexture:outputTexture atIndex:targetTextureIndex];
                //
                //                [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
                //            }
                //
                //            CVPixelBufferUnlockBaseAddress(movieFrame, 0);
                //            CVOpenGLESTextureCacheFlush(coreVideoTextureCache, 0);
                //            CFRelease(texture);
                //
                //            outputTexture = 0;
            }
        }
        else
        {
            // Upload to texture
            CVPixelBufferLockBaseAddress(movieFrame, 0);
            
            outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(bufferWidth, bufferHeight) textureOptions:self.outputTextureOptions onlyTexture:YES];
            
            glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
            // Using BGRA extension to pull in video frame data directly
            glTexImage2D(GL_TEXTURE_2D,
                         0,
                         self.outputTextureOptions.internalFormat,
                         bufferWidth,
                         bufferHeight,
                         0,
                         self.outputTextureOptions.format,
                         self.outputTextureOptions.type,
                         CVPixelBufferGetBaseAddress(movieFrame));
            
            for (id<GPUImageInput> currentTarget in targets)
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
            }
            
            [outputFramebuffer unlock];
            
            for (id<GPUImageInput> currentTarget in targets)
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
            }
            CVPixelBufferUnlockBaseAddress(movieFrame, 0);
        }
    });
}

- (void)yuvConversionSetup;
{
    if ([GPUImageContext supportsFastTextureUpload])
    {
        runSynchronouslyOnVideoProcessingQueue(^{
            [GPUImageContext useImageProcessingContext];
            
            _preferredConversion = kColorConversion709;
            isFullYUVRange       = YES;
            yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVFullRangeConversionForLAFragmentShaderString];
            
            if (!yuvConversionProgram.initialized)
            {
                [yuvConversionProgram addAttribute:@"position"];
                [yuvConversionProgram addAttribute:@"inputTextureCoordinate"];
                
                if (![yuvConversionProgram link])
                {
                    NSString *progLog = [yuvConversionProgram programLog];
                    NSLog(@"Program link log: %@", progLog);
                    NSString *fragLog = [yuvConversionProgram fragmentShaderLog];
                    NSLog(@"Fragment shader compile log: %@", fragLog);
                    NSString *vertLog = [yuvConversionProgram vertexShaderLog];
                    NSLog(@"Vertex shader compile log: %@", vertLog);
                    yuvConversionProgram = nil;
                    NSAssert(NO, @"Filter shader link failed");
                }
            }
            
            yuvConversionPositionAttribute = [yuvConversionProgram attributeIndex:@"position"];
            yuvConversionTextureCoordinateAttribute = [yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
            yuvConversionLuminanceTextureUniform = [yuvConversionProgram uniformIndex:@"luminanceTexture"];
            yuvConversionChrominanceTextureUniform = [yuvConversionProgram uniformIndex:@"chrominanceTexture"];
            yuvConversionMatrixUniform = [yuvConversionProgram uniformIndex:@"colorConversionMatrix"];
            
            [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
            
            glEnableVertexAttribArray(yuvConversionPositionAttribute);
            glEnableVertexAttribArray(yuvConversionTextureCoordinateAttribute);
        });
    }
}

- (void)convertYUVToRGBOutput;
{
    [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(imageBufferWidth, imageBufferHeight) onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
	glActiveTexture(GL_TEXTURE4);
	glBindTexture(GL_TEXTURE_2D, luminanceTexture);
	glUniform1i(yuvConversionLuminanceTextureUniform, 4);
    
    glActiveTexture(GL_TEXTURE5);
	glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
	glUniform1i(yuvConversionChrominanceTextureUniform, 5);
    
    glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);
    
    glVertexAttribPointer(yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
	glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [[GPUImageContext sharedImageProcessingContext] flush];
}

@end
