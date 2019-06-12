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

#import "TUINSWindow.h"
#import "TUICGAdditions.h"
#import "TUINSView.h"
#import "TUINSView+Hyperfocus.h"

@interface NSView (TUIWindowAdditions)
@end
@implementation NSView (TUIWindowAdditions)

- (void)findViewsOfClass:(Class)cls addTo:(NSMutableArray *)array
{
	if([self isKindOfClass:cls])
		[array addObject:self];
	for(NSView *v in [self subviews])
		[v findViewsOfClass:cls addTo:array];
}

@end

@implementation NSWindow (TUIWindowAdditions)

- (NSArray *)TUINSViews
{
	NSMutableArray *array = [NSMutableArray array];
	[[self contentView] findViewsOfClass:[TUINSView class] addTo:array];
	return array;
}

- (void)setEverythingNeedsDisplay
{
	[[self contentView] setNeedsDisplay:YES];
	[[self TUINSViews] makeObjectsPerformSelector:@selector(setEverythingNeedsDisplay)];
}

NSInteger makeFirstResponderCount = 0;

- (BOOL)tui_containsObjectInResponderChain:(NSResponder *)r
{
	NSResponder *responder = [self firstResponder];
	do {
		if(r == responder)
			return YES;
	} while((responder = [responder nextResponder]));
	return NO;
}

- (NSInteger)futureMakeFirstResponderRequestToken
{
	return makeFirstResponderCount;
}

- (BOOL)tui_makeFirstResponder:(NSResponder *)aResponder
{
	++makeFirstResponderCount; // cool if it overflows
	if([aResponder respondsToSelector:@selector(initialFirstResponder)])
		aResponder = ((TUIResponder *)aResponder).initialFirstResponder;
	return [self makeFirstResponder:aResponder];
}

- (BOOL)makeFirstResponder:(NSResponder *)aResponder withFutureRequestToken:(NSInteger)token
{
	if(token == makeFirstResponderCount) {
		return [self tui_makeFirstResponder:aResponder];
	} else {
		return NO;
	}
}

- (BOOL)makeFirstResponderIfNotAlreadyInResponderChain:(NSResponder *)responder
{
	if(![self tui_containsObjectInResponderChain:responder])
		return [self tui_makeFirstResponder:responder];
	return NO;
}

- (BOOL)makeFirstResponderIfNotAlreadyInResponderChain:(NSResponder *)responder withFutureRequestToken:(NSInteger)token
{
	if(![self tui_containsObjectInResponderChain:responder])
		return [self makeFirstResponder:responder withFutureRequestToken:token];
	return NO;
}


@end


@interface TUINSWindowFrame : NSView
{
	@public
	TUINSWindow __weak *w;
}
@end

@implementation TUINSWindowFrame

- (void)drawRect:(CGRect)r
{
	[w drawBackground:r];
}

@end

@interface TUINSWindow ()
{
    struct {
        unsigned int fixedContentSize: 1;
    } _flags;
}

@end

@implementation TUINSWindow

@synthesize nsView;
@synthesize altUINSViews;

+ (NSInteger)windowMask
{
    return NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable |
            NSWindowStyleMaskTitled | NSWindowStyleMaskUnifiedTitleAndToolbar | NSFullSizeContentViewWindowMask;
}

- (CGFloat)toolbarHeight
{
	return 22;
}

- (BOOL)useCustomContentView
{
	return NO;
}

- (instancetype)initWithContentRect:(CGRect)rect
{
	if (self = [super initWithContentRect:rect styleMask:self.class.windowMask backing:NSBackingStoreBuffered defer:YES]) {
		self.collectionBehavior = NSWindowCollectionBehaviorParticipatesInCycle | NSWindowCollectionBehaviorManaged;
		self.acceptsMouseMovedEvents = YES;

        self.titleVisibility = NSWindowTitleHidden;
        self.titlebarAppearsTransparent = YES;

		CGRect b = self.contentView.frame;

		if (self.useCustomContentView) {
			self.opaque = NO;
			self.backgroundColor = NSColor.clearColor;
			self.hasShadow = YES;
			
			TUINSWindowFrame *contentView = [[TUINSWindowFrame alloc] initWithFrame:b];
			contentView->w = self;
			self.contentView = contentView;
		} else {
			self.opaque = YES;
            self.hasShadow = YES;
		}

		b.size.height -= (self.toolbarHeight -22);
		
		nsView = [[TUINSView alloc] initWithFrame:b];
		nsView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
		[[self contentView] addSubview:nsView];
		
		altUINSViews = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag
{
    BOOL needsUpdateTransform = !CGSizeEqualToSize(frameRect.size, self.frame.size);
    [super setFrame:frameRect display:flag];
    
    if (needsUpdateTransform && _flags.fixedContentSize) {
        [self updateContentTransform];
    }
}

- (void)setFixedContentSize:(CGSize)fixedContentSize
{
    _fixedContentSize = fixedContentSize;
    _flags.fixedContentSize = (_fixedContentSize.width && _fixedContentSize.height);
    if (_flags.fixedContentSize) {
        [self updateContentTransform];
    }
}

- (void)updateContentTransform
{
    if (!_flags.fixedContentSize) {
        return;
    }
    
    CGSize windowSize = self.frame.size;
    CGFloat windowRatio = windowSize.width / windowSize.height;
    CGSize contentSize = _fixedContentSize;
    CGFloat contentRatio = contentSize.width / contentSize.height;
    
    CGFloat scale = 1;
    CGSize targetSize = windowSize;
    if (contentRatio > windowRatio) {
        scale = windowSize.height / contentSize.height;
        targetSize = CGSizeMake(windowSize.height * contentRatio, windowSize.height);
    } else {
        scale = windowSize.width / contentSize.width;
        targetSize = CGSizeMake(windowSize.width, windowSize.width / contentRatio);
    }
    
    nsView.rootView.transform = CGAffineTransformScale(CGAffineTransformIdentity, scale, scale);
    
    CGRect targetFrame = ABRectCenteredInRect(CGRectMake(0, 0, targetSize.width, targetSize.height), nsView.bounds);
    targetFrame.origin.y = windowSize.height - targetSize.height;
    nsView.rootView.frame = CGRectIntegral(targetFrame);
}

- (void)drawBackground:(CGRect)rect
{
	// overridden by subclasses
	CGContextRef ctx = TUIGraphicsGetCurrentContext();
	CGRect f = [self frame];
	CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
	CGContextFillRect(ctx, f);
}

- (void)becomeKeyWindow
{
	[super becomeKeyWindow];
}

- (void)resignKeyWindow
{
	[super resignKeyWindow];
	[nsView endHyperFocus:YES];
}

- (BOOL)canBecomeKeyWindow
{
	return YES;
}

@end

TUI_EXTERN_C_BEGIN

static NSScreen *ABScreenForProposedWindowRect(NSRect proposedRect)
{
	NSScreen *screen = [NSScreen mainScreen];
	
	NSPoint center = NSMakePoint(proposedRect.origin.x + proposedRect.size.width * 0.5, proposedRect.origin.y + proposedRect.size.height * 0.5);
	for(NSScreen *s in [NSScreen screens]) {
		NSRect r = [s visibleFrame];
		if(NSPointInRect(center, r))
			screen = s;
	}
	
	return screen;
}

NSRect ABClampProposedRectToScreen(NSRect proposedRect)
{
	NSScreen *screen = ABScreenForProposedWindowRect(proposedRect);
	NSRect screenRect = [screen visibleFrame];

	if(proposedRect.origin.y < screenRect.origin.y) {
		proposedRect.origin.y = screenRect.origin.y;
	}

	if(proposedRect.origin.y + proposedRect.size.height > screenRect.origin.y + screenRect.size.height) {
		proposedRect.origin.y = screenRect.origin.y + screenRect.size.height - proposedRect.size.height;
	}

	if(proposedRect.origin.x + proposedRect.size.width > screenRect.origin.x + screenRect.size.width) {
		proposedRect.origin.x = screenRect.origin.x + screenRect.size.width - proposedRect.size.width;
	}

	if(proposedRect.origin.x < screenRect.origin.x) {
		proposedRect.origin.x = screenRect.origin.x;
	}

	return proposedRect;
}

TUI_EXTERN_C_END
