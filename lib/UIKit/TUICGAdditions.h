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

enum _TUICGRoundedRectCorner {
	TUICGRoundedRectCornerTopLeft = 1 << 0,
	TUICGRoundedRectCornerTopRight = 1 << 1,
	TUICGRoundedRectCornerBottomLeft = 1 << 2,
	TUICGRoundedRectCornerBottomRight = 1 << 3,
	TUICGRoundedRectCornerTop = TUICGRoundedRectCornerTopLeft | TUICGRoundedRectCornerTopRight,
	TUICGRoundedRectCornerBottom = TUICGRoundedRectCornerBottomLeft | TUICGRoundedRectCornerBottomRight,
	TUICGRoundedRectCornerAll = TUICGRoundedRectCornerTopLeft | TUICGRoundedRectCornerTopRight | TUICGRoundedRectCornerBottomLeft | TUICGRoundedRectCornerBottomRight,
	TUICGRoundedRectCornerNone = 0,
};

typedef NSUInteger TUICGRoundedRectCorner;

#import <Foundation/Foundation.h>

@class TUIView;

#if defined(__cplusplus)
extern "C" {
#endif

CGContextRef TUICreateOpaqueGraphicsContext(CGSize size);
CGContextRef TUICreateGraphicsContext(CGSize size);
CGContextRef TUICreateGraphicsContextWithOptions(CGSize size, BOOL opaque);
CGImageRef TUICreateCGImageFromBitmapContext(CGContextRef ctx);

CGPathRef TUICGPathCreateRoundedRect(CGRect rect, CGFloat radius);
CGPathRef TUICGPathCreateRoundedRectWithCorners(CGRect rect, CGFloat radius, TUICGRoundedRectCorner corners);
void CGContextAddRoundRect(CGContextRef context, CGRect rect, CGFloat radius);
void CGContextClipToRoundRect(CGContextRef context, CGRect rect, CGFloat radius);

CGRect ABScaleToFill(CGSize s, CGRect r);
CGRect ABScaleToFit(CGSize s, CGRect r);
CGRect ABRectCenteredInRect(CGRect a, CGRect b);
CGRect ABRectRoundOrigin(CGRect f);
CGRect ABIntegralRectWithSizeCenteredInRect(CGSize s, CGRect r);

void CGContextFillRoundRect(CGContextRef context, CGRect rect, CGFloat radius);
void CGContextDrawLinearGradientBetweenPoints(CGContextRef context, CGPoint a, CGFloat color_a[4], CGPoint b, CGFloat color_b[4]);

CGContextRef TUIGraphicsGetCurrentContext(void);
void TUIGraphicsPushContext(CGContextRef context);
void TUIGraphicsPopContext(void);

NSImage *TUIGraphicsContextGetImage(CGContextRef ctx);

void TUIGraphicsBeginImageContext(CGSize size);
// as in the iOS docs, "if you specify a value of 0.0, the scale factor is set to the scale factor of the device’s main screen."
void TUIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale);
NSImage *TUIGraphicsGetImageFromCurrentImageContext(void);
void TUIGraphicsEndImageContext(void);

NSImage *TUIGraphicsGetImageForView(TUIView *view);

NSImage *TUIGraphicsDrawAsImage(CGSize size, void(^draw)(void));

/**
 Draw drawing as a PDF
 @param optionalMediaBox may be NULL
 @returns NSData encapsulating the PDF drawing, suitable for writing to a file or the pasteboard
 */
NSData *TUIGraphicsDrawAsPDF(CGRect *optionalMediaBox, void(^draw)(CGContextRef));

#if defined(__cplusplus)
}
#endif
