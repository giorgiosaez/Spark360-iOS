//
//  MessageListController.m
//  BachZero
//
//  Created by Akop Karapetyan on 12/7/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MessageListController.h"

#import "MessageCell.h"
#import "TaskController.h"

#import "MessageCompositionController.h"
#import "ViewMessageController.h"

@interface MessageListController (Private)

- (void)configureCell:(UITableViewCell *)cell 
          atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation MessageListController

@synthesize fetchedResultsController = __fetchedResultsController;

@synthesize composeButton = _composeButton;

-(id)initWithAccount:(XboxLiveAccount*)account
{
    if (self = [super initWithAccount:account 
                              nibName:@"MessageListController"])
    {
    }
    
    return self;
}

-(void)dealloc
{
    [__fetchedResultsController release];
    
    [super dealloc];
}

-(void)syncCompleted:(NSNotification *)notification
{
    NSLog(@"Got sync completed notification");
    
    XboxLiveAccount *account = [notification.userInfo objectForKey:BACHNotificationAccount];
    
    if ([account isEqualToAccount:self.account])
    {
        [self hideRefreshHeaderTableView];
        [self.tableView reloadData];
    }
}

#pragma mark - GenericTableViewController

- (void)mustSynchronizeWithRemote
{
    [super mustSynchronizeWithRemote];
    
    [[TaskController sharedInstance] synchronizeMessagesForAccount:self.account
                                              managedObjectContext:managedObjectContext];
}

- (NSDate*)lastSynchronized
{
    return self.account.lastMessagesUpdate;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(syncCompleted:)
                                                 name:BACHMessagesSynced
                                               object:nil];
    
    self.title = NSLocalizedString(@"MyMessages", nil);
    
    [self updateSynchronizationDate];
    
    if ([self.account areMessagesStale])
        [self synchronizeWithRemote];
    
    self.composeButton.enabled = [self.account canSendMessages]; 
}

-(void)viewDidUnload
{
    [super viewDidUnload];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:BACHMessagesSynced
                                                  object:nil];
    
    self.fetchedResultsController = nil;
}

#pragma mark - EGORefreshTableHeaderDelegate Methods

-(BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view
{
	return [[TaskController sharedInstance] isSynchronizingMessagesForAccount:self.account];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        NSManagedObject *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [[TaskController sharedInstance] deleteMessageWithUid:[message valueForKey:@"uid"]
                                                      account:self.account
                                         managedObjectContext:managedObjectContext];
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    
    if (!cell)
    {
        [[NSBundle mainBundle] loadNibNamed:@"MessageCell"
                                      owner:self
                                    options:nil];
        
        cell = self.tableViewCell;
    }
    
    [self configureCell:cell 
            atIndexPath:indexPath];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView 
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Message selected
    NSManagedObject *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    ViewMessageController *ctlr = [[ViewMessageController alloc] initWithUid:[message valueForKey:@"uid"]
                                                                     account:self.account];
    
    [self.navigationController pushViewController:ctlr animated:YES];
    [ctlr release];
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (__fetchedResultsController != nil)
    {
        return __fetchedResultsController;
    }
    
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"profile.uuid == %@", 
                              self.account.uuid];
    
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"XboxMessage" 
                                              inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"sent" 
                                                                   ascending:NO];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest 
                                                                                                managedObjectContext:managedObjectContext 
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
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	}
    
    return __fetchedResultsController;
}    

#pragma mark - Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    switch(type)
    {
            
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath] 
                    atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

#pragma mark - Actions

-(IBAction)refresh:(id)sender
{
    [self synchronizeWithRemote];
}

-(IBAction)compose:(id)sender
{
    MessageCompositionController *ctlr = [[MessageCompositionController alloc] initWithRecipient:nil
                                                                                         account:self.account];
    
    [self.navigationController pushViewController:ctlr animated:YES];
    [ctlr release];
}

#pragma mark - Misc

- (void)configureCell:(UITableViewCell *)cell 
          atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
    MessageCell *messageCell = (MessageCell*)cell;
    
    NSString *excerpt = [managedObject valueForKey:@"excerpt"];
    
    if (!excerpt || excerpt.length < 1)
    {
        excerpt = NSLocalizedString(@"MessageHasNoText", nil);
    }
    else
    {
        NSString *excerptTemplate;
        
        if (![[managedObject valueForKey:@"isDirty"] boolValue])
            excerptTemplate = NSLocalizedString(@"MessageExcerptTemplate_f", nil);
        else
            excerptTemplate = NSLocalizedString(@"MessageDirtyExcerptTemplate_f", nil);
        
        excerpt = [NSString stringWithFormat:excerptTemplate, excerpt];
    }
    
    messageCell.title.text = excerpt;
    messageCell.sender.text = [NSString localizedStringWithFormat:NSLocalizedString(@"From_f", nil),
                               [managedObject valueForKey:@"sender"]];
    messageCell.sent.text = [NSString localizedStringWithFormat:NSLocalizedString(@"Sent_f", nil),
                             [self.shortDateFormatter stringFromDate:[managedObject valueForKey:@"sent"]]];
    messageCell.attachment.hidden = !([[managedObject valueForKey:@"hasPicture"] boolValue] || 
                                      [[managedObject valueForKey:@"hasVoice"] boolValue]);
    messageCell.unreadMarker.hidden = [[managedObject valueForKey:@"isRead"] boolValue];
    
    UIImage *gamerpic = [self tableCellImageFromUrl:[managedObject valueForKey:@"senderIconUrl"]
                                          indexPath:indexPath];
    
    messageCell.gamerpic.image = gamerpic;
}

@end
