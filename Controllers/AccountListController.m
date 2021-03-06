/*
 * Spark 360 for iOS
 * https://github.com/pokebyte/Spark360-iOS
 *
 * Copyright (C) 2011-2014 Akop Karapetyan
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
 *  02111-1307  USA.
 *
 */

#import "AccountListController.h"

#import "AppPreferences.h"

#import "BachAppDelegate.h"
#import "AccountAddController.h"
#import "AccountEditController.h"
#import "GameListController.h"
#import "ProfileOverviewController.h"
#import "XboxLiveStatusController.h"
#import "AboutAppController.h"

#import "AKImageCache.h"

@interface AccountListController (Private)

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation AccountListController
{
    NSMutableDictionary *_accountCache;
}

@synthesize selectionDelegate = _selectionDelegate;
@synthesize fetchedResultsController = __fetchedResultsController;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _accountCache = [[NSMutableDictionary alloc] init];
    
    // Set up the edit and add buttons.
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd 
                                                                               target:self 
                                                                               action:@selector(insertNewObject)];
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    self.navigationItem.title = NSLocalizedString(@"Accounts", nil);
    self.navigationItem.rightBarButtonItem = addButton;
    
    [addButton release];
    
    self.tableView.allowsSelectionDuringEditing = YES;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [_accountCache release];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self setEditing:NO];
    [self.tableView setEditing:NO 
                      animated:YES];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing 
             animated:animated];
    
    [self.tableView setEditing:editing
                      animated:animated];
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
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    
    if (!cell)
    {
        [[NSBundle mainBundle] loadNibNamed:@"AccountCell"
                                      owner:self
                                    options:nil];
        
        cell = self.tableViewCell;
    }
    
    [self configureCell:cell 
            atIndexPath:indexPath];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        // Delete the managed object for the given index path
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        NSManagedObject *profile = [self.fetchedResultsController objectAtIndexPath:indexPath];
        
        NSString *uuid = [profile valueForKey:@"uuid"];
        [AppPreferences deleteAccountWithUuid:uuid
                         managedObjectContext:managedObjectContext];
        
        [context deleteObject:profile];
        
        // Save the context.
        NSError *error = nil;
        if (![context save:&error])
        {
            BACHLog(@"Unresolved error %@, %@", error, [error userInfo]);
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *profile = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSString *uuid = [profile valueForKey:@"uuid"];
    
    XboxLiveAccount *account = nil;
    if (!(account = [_accountCache objectForKey:uuid]))
    {
        if ((account = [XboxLiveAccount preferencesForUuid:uuid]))
            [_accountCache setObject:account forKey:uuid];
    }
    
    if (account)
    {
        if ([tableView cellForRowAtIndexPath:indexPath].editing)
        {
            AccountEditController *editController;
            editController = [[AccountEditController alloc] initWithNibName:@"AccountAdd" 
                                                             bundle:nil];
            
            editController.account = account;
            
            [self.navigationController pushViewController:editController 
                                                 animated:YES];
            
            [editController release];
        }
        else
        {
            if (DeviceIsPad()) 
            {
                if (self.selectionDelegate != nil)
                    [self.selectionDelegate accountDidChange:account];
            }
            else
            {
                ProfileOverviewController *ctlr = [[ProfileOverviewController alloc] initWithAccount:account];
                [self.navigationController pushViewController:ctlr animated:YES];
                [ctlr release];
            }
        }
    }
}

- (void)dealloc
{
    self.selectionDelegate = nil;
    self.fetchedResultsController = nil;
    
    [super dealloc];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *profile = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    UILabel *label = (UILabel*)[cell viewWithTag:2];
    [label setText:[profile valueForKey:@"screenName"]];
    
    label = (UILabel*)[cell viewWithTag:3];
    [label setText:NSLocalizedString(@"XboxLiveAccount", @"")];
    
    UIImage *boxArt = [self tableCellImageFromUrl:[profile valueForKey:@"iconUrl"]
                                        indexPath:indexPath];
    
    UIImageView *view = (UIImageView*)[cell viewWithTag:6];
    [view setImage:boxArt];
}

- (void)insertNewObject
{
    AccountAddController *ctrl = [[AccountAddController alloc] initWithNibName:@"AccountAdd"
                                                                        bundle:nil];
    
    [self.navigationController pushViewController:ctrl 
                                         animated:YES];
    
    [ctrl release];
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
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"XboxProfile" 
                                              inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"screenName" 
                                                                   ascending:YES
                                                                    selector:@selector(caseInsensitiveCompare:)];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest 
                                                                                                managedObjectContext:managedObjectContext 
                                                                                                  sectionNameKeyPath:nil 
                                                                                                           cacheName:@"Root"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    [aFetchedResultsController release];
    [fetchRequest release];
    [sortDescriptor release];
    [sortDescriptors release];
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error])
    {
	    BACHLog(@"Unresolved error %@, %@", error, [error userInfo]);
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

#pragma mark - Actions

-(void)about:(id)sender
{
    AboutAppController *ctlr = [[AboutAppController alloc] initAbout];
    [self.navigationController pushViewController:ctlr animated:YES];
    [ctlr release];
}

-(void)refresh:(id)sender
{
    [self.tableView reloadData];
}

- (void)viewLiveStatus:(id)sender
{
    XboxLiveStatusController *ctlr = [[XboxLiveStatusController alloc] initWithAccount:self.account];
    [self.navigationController pushViewController:ctlr animated:YES];
    [ctlr release];
}

@end
