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

#import "TUIView.h"
#import "TUITextRenderer.h"

@interface TUIView (Private)

@property (nonatomic, assign) CGDirectDisplayID displayID;

- (void)_updateLayerScaleFactor;
- (void)_updateDisplayID;
- (void)_superSetNextResponder:(NSResponder *)responder;

@end

TUI_EXTERN_C_BEGIN

CGFloat TUICurrentContextScaleFactor(void);
void TUISetCurrentContextScaleFactor(CGFloat scale);

CGDirectDisplayID TUICurrentContextDisplayID(void);
void TUISetCurrentContextDisplayID(CGDirectDisplayID displayID);

TUI_EXTERN_C_END
