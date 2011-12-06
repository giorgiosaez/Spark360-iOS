//
//  RootViewController.m
//  ListTest
//
//  Created by Akop Karapetyan on 7/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AchievementListController.h"

#import "CFImageCache.h"
#import "TaskController.h"

#import "XboxLiveParser.h"

@interface AchievementListController (Private)

-(void)updateGameStats;
-(void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation AchievementListController

@synthesize tvCell;
@synthesize fetchedResultsController = __fetchedResultsController;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize numberFormatter = __numberFormatter;

@synthesize account;
@synthesize gameUid;
@synthesize gameTitle;
@synthesize isGameDirty;
@synthesize gameLastUpdated;

-(void)syncCompleted:(NSNotification *)notification
{
    NSLog(@"Got sync completed notification");
    
    [self updateGameStats];
    [_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
}

+(BOOL)startFromController:(UIViewController*)controller
      managedObjectContext:(NSManagedObjectContext*)managedObjectContext
                   account:(XboxLiveAccount*)account
               gameTitleId:(NSString*)gameTitleId
{
    AchievementListController *ctlr = [[AchievementListController alloc] initWithNibName:@"AchievementList"
                                                                                  bundle:nil];
    
    ctlr.account = account;
    ctlr.gameUid = gameTitleId;
    ctlr.managedObjectContext = managedObjectContext;
    
    [controller.navigationController pushViewController:ctlr
                                               animated:YES];
    
    [ctlr release];
    
    return YES;
}

-(void)updateGameStats
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"XboxGame"
                                                         inManagedObjectContext:self.managedObjectContext];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uid == %@", self.gameUid];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    [request setEntity:entityDescription];
    [request setPredicate:predicate];
    
    NSArray *array = [self.managedObjectContext executeFetchRequest:request 
                                                              error:nil];
    
    NSManagedObject *game = [array lastObject];
    
    [request release];
    
    if (game)
    {
        self.gameTitle = [game valueForKey:@"title"];
        self.isGameDirty = [[game valueForKey:@"achievesDirty"] boolValue];
        self.gameLastUpdated = [game valueForKey:@"lastUpdated"];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self updateGameStats];
    
    self.title = [NSString localizedStringWithFormat:NSLocalizedString(@"Achievements_f", nil),
                  gameTitle];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(syncCompleted:)
                                                 name:BACHAchievementsSynced 
                                               object:nil];
    
    self.numberFormatter = [[NSNumberFormatter alloc] init];
    [self.numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
    [[CFImageCache sharedInstance] purgeInMemCache];
    
	if (_refreshHeaderView == nil) 
    {
		EGORefreshTableHeaderView *view = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, self.view.frame.size.width, self.tableView.bounds.size.height)];
		view.delegate = self;
		[self.tableView addSubview:view];
		_refreshHeaderView = view;
		[view release];
	}
	
	//  update the last update date
	[_refreshHeaderView refreshLastUpdatedDate];
    
    if (self.isGameDirty)
    {
		CGPoint offset = self.tableView.contentOffset;
		offset.y = - 65.0f;
		self.tableView.contentOffset = offset;
		[_refreshHeaderView egoRefreshScrollViewDidEndDragging:self.tableView];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark UIScrollViewDelegate Methods

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	[_refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	[_refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
}

#pragma mark -
#pragma mark EGORefreshTableHeaderDelegate Methods

-(void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view
{
    [[TaskController sharedInstance] synchronizeAchievementsForGame:self.gameUid
                                                            account:self.account
                                               managedObjectContext:self.managedObjectContext];
}

-(BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view
{
    return [[TaskController sharedInstance] isSynchronizingAchievementsForGame:self.gameUid
                                                                       account:self.account];
}

-(NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view
{
	return self.gameLastUpdated;
}

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    
    if (!cell)
    {
        [[NSBundle mainBundle] loadNibNamed:@"AchievementCell"
                                      owner:self
                                    options:nil];
        cell = [self tvCell];
    }
    
    [self configureCell:cell 
            atIndexPath:indexPath];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Achievement selected
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    [[CFImageCache sharedInstance] purgeInMemCache];
}

- (void)dealloc
{
    [__fetchedResultsController release];
    [__managedObjectContext release];
    [__numberFormatter release];
    
    account = nil;
    gameTitle = nil;
    gameUid = nil;
    gameLastUpdated = nil;
    
    _refreshHeaderView = nil;
    
    [super dealloc];
}

- (void)configureCell:(UITableViewCell *)cell 
          atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    // Title
    
    UILabel *label = (UILabel*)[cell viewWithTag:2];
    [label setText:[managedObject valueForKey:@"title"]];
    
    // Description
    
    label = (UILabel*)[cell viewWithTag:6];
    [label setText:[managedObject valueForKey:@"achDescription"]];
    
    // Acquired
    
    NSString *unlockedText;
    if ([[managedObject valueForKey:@"isLocked"] boolValue])
    {
        unlockedText = NSLocalizedString(@"AchieveLocked", nil);
    }
    else
    {
        NSDate *acquired = [managedObject valueForKey:@"acquired"];
        NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
        
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        unlockedText = [NSString localizedStringWithFormat:NSLocalizedString(@"AchieveUnlocked_f", nil), 
                        [formatter stringFromDate:acquired]];
    }
    
    label = (UILabel*)[cell viewWithTag:3];
    [label setText:unlockedText];
    
    // Gamescore
    
    label = (UILabel*)[cell viewWithTag:5];
    [label setText:[[managedObject valueForKey:@"points"] stringValue]];
    
    // Icon

    UIImageView *view = (UIImageView*)[cell viewWithTag:7];
    UIImage *icon = [[CFImageCache sharedInstance] getCachedFile:[managedObject valueForKey:@"iconUrl"]
                                                    notifyObject:self
                                                  notifySelector:@selector(imageLoaded:)];
    
    [view setImage:icon];
    [view setClipsToBounds:YES];
}

- (void)imageLoaded:(NSString*)url
{
    // TODO: this causes a full data reload; not a good idea
    [self.tableView reloadData];
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (__fetchedResultsController != nil)
    {
        return __fetchedResultsController;
    }
    
    /*
     Set up the fetched results controller.
    */
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"game.uid == %@ AND game.profile.uuid == %@", 
                              gameUid, account.uuid];
    
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"XboxAchievement" 
                                              inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"sortIndex" 
                                                                   ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest 
                                                                                                managedObjectContext:self.managedObjectContext 
                                                                                                  sectionNameKeyPath:nil 
                                                                                                           cacheName:nil]; // AK: cacheName was 'Root'
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    [aFetchedResultsController release];
    [fetchRequest release];
    [sortDescriptor release];
    [sortDescriptors release];
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error])
        {
	    /*
	     Replace this implementation with code to handle the error appropriately.

	     abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
	     */
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return __fetchedResultsController;
}    

#pragma mark - Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type)
    {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type)
    {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

@end
