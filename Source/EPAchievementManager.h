//
//  AchievementManager.h
//
//  Created by Simone Manganelli on 2012-03-19
//

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>


@interface EPAchievementManager : NSObject <GKAchievementViewControllerDelegate, GKLeaderboardViewControllerDelegate, UIAlertViewDelegate> {
	NSObject *_delegate;
    GKLocalPlayer *_localPlayer;
    NSArray *_localScores;
    NSArray *_localScorePlayerInfoArray;
    
    IBOutlet UIViewController *_viewController;
	
	NSURL *unreportedAchievementsURL;
    NSURL *achievementHashURL;
	NSMutableDictionary *unreportedAchievementDict;
	NSMutableDictionary *localAchievementsDict;
    NSMutableArray *currentlyBeingReportedArray;
}


@property (retain) NSObject *delegate;
@property (retain) GKLocalPlayer *localPlayer;
@property (retain) NSArray *localScores;
@property (retain) NSArray *localScorePlayerInfoArray;

@property (nonatomic) IBOutlet UIViewController *viewController;


+ (EPAchievementManager*)sharedManager;
- (void)applicationDidBecomeActive:(UIApplication *)application;

- (NSString *)gameCenterPlayerID; // this method attempts to log in
- (void)disposeOfCurrentGameCenterLocalPlayer;
- (void)authenticateLocalPlayer;

- (void)showAchievements;
- (void)showScores;
- (void)reportAchievementIdentifier:(NSString*)identifier
                    percentComplete:(CGFloat)percent;
- (void)reportScore:(NSString *)leaderboardIdentifier
              score:(NSInteger)newScoreValue;

- (void)checkGameCenterResetPref;

@end
