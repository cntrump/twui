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

#import "CoreText+Additions.h"

TUI_EXTERN_C_BEGIN

CGSize AB_CTLineGetSize(CTLineRef line)
{
	CGFloat ascent, descent, leading;
	CGFloat width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
	CGFloat height = ascent + descent + leading;
	return CGSizeMake(ceil(width), ceil(height));
}

CGSize AB_CTFrameGetSize(CTFrameRef frame)
{
	CGFloat h = 0.0;
	CGFloat w = 0.0;
	NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
	for(id line in lines) {
		CGSize s = AB_CTLineGetSize((__bridge CTLineRef)line);
		if(s.width > w)
			w = s.width;
	}
	
	// Mostly based off http://lists.apple.com/archives/quartz-dev/2008/Mar/msg00079.html
	CTLineRef lastLine = (__bridge CTLineRef)[lines lastObject];
	if(lastLine != NULL) {
		// Get the origin of the last line. We add the descent to this
		// (below) to get the bottom edge of the last line of text.
		CGPoint lastLineOrigin;
		CTFrameGetLineOrigins(frame, CFRangeMake(lines.count - 1, 0), &lastLineOrigin);
		
		CGPathRef framePath = CTFrameGetPath(frame);
		CGRect frameRect = CGPathGetBoundingBox(framePath);
		// The height needed to draw the text is from the bottom of the last line
		// to the top of the frame.
		CGFloat ascent, descent, leading;
		CTLineGetTypographicBounds(lastLine, &ascent, &descent, &leading);
		h = CGRectGetMaxY(frameRect) - lastLineOrigin.y + descent;
	}
	
	return CGSizeMake(ceil(w), ceil(h + 1));
}

CGFloat AB_CTFrameGetHeight(CTFrameRef f)
{
	NSArray *lines = (__bridge NSArray *)CTFrameGetLines(f);
	NSInteger n = (NSInteger)[lines count];
	CGPoint *lineOrigins = (CGPoint *) malloc(sizeof(CGPoint) * n);
	CTFrameGetLineOrigins(f, CFRangeMake(0, n), lineOrigins);
	
	CGPoint first, last;
	
	CGFloat h = 0.0;
	for(int i = 0; i < n; ++i) {
		CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
		CGFloat ascent, descent, leading;
		CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
		if(i == 0) {
			first = lineOrigins[i];
			h += ascent;
			h += descent;
		}
		if(i == n-1) {
			last = lineOrigins[i];
			h += first.y - last.y;
			h += descent;
			free(lineOrigins);
			return ceil(h);
		}
	}
	free(lineOrigins);
	return 0.0;
}

CFIndex AB_CTFrameGetStringIndexForPosition(CTFrameRef frame, CGPoint p)
{
//	p = (CGPoint){0, 0};
//	NSLog(@"checking p = %@", NSStringFromCGPoint(p));
//	CGRect f = [self frame];
//	NSLog(@"frame = %@", f);
	NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
	
	CFIndex linesCount = [lines count];
	CGPoint *lineOrigins = (CGPoint *) malloc(sizeof(CGPoint) * linesCount);
	CTFrameGetLineOrigins(frame, CFRangeMake(0, linesCount), lineOrigins);
	
	CTLineRef line = NULL;
	CGPoint lineOrigin = CGPointZero;
	
	for(CFIndex i = 0; i < linesCount; ++i) {
		line = (__bridge CTLineRef)[lines objectAtIndex:i];
		lineOrigin = lineOrigins[i];
//		NSLog(@"%d origin = %@", i, NSStringFromCGPoint(lineOrigin));
		CGFloat descent, ascent;
		CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
		if(p.y > (floor(lineOrigin.y) - floor(descent))) { // above bottom of line
			if(i == 0 && (p.y > (ceil(lineOrigin.y) + ceil(ascent)))) { // above top of first line
				free(lineOrigins);
				return 0;
			} else {
				goto found;
			}
		}
	}
	
	free(lineOrigins);
	
	// didn't find a line, must be beneath the last line
	return CTFrameGetStringRange(frame).length; // last character index

found:

	p.x -= lineOrigin.x;
	p.y -= lineOrigin.y;
	
	if(line) {
		CFIndex i = CTLineGetStringIndexForPosition(line, p);
		free(lineOrigins);
		return i;
	}
	
	free(lineOrigins);
	
	return 0;
}

extern double AB_CTFrameGetTypographicBoundsForLineAtPosition(CTFrameRef frame, CGPoint p, CGFloat* ascent, CGFloat* descent, CGFloat* leading)
{
    //	p = (CGPoint){0, 0};
    //	NSLog(@"checking p = %@", NSStringFromCGPoint(p));
    //	CGRect f = [self frame];
    //	NSLog(@"frame = %@", f);
	NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
	
	CFIndex linesCount = [lines count];
	CGPoint lineOrigins[linesCount];
	CTFrameGetLineOrigins(frame, CFRangeMake(0, linesCount), lineOrigins);
	
	CTLineRef line = NULL;
	CGPoint lineOrigin = CGPointZero;
	
	for(CFIndex i = 0; i < linesCount; ++i) {
		line = (__bridge CTLineRef)[lines objectAtIndex:i];
		lineOrigin = lineOrigins[i];
        //		NSLog(@"%d origin = %@", i, NSStringFromCGPoint(lineOrigin));
		CGFloat descent, ascent;
		CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
		if(p.y > (floor(lineOrigin.y) - floor(descent))) { // above bottom of line
			if(i == 0 && (p.y > (ceil(lineOrigin.y) + ceil(ascent)))) { // above top of first line
                line = (__bridge CTLineRef)lines[0];
			}
            break;
		}
	}
	
    if (!line && linesCount)
    {
        line = (__bridge CTLineRef)lines[linesCount - 1];
    }

    if (line)
    {
        return CTLineGetTypographicBounds(line, ascent, descent, leading);
    }
    
    return 0;
}

static inline BOOL RangeContainsIndex(CFRange range, CFIndex index)
{
	BOOL a = (index >= range.location);
	BOOL b = (index <= (range.location + range.length));
	return (a && b);
}


void AB_CTFrameGetRectsForRange(CTFrameRef frame, CFRange range, CGRect rects[], CFIndex *rectCount)
{
	AB_CTFrameGetRectsForRangeWithAggregationType(frame, range, AB_CTLineRectAggregationTypeInline, rects, rectCount);
}

static void AB_addRectToRects(CGRect r, CGRect rects[], CFIndex index, NSInteger previousLineY, AB_CTLineRectAggregationType aggregationType)
{
    r = CGRectIntegral(r);
    
    if (aggregationType == AB_CTLineRectAggregationTypeInlineContinuous &&
        previousLineY != NSNotFound)
    {
        r.size.height = previousLineY - r.origin.y;
    }
    rects[index] = r;
}

void AB_CTFrameGetRectsForRangeWithAggregationType(CTFrameRef frame, CFRange range, AB_CTLineRectAggregationType aggregationType, CGRect rects[], CFIndex *rectCount)
{
    AB_CTFrameGetRectsForRangeWithNumberOfLines(frame, range, 0, aggregationType, rects, rectCount);
}

void AB_CTFrameGetRectsForRangeWithNumberOfLines(CTFrameRef frame, CFRange range, NSInteger numberOfLines, AB_CTLineRectAggregationType aggregationType, CGRect rects[], CFIndex *rectCount)
{
    if (!frame)
    {
        return;
    }
    
    CGRect bounds;
	CGPathIsRect(CTFrameGetPath(frame), &bounds);
	
	CFIndex maxRects = *rectCount;
	CFIndex rectIndex = 0;
	
	CFIndex startIndex = range.location;
	CFIndex endIndex = startIndex + range.length;
	
	NSArray *lines = (NSArray *)CTFrameGetLines(frame);
	CFIndex linesCount = [lines count];
	CGPoint lineOrigins[linesCount];
	CTFrameGetLineOrigins(frame, CFRangeMake(0, linesCount), lineOrigins);
    
    NSInteger previousLineY = NSNotFound;
    
	for(CFIndex i = 0; i < linesCount; ++i)
    {
        if (numberOfLines && i >= numberOfLines)
        {
            break;
        }
        
		CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
		
		CGPoint lineOrigin = lineOrigins[i];
		CGFloat ascent, descent, leading;
		CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
		lineWidth = lineWidth;
		CGFloat lineHeight = ascent + descent + leading;
		CGFloat line_y = lineOrigin.y - descent + bounds.origin.y;
		
		CFRange lineRange = CTLineGetStringRange(line);
		CFIndex lineStartIndex = lineRange.location;
		CFIndex lineEndIndex = lineStartIndex + lineRange.length;
        
        BOOL lastLine = ((numberOfLines > 0) && (i == numberOfLines - 1)) || (i == linesCount - 1);
        if (lastLine && endIndex > (lineRange.location + lineRange.length))
        {
            endIndex = lineRange.location + lineRange.length;
        }
        
		BOOL containsStartIndex = RangeContainsIndex(lineRange, startIndex);
		BOOL containsEndIndex = RangeContainsIndex(lineRange, endIndex);
        
		if(containsStartIndex && containsEndIndex)
        {
            // 一共只有一行
            if (aggregationType == AB_CTLineRectAggregationTypeInline || startIndex != endIndex)
            {
                CGFloat startOffset = CTLineGetOffsetForStringIndex(line, startIndex, NULL);
                CGFloat endOffset = CTLineGetOffsetForStringIndex(line, endIndex, NULL);
                CGRect r = CGRectMake(bounds.origin.x + lineOrigin.x + startOffset, line_y, endOffset - startOffset, lineHeight);
                if(aggregationType == AB_CTLineRectAggregationTypeBlock)
                {
                    r.size.width = bounds.size.width - startOffset;
                }
                
                if(rectIndex < maxRects)
                {
                    AB_addRectToRects(r, rects, rectIndex++, previousLineY, aggregationType);
                }
            }
			goto end;
		}
        else if(containsStartIndex)
        {
            // 多行时的第一行
			if(startIndex != lineEndIndex)
            {
                CGFloat startOffset = CTLineGetOffsetForStringIndex(line, startIndex, NULL);
                CGRect r = CGRectMake(bounds.origin.x + lineOrigin.x + startOffset, line_y, bounds.size.width - startOffset - lineOrigin.x, lineHeight);
                if(rectIndex < maxRects)
                {
                    AB_addRectToRects(r, rects, rectIndex++, previousLineY, aggregationType);
                }
            }
		}
        else if(containsEndIndex)
        {
            // 多行时的最后一行
			CGFloat endOffset = CTLineGetOffsetForStringIndex(line, endIndex, NULL);
			CGRect r = CGRectMake(bounds.origin.x + lineOrigin.x, line_y, endOffset, lineHeight);
			if(aggregationType == AB_CTLineRectAggregationTypeBlock)
            {
				r.size.width = bounds.size.width;
			}
			
			if(rectIndex < maxRects)
            {
				AB_addRectToRects(r, rects, rectIndex++, previousLineY, aggregationType);
            }
		}
        else if(RangeContainsIndex(range, lineRange.location))
        {
            // 三行以上时的中间行
			CGRect r = CGRectMake(bounds.origin.x + lineOrigin.x, line_y, bounds.size.width - lineOrigin.x, lineHeight);
			if(rectIndex < maxRects)
            {
                AB_addRectToRects(r, rects, rectIndex++, previousLineY, aggregationType);
            }
        }
        
        previousLineY = line_y;
        
        if (lastLine)
        {
            break;
        }
	}
    
end:
	*rectCount = rectIndex;
}

void AB_CTLinesGetRectsForRangeWithAggregationType(NSArray *lines, CGPoint *lineOrigins, CGRect bounds, CFRange range, AB_CTLineRectAggregationType aggregationType, CGRect rects[], CFIndex *rectCount)
{
	CFIndex maxRects = *rectCount;
	CFIndex rectIndex = 0;
	
	CFIndex startIndex = range.location;
	CFIndex endIndex = startIndex + range.length;
	
	CFIndex linesCount = [lines count];
	
	for(CFIndex i = 0; i < linesCount; ++i) {
		CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
		
		CFRange lineRange = CTLineGetStringRange(line);
		CFIndex lineStartIndex = lineRange.location;
		CFIndex lineEndIndex = lineStartIndex + lineRange.length;
		BOOL containsStartIndex = RangeContainsIndex(lineRange, startIndex);
		BOOL containsEndIndex = RangeContainsIndex(lineRange, endIndex);
		
		if(containsStartIndex && containsEndIndex) {
			CGPoint lineOrigin = lineOrigins[i];
			CGFloat ascent, descent, leading;
			CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
			lineWidth = lineWidth;
			
			// If we have more than 1 line, we want to find the real height of the line by measuring the distance between the current line and previous line. If it's only 1 line, then we'll guess the line's height.
			BOOL useRealHeight = i < linesCount - 1;
			CGFloat neighborLineY = i > 0 ? lineOrigins[i - 1].y : (linesCount - 1 > i ? lineOrigins[i + 1].y : 0.0f);
			CGFloat lineHeight = ceil(useRealHeight ? fabs(neighborLineY - lineOrigin.y) : ascent + descent + leading);
			CGFloat line_y = round(useRealHeight ? lineOrigin.y + bounds.origin.y - lineHeight/2 + descent : lineOrigin.y - descent + bounds.origin.y);
			
			CGFloat startOffset = CTLineGetOffsetForStringIndex(line, startIndex, NULL);
			CGFloat endOffset = CTLineGetOffsetForStringIndex(line, endIndex, NULL);
			CGRect r = CGRectMake(bounds.origin.x + lineOrigin.x + startOffset, line_y, endOffset - startOffset, lineHeight);
			if(aggregationType == AB_CTLineRectAggregationTypeBlock) {
				r.size.width = bounds.size.width - startOffset;
			}
			
			if(rectIndex < maxRects)
				rects[rectIndex++] = r;
			goto end;
		} else if(containsStartIndex) {
			if(startIndex == lineEndIndex)
				continue;
			
			CGPoint lineOrigin = lineOrigins[i];
			CGFloat ascent, descent, leading;
			CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
			lineWidth = lineWidth;
			
			// If we have more than 1 line, we want to find the real height of the line by measuring the distance between the current line and previous line. If it's only 1 line, then we'll guess the line's height.
			BOOL useRealHeight = i < linesCount - 1;
			CGFloat neighborLineY = i > 0 ? lineOrigins[i - 1].y : (linesCount > i ? lineOrigins[i + 1].y : 0.0f);
			CGFloat lineHeight = ceil(useRealHeight ? fabs(neighborLineY - lineOrigin.y) : ascent + descent + leading);
			CGFloat line_y = round(useRealHeight ? lineOrigin.y + bounds.origin.y - lineHeight/2 + descent : lineOrigin.y - descent + bounds.origin.y);
			
			CGFloat startOffset = CTLineGetOffsetForStringIndex(line, startIndex, NULL);
			CGRect r = CGRectMake(bounds.origin.x + lineOrigin.x + startOffset, line_y, bounds.size.width - startOffset, lineHeight);
			if(rectIndex < maxRects)
				rects[rectIndex++] = r;
		} else if(containsEndIndex) {
			CGPoint lineOrigin = lineOrigins[i];
			CGFloat ascent, descent, leading;
			CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
			lineWidth = lineWidth;
			
			// If we have more than 1 line, we want to find the real height of the line by measuring the distance between the current line and previous line. If it's only 1 line, then we'll guess the line's height.
			BOOL useRealHeight = i < linesCount - 1;
			CGFloat neighborLineY = i > 0 ? lineOrigins[i - 1].y : (linesCount > i ? lineOrigins[i + 1].y : 0.0f);
			CGFloat lineHeight = ceil(useRealHeight ? fabs(neighborLineY - lineOrigin.y) : ascent + descent + leading);
			CGFloat line_y = round(useRealHeight ? lineOrigin.y + bounds.origin.y - lineHeight/2 + descent : lineOrigin.y - descent + bounds.origin.y);
			
			CGFloat endOffset = CTLineGetOffsetForStringIndex(line, endIndex, NULL);
			CGRect r = CGRectMake(bounds.origin.x + lineOrigin.x, line_y, endOffset, lineHeight);
			if(aggregationType == AB_CTLineRectAggregationTypeBlock) {
				r.size.width = bounds.size.width;
			}
			
			if(rectIndex < maxRects)
				rects[rectIndex++] = r;
		} else if(RangeContainsIndex(range, lineRange.location)) {
			CGPoint lineOrigin = lineOrigins[i];
			CGFloat ascent, descent, leading;
			CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
			lineWidth = lineWidth;
			
			// If we have more than 1 line, we want to find the real height of the line by measuring the distance between the current line and previous line. If it's only 1 line, then we'll guess the line's height.
			BOOL useRealHeight = i < linesCount - 1;
			CGFloat neighborLineY = i > 0 ? lineOrigins[i - 1].y : (linesCount > i ? lineOrigins[i + 1].y : 0.0f);
			CGFloat lineHeight = ceil(useRealHeight ? fabs(neighborLineY - lineOrigin.y) : ascent + descent + leading);
			CGFloat line_y = round(useRealHeight ? lineOrigin.y + bounds.origin.y - lineHeight/2 + descent : lineOrigin.y - descent + bounds.origin.y);
			
			CGRect r = CGRectMake(bounds.origin.x + lineOrigin.x, line_y, bounds.size.width, lineHeight);
			if(rectIndex < maxRects)
				rects[rectIndex++] = r;
		}
	}
	
end:
	*rectCount = rectIndex;
}

TUI_EXTERN_C_END
