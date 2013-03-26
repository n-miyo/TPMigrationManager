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

#import "Book.h"

@interface CoreDataManager()

@property (nonatomic,retain, readwrite)
  NSPersistentStoreCoordinator* persistentStoreCoordinator;
@property (nonatomic,retain, readwrite)
  NSManagedObjectModel* managedObjectModel;
@property (nonatomic,retain, readwrite)
  NSManagedObjectContext* managedObjectContext;
@property (retain, nonatomic) NSURL *modelURL;
@property (retain, nonatomic) NSURL *persistentStoreURL;
@property (retain, nonatomic, readonly) NSString *resourceBaseName;

@end

@implementation CoreDataManager

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
    TPLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }

  return _persistentStoreCoordinator;
}

- (NSManagedObjectModel *)managedObjectModel
{
  if (_managedObjectModel != nil) {
    return _managedObjectModel;
  }

  _managedObjectModel =
    [[NSManagedObjectModel alloc] initWithContentsOfURL:self.modelURL];

  return _managedObjectModel;
}

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

- (NSURL *)modelURL
{
  if (_modelURL) {
    return _modelURL;
  }

  NSString *s = [NSString stringWithFormat:@"%@.momd", self.resourceBaseName];
  _modelURL =
    [[NSBundle mainBundle]
      URLForResource:self.resourceBaseName
       withExtension:@"mom"
        subdirectory:s];

  return _modelURL;
}

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
  return @"TPMigrationManagerExample";
}

#pragma mark -
#pragma mark private

- (void)setupPersistntStoreWithItemNumber:(NSInteger)number
{
  [self removePersistenStores];
  NSManagedObjectContext *moc = self.managedObjectContext;
  for (int i = 0; i < number; i++) {
    Book *book =
      [NSEntityDescription
        insertNewObjectForEntityForName:@"Book"
                 inManagedObjectContext:moc];

    if (!book) {
      TPLog(@"Fail to create DB instance.");
      abort();
    }
    book.title = [NSString stringWithFormat:@"title-%05d", i];
  }

  NSError *error = nil;
  if (![moc save:&error]) {
    TPLog(@"Fail to save: %@, %@", error, [error userInfo]);
    abort();
  }
}

#pragma mark -
#pragma mark private

- (void)removePersistenStores
{
  [self removePersistenStoreOfURL:self.persistentStoreURL];
  NSURL *backupURL = [self backupURLWithURL:self.persistentStoreURL];
  [self removePersistenStoreOfURL:backupURL];
  BOOL exist = [backupURL checkResourceIsReachableAndReturnError:nil];
  if (exist) {
    TPLog(@"Fail to remove.");
    abort();
  }
}

- (void)removePersistenStoreOfURL:(NSURL *)url
{
  NSError *error = nil;
  BOOL exist = [url checkResourceIsReachableAndReturnError:&error];
  if (!exist) {
    return;
  }
  error = nil;
  [[NSFileManager defaultManager]
    removeItemAtURL:url
              error:&error];
  if (error) {
    TPLog(@"Fail to remove DB file.");
    abort();
  }
}

- (NSURL *)backupURLWithURL:(NSURL *)url
{
  NSURL *u =
    [NSURL
      URLWithString:[NSString stringWithFormat:@"%@~", [url absoluteString]]];
  return u;
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
