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

extern NSString * const TUIAttributedStringBackgroundColorAttributeName;
extern NSString * const TUIAttributedStringBackgroundFillStyleName;
extern NSString * const TUIAttributedStringPreDrawBlockName;

typedef void (^TUIAttributedStringPreDrawBlock)(NSAttributedString *attributedString, NSRange substringRange, CGRect rects[], CFIndex rectCount);

typedef enum {		
	TUILineBreakModeWordWrap = 0,
	TUILineBreakModeCharacterWrap,
	TUILineBreakModeClip,
	TUILineBreakModeHeadTruncation,
	TUILineBreakModeTailTruncation,
	TUILineBreakModeMiddleTruncation,
} TUILineBreakMode;

typedef enum {
	TUIBaselineAdjustmentAlignBaselines = 0,
	TUIBaselineAdjustmentAlignCenters,
	TUIBaselineAdjustmentNone,
} TUIBaselineAdjustment;

typedef enum {
	TUITextAlignmentLeft = 0,
	TUITextAlignmentCenter,
	TUITextAlignmentRight,
	TUITextAlignmentJustified,
} TUITextAlignment;

typedef enum {
	TUIBackgroundFillStyleInline = 0,
	TUIBackgroundFillStyleBlock,
} TUIBackgroundFillStyle;

@interface TUIAttributedString : NSMutableAttributedString

+ (TUIAttributedString *)stringWithString:(NSString *)string;

@end

@interface NSMutableAttributedString (TUIAdditions)

// write-only properties, reading will return nil
@property (nonatomic, strong) NSFont *font;
@property (nonatomic, strong) NSColor *color;
@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, assign) TUIBackgroundFillStyle backgroundFillStyle;
@property (nonatomic, strong) NSShadow *shadow;
@property (nonatomic, assign) TUITextAlignment alignment; // setting this will set lineBreakMode to word wrap, use setAlignment:lineBreakMode: for more control
@property (nonatomic, assign) CGFloat kerning;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, copy) NSString *text;

- (void)setAlignment:(TUITextAlignment)alignment lineBreakMode:(TUILineBreakMode)lineBreakMode;

- (NSRange)_stringRange;
- (void)setFont:(NSFont *)font inRange:(NSRange)range;
- (void)setColor:(NSColor *)color inRange:(NSRange)range;
- (void)setBackgroundColor:(NSColor *)color inRange:(NSRange)range;
- (void)setBackgroundFillStyle:(TUIBackgroundFillStyle)fillStyle inRange:(NSRange)range;
- (void)setPreDrawBlock:(TUIAttributedStringPreDrawBlock)block inRange:(NSRange)range; // the pre-draw block is called before the text or text background has been drawn
- (void)setShadow:(NSShadow *)shadow inRange:(NSRange)range;
- (void)setKerning:(CGFloat)f inRange:(NSRange)range;
- (void)setLineHeight:(CGFloat)f inRange:(NSRange)range;

@end

@interface NSShadow (TUIAdditions)

+ (NSShadow *)shadowWithRadius:(CGFloat)radius offset:(CGSize)offset color:(NSColor *)color;

@end

extern NSParagraphStyle *ABNSParagraphStyleForTextAlignment(TUITextAlignment alignment);
