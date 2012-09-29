offline-game-center
===================

Offline Game Center Reporting

EPAchievementManager is a class that does all the work of managing Game Center achievements and scores so that they can be correctly reported, even if they were achieved while offline.

The [Game Center Programming Guide claims](http://developer.apple.com/library/ios/DOCUMENTATION/NetworkingInternet/Conceptual/GameKit_Guide/Achievements/Achievements.html#//apple_ref/doc/uid/TP40008304-CH7-SW8) that Game Kit does this automatically for you as of iOS 5, but as of iOS 6, this functionality still does not appear to work.  Grab any Game Center-enabled app, turn off cellular data and Wi-Fi, get a score or achievement, turn data/Wi-Fi back on, and you'll see that those scores/achievements you got while offline will never be reported.

### Using EPAchievementManager

There are a few things you need to do before EPAchievementManager will work in your iOS app:

1. Change the bundle identifier of the app.  If you're using EPAchievementManager in your own app, you probably already have a good bundle ID.  If you're using the test app included with this repo, you'll need to change the bundle ID to something more suitable.

2. Set up your app in iTunes Connect.  The [Game Center Programming Guide](http://developer.apple.com/library/ios/#DOCUMENTATION/NetworkingInternet/Conceptual/GameKit_Guide/Introduction/Introduction.html) tells you all that you need to know to do this.  You'll need to do this before even the test app will work!  Upon startup, the test app should either prompt you to log in to Game Center, or it should automatically show the Game Center banner.  If it doesn't, you haven't set up your bundle ID for Game Center properly in iTunes Connect.

3. EPAchievementManager needs a viewController to display the Game Center leaderboards or scores when requested.  You can either connect it in a xib (as the test app does), or just set the property in code.

4. Because offline Game Center reporting necessitates storing Game Kit objects for later transmission, they need to be stored on disk somewhere.  Without even simple hashing, a malicious user could easily get a score while offline and then mess with the saved file on disk, so that your app could report an artificially inflated high score to Game Center.  To guard against this, EPAchievementManager hashes the file that stores unreported achievements, but you should change the prefix and suffix hash strings to something different!  That way it's harder for malicious users to mess with your score/achievement reporting.