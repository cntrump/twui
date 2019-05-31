/*
 Copyright 2011 Twitter, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this work except in compliance with the License.
 You may obtain a copy of the License in the LICENSE file, or at:
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <Foundation/Foundation.h>
#import "TUIGeometry.h"

@interface TUIImage : NSObject

+ (TUIImage *)imageNamed:(NSString *)name;
+ (TUIImage *)imageNamed:(NSString *)name cache:(BOOL)shouldCache;

+ (TUIImage *)imageWithData:(NSData *)data;
+ (TUIImage *)imageWithCGImage:(CGImageRef)imageRef;
+ (TUIImage *)imageWithCGImage:(CGImageRef)imageRef scale:(CGFloat)scale;
+ (TUIImage *)imageWithNSImage:(NSImage *)image;

+ (TUIImage *)_imageWithABImage:(id)abimage __attribute__((deprecated)); // don't use this

- (instancetype)initWithCGImage:(CGImageRef)imageRef;
- (instancetype)initWithCGImage:(CGImageRef)imageRef scale:(CGFloat)scale;

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGImageRef CGImage;

- (void)drawAtPoint:(CGPoint)point;                                                        // mode = kCGBlendModeNormal, alpha = 1.0
- (void)drawAtPoint:(CGPoint)point blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
- (void)drawInRect:(CGRect)rect;                                                           // mode = kCGBlendModeNormal, alpha = 1.0
- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;

- (TUIImage *)stretchableImageWithLeftCapWidth:(NSInteger)leftCapWidth topCapHeight:(NSInteger)topCapHeight;
- (TUIImage *)stretchableImageWithEdgeInsets:(TUIEdgeInsets)insets;

- (NSData *)dataRepresentationForType:(NSString *)type compression:(CGFloat)compressionQuality;

@property (nonatomic, readonly) NSInteger leftCapWidth;   // default is 0. if non-zero, horiz. stretchable. right cap is calculated as width - leftCapWidth - 1
@property (nonatomic, readonly) NSInteger topCapHeight;   // default is 0. if non-zero, vert. stretchable. bottom cap is calculated as height - topCapWidth - 1
@property (nonatomic, readonly) TUIEdgeInsets capEdgeInsets;

@end

@interface TUIImage (AppKit)
@property (nonatomic, readonly) id nsImage; // NSImage *
@end

TUI_EXTERN_C_BEGIN

NSData *TUIImagePNGRepresentation(TUIImage *image);
NSData *TUIImageJPEGRepresentation(TUIImage *image, CGFloat compressionQuality);

CGImageRef TUICreateImageRefForNameAndScaleFactor(NSString *name, CGFloat scaleFactor, BOOL shouldCache, CGFloat *imageScaleFactor);

TUI_EXTERN_C_END

#import "TUIImage+Drawing.h"
