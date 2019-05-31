#import <Cocoa/Cocoa.h>

@import TwUI;

@interface ExampleSectionHeaderView : TUITableViewSectionHeader {
  
  TUITextRenderer * _labelRenderer;
  
}

@property (readonly) TUITextRenderer  * labelRenderer;

@end

