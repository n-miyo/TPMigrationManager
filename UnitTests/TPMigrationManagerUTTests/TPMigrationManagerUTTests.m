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

#import "TPMigrationManagerUTTests.h"

#import "TPMigrationManager.h"
#import "AnyV1CoreDataManager.h"
#import "AnyCoreDataManager.h"
#import "NoMapV1CoreDataManager.h"
#import "InferredOnlyV1CoreDataManager.h"
#import "SpecificOnlyV1CoreDataManager.h"
#import "Item.h"

static dispatch_semaphore_t sem;

extern NSString * const TPMigrationManagerInferMappingModelOption;
extern NSString * const TPMigrationManagerSpecificMappingModelOption;

#if TARGET_IPHONE_SIMULATOR
#define MAX_ITEM_NUM 100000
#else
#define MAX_ITEM_NUM 10000
#endif
@interface TPMigrationManager()

- (BOOL)migrateSynchronouslyWithOptions:(NSDictionary *)options
                                  error:(NSError **)error;
@end

@implementation TPMigrationManagerUTTests

- (void)manager:(TPMigrationManager *)manager
  didUpdateProgressInfo:(NSDictionary *)progressInfo
{
}

- (void)setUp
{
  [super setUp];
  sem = dispatch_semaphore_create(0);
}

- (void)tearDown
{
  // No need to release in iOS6
  // dispatch_release(sem);
  [super tearDown];
}

// test for public asynchronous method.

- (void)testAsyncMigration
{
  AnyV1CoreDataManager *anv1man = [[AnyV1CoreDataManager alloc] init];
  [self removePersistenStoreWithManager:anv1man];
  [self setupV1DataWithManager:anv1man];

  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"Any"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusAnyMappingModel,
                 @"Need migration");

  [manager
    migrateByInferredMappingModelWithOptions:
      @{TPMigrationManagerBackupPersitentStoreExtensionOption:@"~~~"}
  completed:^(NSError *error) {
      STAssertNil(error, @"migration should not be fail.");
      AnyCoreDataManager *anman = [[AnyCoreDataManager alloc] init];
      NSArray *a = [self fetchAllItemsWithManager:anman];
      Item *i;
      i = a[0];
      STAssertEqualObjects([i name], @"name-00000", @"wrong name migration");
      STAssertNil([i address], @"wrong address generation.");
      i = a[9999];
      STAssertEqualObjects([i name], @"name-09999", @"wrong name migration");
      STAssertNil([i address], @"wrong address generation.");
      AnyV1CoreDataManager *v1man = [[AnyV1CoreDataManager alloc] init];
      NSURL *backupURL = [self backupURLForURL:v1man.persistentStoreURL];
      STAssertEquals(
        [backupURL checkResourceIsReachableAndReturnError:nil],
        YES,
        @"Fail to create backup");
      dispatch_semaphore_signal(sem);
    }];
  dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)testAsyncMigrationWithCancel
{
  AnyV1CoreDataManager *anv1man = [[AnyV1CoreDataManager alloc] init];
  [self removePersistenStoreWithManager:anv1man];
  [self setupHugeV1DataWithManager:anv1man];

  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"Any"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusAnyMappingModel,
                 @"Need migration");

  [manager
    migrateByInferredMappingModelWithOptions:
      @{TPMigrationManagerBackupPersitentStoreExtensionOption:@"~~~"}
  completed:^(NSError *error) {
      STAssertNotNil(error, @"migration should be fail.");
      STAssertEqualObjects(
        [error domain],
        TPMigrationManageErrorDomain,
        @"error domain is not cancel.");
      STAssertEquals(
        [error code],
        TPMigrationManageCancelByUserError,
        @"error code is not cancel.");
      dispatch_semaphore_signal(sem);
    }];

  dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 0.4 * NSEC_PER_SEC);
  dispatch_queue_t queue =
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_after(time, queue, ^{
      NSLog(@"migration cancel");
      [manager cancel];
    });
  dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)testAsyncManualMigrationWithCancel
{
  AnyV1CoreDataManager *anv1man = [[AnyV1CoreDataManager alloc] init];
  [self removePersistenStoreWithManager:anv1man];
  [self setupV1DataWithManager:anv1man];

  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"Any"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusAnyMappingModel,
                 @"Need migration");

  [manager migrateBySpecificMappingModelWithOptions:nil
  progress:^(float migrationProgress, NSEntityMapping *currentEntityMapping) {
      NSLog(@"progress: %f [%@]",
            migrationProgress, [currentEntityMapping name]);
    }
  completed:^(NSError *error) {
      STAssertNotNil(error, @"migration should be fail.");
      STAssertEqualObjects(
        [error domain],
        TPMigrationManageErrorDomain,
        @"error domain is not cancel.");
      STAssertEquals(
        [error code],
        TPMigrationManageCancelByUserError,
        @"error code is not cancel.");
      dispatch_semaphore_signal(sem);
    }];

  dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC);
  dispatch_queue_t queue =
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_after(time, queue, ^{
      NSLog(@"migration cancel");
      [manager cancel];
    });
  dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

// test for private synchronous method.

- (void)testAutomaticMigration
{
  AnyV1CoreDataManager *anv1man = [[AnyV1CoreDataManager alloc] init];
  [self removePersistenStoreWithManager:anv1man];
  [self setupV1DataWithManager:anv1man];

  NSError *error;
  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"Any"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusAnyMappingModel,
                 @"Need migration");
  BOOL b =
    [manager
      migrateSynchronouslyWithOptions:
        @{TPMigrationManagerInferMappingModelOption:@YES,
          TPMigrationManagerBackupPersitentStoreExtensionOption:@""}
                   error:&error];
  STAssertEquals(b, YES, @"migration failed");

  AnyCoreDataManager *anman = [[AnyCoreDataManager alloc] init];
  NSArray *a = [self fetchAllItemsWithManager:anman];
  Item *i;
  i = a[0];
  STAssertEqualObjects([i name], @"name-00000", @"wrong name migration");
  STAssertNil([i address], @"wrong address generation.");
  i = a[9999];
  STAssertEqualObjects([i name], @"name-09999", @"wrong name migration");
  STAssertNil([i address], @"wrong address generation.");
  NSURL *backupURL = [self backupURLForURL:anv1man.persistentStoreURL];
  STAssertEquals(
    [backupURL checkResourceIsReachableAndReturnError:nil],
    NO,
    @"Should not exist back up file.");
}

- (void)testManualMigration
{
  AnyV1CoreDataManager *anv1man = [[AnyV1CoreDataManager alloc] init];
  [self removePersistenStoreWithManager:anv1man];
  [self setupV1DataWithManager:anv1man];

  NSURL *modelURL =
    [[NSBundle bundleForClass:[self class]]
      URLForResource:@"Any"
       withExtension:@"momd"];
  NSManagedObjectModel *model =
    [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];

  NSError *error;
  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithManagedObjectModel:model
              persistentStoreURL:anv1man.persistentStoreURL
             persistentStoreType:NSSQLiteStoreType];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusAnyMappingModel,
                 @"Need migration");

  BOOL b =
    [manager
      migrateSynchronouslyWithOptions:nil
                   error:&error];
  STAssertEquals(b, YES, @"migration failed");

  AnyCoreDataManager *anman = [[AnyCoreDataManager alloc] init];
  NSArray *a = [self fetchAllItemsWithManager:anman];
  Item *i;
  i = a[0];
  STAssertEqualObjects([i name], @"name-00000", @"wrong name migration");
  STAssertEqualObjects([i address],
                       @"nowhere1_3",
                       @"wrong address generation.");
  i = a[9999];
  STAssertEqualObjects([i name], @"name-09999", @"wrong name migration");
  STAssertEqualObjects([i address],
                       @"nowhere1_3",
                       @"wrong address generation.");
  NSURL *backupURL = [self backupURLForURL:anv1man.persistentStoreURL];
  STAssertEquals(
    [backupURL checkResourceIsReachableAndReturnError:nil],
    NO,
    @"should not create backup");
}

- (void)testNoMapMigration
{
  NoMapV1CoreDataManager *nmv1man = [[NoMapV1CoreDataManager alloc] init];
  [self removePersistenStoreWithManager:nmv1man];
  [self setupNoMapV1CoreDataWithManager:nmv1man];

  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"NoMap"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusNoMappingModel,
                 @"Need migration");
}

- (void)testInferredOnlyMigration
{
  InferredOnlyV1CoreDataManager *ifv1man =
    [[InferredOnlyV1CoreDataManager alloc] init];
  [self removePersistenStoreWithManager:ifv1man];
  [self setupInferredOnlyV1CoreDataWithManager:ifv1man];

  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"InferredOnly"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusInferredMappingModel,
                 @"Need migration");

  NSError *error;
  BOOL b;
  b =
    [manager
      migrateSynchronouslyWithOptions:
        @{TPMigrationManagerInferMappingModelOption:@NO}
    error:&error];
  STAssertEquals(b, NO, @"Inferred only.");

  b =
    [manager
      migrateSynchronouslyWithOptions:
        @{TPMigrationManagerInferMappingModelOption:@YES}
    error:&error];
  STAssertEquals(b, YES, @"migration failed.");
}

- (void)testSpecificOnlyMigration
{
  SpecificOnlyV1CoreDataManager *ifv1man =
    [[SpecificOnlyV1CoreDataManager alloc] init];
  [self removePersistenStoreWithManager:ifv1man];
  [self setupSpecificOnlyV1CoreDataWithManager:ifv1man];

  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"SpecificOnly"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusSpecificMappingModel,
                 @"Need migration");

  NSError *error;
  BOOL b;
  b =
    [manager
      migrateSynchronouslyWithOptions:
        @{TPMigrationManagerInferMappingModelOption:@YES}
    error:&error];
  STAssertEquals(b, NO, @"Specific only.");

  b =
    [manager
      migrateSynchronouslyWithOptions:
        @{TPMigrationManagerInferMappingModelOption:@NO}
    error:&error];
  STAssertEquals(b, YES, @"migration failed.");
}

- (void)testAutomaticMigrationNonExistModel
{
  AnyV1CoreDataManager *anv1man = [[AnyV1CoreDataManager alloc] init];
  [self removePersistenStoreOfURL:anv1man.persistentStoreURL];
  [self createZeroPersistentStoreOfURL:anv1man.persistentStoreURL];

  NSError *error;
  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"NonExist"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusNoManagedObjectModel,
                 @"Model is not exist.");
  BOOL b =
    [manager
      migrateSynchronouslyWithOptions:
        @{TPMigrationManagerInferMappingModelOption:@YES}
                   error:&error];
  STAssertEquals(b, NO, @"migration failed");
  STAssertEqualObjects(
    [error domain],
    TPMigrationManageErrorDomain,
    @"Should fail to detect correct source metadata.");
  STAssertEquals(
    [error code],
    TPMigrationManageInvalidManagedObjectModel,
    @"Should fail to detect correct source metadata.");
}

- (void)testAutomaticMigrationNonExistPersistentStore
{
  AnyV1CoreDataManager *anv1man = [[AnyV1CoreDataManager alloc] init];
  [self removePersistenStoreOfURL:anv1man.persistentStoreURL];

  NSError *error;
  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"Any"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusNoPersistentStore,
                 @"Model is not exist.");
  BOOL b =
    [manager
      migrateSynchronouslyWithOptions:
        @{TPMigrationManagerInferMappingModelOption:@YES}
                   error:&error];
  STAssertEquals(b, NO, @"migration failed");
  STAssertEqualObjects(
    [error domain],
    NSCocoaErrorDomain,
    @"fail to detect no persistent store.");
  STAssertEquals(
    [error code],
    NSFileReadNoSuchFileError,
    @"fail to detect no persistent store.");
}

- (void)testAutomaticMigrationZeroSizePersistentStore
{
  AnyV1CoreDataManager *anv1man = [[AnyV1CoreDataManager alloc] init];
  [self removePersistenStoreOfURL:anv1man.persistentStoreURL];
  [self createZeroPersistentStoreOfURL:anv1man.persistentStoreURL];

  NSError *error;
  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"Any"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusCorruptedStore,
                 @"Corrupt Database");
  BOOL b =
    [manager
      migrateSynchronouslyWithOptions:
        @{TPMigrationManagerInferMappingModelOption:@YES}
                   error:&error];
  STAssertEquals(b, NO, @"migration failed");
  STAssertEquals(
    [error code],
    NSPersistentStoreInvalidTypeError,
    @"Should fail to detect correct source metadata.");
}

- (void)testAutomaticMigrationTruncatedPersistentStore
{
  AnyV1CoreDataManager *anv1man = [[AnyV1CoreDataManager alloc] init];
  [self removePersistenStoreOfURL:anv1man.persistentStoreURL];
  [self setupV1DataWithManager:anv1man];
  [self truncatePersistentStoreOfURL:anv1man.persistentStoreURL];

  NSError *error;
  TPMigrationManager *manager =
    [[TPMigrationManager alloc]
      initWithBasename:@"Any"];
  STAssertEquals([manager migrationStatus],
                 TPMigrationManagerMigrationStatusCorruptedStore,
                 @"Corrupt Database");
  BOOL b =
    [manager
      migrateSynchronouslyWithOptions:
        @{TPMigrationManagerInferMappingModelOption:@YES}
                   error:&error];
  STAssertEquals(b, NO, @"migration failed");
  STAssertEquals(
    [error code],
    NSFileReadCorruptFileError,
    @"Should fail to detect corrupt database.");
}

#pragma mark - support methods

- (NSURL *)backupURLForURL:(NSURL *)url
{
  NSURL *u =
    [NSURL URLWithString:
             [NSString stringWithFormat:@"%@~~~", [url absoluteString]]];
  return u;
}

- (void)createZeroPersistentStoreOfURL:(NSURL *)url
{
  NSData *d = [NSData new];
  if (![d writeToURL:url atomically:YES]) {
    NSLog(@"Fail to create fake DB file.");
    abort();
  }
}

- (void)truncatePersistentStoreOfURL:(NSURL *)url
{
  NSMutableData *d = [NSMutableData dataWithContentsOfURL:url];
  [d setLength:[d length]/2];   // truncate to half.

  if (![d writeToURL:url atomically:YES]) {
    NSLog(@"Fail to create fake DB file.");
    abort();
  }
}

- (void)removePersistenStoreWithManager:(CoreDataManager *)manager
{
  [self removePersistenStoreOfURL:manager.persistentStoreURL];
  NSURL *backupURL = [self backupURLForURL:manager.persistentStoreURL];
  [self removePersistenStoreOfURL:backupURL];
  BOOL exist = [backupURL checkResourceIsReachableAndReturnError:nil];
  if (exist) {
    NSLog(@"Fail to remove.");
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
    NSLog(@"Fail to remove DB file.");
    abort();
  }
}

- (void)setupV1DataWithManager:(AnyV1CoreDataManager *)manager
{
  [self setupV1DataWithManager:manager maxNumber:MAX_ITEM_NUM];
}

- (void)setupHugeV1DataWithManager:(AnyV1CoreDataManager *)manager
{
  [self setupV1DataWithManager:manager maxNumber:MAX_ITEM_NUM*10];
}

- (void)setupV1DataWithManager:(AnyV1CoreDataManager *)manager
                     maxNumber:(NSInteger)maxNumber
{
  NSManagedObjectContext *moc = manager.managedObjectContext;
  for (int i = 0; i < maxNumber; i++) {
    Item *item =
      [NSEntityDescription
        insertNewObjectForEntityForName:@"Item"
                 inManagedObjectContext:moc];

    if (!item) {
      NSLog(@"Fail to create DB instance.");
      abort();
    }
    item.name = [NSString stringWithFormat:@"name-%05d", i];
  }

  NSError *error = nil;
  if (![moc save:&error]) {
    NSLog(@"Fail to save: %@, %@", error, [error userInfo]);
    abort();
  }

  NSArray *a = [self fetchAllItemsWithManager:manager];
  if (a == nil || [a count] != maxNumber) {
    NSLog(@"Fail to fetch.");
    abort();
  }
  Item *i = a[0];
  if (![i.name isEqualToString:@"name-00000"]) {
    NSLog(@"invalid data.");
    abort();
  }

  // V1 DataBase does not have age property.
  BOOL e = NO;
  @try {
    __attribute__((__unused__)) NSString *s = [i address];
  }
  @catch(NSException *ex) {
    e = YES;
  }
  if (!e) {
    NSLog(@"invalid DB version.");
    abort();
  }
}

- (void)setupDefaultDataWithManager:(AnyCoreDataManager *)manager
{
  NSManagedObjectContext *moc = manager.managedObjectContext;
  Item *item =
    [NSEntityDescription
      insertNewObjectForEntityForName:@"Item"
               inManagedObjectContext:moc];

  if (!item) {
    NSLog(@"Fail to create DB instance.");
    abort();
  }
  item.name = @"name-default";
  item.address = @"address-default";

  NSError *error = nil;
  if (![moc save:&error]) {
    NSLog(@"Fail to save: %@, %@", error, [error userInfo]);
    abort();
  }
}

- (void)setupNoMapV1CoreDataWithManager:(NoMapV1CoreDataManager *)manager
{
  NSManagedObjectContext *moc = manager.managedObjectContext;
  NSError *error = nil;
  if (![moc save:&error]) {
    NSLog(@"Fail to save: %@, %@", error, [error userInfo]);
    abort();
  }
}

- (void)setupInferredOnlyV1CoreDataWithManager:
  (InferredOnlyV1CoreDataManager *)manager
{
  NSManagedObjectContext *moc = manager.managedObjectContext;
  NSError *error = nil;
  if (![moc save:&error]) {
    NSLog(@"Fail to save: %@, %@", error, [error userInfo]);
    abort();
  }
}

- (void)setupSpecificOnlyV1CoreDataWithManager:
  (SpecificOnlyV1CoreDataManager *)manager
{
  NSManagedObjectContext *moc = manager.managedObjectContext;
  NSError *error = nil;
  if (![moc save:&error]) {
    NSLog(@"Fail to save: %@, %@", error, [error userInfo]);
    abort();
  }
}

- (NSArray *)fetchAllItemsWithManager:(CoreDataManager *)manager
{
  NSManagedObjectContext *moc = manager.managedObjectContext;
  NSEntityDescription *entityDescription =
    [NSEntityDescription
      entityForName:@"Item"
      inManagedObjectContext:moc];
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  [request setEntity:entityDescription];
  NSSortDescriptor *sortDescriptor =
    [[NSSortDescriptor alloc]
      initWithKey:@"name" ascending:YES];
  [request setSortDescriptors:@[sortDescriptor]];

  NSError *error = nil;
  return [moc executeFetchRequest:request error:&error];
}

@end

// EOF
