//
//  AfloatPanelController.m
//  AfloatHUD
//
//  Created by ∞ on 04/03/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "AfloatPanelController.h"
#import <QuartzCore/QuartzCore.h>
#import "AfloatStorage.h"
#import "Afloat.h"

#define kAfloatPanelControllerKey @"AfloatPanelController"

@interface AfloatPanelController ()
- (void) positionWindowRelativeToParentWindow;
@end

@implementation AfloatPanelController

/*
+ (void) initialize {
	[self setKeys:[NSArray arrayWithObject:@"parentWindow"] triggerChangeNotificationsForDependentKey:@"alphaValue"];
}
 
 // Replaced by nondeprecated variant below.
 
*/
+ (NSSet*) keyPathsForValuesAffectingAlphaValue;
{
    return [NSSet setWithObject:@"parentWindow"];
}

@synthesize parentWindow = _parentWindow;

- (void) setParentWindow:(NSWindow*) newParent {
    
    L0LogS(@"setParentWindow");
	if (newParent != _parentWindow) {
		if (_parentWindow) {
			[AfloatStorage removeSharedValueForWindow:_parentWindow key:kAfloatPanelControllerKey];
			[_parentWindow removeChildWindow:[self window]];
			
			[[NSNotificationCenter defaultCenter]
			 removeObserver:self name:NSWindowDidResizeNotification object:_parentWindow];
						
			[_parentWindow release];
		}
		
		if (newParent) {
			[AfloatStorage setSharedValue:self window:newParent key:kAfloatPanelControllerKey];
			
			[[NSNotificationCenter defaultCenter]
			 addObserver:self selector:@selector(parentWindowDidResize:) name:NSWindowDidResizeNotification object:_parentWindow];
			
			
			[newParent retain];
		}
		
		_parentWindow = newParent;
		
		[[self window] setCollectionBehavior:[self.parentWindow collectionBehavior]];
	}
}

- (void) parentWindowDidResize:(NSNotification*) n {
    L0LogS(@"parentWindowDidResize");
	NSWindow* w = [self window];
	if (![w isVisible]) return;
	
	[self positionWindowRelativeToParentWindow];
}

- (void) positionWindowRelativeToParentWindow {
    L0LogS(@"positionWindowRelativeToParentWindow");
	NSRect contentRect = [self.parentWindow contentRectForFrameRect:[self.parentWindow frame]];
	NSWindow* w = [self window];
	NSRect frame = [w frame];
	
	NSPoint newOrigin = contentRect.origin;
	newOrigin.x += contentRect.size.width / 2;
	newOrigin.x -= frame.size.width / 2;
	newOrigin.y += contentRect.size.height;
	newOrigin.y -= frame.size.height;
	newOrigin.y += 4;
	
	[w setFrameOrigin:newOrigin];
}

- (id) initAttachedToWindow:(NSWindow*) parentWindow {
    L0LogS(@"initAttachedToWindow");
	if (self = [self initWithWindowNibName:@"AfloatPanel" owner:self]) {
		self.parentWindow = parentWindow;
		lastAlpha = -1;
	}
	
	return self;
}

+ (id) panelControllerForWindow:(NSWindow*) w {
    L0LogS(@"panelControllerForWindow");
	id panel = [AfloatStorage sharedValueForWindow:w key:kAfloatPanelControllerKey];
	if (panel)
		return panel;
	else
		return [[[self alloc] initAttachedToWindow:w] autorelease];
}

- (void) dealloc {
    L0LogS(@"dealloc");
	[AfloatStorage removeSharedValueForWindow:self.parentWindow key:kAfloatPanelControllerKey];
	self.parentWindow = nil;
	[super dealloc];
}

- (IBAction) toggleWindow:(id) sender {
    L0LogS(@"toggleWindow");
	if ([[self window] isVisible])
    {
		[self hideWindow:sender];
        L0LogS(@"hideWindow");
    }
	else
    {
		[self showWindow:sender];
        L0LogS(@"showWindow");
    }
}

- (IBAction) showWindow:(id) sender {
    L0LogS(@"showWindow");
	[self positionWindowRelativeToParentWindow];
	
	[self willChangeValueForKey:@"alphaValue"];
	[self didChangeValueForKey:@"alphaValue"]; // causes an update to trigger, just in case

	NSDisableScreenUpdates();
	
	NSWindow* w = [self window];
	[w setAlphaValue:0];
	[self.parentWindow addChildWindow:[self window] ordered:NSWindowAbove];
	
	NSEnableScreenUpdates();

	[NSAnimationContext beginGrouping];
		[[NSAnimationContext currentContext] setDuration:0.2];
		[(NSWindow*)[w animator] setAlphaValue:1.0];
	[NSAnimationContext endGrouping];
	
}

- (IBAction) hideWindow:(id) sender {
    L0LogS(@"hideWindow");
	self.parentWindow = nil;
	NSWindow* w = [self window];

	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.2];
		[(NSWindow*)[w animator] setAlphaValue:0];
	[NSAnimationContext endGrouping];
	
	[self performSelector:@selector(hideWindowImmediatly) withObject:nil afterDelay:0.5];
}

- (void) hideWindowImmediatly {
    L0LogS(@"hideWindowImmediatly");
	[self.parentWindow removeChildWindow:[self window]];
	[[self window] orderOut:self];
}

- (CGFloat) alphaValue {
    L0LogS(@"alphaValue");
	if (self.parentWindow) {
		lastAlpha = [[Afloat sharedInstance] currentAlphaValueForWindow:self.parentWindow];
		return lastAlpha;
	} else if (lastAlpha >= 0.0)
		return lastAlpha;
	else
		return 0.0;
		
}

- (void) setAlphaValue:(CGFloat) newAlpha {
    L0LogS(@"setAlphaValue");
	lastAlpha = newAlpha;
	[[Afloat sharedInstance] setAlphaValue:newAlpha forWindow:self.parentWindow animated:YES];
}

//- (BOOL) isKeptAfloat {
//	return [[Afloat sharedInstance] isWindowKeptAfloat:self.parentWindow];
//}

- (AfloatWindowState) windowState {
    L0LogS(@"windowState");
	Afloat* a = [Afloat sharedInstance];
	
	if ([a isWindowKeptAfloat:self.parentWindow])
		return kAfloatWindowStateAfloat;
	else if ([a isWindowKeptPinnedToDesktop:self.parentWindow])
		return kAfloatWindowStatePinnedToDesktop;
	else
		return kAfloatWindowStateNormal;
}

- (void) setWindowState:(AfloatWindowState) state {
    L0LogS(@"setWindowState");
	[self willChangeValueForKey:@"overlay"];

	Afloat* a = [Afloat sharedInstance];
	
	switch (state) {
		case kAfloatWindowStateNormal:
			[a setKeptAfloat:NO forWindow:self.parentWindow showBadgeAnimation:NO];
            L0Log(@"setWindowState: Set window afloat = %d with badge animation = %d", NO, NO);
			[a setKeptPinnedToDesktop:NO forWindow:self.parentWindow showBadgeAnimation:NO];
            L0Log(@"setWindowState: Set window pinned to desktop = %d with badge animation = %d", NO, NO);
			break;
			
		case kAfloatWindowStateAfloat:
			[a setKeptAfloat:YES forWindow:self.parentWindow showBadgeAnimation:NO];
            L0Log(@"setWindowState: Set window afloat = %d with badge animation = %d", YES, NO);
			break;
			
		case kAfloatWindowStatePinnedToDesktop:
			[a setKeptPinnedToDesktop:YES forWindow:self.parentWindow showBadgeAnimation:NO];
            L0Log(@"setWindowState: Set window pinned to desktop = %d with badge animation = %d", YES, NO);
			break;
	}

	[self didChangeValueForKey:@"overlay"];
}

//- (void) setKeptAfloat:(BOOL) afloat {
//	[self willChangeValueForKey:@"overlay"];
//
//	[[Afloat sharedInstance] setKeptAfloat:afloat forWindow:self.parentWindow showBadgeAnimation:NO];
//	
//	[self didChangeValueForKey:@"overlay"];
//}

- (BOOL) isOnAllSpaces {
    L0LogS(@"isOnAllSpaces");
	return [[Afloat sharedInstance] isWindowOnAllSpaces:self.parentWindow];
}

- (void) setOnAllSpaces:(BOOL) spaces {
    L0LogS(@"setOnAllSpaces");
	[[Afloat sharedInstance] setOnAllSpaces:spaces forWindow:self.parentWindow];
	[[self window] setCollectionBehavior:[self.parentWindow collectionBehavior]];
}

- (BOOL) alphaValueAnimatesOnMouseOver {
    L0LogS(@"alphaValueAnimatesOnMouseOver");
	return [[Afloat sharedInstance] alphaValueAnimatesOnMouseOverForWindow:self.parentWindow];
}

- (void) setAlphaValueAnimatesOnMouseOver:(BOOL) animates {
    L0LogS(@"setAlphaValueAnimatesOnMouseOver");
	[[Afloat sharedInstance] setAlphaValueAnimatesOnMouseOver:animates forWindow:self.parentWindow];
}

- (BOOL) isOverlay {
    L0LogS(@"isOverlay");
	return [[Afloat sharedInstance] isWindowOverlay:self.parentWindow];
}

- (IBAction)pinnedToDesktop:(id)sender
{
    self.windowState = kAfloatWindowStatePinnedToDesktop;
}

- (void) setOverlay:(BOOL) overlay {
    L0LogS(@"setOverlay");
	[self willChangeValueForKey:@"alphaValue"];
	[self willChangeValueForKey:@"keptAfloat"];
	[self willChangeValueForKey:@"alphaValueAnimatesOnMouseOver"];
	[self willChangeValueForKey:@"canSetAlphaValueAnimatesOnMouseOver"];
	[self willChangeValueForKey:@"windowState"];

	[[Afloat sharedInstance] setOverlay:overlay forWindow:self.parentWindow animated:YES showBadgeAnimation:NO];

	[self didChangeValueForKey:@"windowState"];
	[self didChangeValueForKey:@"canSetAlphaValueAnimatesOnMouseOver"];
	[self didChangeValueForKey:@"alphaValueAnimatesOnMouseOver"];
	[self didChangeValueForKey:@"keptAfloat"];
	[self didChangeValueForKey:@"alphaValue"];
}

- (IBAction) disableAllOverlays:(id) sender {
    L0LogS(@"disableAllOverlays");
	[self willChangeValueForKey:@"overlay"];
	[self willChangeValueForKey:@"alphaValue"];
	[self willChangeValueForKey:@"keptAfloat"];
	[self willChangeValueForKey:@"alphaValueAnimatesOnMouseOver"];
	[self willChangeValueForKey:@"canSetAlphaValueAnimatesOnMouseOver"];
	
	[[Afloat sharedInstance] disableAllOverlaysShowingBadgeAnimation:NO];
	
	[self didChangeValueForKey:@"canSetAlphaValueAnimatesOnMouseOver"];
	[self didChangeValueForKey:@"alphaValueAnimatesOnMouseOver"];
	[self didChangeValueForKey:@"keptAfloat"];
	[self didChangeValueForKey:@"alphaValue"];
	[self didChangeValueForKey:@"overlay"];
}

- (BOOL) canSetAlphaValueAnimatesOnMouseOver {
    L0LogS(@"canSetAlphaValueAnimatesOnMouseOver");
	return !self.overlay;
}

@end
