// -*- mode:objc -*-
//
// Copyright (c) 2013 MIYOKAWA, Nobuyoshi (http://www.tempus.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

#import "CoreDataManager.h"

@interface CoreDataManager()

@property (nonatomic,retain, readwrite)
  NSManagedObjectModel* managedObjectModel;
@property (nonatomic,retain, readwrite)
  NSPersistentStoreCoordinator* persistentStoreCoordinator;
@property (nonatomic,retain, readwrite)
  NSManagedObjectContext* managedObjectContext;
@property (retain, nonatomic, readwrite)
  NSURL *modelURL;
@property (retain, nonatomic, readwrite)
  NSURL *persistentStoreURL;

@end

@implementation CoreDataManager

// Returns the managed object model for the application.  If
// the model doesn't already exist, it is created from the
// application's model.
- (NSManagedObjectModel *)managedObjectModel
{
  if (_managedObjectModel != nil) {
    return _managedObjectModel;
  }

  _managedObjectModel =
    [[NSManagedObjectModel alloc] initWithContentsOfURL:self.modelURL];

  return _managedObjectModel;
}

// Returns the persistent store coordinator for the
// application.  If the coordinator doesn't already exist,
// it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
  if (_persistentStoreCoordinator != nil) {
    return _persistentStoreCoordinator;
  }

  _persistentStoreCoordinator =
    [[NSPersistentStoreCoordinator alloc]
      initWithManagedObjectModel:self.managedObjectModel];

  NSError *error = nil;
  if (![_persistentStoreCoordinator
         addPersistentStoreWithType:NSSQLiteStoreType
                      configuration:nil
                                URL:self.persistentStoreURL
                            options:nil
                              error:&error]) {
    /*
      Replace this implementation with code to handle the error appropriately.
         
      abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
      Typical reasons for an error here include:
      * The persistent store is not accessible;
      * The schema for the persistent store is incompatible with current managed object model.
      Check the error message to determine what the actual problem was.
         
         
      If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
      If you encounter schema incompatibility errors during development, you can reduce their frequency by:
      * Simply deleting the existing store:
      [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
      * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
      @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
      Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
    */
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }    
    
  return _persistentStoreCoordinator;
}

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and
// bound to the persistent store coordinator for the
// application.
- (NSManagedObjectContext *)managedObjectContext
{
  if (_managedObjectContext != nil) {
    return _managedObjectContext;
  }

  NSAssert([self persistentStoreCoordinator],
           @"invalid persistentStoreCoordinator");
  NSPersistentStoreCoordinator *coordinator =
    [self persistentStoreCoordinator];
  if (coordinator != nil) {
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
  }

  return _managedObjectContext;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreturn-type"
- (NSURL *)modelURL
{
  NSAssert(NO, @"MUST OVERWRITE");
}
#pragma clang diagnostic pop

- (NSURL *)persistentStoreURL
{
  if (_persistentStoreURL) {
    return _persistentStoreURL;
  }

  _persistentStoreURL =
    [[self applicationDocumentsDirectory]
      URLByAppendingPathComponent:
        [NSString
          stringWithFormat:@"%@.sqlite",
          self.resourceBaseName]];

  return _persistentStoreURL;
}

- (NSString *)resourceBaseName
{
  return
    [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
}

#pragma mark -

- (void)deleteAllObjects:(NSString *)entityDescription
{
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity =
    [NSEntityDescription entityForName:entityDescription
                inManagedObjectContext:self.managedObjectContext];
  [fetchRequest setEntity:entity];

  NSError *error = nil;
  NSArray *items =
    [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
  if (error) {
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }

  for (NSManagedObject *managedObject in items) {
    [self.managedObjectContext deleteObject:managedObject];
  }

  error = nil;
  if (![self.managedObjectContext save:&error]) {
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
  return [[[NSFileManager defaultManager]
            URLsForDirectory:NSDocumentDirectory
                   inDomains:NSUserDomainMask] lastObject];
}

@end

// EOF
