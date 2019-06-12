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

#import "TUIImageView.h"
#import "TUIImage.h"

@implementation TUIImageView

- (instancetype)initWithImage:(TUIImage *)image
{
    if (self = [self initWithFrame:image ? CGRectMake(0, 0, image.size.width, image.size.height) : CGRectZero]) {
        _image = image;
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = NO;
        _image = nil;
    }

    return self;
}

- (TUIImage *)image
{
	return _image;
}

- (void)setImage:(TUIImage *)i
{
	_image = i;
	[self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
	[super drawRect:rect];
	if (_image == nil)
		return;
    
    [_image drawInRect:rect];
}

- (CGSize)sizeThatFits:(CGSize)size {
	return _image.size;
}

@end
