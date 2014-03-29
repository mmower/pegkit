#import "ElementParser.h"
#import <PEGKit/PEGKit.h>

#define LT(i) [self LT:(i)]
#define LA(i) [self LA:(i)]
#define LS(i) [self LS:(i)]
#define LF(i) [self LD:(i)]

#define POP()            [self.assembly pop]
#define POP_STR()        [self popString]
#define POP_QUOTED_STR() [self popQuotedString]
#define POP_TOK()        [self popToken]
#define POP_BOOL()       [self popBool]
#define POP_INT()        [self popInteger]
#define POP_UINT()       [self popUnsignedInteger]
#define POP_FLOAT()      [self popFloat]
#define POP_DOUBLE()     [self popDouble]

#define PUSH(obj)      [self.assembly push:(id)(obj)]
#define PUSH_BOOL(yn)  [self pushBool:(BOOL)(yn)]
#define PUSH_INT(i)    [self pushInteger:(NSInteger)(i)]
#define PUSH_UINT(u)   [self pushUnsignedInteger:(NSUInteger)(u)]
#define PUSH_FLOAT(f)  [self pushFloat:(float)(f)]
#define PUSH_DOUBLE(d) [self pushDouble:(double)(d)]

#define EQ(a, b) [(a) isEqual:(b)]
#define NE(a, b) (![(a) isEqual:(b)])
#define EQ_IGNORE_CASE(a, b) (NSOrderedSame == [(a) compare:(b)])

#define MATCHES(pattern, str)               ([[NSRegularExpression regularExpressionWithPattern:(pattern) options:0                                  error:nil] numberOfMatchesInString:(str) options:0 range:NSMakeRange(0, [(str) length])] > 0)
#define MATCHES_IGNORE_CASE(pattern, str)   ([[NSRegularExpression regularExpressionWithPattern:(pattern) options:NSRegularExpressionCaseInsensitive error:nil] numberOfMatchesInString:(str) options:0 range:NSMakeRange(0, [(str) length])] > 0)

#define ABOVE(fence) [self.assembly objectsAbove:(fence)]
#define EMPTY() [self.assembly isStackEmpty]

#define LOG(obj) do { NSLog(@"%@", (obj)); } while (0);
#define PRINT(str) do { printf("%s\n", (str)); } while (0);

@interface PKParser ()
@property (nonatomic, retain) NSMutableDictionary *tokenKindTab;
@property (nonatomic, retain) NSMutableArray *tokenKindNameTab;
@property (nonatomic, retain) NSString *startRuleName;
@property (nonatomic, retain) NSString *statementTerminator;
@property (nonatomic, retain) NSString *singleLineCommentMarker;
@property (nonatomic, retain) NSString *blockStartMarker;
@property (nonatomic, retain) NSString *blockEndMarker;
@property (nonatomic, retain) NSString *braces;

- (BOOL)popBool;
- (NSInteger)popInteger;
- (double)popDouble;
- (PKToken *)popToken;
- (NSString *)popString;

- (void)pushBool:(BOOL)yn;
- (void)pushInteger:(NSInteger)i;
- (void)pushDouble:(double)d;
@end

@interface ElementParser ()

@property (nonatomic, retain) NSMutableDictionary *lists_memo;
@property (nonatomic, retain) NSMutableDictionary *list_memo;
@property (nonatomic, retain) NSMutableDictionary *elements_memo;
@property (nonatomic, retain) NSMutableDictionary *element_memo;
@property (nonatomic, retain) NSMutableDictionary *lbracket_memo;
@property (nonatomic, retain) NSMutableDictionary *rbracket_memo;
@property (nonatomic, retain) NSMutableDictionary *comma_memo;
@end

@implementation ElementParser { }

- (id)initWithDelegate:(id)d {
    self = [super initWithDelegate:d];
    if (self) {
        
        self.startRuleName = @"lists";
        self.tokenKindTab[@"["] = @(ELEMENT_TOKEN_KIND_LBRACKET);
        self.tokenKindTab[@"]"] = @(ELEMENT_TOKEN_KIND_RBRACKET);
        self.tokenKindTab[@","] = @(ELEMENT_TOKEN_KIND_COMMA);

        self.tokenKindNameTab[ELEMENT_TOKEN_KIND_LBRACKET] = @"[";
        self.tokenKindNameTab[ELEMENT_TOKEN_KIND_RBRACKET] = @"]";
        self.tokenKindNameTab[ELEMENT_TOKEN_KIND_COMMA] = @",";

        self.lists_memo = [NSMutableDictionary dictionary];
        self.list_memo = [NSMutableDictionary dictionary];
        self.elements_memo = [NSMutableDictionary dictionary];
        self.element_memo = [NSMutableDictionary dictionary];
        self.lbracket_memo = [NSMutableDictionary dictionary];
        self.rbracket_memo = [NSMutableDictionary dictionary];
        self.comma_memo = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    
    self.lists_memo = nil;
    self.list_memo = nil;
    self.elements_memo = nil;
    self.element_memo = nil;
    self.lbracket_memo = nil;
    self.rbracket_memo = nil;
    self.comma_memo = nil;

    [super dealloc];
}

- (void)_clearMemo {
    [_lists_memo removeAllObjects];
    [_list_memo removeAllObjects];
    [_elements_memo removeAllObjects];
    [_element_memo removeAllObjects];
    [_lbracket_memo removeAllObjects];
    [_rbracket_memo removeAllObjects];
    [_comma_memo removeAllObjects];
}

- (void)start {
    [self lists_]; 
    [self matchEOF:YES]; 
}

- (void)__lists {
    
    do {
        [self list_]; 
    } while ([self speculate:^{ [self list_]; }]);

    [self fireDelegateSelector:@selector(parser:didMatchLists:)];
}

- (void)lists_ {
    [self parseRule:@selector(__lists) withMemo:_lists_memo];
}

- (void)__list {
    
    [self lbracket_]; 
    [self elements_]; 
    [self rbracket_]; 

    [self fireDelegateSelector:@selector(parser:didMatchList:)];
}

- (void)list_ {
    [self parseRule:@selector(__list) withMemo:_list_memo];
}

- (void)__elements {
    
    [self element_]; 
    while ([self speculate:^{ [self comma_]; [self element_]; }]) {
        [self comma_]; 
        [self element_]; 
    }

    [self fireDelegateSelector:@selector(parser:didMatchElements:)];
}

- (void)elements_ {
    [self parseRule:@selector(__elements) withMemo:_elements_memo];
}

- (void)__element {
    
    if ([self predicts:TOKEN_KIND_BUILTIN_NUMBER, 0]) {
        [self matchNumber:NO]; 
    } else if ([self predicts:ELEMENT_TOKEN_KIND_LBRACKET, 0]) {
        [self list_]; 
    } else {
        [self raise:@"No viable alternative found in rule 'element'."];
    }

    [self fireDelegateSelector:@selector(parser:didMatchElement:)];
}

- (void)element_ {
    [self parseRule:@selector(__element) withMemo:_element_memo];
}

- (void)__lbracket {
    
    [self match:ELEMENT_TOKEN_KIND_LBRACKET discard:NO]; 

    [self fireDelegateSelector:@selector(parser:didMatchLbracket:)];
}

- (void)lbracket_ {
    [self parseRule:@selector(__lbracket) withMemo:_lbracket_memo];
}

- (void)__rbracket {
    
    [self match:ELEMENT_TOKEN_KIND_RBRACKET discard:YES]; 

    [self fireDelegateSelector:@selector(parser:didMatchRbracket:)];
}

- (void)rbracket_ {
    [self parseRule:@selector(__rbracket) withMemo:_rbracket_memo];
}

- (void)__comma {
    
    [self match:ELEMENT_TOKEN_KIND_COMMA discard:YES]; 

    [self fireDelegateSelector:@selector(parser:didMatchComma:)];
}

- (void)comma_ {
    [self parseRule:@selector(__comma) withMemo:_comma_memo];
}

@end