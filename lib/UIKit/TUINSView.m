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

//	Portions of this code were taken from Velvet,
//	which is copyright (c) 2012 Bitswift, Inc.
//	See LICENSE.txt for more information.

#import "TUINSView.h"
#import "CALayer+TUIExtensions.h"
#import "TUIBridgedScrollView.h"
#import "TUINSHostView.h"
#import "TUINSView+Hyperfocus.h"
#import "TUINSView+Private.h"
#import "TUIViewNSViewContainer.h"
#import "TUIView.h"
#import "TUIView+Private.h"
#import "TUITextRenderer+Event.h"
#import "TUITooltipWindow.h"
#import "TUIViewControllerPreviewing.h"
#import "TUIViewControllerPreviewingContext_Private.h"
#import "TUILayoutManager.h"
#import <CoreFoundation/CoreFoundation.h>

// If enabled, NSViews contained within TUIViewNSViewContainers will be clipped
// by any TwUI ancestors that enable clipping to bounds.
//
// This should really only be disabled for debugging.
#define ENABLE_NSVIEW_CLIPPING 1

static NSComparisonResult compareNSViewOrdering (__kindof NSView *viewA, __kindof NSView *viewB, void * __nullable context) {
	TUIViewNSViewContainer *hostA = viewA.hostView;
	TUIViewNSViewContainer *hostB = viewB.hostView;

	// hosted NSViews should be on top of everything else
	if (!hostA) {
		if (!hostB) {
			return NSOrderedSame;
		} else {
			return NSOrderedAscending;
		}
	} else if (!hostB) {
		return NSOrderedDescending;
	}

	TUIView *ancestor = [hostA ancestorSharedWithView:(TUIView *)hostB];
	NSCAssert2(ancestor, @"TwUI-hosted NSViews in the same TUINSView should share a TwUI ancestor: %@, %@", viewA, viewB);

	__block NSInteger orderA = -1;
	__block NSInteger orderB = -1;

	[ancestor.subviews enumerateObjectsUsingBlock:^(TUIView *subview, NSUInteger index, BOOL *stop){
		if ([hostA isDescendantOfView:subview]) {
			orderA = (NSInteger)index;
		} else if ([hostB isDescendantOfView:subview]) {
			orderB = (NSInteger)index;
		}

		if (orderA >= 0 && orderB >= 0) {
			*stop = YES;
		}
	}];

	if (orderA < orderB) {
		return NSOrderedAscending;
	} else if (orderA > orderB) {
		return NSOrderedDescending;
	} else {
		return NSOrderedSame;
	}
}

@interface TUINSView ()
{
    struct {
        unsigned int delegateMouseEntered:1;
        unsigned int delegateMouseExited:1;
        unsigned int delegateMouseMoved:1;
        unsigned int delegateMenuForEvent:1;
        unsigned int delegateRightMouseDown:1;
        unsigned int delegateRightMouseUp:1;
        unsigned int delegateMouseUp:1;
        unsigned int delegateScrollWheel:1;
        unsigned int delegateBeginGesture:1;
        unsigned int delegateEndGesture:1;
        
        unsigned int previewEventFired: 1;
    } _viewFlags;
}

/*
 * The layer-hosted view which actually holds the TwUI hierarchy.
 */
@property (nonatomic, readonly, strong) TUINSHostView *tuiHostView;

- (void)recalculateNSViewClipping;
- (void)recalculateNSViewOrdering;

/*
 * A layer used to mask the rendering of NSView-owned layers added to the
 * receiver.
 *
 * This masking will keep the rendering of a given NSView consistent with the
 * clipping its TUIViewNSViewContainer would have in the TwUI hierarchy.
 */
@property (nonatomic, strong) CAShapeLayer *maskLayer;

@property (nonatomic, weak) TUIView * gesturePerformingView;

/*
 * Returns any existing AppKit-created focus ring layer for the given view, or
 * nil if one could not be found.
 */
- (CALayer *)focusRingLayerForView:(NSView *)view;

/*
 * Configures all the necessary properties on the receiver. This is outside of
 * an initializer because NSView has no true designated initializer.
 */
- (void)setUp;

- (void)windowDidResignKey:(NSNotification *)notification;
- (void)windowDidBecomeKey:(NSNotification *)notification;
- (void)screenProfileOrBackingPropertiesDidChange:(NSNotification *)notification;
@end


@implementation TUINSView

// implemented by TUIView
@dynamic layer;

// these cannot be implicitly synthesized because they're from protocols/categories
@synthesize hostView = _hostView;
@synthesize appKitHostView = _appKitHostView;
@synthesize rootView = _rootView;
@synthesize maskLayer = _maskLayer;
@synthesize tuiHostView = _tuiHostView;

- (instancetype)init {
    return [self initWithFrame:NSZeroRect];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self == nil)
		return nil;
	
	[self setUp];
	return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self == nil)
		return nil;
	[self setUp];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_rootView.nsView = nil;
	[_rootView removeFromSuperview];
	
	_rootView = nil;
	_hoverView = nil;
	_trackingView = nil;
	_trackingArea = nil;
	
}

- (void)resetCursorRects
{
	NSRect f = [self frame];
	f.origin = NSZeroPoint;
	[self addCursorRect:f cursor:[NSCursor arrowCursor]];
}
		 
- (void)ab_setIsOpaque:(BOOL)o
{
	opaque = o;
}

- (void)tui_setOpaque:(BOOL)o
{
	opaque = o;
}

- (BOOL)isOpaque
{
	return opaque;
}

- (BOOL)mouseDownCanMoveWindow
{
	return NO;
}

- (void)updateTrackingAreas
{
	[super updateTrackingAreas];
	
	if(_trackingArea) {
		[self removeTrackingArea:_trackingArea];
	}
	
	NSRect r = [self frame];
	r.origin = NSZeroPoint;
	_trackingArea = [[NSTrackingArea alloc] initWithRect:r options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways owner:self userInfo:nil];
	[self addTrackingArea:_trackingArea];
}

- (void)viewWillStartLiveResize
{
	[super viewWillStartLiveResize];
	inLiveResize = YES;
	[_rootView viewWillStartLiveResize];
}

- (BOOL)inLiveResize
{
	return inLiveResize;
}

- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	inLiveResize = NO;
	[_rootView viewDidEndLiveResize]; // will send to all subviews
	
	if([[self window] respondsToSelector:@selector(ensureWindowRectIsOnScreen)])
		[[self window] performSelector:@selector(ensureWindowRectIsOnScreen)];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [super resizeSubviewsWithOldSize:oldSize];

    CGSize s = [self frame].size;
    self.rootView.frame = CGRectMake(0, 0, s.width, s.height);
}

- (void)setRootView:(TUIView *)v
{
	v.autoresizingMask = TUIViewAutoresizingFlexibleSize;

	_rootView.nsView = nil;
	_rootView.hostView = nil;
	_rootView = v;
	_rootView.nsView = self;
	_rootView.hostView = self;
	
	[_rootView setNextResponder:self];
	
	CGSize s = [self frame].size;
	v.frame = CGRectMake(0, 0, s.width, s.height);
	[self.tuiHostView.layer addSublayer:_rootView.layer];
	
    [self _updateDisplayID];
	[self _updateLayerScaleFactor];
}

- (void)setNextResponder:(NSResponder *)r
{
    if (!r) [super setNextResponder:r];
    
	NSResponder *nextResponder = [self nextResponder];
	if([nextResponder isKindOfClass:[NSViewController class]] &&
       nextResponder != r) {
		// keep view controller in chain
		[nextResponder setNextResponder:r];
	} else {
		[super setNextResponder:r];
	}
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
	if(self.window != nil) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:self.window];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignKeyNotification object:self.window];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidChangeScreenProfileNotification object:self.window];
        
        
        if (OSXMinorVersion > 7 || (OSXMinorVersion == 7 && OSXBugfixVersion >= 3))
        {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:@"NSWindowDidChangeBackingPropertiesNotification" object:self.window];
        }
	}
	
	CALayer *hostLayer = self.layer;
	if(newWindow != nil && _rootView.layer.superlayer != hostLayer) {
		_rootView.layer.frame = hostLayer.bounds;
		[hostLayer insertSublayer:_rootView.layer atIndex:0];
	}
    
	[self.rootView willMoveToWindow:(TUINSWindow *) newWindow];
    
	if(newWindow == nil) {
		[_rootView removeFromSuperview];
		// since the layer retains the layoutManger, we need to set it to nil to
		// make sure TUINSView will be deallocated
		self.appKitHostView.layer.layoutManager = nil;
	} else {
		self.appKitHostView.layer.layoutManager = self;
	}
}

- (void)viewDidMoveToWindow
{
    [self _updateDisplayID];
	[self _updateLayerScaleFactor];
	
	[self.rootView didMoveToWindow];
	
	if(self.window != nil) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification object:self.window];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:self.window];
		
		// make sure the window will post NSWindowDidChangeScreenProfileNotification
		[self.window setDisplaysWhenScreenProfileChanges:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenProfileOrBackingPropertiesDidChange:) name:NSWindowDidChangeScreenProfileNotification object:self.window];
        
        if (OSXMinorVersion > 7 || (OSXMinorVersion == 7 && OSXBugfixVersion >= 3))
        {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenProfileOrBackingPropertiesDidChange:) name:@"NSWindowDidChangeBackingPropertiesNotification" object:self.window];
        }
	}
}

- (void)_updateLayerScaleFactor {
	if([self window] != nil) {
		CGFloat scale = 1.0f;
		if([[self window] respondsToSelector:@selector(backingScaleFactor)]) {
			scale = [[self window] backingScaleFactor];
		}
		
		if([self.tuiHostView.layer respondsToSelector:@selector(setContentsScale:)]) {
			if(fabs(self.tuiHostView.layer.contentsScale - scale) > 0.1f) {
				self.tuiHostView.layer.contentsScale = scale;
			}
		}
		
		[self.rootView _updateLayerScaleFactor];
	}
}

- (void)_updateDisplayID {
    if([self window] != nil) {
        [self.rootView _updateDisplayID];
    }
}

- (void)screenProfileOrBackingPropertiesDidChange:(NSNotification *)notification
{
    [self performSelector:@selector(_updateDisplayID) withObject:nil afterDelay:0.0];
	[self performSelector:@selector(_updateLayerScaleFactor) withObject:nil afterDelay:0.0]; // the window's backingScaleFactor doesn't update until after this notification fires (10.8) - so delay it a bit.
}

- (TUIView *)viewForLocalPoint:(NSPoint)p
{
	return [_rootView hitTest:p withEvent:nil];
}

- (NSPoint)localPointForLocationInWindow:(NSPoint)locationInWindow
{
	return [self convertPoint:locationInWindow fromView:nil];
}

- (TUIView *)viewForLocationInWindow:(NSPoint)locationInWindow
{
	return [self viewForLocalPoint:[self localPointForLocationInWindow:locationInWindow]];
}

- (TUIView *)viewForEvent:(NSEvent *)event
{
	return [self viewForLocationInWindow:[event locationInWindow]];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	[TUITooltipWindow endTooltip];
	
	if(![self isWindowKey]) {
		[self.rootView windowDidResignKey];
	}
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	[self.rootView windowDidBecomeKey];
}

- (BOOL)isWindowKey
{
	if([self.window isKeyWindow]) return YES;
	
	NSWindow *keyWindow = [NSApp keyWindow];
	if(keyWindow == nil) return NO;
	
	return keyWindow == [self.window attachedSheet];
}

- (void)viewWillMoveToSuperview:(NSView *)newSuperview
{
	[super viewWillMoveToSuperview:newSuperview];
	
	if(newSuperview == nil) {
		[TUITooltipWindow endTooltip];
	}
}

- (void)_updateHoverView:(TUIView *)_newHoverView withEvent:(NSEvent *)event
{
	if(_hyperFocusView) {
		if(![_newHoverView isDescendantOfView:_hyperFocusView]) {
			_newHoverView = nil; // don't allow hover
		}
	}
	
	if(_newHoverView != _hoverView) {
        TUIView * oldHoverView = _hoverView;
        _hoverView = _newHoverView;

		[oldHoverView mouseExited:event];
		[_newHoverView mouseEntered:event];
		
		if([[self window] isKeyWindow]) {
			[TUITooltipWindow updateTooltip:_hoverView.toolTip delay:_hoverView.toolTipDelay];
		} else {
			[TUITooltipWindow updateTooltip:nil delay:_hoverView.toolTipDelay];
		}
	} else {
		[_hoverView mouseMoved:event];
	}
}

- (void)_updateHoverViewWithEvent:(NSEvent *)event
{
	TUIView *_newHoverView = [self viewForEvent:event];
	
	if(![[self window] isKeyWindow]) {
		if(![_newHoverView acceptsFirstMouse:event]) {
			// in background, don't do hover for things that don't accept first mouse
			_newHoverView = nil;
		}
	}
	
	[self _updateHoverView:_newHoverView withEvent:event];
}

- (void)updateHoverView
{
    NSPoint point = [self.window convertRectFromScreen:(NSRect){.origin = [NSEvent mouseLocation], .size = NSZeroSize}].origin;
    NSEvent * event = [NSEvent mouseEventWithType:NSEventTypeMouseMoved location:point modifierFlags:0 timestamp:0 windowNumber:self.window.windowNumber context:nil eventNumber:0 clickCount:0 pressure:0];
    [self _updateHoverViewWithEvent:event];
}

- (void)invalidateHover
{
	[self _updateHoverView:nil withEvent:nil];
}

- (void)invalidateHoverForView:(TUIView *)v
{
	if([_hoverView isDescendantOfView:v]) {
		[self invalidateHover];
	}
}

- (void)mouseDown:(NSEvent *)event
{
	if(_hyperFocusView) {
		TUIView *v = [self viewForEvent:event];
		if([v isDescendantOfView:_hyperFocusView]) {
			// activate it normally
			[self endHyperFocus:NO]; // not cancelled
			goto normal;
		} else {
			// dismiss hover, don't click anything
			[self endHyperFocus:YES];
		}
	} else {
		// normal case
	normal:
		;
		_trackingView = [self viewForEvent:event];
		[_trackingView mouseDown:event];
	}
	
	[TUITooltipWindow endTooltip];
}

- (void)mouseUp:(NSEvent *)event
{
    if (_viewFlags.delegateMouseUp)
    {
        [_viewDelegate nsView:self mouseUp:event];
    }
    
	TUIView *lastTrackingView = _trackingView;

	_trackingView = nil;

    if (!_viewFlags.previewEventFired) {
        [lastTrackingView mouseUp:event]; // after _trackingView set to nil, will call mouseUp:fromSubview:
    } else {
        [lastTrackingView setDisablesActionSending:YES];
        [lastTrackingView mouseUp:event];
        [lastTrackingView setDisablesActionSending:NO];
        _viewFlags.previewEventFired = NO;
    }
	
	[self _updateHoverViewWithEvent:event];
}

- (void)mouseDragged:(NSEvent *)event
{
	[_trackingView mouseDragged:event];
}

- (void)mouseMoved:(NSEvent *)event
{
	[self _updateHoverViewWithEvent:event];
    
    if (_viewFlags.delegateMouseMoved)
    {
        [_viewDelegate nsView:self mouseMoved:event];
    }
}

-(void)mouseEntered:(NSEvent *)event {
  [self _updateHoverViewWithEvent:event];
    
    if (_viewFlags.delegateMouseEntered)
    {
        [_viewDelegate nsView:self mouseEntered:event];
    }
}

-(void)mouseExited:(NSEvent *)event {
  [self _updateHoverViewWithEvent:event];
    
    if (_viewFlags.delegateMouseExited)
    {
        [_viewDelegate nsView:self mouseExited:event];
    }    
}

- (void)rightMouseDown:(NSEvent *)event
{
	_trackingView = [self viewForEvent:event];
	[_trackingView rightMouseDown:event];
	[TUITooltipWindow endTooltip];
	[super rightMouseDown:event]; // we need to send this up the responder chain so that -menuForEvent: will get called for two-finger taps
    
    if (_viewFlags.delegateRightMouseDown)
    {
        [_viewDelegate nsView:self rightMouseDown:event];
    }
}

- (void)rightMouseUp:(NSEvent *)event
{
	TUIView *lastTrackingView = _trackingView;
	
	_trackingView = nil;
	
	[lastTrackingView rightMouseUp:event]; // after _trackingView set to nil, will call mouseUp:fromSubview:
    
    if (_viewFlags.delegateRightMouseUp)
    {
        [_viewDelegate nsView:self rightMouseUp:event];
    }
}

- (void)scrollWheel:(NSEvent *)event
{
    if (event.phase == NSEventPhaseBegan) {
        [self beginGesturePerformingIfNeededWithEvent:event];
    }
    
    {
        TUIView * view = [self viewForEvent:event];
        [view scrollWheel:event];
        if (view != _hoverView || !view.needsHoverStateDuringScroll) {
            [self _updateHoverView:nil withEvent:event]; // don't pop in while scrolling
        }
        
        if (_viewFlags.delegateScrollWheel)
        {
            [_viewDelegate nsView:self scrollWheel:event];
        }
    }
    
    if (event.phase == NSEventPhaseEnded) {
        [self endGesturePerformingWithEvent:event];
    }
}

- (void)beginGestureWithEvent:(nonnull NSEvent *)event
{
	[[self viewForEvent:event] beginGestureWithEvent:event];
}

- (void)endGestureWithEvent:(nonnull NSEvent *)event
{
	[[self viewForEvent:event] endGestureWithEvent:event];
}

- (void)magnifyWithEvent:(NSEvent *)event
{
	if(!deliveringEvent) {
		deliveringEvent = YES;
		[[self viewForEvent:event] magnifyWithEvent:event];	
		deliveringEvent = NO;
	}
}

- (void)rotateWithEvent:(NSEvent *)event
{
	if(!deliveringEvent) {
		deliveringEvent = YES;
		[[self viewForEvent:event] rotateWithEvent:event];
		deliveringEvent = NO;
	}
}

- (void)swipeWithEvent:(NSEvent *)event
{
	if(!deliveringEvent) {
		deliveringEvent = YES;
		[[self viewForEvent:event] swipeWithEvent:event];
		deliveringEvent = NO;
	}
}

- (void)beginGesturePerformingIfNeededWithEvent:(NSEvent *)event
{
    if (_gesturePerformingView) {
        return;
    }
    
    if ((event.phase == NSEventPhaseBegan) || [event touchesMatchingPhase:NSTouchPhaseTouching inView:self].count > 1) {
        _gesturePerformingView = [self viewForEvent:event];
        [_gesturePerformingView beginGestureWithEvent:event];
        
        if (_viewFlags.delegateBeginGesture) {
            [_viewDelegate nsView:self beginGestureWithEvent:event];
        }
    }
}

- (void)endGesturePerformingWithEvent:(NSEvent *)event
{
    if (!_gesturePerformingView) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
		if (!self->_gesturePerformingView) {
            return;
        }
        
		[self->_gesturePerformingView endGestureWithEvent:event];
		self->_gesturePerformingView = nil;
        
		if (self->_viewFlags.delegateEndGesture) {
			[self->_viewDelegate nsView:self endGestureWithEvent:event];
        }
    });
}

- (void)touchesBeganWithEvent:(NSEvent *)event
{
    [self beginGesturePerformingIfNeededWithEvent:event];
}

- (void)touchesMovedWithEvent:(NSEvent *)event
{
    [self beginGesturePerformingIfNeededWithEvent:event];
}

- (void)touchesCancelledWithEvent:(NSEvent *)event
{
    _viewFlags.previewEventFired = NO;
    [self endGesturePerformingWithEvent:event];
}

- (void)touchesEndedWithEvent:(NSEvent *)event
{
    _viewFlags.previewEventFired = NO;
    [self endGesturePerformingWithEvent:event];
}

- (void)keyDown:(NSEvent *)event
{
	BOOL consumed = NO;
	// TUIView uses -performKeyAction: in -keyDown: to do its key equivalents. If none of our TUIViews consumed the key down as a key action, we want to give our view controller a chance to handle the key down as a key equivalent.
	if([[self nextResponder] isKindOfClass:[NSViewController class]]) {
		consumed = [[self nextResponder] performKeyEquivalent:event];
	}
	
	if(!consumed) {
		[super keyDown:event];
	}
}

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
	return [_rootView performKeyEquivalent:event];
}

- (void)setViewDelegate:(id <TUINSViewDelegate>)d
{
	_viewDelegate = d;
	_viewFlags.delegateMouseEntered = [_viewDelegate respondsToSelector:@selector(nsView:mouseEntered:)];
	_viewFlags.delegateMouseExited = [_viewDelegate respondsToSelector:@selector(nsView:mouseExited:)];
    _viewFlags.delegateMouseMoved = [_viewDelegate respondsToSelector:@selector(nsView:mouseMoved:)];
    _viewFlags.delegateMenuForEvent = [_viewDelegate respondsToSelector:@selector(nsView:menuForEvent:)];
    _viewFlags.delegateRightMouseDown = [_viewDelegate respondsToSelector:@selector(nsView:rightMouseDown:)];
    _viewFlags.delegateRightMouseUp = [_viewDelegate respondsToSelector:@selector(nsView:rightMouseUp:)];
    _viewFlags.delegateMouseUp = [_viewDelegate respondsToSelector:@selector(nsView:mouseUp:)];
    _viewFlags.delegateScrollWheel = [_viewDelegate respondsToSelector:@selector(nsView:scrollWheel:)];
    _viewFlags.delegateBeginGesture = [_viewDelegate respondsToSelector:@selector(nsView:beginGestureWithEvent:)];
    _viewFlags.delegateEndGesture = [_viewDelegate respondsToSelector:@selector(nsView:endGestureWithEvent:)];
}

- (void)setEverythingNeedsDisplay
{
	[_rootView setEverythingNeedsDisplay];
}

- (BOOL)isTrackingSubviewOfView:(TUIView *)v
{
	return [_trackingView isDescendantOfView:v];
}

- (BOOL)isHoveringSubviewOfView:(TUIView *)v
{
	return [_hoverView isDescendantOfView:v];
}

- (BOOL)isHoveringView:(TUIView *)v
{
	return _hoverView == v;
}

- (TUIView *)hoverView
{
    return _hoverView;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
	return [[self viewForEvent:event] acceptsFirstMouse:event];
}

/* http://developer.apple.com/Mac/library/documentation/Cocoa/Conceptual/MenuList/Articles/EnablingMenuItems.html
 If the menu item’s target is not set and the NSMenu object is a contextual menu, NSMenu goes through the same steps as before but the search order for the responder chain is different:
 - The responder chain for the window in which the view that triggered the context menu resides, starting with the view.
 - The window itself.
 - The window’s delegate.
 - The NSApplication object.
 - The NSApplication object’s delegate.
 */

- (NSResponder *)firstResponderForSelector:(SEL)action
{
	if(!action)
		return nil;
	
	NSResponder *f = [[self window] firstResponder];
//	NSLog(@"starting search at %@", f);
	do {
		if([f respondsToSelector:action])
			return f;
	} while((f = [f nextResponder]));
	
	return nil;
}

- (void)_patchMenu:(NSMenu *)menu
{
	for(NSMenuItem *item in [menu itemArray]) {
		if(![item target]) {
			// would normally travel the responder chain starting too high up, patch it to target what it would target if it hit the true responder chain
			[item setTarget:[self firstResponderForSelector:[item action]]];
		}
		
		if([item submenu])
			[self _patchMenu:[item submenu]]; // recurse
	}
}

// the problem is for context menus the responder chain search starts with the NSView... we want it to start deeper, so we can patch up targets of a copy of the menu here
- (NSMenu *)menuWithPatchedItems:(NSMenu *)menu
{
	NSData *d = [NSKeyedArchiver archivedDataWithRootObject:menu]; // this is bad - doesn't persist 'target'?
	menu = [NSKeyedUnarchiver unarchiveObjectWithData:d];
	
	[self _patchMenu:menu];
	
	return menu;
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    if (_viewFlags.delegateMenuForEvent)
    {
        return [_viewDelegate nsView:self menuForEvent:event];
    }
    
	TUIView *v = [self viewForEvent:event];
	do {
		NSMenu *m = [v menuForEvent:event];
		if(m)
			return m; // not patched
		v = v.superview;
	} while(v);
	return nil;
}

- (void)quickLookWithEvent:(NSEvent *)event
{
    [self viewForEvent:event];
    
    if ([self firePreviewEventIfNeeded:event]) {
        return;
    }
    
    [super quickLookWithEvent:event];
}

- (void)pressureChangeWithEvent:(NSEvent *)event
{
    if (event.stage == 2) {
        [self firePreviewEventIfNeeded:event];
    }
}

- (BOOL)firePreviewEventIfNeeded:(NSEvent *)event
{
    if (!self.window.canBecomeMainWindow) {
        return NO;
    }
    
    if (!_viewFlags.previewEventFired) {
        _viewFlags.previewEventFired = YES;
        
        TUIView * view = [self viewForEvent:event];
        Protocol * protocol = @protocol(TUIViewControllerPreviewing);
        while (view) {
            if ([view conformsToProtocol:protocol]) {
                break;
            }
            view = view.superview;
        }
        
        if ([view conformsToProtocol:protocol]) {
            if ([self beginPreviewingWithView:(id)view event:event]) {
                return YES;
            }
        }
        
        TUITextRenderer * renderer = [view textRendererAtPoint:[view localPointForEvent:event]];
        
        if (renderer) {
            [renderer quickLookWithEvent:event];
            return YES;
        }
        _viewFlags.previewEventFired = NO;
    }
    return NO;
}

- (void)setUp {
    
    self.acceptsTouchEvents = YES;
    
	opaque = YES;

	_maskLayer = [CAShapeLayer layer];
	_maskLayer.frame = self.bounds;
	_maskLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;

	// enable layer-backing for this view
	self.wantsLayer = YES;
	self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawNever;

	_tuiHostView = [[TUINSHostView alloc] initWithFrame:self.bounds];
	_tuiHostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[self addSubview:_tuiHostView];

	_appKitHostView = [[NSView alloc] initWithFrame:self.bounds];
	_appKitHostView.autoresizesSubviews = NO;
	_appKitHostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	_appKitHostView.wantsLayer = YES;
    _appKitHostView.layer = [CALayer layer];
	_appKitHostView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawNever;
	[self addSubview:_appKitHostView];

	// set up masking on the AppKit host view, and make ourselves the layout
	// manager, so that we'll know when new sublayers are added
	self.appKitHostView.layer.layoutManager = self;

	#if ENABLE_NSVIEW_CLIPPING
	self.appKitHostView.layer.mask = self.maskLayer;
	[self recalculateNSViewClipping];
	#endif
}

- (void)didAddSubview:(NSView *)view {
	NSAssert2(view == self.tuiHostView || view == self.appKitHostView, @"Subviews should not be added to TUINSView %@: %@", self, view);
	[super didAddSubview:view];
}

#pragma mark AppKit bridging

- (NSView *)hitTest:(NSPoint)point {
	// convert point into our coordinate system, so it's ready to go for all
	// subviews (which expect it in their superview's coordinate system)
    point = [self convertPoint:point fromView:self.superview];
    
	if (!CGRectContainsPoint(self.bounds, point))
		return nil;

    TUIView * view = [self.rootView hitTest:point withEvent:nil];
    if (view.moveWindowByDragging && self.mouseDownCanMoveWindow) {
        return nil;
    }
    
	__block NSView *result = self;

	// we need to avoid hitting any NSViews that are clipped by their
	// corresponding TwUI views
	[self.appKitHostView.subviews enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSView *view, NSUInteger index, BOOL *stop){
		id<TUIBridgedView> hostView = view.hostView;
		if (hostView) {
			CGRect bounds = hostView.layer.bounds;
			CGRect clippedBounds = [hostView.layer tui_convertAndClipRect:bounds toLayer:self.layer];

			if (!CGRectContainsPoint(clippedBounds, point)) {
				// skip this view
				return;
			}
		}

		NSView *hitTestedView = [view hitTest:point];
		if (hitTestedView) {
			result = hitTestedView;
			*stop = YES;
		}
	}];

	return result;
}

- (void)recalculateNSViewOrdering {
	NSAssert([NSThread isMainThread], @"");
	[self.appKitHostView sortSubviewsUsingFunction:&compareNSViewOrdering context:NULL];
}

- (void)recalculateNSViewClipping {
	NSAssert([NSThread isMainThread], @"");

	#if !ENABLE_NSVIEW_CLIPPING
	return;
	#endif

	CGMutablePathRef clippingPath = CGPathCreateMutable();

	for (NSView *view in self.appKitHostView.subviews) {
		id<TUIBridgedView> hostView = view.hostView;
		if (!hostView)
			continue;

		CALayer *focusRingLayer = [self focusRingLayerForView:view];
		if (focusRingLayer) {
			id<TUIBridgedScrollView> clippingView = hostView.ancestorScrollView;
			CGRect clippedFocusRingBounds = CGRectNull;

			if (clippingView && self.ancestorScrollView != clippingView) {
				CGRect rect = [clippingView.layer tui_convertAndClipRect:clippingView.layer.visibleRect toLayer:focusRingLayer];
				if (!CGRectIsNull(rect) && !CGRectIsInfinite(rect) && !CGRectContainsRect(rect, clippedFocusRingBounds)) {
					clippedFocusRingBounds = CGRectIntersection(rect, focusRingLayer.bounds);
				}
			}

			// the frame of the focus ring, represented in the TUINSView's
			// coordinate system
			CGRect focusRingFrame;

			if (CGRectIsNull(clippedFocusRingBounds)) {
				focusRingLayer.mask = nil;
				focusRingFrame = [focusRingLayer tui_convertAndClipRect:focusRingLayer.bounds toLayer:self.layer];
			} else {
				// set up a mask on the focus ring that clips to any ancestor scroll views
				CAShapeLayer *maskLayer = (id)focusRingLayer.mask;
				if (![maskLayer isKindOfClass:[CAShapeLayer class]]) {
					maskLayer = [CAShapeLayer layer];

					focusRingLayer.mask = maskLayer;
				}

				CGPathRef focusRingPath = CGPathCreateWithRect(clippedFocusRingBounds, NULL);
				maskLayer.path = focusRingPath;
				CGPathRelease(focusRingPath);
				
				focusRingFrame = [focusRingLayer tui_convertAndClipRect:clippedFocusRingBounds toLayer:self.layer];
			}

			CGPathAddRect(clippingPath, NULL, focusRingFrame);
		}

		// clip the frame of each NSView using the TwUI hierarchy
		CGRect rect = [hostView.layer tui_convertAndClipRect:hostView.layer.visibleRect toLayer:self.layer];
		if (CGRectIsNull(rect) || CGRectIsInfinite(rect))
			continue;

		CGPathAddRect(clippingPath, NULL, rect);
	}

	// mask them all at once (so fast!)
	self.maskLayer.path = clippingPath;
	CGPathRelease(clippingPath);
}

#pragma mark CALayer delegate

- (void)layoutSublayersOfLayer:(CALayer *)layer {
	NSAssert([NSThread isMainThread], @"");

	if (layer == self.layer) {
		// TUINSView.layer is being laid out
		return;
	}

	// appKitHostView.layer is being laid out
	//
	// this often happens in response to AppKit adding a focus ring layer, so
	// recalculate our clipping paths to take it into account
	[self recalculateNSViewClipping];
}

- (CALayer *)focusRingLayerForView:(NSView *)view {
	CALayer *resultSoFar = nil;

	for (CALayer *layer in self.appKitHostView.layer.sublayers) {
		// don't return the layer of the view itself
		if (layer == view.layer) {
			continue;
		}

		// if the layer doesn't wrap around this view, it's not the focus ring
		if (!CGRectContainsRect(layer.frame, view.frame)) {
			continue;
		}

		// if resultSoFar matched more tightly than this layer, consider the
		// former to be the focus ring
		if (resultSoFar && !CGRectContainsRect(resultSoFar.frame, layer.frame)) {
			continue;
		}

		resultSoFar = layer;
	}

	return resultSoFar;
}

#pragma mark TUIHostView

- (void)ancestorDidLayout {
	[super ancestorDidLayout];
	[self.rootView ancestorDidLayout];
}

- (id<TUIBridgedView>)descendantViewAtPoint:(CGPoint)point {
	if (!CGRectContainsPoint(self.bounds, point))
		return nil;

	return [self.rootView descendantViewAtPoint:point] ?: self;
}

- (id<TUIHostView>)hostView {
    if (_hostView)
        return _hostView;
    else
        return self.superview.hostView;
}

- (void)viewHierarchyDidChange {
	[super viewHierarchyDidChange];
	[self.rootView viewHierarchyDidChange];
}

- (void)willMoveToTUINSView:(TUINSView *)view {
	// despite the TUIBridgedView contract that says we should forward this
	// message onto all subviews and our rootView, doing so could result in
	// crazy behavior, since the TUINSView of those views is and will remain
	// 'self' by definition
}

- (void)didMoveFromTUINSView:(TUINSView *)view {
	// despite the TUIBridgedView contract that says we should forward this
	// message onto all subviews and our rootView, doing so could result in
	// crazy behavior, since the TUINSView of those views is and will remain
	// 'self' by definition
}

#pragma mark - Previewing

- (BOOL)beginPreviewingWithView:(TUIView<TUIViewControllerPreviewing> *)view event:(NSEvent *)event
{
    if (!view || !event) {
        return NO;
    }
    
    TUIViewControllerPreviewingContext * context = [[TUIViewControllerPreviewingContext alloc] initWithSourceView:view];
    CGPoint location = [view localPointForEvent:event];
    TUIViewController * controller = [view previewingContext:context viewControllerForLocation:location];
    
    if (!controller) {
        return NO;
    }
    
    CGRect sourceRect = context.sourceRect;
    if (context.sourceSubview) {
        sourceRect = [view convertRect:context.sourceSubview.bounds fromView:context.sourceSubview];
    } else if (context.sourcePath) {
        sourceRect = (CGRect)context.sourcePath.bounds;
    }
    if (CGRectIsNull(sourceRect)) {
        sourceRect = view.bounds;
    }
    
    sourceRect = [view convertRect:sourceRect toView:view.nsView.rootView];
    
    CGSize contentSize = context.preferredContentSize;
    if (CGSizeEqualToSize(contentSize, CGSizeZero)) {
        contentSize = controller.preferredContentSize;
    }
    if (CGSizeEqualToSize(contentSize, CGSizeZero)) {
        contentSize = self.bounds.size;
    }
    
    if ([self.viewDelegate respondsToSelector:@selector(nsView:previewViewController:sourceRect:contentSize:)]) {
        [self.viewDelegate nsView:self previewViewController:controller sourceRect:sourceRect contentSize:contentSize];
    }
    
    return YES;
}

@end
