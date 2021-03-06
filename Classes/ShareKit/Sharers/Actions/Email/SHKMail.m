//
//  SHKMail.m
//  ShareKit
//
//  Created by Nathan Weiner on 6/17/10.

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//

#import "SHKConfiguration.h"
#import "SHKMail.h"


@implementation MFMailComposeViewController (SHK)

- (void)SHKviewDidDisappear:(BOOL)animated
{	
	[super viewDidDisappear:animated];
	
	// Remove the SHK view wrapper from the window (but only if the view doesn't have another modal over it)
	if (self.modalViewController == nil) {
		
        if (![UIViewController instancesRespondToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
            // Remove the SHK view wrapper from the window
            [[SHK currentHelper] viewWasDismissed];
        }
    }
}

@end



@implementation SHKMail

#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle
{
	return SHKLocalizedString(@"Email");
}

+ (BOOL)canShareText
{
	return YES;
}

+ (BOOL)canShareURL
{
	return YES;
}

+ (BOOL)canShareImage
{
	return YES;
}

+ (BOOL)canShareFile
{
	return YES;
}

+ (BOOL)shareRequiresInternetConnection
{
	return NO;
}

+ (BOOL)requiresAuthentication
{
	return NO;
}


#pragma mark -
#pragma mark Configuration : Dynamic Enable

+ (BOOL)canShare
{
	return [MFMailComposeViewController canSendMail];
}

- (BOOL)shouldAutoShare
{
	return YES;
}

- (BOOL)validateItem
{
	BOOL isValid = [super validateItem];
	
	//we can send as long as there is something in one of these fields
	if(isValid == NO && (item.URL || item.title || item.text || item.filename || item.image))
		isValid = YES;

	return isValid;
}


#pragma mark -
#pragma mark Share API Methods

- (BOOL)send
{
	self.quiet = YES;
	
	if (![self validateItem])
		return NO;
	
	return [self sendMail]; // Put the actual sending action in another method to make subclassing SHKMail easier
}

- (BOOL)sendMail
{	
	MFMailComposeViewController *mailController = [[[MFMailComposeViewController alloc] init] autorelease];
	if (!mailController) {
		// e.g. no mail account registered (will show alert)
		[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];
		return YES;
	}
	
    [self retain]; //must retain, because mailController does not retain its delegates. Released in callback.
	mailController.mailComposeDelegate = self;
	mailController.navigationBar.tintColor = SHKCONFIG_WITH_ARGUMENT(barTintForView:,mailController);
	
	NSString *body = item.text;
	BOOL isHTML = self.item.isMailHTML;
	NSString *separator = (isHTML ? @"<br/><br/>" : @"\n\n");
    
	if (body == nil)
	{
		body = @"";
		
		if (item.URL != nil)
		{
			NSString *urlStr = [item.URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			
			if (isHTML)
				body = [body stringByAppendingFormat:@"%@%@", separator, urlStr];
			else
				body = urlStr;
		}
		
		if (item.data)
		{
			NSString *attachedStr = SHKLocalizedString(@"Attached: %@", item.title ? item.title : item.filename);
			
			if (isHTML)
				body = [body stringByAppendingFormat:@"%@%@", separator, attachedStr];
			else
				body = attachedStr;
		}
		
		// fallback
		if (body == nil)
			body = @"";
		
		// sig
		if (self.item.mailShareWithAppSignature)
		{
			body = [body stringByAppendingString:separator];
			body = [body stringByAppendingString:SHKLocalizedString(@"Sent from %@", SHKCONFIG(appName))];
		}
	}
	
	if (item.data)		
		[mailController addAttachmentData:item.data mimeType:item.mimeType fileName:item.filename];
	
	NSArray *toRecipients = self.item.mailToRecipients;
    if (toRecipients)
		[mailController setToRecipients:toRecipients];
    
	if (item.image){
        
        CGFloat jpgQuality = self.item.mailJPGQuality;
        if ((int)jpgQuality  > 1)
        {
            // if rounded jpgQuality is set 2 or higher then we will use PNG for our attachment type.
            [mailController addAttachmentData:UIImagePNGRepresentation(item.image) mimeType:@"image/png" fileName:@"Image.png"];
        }
        else
        {
            [mailController addAttachmentData:UIImageJPEGRepresentation(item.image, jpgQuality) mimeType:@"image/jpeg" fileName:@"Image.jpg"];
        }
	}
	
	[mailController setSubject:item.title];
	[mailController setMessageBody:body isHTML:isHTML];
			
	[[SHK currentHelper] showViewController:mailController];
	
	return YES;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
	[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];
	
	switch (result) 
	{
		case MFMailComposeResultSent:
			[self sendDidFinish];
			break;
		case MFMailComposeResultSaved:
			[self sendDidFinish];
			break;
		case MFMailComposeResultCancelled:
			[self sendDidCancel];
			break;
		case MFMailComposeResultFailed:
			[self sendDidFailWithError:nil];
			break;
	}
	[self autorelease];
}


@end
