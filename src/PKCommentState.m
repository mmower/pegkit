// The MIT License (MIT)
// 
// Copyright (c) 2014 Todd Ditchendorf
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy 
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is 
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <PEGKit/PKCommentState.h>
#import <PEGKit/PKTokenizer.h>
#import <PEGKit/PKToken.h>
#import <PEGKit/PKReader.h>
#import <PEGKit/PKSingleLineCommentState.h>
#import <PEGKit/PKMultiLineCommentState.h>
#import "PKSymbolRootNode.h"

@interface PKToken ()
@property (nonatomic, readwrite) NSUInteger offset;
@end

@interface PKTokenizerState ()
- (void)resetWithReader:(PKReader *)r;
- (PKTokenizerState *)nextTokenizerStateFor:(PKUniChar)c tokenizer:(PKTokenizer *)t;
@property (nonatomic) NSUInteger offset;
@end

@interface PKCommentState ()
@property (nonatomic, retain) PKSymbolRootNode *rootNode;
@property (nonatomic, retain) PKSingleLineCommentState *singleLineState;
@property (nonatomic, retain) PKMultiLineCommentState *multiLineState;
@end

@interface PKSingleLineCommentState ()
- (void)addStartMarker:(NSString *)start;
- (void)removeStartMarker:(NSString *)start;
@property (nonatomic, retain) NSMutableArray *startMarkers;
@property (nonatomic, retain) NSString *currentStartMarker;
@end

@interface PKMultiLineCommentState ()
- (void)addStartMarker:(NSString *)start endMarker:(NSString *)end;
- (void)removeStartMarker:(NSString *)start;
@property (nonatomic, retain) NSMutableArray *startMarkers;
@property (nonatomic, retain) NSMutableArray *endMarkers;
@property (nonatomic, copy) NSString *currentStartMarker;
@end

@implementation PKCommentState

- (id)init {
    self = [super init];
    if (self) {
        self.rootNode = [[[PKSymbolRootNode alloc] init] autorelease];
        self.singleLineState = [[[PKSingleLineCommentState alloc] init] autorelease];
        self.multiLineState = [[[PKMultiLineCommentState alloc] init] autorelease];
    }
    return self;
}


- (void)dealloc {
    self.rootNode = nil;
    self.singleLineState = nil;
    self.multiLineState = nil;
    [super dealloc];
}


- (void)addSingleLineStartMarker:(NSString *)start {
    NSParameterAssert([start length]);
    [rootNode add:start];
    [singleLineState addStartMarker:start];
}


- (void)removeSingleLineStartMarker:(NSString *)start {
    NSParameterAssert([start length]);
    [rootNode remove:start];
    [singleLineState removeStartMarker:start];
}


- (void)addMultiLineStartMarker:(NSString *)start endMarker:(NSString *)end {
    NSParameterAssert([start length]);
    NSParameterAssert([end length]);
    [rootNode add:start];
    [rootNode add:end];
    [multiLineState addStartMarker:start endMarker:end];
}


- (void)removeMultiLineStartMarker:(NSString *)start {
    NSParameterAssert([start length]);
    [rootNode remove:start];
    [multiLineState removeStartMarker:start];
}


- (PKToken *)nextTokenFromReader:(PKReader *)r startingWith:(PKUniChar)cin tokenizer:(PKTokenizer *)t {
    NSParameterAssert(r);
    NSParameterAssert(t);

    [self resetWithReader:r];

    NSString *symbol = [rootNode nextSymbol:r startingWith:cin];
    PKToken *tok = nil;
    
    while ([symbol length]) {
        if ([multiLineState.startMarkers containsObject:symbol]) {
            multiLineState.currentStartMarker = symbol;
            tok = [multiLineState nextTokenFromReader:r startingWith:cin tokenizer:t];
            if (tok.isComment) {
                tok.offset = self.offset;
            }
        } else if ([singleLineState.startMarkers containsObject:symbol]) {
            singleLineState.currentStartMarker = symbol;
            tok = [singleLineState nextTokenFromReader:r startingWith:cin tokenizer:t];
            if (tok.isComment) {
                tok.offset = self.offset;
            }
        }
        
        if (tok) {
            return tok;
        } else {
            if ([symbol length] > 1) {
                symbol = [symbol substringToIndex:[symbol length] - 1];
            } else {
                break;
            }
            [r unread:1];
        }
    }

    return [[self nextTokenizerStateFor:cin tokenizer:t] nextTokenFromReader:r startingWith:cin tokenizer:t];
}

@synthesize rootNode;
@synthesize singleLineState;
@synthesize multiLineState;
@synthesize reportsCommentTokens;
@synthesize balancesEOFTerminatedComments;
@end
