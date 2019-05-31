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

#if !defined(TUI_EXTERN)
#   if defined(__cplusplus)
#       define TUI_EXTERN extern "C"
#   else
#       define TUI_EXTERN extern
#   endif
#endif

#if !defined(TUI_EXTERN_C_BEGIN) && !defined(TUI_EXTERN_C_END)
#   ifdef __cplusplus
#       define TUI_EXTERN_C_BEGIN extern "C" {
#       define TUI_EXTERN_C_END   }
#   else
#       define TUI_EXTERN_C_BEGIN
#       define TUI_EXTERN_C_END
#   endif
#endif

#import <TWUI/ABActiveRange.h>
#import <TWUI/CAAnimation+TUIExtensions.h>
#import <TWUI/CALayer+TUIExtensions.h>
#import <TWUI/CATransaction+TUIExtensions.h>
#import <TWUI/CoreText+Additions.h>
#import <TWUI/NSFont+TUIExtensions.h>
#import <TWUI/NSTextView+TUIExtensions.h>
#import <TWUI/TUIAnimationManager.h>
#import <TWUI/TUICAAction.h>

#import <TWUI/TUIResponder.h>
#import <TWUI/TUIView.h>
#import <TWUI/NSClipView+TUIExtensions.h>
#import <TWUI/NSColor+TUIExtensions.h>
#import <TWUI/NSImage+TUIExtensions.h>
#import <TWUI/NSScrollView+TUIExtensions.h>
#import <TWUI/NSView+TUIExtensions.h>
#import <TWUI/TUIAccessibility.h>
#import <TWUI/TUIAccessibilityElement.h>
#import <TWUI/TUIActivityIndicatorView.h>
#import <TWUI/TUIAppearance.h>
#import <TWUI/TUIAttributedString.h>
#import <TWUI/TUIBridgedScrollView.h>
#import <TWUI/TUIBridgedView.h>
#import <TWUI/TUIButton.h>
#import <TWUI/TUIButton+Accessibility.h>
#import <TWUI/TUICGAdditions.h>
#import <TWUI/TUIColor.h>
#import <TWUI/TUIControl.h>
#import <TWUI/TUIControl+Accessibility.h>
#import <TWUI/TUIFastIndexPath.h>
#import <TWUI/TUIFont.h>
#import <TWUI/TUIGeometry.h>
#import <TWUI/TUIHostView.h>
#import <TWUI/TUIImage.h>
#import <TWUI/TUIImage+Drawing.h>
#import <TWUI/TUIImageView.h>
#import <TWUI/TUILabel.h>
#import <TWUI/TUILayoutConstraint.h>
#import <TWUI/TUILayoutManager.h>
#import <TWUI/TUINSHostView.h>
#import <TWUI/TUINSView.h>
#import <TWUI/TUINSView+Accessibility.h>
#import <TWUI/TUINSView+Hyperfocus.h>
#import <TWUI/TUINSView+NSTextInputClient.h>
#import <TWUI/TUINSWindow.h>
#import <TWUI/TUIPopover.h>
#import <TWUI/TUIProgressBar.h>
#import <TWUI/TUIScrollKnob.h>
#import <TWUI/TUIScrollView.h>
#import <TWUI/TUIScrollView+TUIBridgedScrollView.h>
#import <TWUI/TUIStringDrawing.h>
#import <TWUI/TUIStyledView.h>
#import <TWUI/TUITableView.h>
#import <TWUI/TUITableView+Additions.h>
#import <TWUI/TUITableView+Cell.h>
#import <TWUI/TUITableView+Derepeater.h>
#import <TWUI/TUITableViewCell.h>
#import <TWUI/TUITableViewController.h>
#import <TWUI/TUITableViewFastLiveResizingContext.h>
#import <TWUI/TUITableViewSectionHeader.h>
#import <TWUI/TUITextAttachment.h>
#import <TWUI/TUITextComposedSequence.h>
#import <TWUI/TUITextEditor.h>
#import <TWUI/TUITextField.h>
#import <TWUI/TUITextLayout.h>
#import <TWUI/TUITextLayoutFrame.h>
#import <TWUI/TUITextLayoutLine.h>
#import <TWUI/TUITextRenderer.h>
#import <TWUI/TUITextRenderer+Accessibility.h>
#import <TWUI/TUITextRenderer+Event.h>
#import <TWUI/TUITextRenderer+LayoutResult.h>
#import <TWUI/TUITextStorage.h>
#import <TWUI/TUITextView.h>
#import <TWUI/TUITextViewEditor.h>
#import <TWUI/TUITooltipWindow.h>
#import <TWUI/TUIView+Accessibility.h>
#import <TWUI/TUIView+Event.h>
#import <TWUI/TUIView+Layout.h>
#import <TWUI/TUIView+NSTextInputClient.h>
#import <TWUI/TUIView+PasteboardDragging.h>
#import <TWUI/TUIView+TUIBridgedView.h>
#import <TWUI/TUIViewController.h>
#import <TWUI/TUIViewControllerPreviewing.h>
#import <TWUI/TUIViewControllerPreviewingContext.h>
#import <TWUI/TUIViewNSViewContainer.h>
#import <TWUI/TUIVisualEffectView.h>

extern BOOL AtLeastLion; // set at launch
extern BOOL AtLeastElCapitan; // set at launch
extern NSInteger OSXMajorVersion;
extern NSInteger OSXMinorVersion;
extern NSInteger OSXBugfixVersion;
