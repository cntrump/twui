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

#import "ExampleTableViewCell.h"

@interface ExampleTableViewCell () {
    TUILabel *_textLabel;
}

@end

@implementation ExampleTableViewCell

- (id)initWithStyle:(TUITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	if((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.supportsConstraints = YES;
        _textLabel = [[TUILabel alloc] init];
        _textLabel.font = [TUIFont systemFontOfSize:12];
        _textLabel.textColor = [TUIColor colorWithRGB:0 alpha:0.85];
        _textLabel.layoutName = @"textLabel";
        [self addSubview:_textLabel];
        [_textLabel addLayoutConstraint:[TUILayoutConstraint constraintWithAttribute:TUILayoutConstraintAttributeMinX relativeTo:@"superview" attribute:TUILayoutConstraintAttributeMinX offset:16]];
        [_textLabel addLayoutConstraint:[TUILayoutConstraint constraintWithAttribute:TUILayoutConstraintAttributeMidY relativeTo:@"superview" attribute:TUILayoutConstraintAttributeMidY]];

		NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 91, 22)];
		[textField.cell setUsesSingleLineMode:YES];
		[textField.cell setScrollable:YES];

		self.textFieldContainer = [[TUIViewNSViewContainer alloc] initWithNSView:textField];
		self.textFieldContainer.backgroundColor = TUIColor.blueColor;
        self.textFieldContainer.layoutName = @"textField";
		[self addSubview:self.textFieldContainer];
        [self.textFieldContainer addLayoutConstraint:[TUILayoutConstraint constraintWithAttribute:TUILayoutConstraintAttributeMaxX relativeTo:@"superview" attribute:TUILayoutConstraintAttributeMaxX offset:-16]];
        [self.textFieldContainer addLayoutConstraint:[TUILayoutConstraint constraintWithAttribute:TUILayoutConstraintAttributeMidY relativeTo:@"superview" attribute:TUILayoutConstraintAttributeMidY]];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
}

- (NSAttributedString *)attributedString
{
	return _textLabel.attributedString;
}

- (void)setAttributedString:(NSAttributedString *)attributedString
{
	_textLabel.attributedString = attributedString;
    [_textLabel sizeToFit];

	[self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
	CGRect b = self.bounds;
	CGContextRef ctx = TUIGraphicsGetCurrentContext();
	
	if(self.selected) {
		// selected background
		CGContextSetRGBFillColor(ctx, .87, .87, .87, 1);
		CGContextFillRect(ctx, b);
	} else {
		// light gray background
		CGContextSetRGBFillColor(ctx, .97, .97, .97, 1);
		CGContextFillRect(ctx, b);
		
		// emboss
		CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.9); // light at the top
		CGContextFillRect(ctx, CGRectMake(0, b.size.height-1, b.size.width, 1));
		CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.08); // dark at the bottom
		CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
	}
}

@end
