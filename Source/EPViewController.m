//
//  EPViewController.m
//  OfflineGameCenter
//
//  Created by Simone Manganelli on 2012-03-19
//

#import "EPViewController.h"
#import "EPAchievementManager.h"

@interface EPViewController ()

@end

@implementation EPViewController

#pragma mark Boilerplate

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark Achievement Reporting

- (IBAction)reportAnAchievement:(id)sender;
{
    EPAchievementManager *sharedManager = [EPAchievementManager sharedManager];
    
#warning Change the bundle identifier to match an identifier in iTunes Connect!
#warning Also, make sure to set up your achievements and leaderboards, too!
    [sharedManager reportAchievementIdentifier:@"com.EllipsisProductions.OfflineGameCenter.achievements.TestAchievement"
                               percentComplete:100.0];
    [sharedManager reportScore:@"com.EllipsisProductions.OfflineGameCenter.leaderboards.TestScore"
                         score:7.0];
    
}

- (IBAction)showAchievements:(id)sender;
{
    [[EPAchievementManager sharedManager] showAchievements];
}

- (IBAction)showScores:(id)sender;
{
    [[EPAchievementManager sharedManager] showScores];
}

@end
