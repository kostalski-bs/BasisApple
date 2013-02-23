#import "ObjectManager.h"

@implementation ObjectManager

NSMutableDictionary *_objects;
NSMutableDictionary *_classTypes;

- (id) init
{
	self = [super init];
	if (self != nil)
	{
	    _objects = [[NSMutableDictionary alloc] init];
	    _classTypes = [[NSMutableDictionary alloc] init];
	    _delegate = nil;
	}
	return self;
}


+(NSString*) getObjectID:(id)object
{
    return [NSString stringWithFormat:@"%zx", (size_t)object];
}

-(void)setDelegate:(NSObject <ObjectManagerDelegateProtocol>*)delegate;
{
	_delegate = delegate;
}

-(void) addClass:(NSString *) haxeName :(NSString *) objcName
{
	[_classTypes setObject:haxeName forKey:objcName];
	[_classTypes setObject:objcName forKey:haxeName];
}

-(NSString *) getObjCClassName:(NSString *)haxeName
{
	return [_classTypes objectForKey:haxeName];
}

-(id) getObject:(NSString *) objectID
{
	return [_objects objectForKey:objectID];
}

-(NSString *) addObject:(NSObject*)object
{
	NSString* objectID = [ObjectManager getObjectID:object];
	[_objects setObject:object forKey:objectID];
	if(_delegate != nil)
		[_delegate objectBeingAdded:object];
	return objectID;
}

-(NSString *) createObjectWithClassName:(NSString*)haxeClassName
{
	NSString *className = [_classTypes objectForKey:haxeClassName];
	id object = [[NSClassFromString(className) alloc] init];
	return [self addObject:object];
}

-(id) callMethod:(id)object :(NSString *)selectorString :(NSArray *)args :(BOOL)isObject
{
	SEL msel;
    NSMethodSignature *signature;
    NSInvocation *invocation;
    @try {
        msel = NSSelectorFromString(selectorString);
        signature = [object methodSignatureForSelector:msel];
        invocation = [NSInvocation invocationWithMethodSignature:signature];
    }
    @catch (NSException *exception) {
        NSLog(@"Method signature does not exist: %@", selectorString);
        return nil;
    }
    [invocation setTarget:object];
    [invocation setSelector:msel];
    for(int a=0; a < args.count; ++a)
    {
        id currentValTMP = [args objectAtIndex:a];
        if([currentValTMP isKindOfClass:[NSValue class]])
        {
            NSUInteger bufferSize = 0;
            NSGetSizeAndAlignment([currentValTMP objCType], &bufferSize, NULL);
            void* buffer = malloc(bufferSize);
            [currentValTMP getValue:buffer];
            [invocation setArgument:buffer atIndex:a + 2];
            free(buffer);
        }
        else
            [invocation setArgument:&currentValTMP atIndex:a + 2];
    }
    
    [invocation invoke];
    
    if([[invocation methodSignature] methodReturnLength] <= 0)
        return nil;
    
    if(isObject)
    {
	    CFTypeRef result;
	    [invocation getReturnValue:&result];
	    if (result)
	    {
	        id object = (__bridge id)result;
	        return object;
	    }
	}
	else
	{
		NSUInteger length = [[invocation methodSignature] methodReturnLength];
		void *returnBuffer = (void *)malloc(length);
		[invocation getReturnValue:returnBuffer];
		NSValue *nsValue = [NSValue valueWithBytes:returnBuffer objCType:[[invocation methodSignature] methodReturnType]];
		free(returnBuffer);
		return nsValue;
	}
    return nil;
}

-(void) destroyObject:(NSString *) objectID
{
	id object = [self getObject:objectID];
	[_objects removeObjectForKey:objectID];
	
	if(_delegate != nil)
		[_delegate objectBeingDestroyed:object];
	
	[self destroyCFFIObject:object];
}

-(void) destroyCFFIObject:(id) object
{
}



@end
