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
//
//  TUITableView+Private.h
//  TwUI
//
//  Created by 吴天 on 2018/2/6.
//

#import "TUITableView.h"

@interface TUITableView ()

@property (nonatomic, strong) TUIFastIndexPath * keepVisibleIndexPathForReload;
@property (nonatomic, assign) CGFloat relativeOffsetForReload;

@end
