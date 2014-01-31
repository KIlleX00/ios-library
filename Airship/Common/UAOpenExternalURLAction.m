/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAOpenExternalURLAction.h"

NSString * const UAOpenExternalURLActionErrorDomain = @"com.urbanairship.actions.externalurlaction";

@implementation UAOpenExternalURLAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    if ([arguments.situation isEqualToString:UASituationBackgroundPush]) {
        return NO;
    }

    if ([arguments.value isKindOfClass:[NSString class]]) {
        return [NSURL URLWithString:arguments.value] != nil;
    }
    return [arguments.value isKindOfClass:[NSURL class]];
}

- (void)performWithArguments:(UAActionArguments *)arguments
       withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    NSURL *url = [self createURLFromValue:arguments.value];

    UAActionResult *result = [UAActionResult resultWithValue:url];

    // do this in the background in case we're opening our own app!
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (![[UIApplication sharedApplication] openURL:url]) {
            // Unable to open url
            result.error =  [NSError errorWithDomain:UAOpenExternalURLActionErrorDomain
                                                code:UAOpenExternalURLActionErrorCodeURLFailedToOpen
                                            userInfo:@{NSLocalizedDescriptionKey : @"Unable to open URL"}];
        }

        completionHandler(result);
    });


}

- (NSURL *)createURLFromValue:(id)value {
    NSURL *url = [value isKindOfClass:[NSURL class]] ? value : [NSURL URLWithString:value];

    if ([[url host] isEqualToString:@"phobos.apple.com"] || [[url host] isEqualToString:@"itunes.apple.com"]) {
        // Set the url scheme to http, as it could be itms which will cause the store to launch twice (undesireable)
        url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@%@", url.host, url.path]];
    } else if ([[url scheme] isEqualToString:@"tel"] || [[url scheme] isEqualToString:@"sms"]) {
        
        NSString *decodedUrlString = [url.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSCharacterSet *characterSet = [[NSCharacterSet characterSetWithCharactersInString:@"+-.0123456789"] invertedSet];
        NSString *strippedNumber = [[decodedUrlString componentsSeparatedByCharactersInSet:characterSet] componentsJoinedByString:@""];

        NSString *scheme = [decodedUrlString hasPrefix:@"sms"] ? @"sms:" : @"tel:";
        url = [NSURL URLWithString:[scheme stringByAppendingString:strippedNumber]];
    }

    return url;
}

#pragma mark -
#pragma mark Internal (Unused - TODO) Utilities for Testing URL Support

/**
 * Tests whether or not a given URL can be handled by the current application via the UIApplicationDelegate
 * URL handlers. To support a URL, the scheme must be declared in the application's Info.plist, and
 * the proper handlers must be provided in the application delegate.
 *
 * @return `YES` if the current application can handle the URL, otherwise `NO`.
 *
 */
- (BOOL)currentApplicationHandlesURL:(NSURL *)url {
    NSArray *schemes = [self supportedSchemes];
    return  [[UIApplication sharedApplication].delegate respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)]
                && [schemes containsObject:[url scheme]];
}

/**
 * Returns the array of URI schemes that this application will handle for other applications.
 *
 * @return An NSArray of schemes, as NSString. Empty if no schemes are supported.
 */
- (NSArray *)supportedSchemes {

    // TODO: needs tests using a mock plist

    NSMutableArray *schemes = [NSMutableArray array];

    // Look at our plist
    // CFBundleURLTypes contains an array of actions, each containing a dictionary with the details.
    // We care about the nested CFBundleURLSchemes array, which contains a list of schemes
    NSArray *bundleURLTypes = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleURLTypes"];
    [bundleURLTypes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [schemes addObjectsFromArray:[bundleURLTypes[idx] objectForKey:@"CFBundleURLSchemes"]];
    }];

    return schemes;
}

@end
