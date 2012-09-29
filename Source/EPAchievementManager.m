/*
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * The names of its contributors may not be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

//
//  AchievementManager.m
//
//  Created by Simone Manganelli on 2012-03-19
//

#import "EPAchievementManager.h"
#import "EPViewController.h"
#import "NSData+AES256.h"

#warning Change the value of these defines for your app!
#define HASH_SALT_PREFIX_STRING @"%84kbec209249y!NTB309g"
#define HASH_SALT_SUFFIX_STRING @"X)894di0.cehy37#c3dhyt"


@interface EPAchievementManager (Private)

- (void)loadAchievements;
- (void)confirmGameCenterReset;
- (void)resetAll;
- (void)resetAchievements;
- (void)saveUnreportedGameCenterAchievements;

@end


@implementation EPAchievementManager

@synthesize delegate = _delegate;
@synthesize localPlayer = _localPlayer;
@synthesize localScores = _localScores;
@synthesize localScorePlayerInfoArray = _localScorePlayerInfoArray;

#warning This is connected in the xib.  Change it to use your controller!
@synthesize viewController = _viewController;



static EPAchievementManager *sharedAchievementManager = nil;


#pragma mark Initialization Stuff

+ (EPAchievementManager*)sharedManager
{
    @synchronized(self) {
        if (sharedAchievementManager == nil) {
            sharedAchievementManager = [[self allocWithZone:NULL] init];
        }
    }
	
    return sharedAchievementManager;
}



+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedAchievementManager == nil) {
            sharedAchievementManager = [super allocWithZone:zone];
            return sharedAchievementManager;
        }
    }
	
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)init;
{
    if ( (self = [super init]) ) {
		localAchievementsDict = [[NSMutableDictionary alloc] init];
		unreportedAchievementDict = [[NSMutableDictionary alloc] init];
        currentlyBeingReportedArray = [[NSMutableArray alloc] init];
		
		[self loadUnreportedGameCenterAchievements];
    }
    
    return self;
}


#pragma mark Returning from Background

- (void)applicationDidBecomeActive:(UIApplication *)application;
{
    [self checkGameCenterResetPref];
    [self disposeOfCurrentGameCenterLocalPlayer];
}


#pragma mark Public Achievements and Scores Stuff Methods

- (void)reportScore:(NSString *)leaderboardIdentifier
              score:(NSInteger)newScoreValue;
{
    GKScore *newScore = [[GKScore alloc] initWithCategory:leaderboardIdentifier];
    [newScore setValue:newScoreValue];
    [self saveScoreOrAchievement:newScore];
    
    [self reportUnreportedAchievements];
}

- (void)reportAchievementIdentifier:(NSString*)identifier
                    percentComplete:(CGFloat)percent;
{
    GKAchievement *anAchievement = [[GKAchievement alloc] initWithIdentifier:identifier];
	anAchievement.percentComplete = percent;
    [self saveScoreOrAchievement:anAchievement];
    
    [self reportUnreportedAchievements];
}

- (void)showAchievements;
{
    [self showAchievementsOrScores:YES];
}

- (void)showScores;
{
    [self showAchievementsOrScores:NO];
}

#pragma mark Private Methods

- (NSURL *)unreportedAchievementsURL;
{
	// some bits modified from the iOS File System Programming Guide
	
	if (! unreportedAchievementsURL) {
		NSFileManager *sharedManager = [NSFileManager defaultManager];
		NSArray *possibleURLs = [sharedManager URLsForDirectory:NSDocumentDirectory
													  inDomains:NSUserDomainMask];
		NSURL *documentDirectory = nil;
		
		if ([possibleURLs count] >= 1) {
			// Use the first directory (if multiple are returned)
			documentDirectory = [possibleURLs objectAtIndex:0];
		}
		
		// If a valid app support directory exists, add the
		// app's bundle ID to it to specify the final directory.
		if (documentDirectory) {
			unreportedAchievementsURL = [documentDirectory URLByAppendingPathComponent:@"gameCenterAchievements.plist"];
		}
	}
	
	return unreportedAchievementsURL;
}

- (NSURL *)achievementHashURL;
{
    NSURL *dataURL = [self unreportedAchievementsURL];
    NSURL *newURL = [[dataURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@".hash"];
    
    return newURL;
}  


- (void)loadUnreportedGameCenterAchievements;
{
	NSData *achievementData = [NSData dataWithContentsOfURL:[self unreportedAchievementsURL]];
    NSData *savedHashData = [NSData dataWithContentsOfURL:[self achievementHashURL]];
    
    if (achievementData && savedHashData) {
        NSString *savedHash = [[NSString alloc] initWithData:savedHashData encoding:NSUTF8StringEncoding];
        
        NSData *suffixData = [HASH_SALT_SUFFIX_STRING dataUsingEncoding:NSUTF8StringEncoding];
        NSData *prefixData = [HASH_SALT_PREFIX_STRING dataUsingEncoding:NSUTF8StringEncoding];
        
        NSMutableData *computedData = [NSMutableData dataWithData:prefixData];
        [computedData appendData:achievementData];
        [computedData appendData:suffixData]; 
        
        NSString *computedHash = [computedData md5String];
        
        if ([savedHash isEqualToString:computedHash]) {
            // the hashes match, the unreported achievements file hasn't been
            // tampered with
            
            //NSLog(@"The unreported achievements match!");
            NSDictionary *achievementDict = (NSDictionary *)[NSKeyedUnarchiver unarchiveObjectWithData:achievementData];
            [unreportedAchievementDict addEntriesFromDictionary:achievementDict];
        } else {
            NSLog(@"Unreported achievements have been tampered with!");
            
            // since the global variable for unreported achievements is empty
            // at this point, this will write an empty file
            [self saveUnreportedGameCenterAchievements];
        }
    } else if (achievementData) {
        NSLog(@"Only achievements, no hash!  Bye-bye!");
        [self saveUnreportedGameCenterAchievements];
    } else if (savedHashData) {
        NSLog(@"Only hash, no achievements.  Oh well!");
        [self saveUnreportedGameCenterAchievements];
    }
}

- (void)saveUnreportedGameCenterAchievements;
{
    NSData *achievementData = [NSKeyedArchiver archivedDataWithRootObject:unreportedAchievementDict];
    NSData *prefixData = [HASH_SALT_PREFIX_STRING dataUsingEncoding:NSUTF8StringEncoding];
	NSData *suffixData = [HASH_SALT_SUFFIX_STRING dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableData *totalData = [NSMutableData dataWithData:prefixData];
    [totalData appendData:achievementData];
    [totalData appendData:suffixData];
    
    BOOL success = [achievementData writeToURL:[self unreportedAchievementsURL]
                                              atomically:YES];
    if (! success) NSLog(@"Could not save unreported achievements to a file?!");
    
    NSData *hashData = [[totalData md5String] dataUsingEncoding:NSUTF8StringEncoding];
    [hashData writeToURL:[self achievementHashURL] atomically:YES];
}




- (NSString *)gameCenterPlayerID;
{
	NSString *playerID = nil;
	GKLocalPlayer *theLocalPlayer = [self localPlayer];
	
	if (theLocalPlayer != nil) {
		if (theLocalPlayer.isAuthenticated) {
			playerID = theLocalPlayer.playerID;
		}
	}
	
	return playerID;
}

// modified from Game Kit Programming Guide
- (BOOL)isGameCenterAPIAvailable;
{
    // Check for presence of GKLocalPlayer class.
    BOOL localPlayerClassAvailable = (NSClassFromString(@"GKLocalPlayer")) != nil;
    
    // The device must be running iOS 4.1 or later.
    NSString *reqSysVer = @"4.2";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
    
    return (localPlayerClassAvailable && osVersionSupported);
}

- (void)disposeOfCurrentGameCenterLocalPlayer;
{
    BOOL noLocalPlayer = ([self localPlayer] == nil);
    
    
    // this isn't strictly necessary as the +localPlayer method
    // returns a singleton, but that's an implementation detail
    GKLocalPlayer *theLocalPlayer = [GKLocalPlayer localPlayer];
    [self setLocalPlayer:theLocalPlayer];
    
	
	if (noLocalPlayer ) {
		[self authenticateLocalPlayer];
	}
}

// modified from Game Kit Programming Guide
- (void)authenticateLocalPlayer
{
    if ([self isGameCenterAPIAvailable]) {
        GKLocalPlayer *theLocalPlayer = [GKLocalPlayer localPlayer];
		
        [theLocalPlayer authenticateWithCompletionHandler:^(NSError *error) {
            if (theLocalPlayer.isAuthenticated) {
                // Perform additional tasks for the authenticated player.

                [[NSNotificationCenter defaultCenter] postNotificationName:@"AFDidLogInToGameCenter"
                                                                    object:nil
                                                                  userInfo:nil];
                [self loadAchievements];
            } else {
				if ([error code] == 2) {
					NSLog(@"Please to be logging in to Game Center via the Game Center app.  KTHXBAI!");
				} else {
					NSLog(@"Error in logging into Game Center: %@, localPlayer: %@",error,theLocalPlayer);
				}
            }
        }];
    }
}

- (void)loadAchievements;
{
    [GKAchievement loadAchievementsWithCompletionHandler:^(NSArray *achievementsArray, NSError *error) {
        if (error == nil) {
			[localAchievementsDict removeAllObjects];
			
			for (GKAchievement *currentAchievement in achievementsArray) {
				[localAchievementsDict setObject:currentAchievement
										  forKey:currentAchievement.identifier];
			}
		} else {
			NSLog(@"Error retrieving achievements: %@",error);
		}
    }];
    
    
    GKLeaderboard *leaderboardRequest = [[GKLeaderboard alloc] init];
    if (leaderboardRequest != nil)
    {
        leaderboardRequest.playerScope = GKLeaderboardPlayerScopeFriendsOnly;
        leaderboardRequest.timeScope = GKLeaderboardTimeScopeAllTime;
        leaderboardRequest.range = NSMakeRange(1,5);
        [leaderboardRequest loadScoresWithCompletionHandler: ^(NSArray *scores, NSError *error) {
            if (error != nil)
            {
                NSLog(@"Error retrieving scores: %@",error);
            }
            if (scores != nil)
            {
                [self setLocalScores:scores];
                
                NSMutableArray *playerIDArray = [NSMutableArray array];
                for (GKScore *currentScore in scores) {
                    [playerIDArray addObject:currentScore.playerID];
                }
                
                [GKPlayer loadPlayersForIdentifiers:playerIDArray withCompletionHandler:^(NSArray *players, NSError *error) {
                    if (error != nil)
                    {
                        // Handle the error.
                        NSLog(@"Error retrieving player information: %@",error);
                        
                    }
                    if (players != nil)
                    {
                        // Process the array of GKPlayer objects.
                        [self setLocalScorePlayerInfoArray:players];
                    }
                }];
            }
        }];
    }
}

// modified from Game Kit Programming Guide
- (void)showAchievementsOrScores:(BOOL)showAchievements;
{
    id gameCenterViewController = nil;
    
    if (showAchievements) {
        GKAchievementViewController *achievementsController = [[GKAchievementViewController alloc] init];
        if (achievementsController) {
            achievementsController.achievementDelegate = self;
            gameCenterViewController = achievementsController;
        }
    } else {
        GKLeaderboardViewController *leaderboardController = [[GKLeaderboardViewController alloc] init];
        if (leaderboardController) {
            leaderboardController.leaderboardDelegate = self;
            gameCenterViewController = leaderboardController;
        }
    }
    GKLocalPlayer *theLocalPlayer = [self localPlayer];
	
	BOOL controllerSuccess = (gameCenterViewController != nil);
	BOOL localPlayerExists = (theLocalPlayer != nil);
	BOOL localPlayerIsAuthenticated = (theLocalPlayer.isAuthenticated);
	
	BOOL shouldShowAchievements = (controllerSuccess && localPlayerExists && localPlayerIsAuthenticated);
	
    if (shouldShowAchievements) {
		[[self viewController] presentModalViewController:gameCenterViewController animated: YES];
    } else {
		UIAlertView *notLoggedInAlertView = [[UIAlertView alloc] initWithTitle:@"Not Logged In"
																	   message:@"Please log in to Game Center to show achievements."
																	  delegate:nil
															 cancelButtonTitle:@"Cancel"
															 otherButtonTitles:nil];
		
		[notLoggedInAlertView show];
	}
}





- (void)achievementViewControllerDidFinish:(GKAchievementViewController *)viewController
{
    [[self viewController] dismissModalViewControllerAnimated:YES];
}

- (void)leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)viewController
{
    [[self viewController] dismissModalViewControllerAnimated:YES];
}



- (void)saveScoreOrAchievement:(id)gameCenterObjectToSave;
{	
	@synchronized(unreportedAchievementDict) {
		NSString *playerID = [self gameCenterPlayerID];
		
		// we store achievements for players when not logged into Game Center,
		// and then report them as the next logged in Game Center user
		if (! playerID) playerID = @"";
		
		NSMutableArray *unreportedAchievementArray = [NSMutableArray arrayWithArray:[unreportedAchievementDict objectForKey:playerID]];
		if (! unreportedAchievementArray) unreportedAchievementArray = [NSMutableArray array];
		
        NSArray *matchingObjectsArray = nil;
        if ([gameCenterObjectToSave isKindOfClass:[GKScore class]]) {
            // score
            NSString *category = ((GKScore *)gameCenterObjectToSave).category;
            NSArray *allScoresArray = [unreportedAchievementArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self isKindOfClass: %@",[GKScore class]]];
            matchingObjectsArray = [allScoresArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@",@"category",category]];
        } else {
            // achievement
            NSString *identifier = ((GKAchievement *)gameCenterObjectToSave).identifier;
            NSArray *allAchievementsArray = [unreportedAchievementArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self isKindOfClass: %@",[GKAchievement class]]];
            matchingObjectsArray = [allAchievementsArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@",@"identifier",identifier]];
        }
		
		for (id currentObject in matchingObjectsArray) {
			[unreportedAchievementArray removeObject:currentObject];
		}
		
		[unreportedAchievementArray addObject:gameCenterObjectToSave];
		[unreportedAchievementDict setObject:unreportedAchievementArray
									  forKey:playerID];
		
		[self saveUnreportedGameCenterAchievements];
	}
}


- (void)removeAchievementFromUnreportedAchievements:(id)gameCenterObjectToRemove;
{
    @synchronized(unreportedAchievementDict) {
        NSString *playerID = [self gameCenterPlayerID];
        
        NSArray *immutableUnreportedAchievementArray = [unreportedAchievementDict objectForKey:playerID];
        NSArray *immutableUnreportedAchievementForNilUserArray = [unreportedAchievementDict objectForKey:@""];
        
        NSMutableArray *achievementArray = nil;
        NSMutableArray *nilUserAchievementArray = nil;
        
        if (immutableUnreportedAchievementArray) achievementArray = [NSMutableArray arrayWithArray:immutableUnreportedAchievementArray];
        if (immutableUnreportedAchievementForNilUserArray) nilUserAchievementArray = [NSMutableArray arrayWithArray:immutableUnreportedAchievementForNilUserArray];
        
        [achievementArray removeObject:gameCenterObjectToRemove];
        [nilUserAchievementArray removeObject:gameCenterObjectToRemove];
        
        if (achievementArray) [unreportedAchievementDict setObject:achievementArray
                                      forKey:playerID];
        if (nilUserAchievementArray) [unreportedAchievementDict setObject:nilUserAchievementArray
                                      forKey:@""];
        [self saveUnreportedGameCenterAchievements];
    }  
}


// this method is called to actually report achievements to Game Center;
// it reports all unreported achievements for the current Game Center user
// AS WELL AS all unreported achievements that were gained when no user
// was logged in to Game Center
- (void)reportUnreportedAchievements;
{	
	@synchronized(unreportedAchievementDict) {
		NSString *playerID = [self gameCenterPlayerID];
		
		if (playerID) {
			NSArray *achievementArray = [unreportedAchievementDict objectForKey:playerID];
			NSArray *nilUserAchievementArray = [unreportedAchievementDict objectForKey:@""];
			
			if (achievementArray || nilUserAchievementArray) {
				NSArray *combinedArray = [achievementArray arrayByAddingObjectsFromArray:nilUserAchievementArray];
				for (id currentGameCenterObject in combinedArray) {
                    if ([currentlyBeingReportedArray containsObject:currentGameCenterObject]) continue;
                    
                    if ([currentGameCenterObject isKindOfClass:[GKAchievement class]]) {
                        GKAchievement *currentAchievement = (GKAchievement *)currentGameCenterObject;
                        GKAchievement *existingAchievement = [localAchievementsDict objectForKey:currentAchievement.identifier];
                        
                        GKAchievement *achievementToReport = nil;
                        if (existingAchievement) {
                            existingAchievement.percentComplete = currentAchievement.percentComplete;
                            achievementToReport = existingAchievement;
                        } else {
                            achievementToReport = currentAchievement;
                        }
                        
                        @synchronized(currentlyBeingReportedArray) {
                            [currentlyBeingReportedArray addObject:currentAchievement];
                        }
                        
                        [achievementToReport reportAchievementWithCompletionHandler:^(NSError *achievementError)
                         {
                             if (achievementError != nil) {
                                 NSLog(@"error reporting achievement to Game Center: %@; error: %@",currentAchievement.identifier,achievementError);
                             } else {
                                 [self removeAchievementFromUnreportedAchievements:currentAchievement];
                             }
                             
                             @synchronized(currentlyBeingReportedArray) {
                                 [currentlyBeingReportedArray removeObject:currentAchievement];
                             }
                         }];
                    } else {
                        GKScore *currentScore = (GKScore *)currentGameCenterObject;
                        
                        @synchronized(currentlyBeingReportedArray) {
                            [currentlyBeingReportedArray addObject:currentScore];
                        }
                        
                        [currentScore reportScoreWithCompletionHandler:^(NSError *scoreError) {
                            if (scoreError != nil) {
                                // handle the reporting error
                                NSLog(@"error reporting score to Game Center: %@; error: %@",currentScore.category,scoreError);
                            } else {
                                [self removeAchievementFromUnreportedAchievements:currentScore];
                            }
                            
                            @synchronized(currentlyBeingReportedArray) {
                                [currentlyBeingReportedArray removeObject:currentScore];
                            }
                        }];
                    }
				}
			}
		}
	}
}


#pragma mark Game Center Reset

- (void)checkGameCenterResetPref;
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    BOOL maybeShouldResetAll = [standardUserDefaults boolForKey:@"EPResetAll"];
    
    // since the simulator doesn't allow you to access a simulated app's
    // settings, you'll need to change the following if condition to "YES" if
    // you want to reset all achievements (and purge unreported achievements)
    if (maybeShouldResetAll) {
        [self confirmGameCenterReset];
        [standardUserDefaults setBool:NO forKey:@"EPResetAll"];
    }
}


- (void)confirmGameCenterReset;
{
	UIAlertView *confirmResetAlertView = [[UIAlertView alloc] initWithTitle:@"Reset All"
																	message:@"Are you sure you want to reset all of your Game Center data?"
																   delegate:self
														  cancelButtonTitle:@"Cancel"
														  otherButtonTitles:@"Reset Game Center",nil];
	
	[confirmResetAlertView show];
}

- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex;
{
    if ([alertView.title isEqualToString:@"Reset All"]) { 
        if (buttonIndex == 1) {
            [self resetAchievements];
        }
    }
}



- (void)resetAchievements;
{
	NSString *playerID = [self gameCenterPlayerID];
	
	if (playerID) {
		
		// Clear all locally saved achievement objects.
		[localAchievementsDict removeAllObjects];
		
		// Clear all locally saved unreported achievements.
		[unreportedAchievementDict setObject:[NSArray array]
									  forKey:playerID];
		[self saveUnreportedGameCenterAchievements];
		
		
		// Clear all progress saved on Game Center.
		[GKAchievement resetAchievementsWithCompletionHandler:^(NSError *error)
		 {
			 if (error != nil) {
				 NSLog(@"Error resetting achievements in Game Center: %@",error);
			 }
		 }];
	}
}



@end