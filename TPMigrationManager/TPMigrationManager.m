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

#import "TPMigrationManager.h"

typedef NS_ENUM(NSInteger, InternalMigrationStatus)
{
  InternalMigrationStatusNeedMigration = 32,
  InternalMigrationStatusSameModel,
  InternalMigrationStatusNoManagedObjectModel,
  InternalMigrationStatusNoPersistentStore,
  InternalMigrationStatusCorruptStore,
};

@interface TPMigrationManager()

@property (strong, nonatomic, readwrite)
  NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic, readwrite) NSURL *storeURL;
@property (strong, nonatomic, readwrite) NSString *storeType;
@property (assign, nonatomic, readwrite) float migrationProgress;
@property (strong, nonatomic, readwrite) NSEntityMapping *currentEntityMapping;

@property (strong, nonatomic) NSString *basename;
@property (strong, nonatomic) NSURL *workingStoreURL;
@property (strong, nonatomic) NSString *workingStoreType;
@property (strong, nonatomic) NSMigrationManager *migrationManager;
@property (strong, nonatomic) NSInvocationOperation *operation;
@property (weak, nonatomic) NSInvocationOperation *weakOperation;
@property (strong, nonatomic) NSOperationQueue *queue;

@end

@implementation TPMigrationManager

NSString * const TPMigrationManagerBackupPersistentStoreExtensionOption =
  @"TPMigrationManagerBackupPersistentStoreExtensionOption";
NSString * const TPMigrationManagerInferMappingModelOption =
  @"TPMigrationManagerInferMappingModelOption";
NSString * const TPMigrationManagerSpecificMappingModelOption =
  @"TPMigrationManagerSpecificMappingModelOption";
NSString * const TPMigrationManagerProgressBlockOption =
  @"TPMigrationManagerProgressBlockOption";
NSString * const TPMigrationManagerCompletedBlockOption =
  @"TPMigrationManagerCompletedBlockOption";

NSString * const TPMigrationManageErrorDomain =
  @"TPMigrationManageErrorDomain";

static NSString * const migrationProgressKeyPath = @"migrationProgress";
static NSString * const currentEntityMappingKeyPath = @"currentEntityMapping";

#pragma mark - Core Data stack

- (NSManagedObjectModel *)managedObjectModel
{
  if (_managedObjectModel) {
    return _managedObjectModel;
  }

  NSURL *modelURL =
    [[NSBundle mainBundle]
      URLForResource:self.basename
       withExtension:@"momd"];
  if (modelURL) {
    _managedObjectModel =
      [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
  }

  return _managedObjectModel;
}

- (NSURL *)storeURL
{
  if (_storeURL) {
    return _storeURL;
  }

  _storeURL =
    [[self applicationDocumentsDirectory]
      URLByAppendingPathComponent:
        [NSString stringWithFormat:@"%@%@", self.basename, @".sqlite"]];

  return _storeURL;
}

- (NSString *)storeType
{
  if (_storeType) {
    return _storeType;
  }

  _storeType = NSSQLiteStoreType;

  return _storeType;
}

- (NSURL *)workingStoreURL
{
  if (_workingStoreURL) {
    return _workingStoreURL;
  }

  NSString *ext = [self.storeURL pathExtension];
  NSString *path = [[self.storeURL URLByDeletingPathExtension] path];

  _workingStoreURL =
    [NSURL
      fileURLWithPath:
        [NSString stringWithFormat:@"%@-WORKING.%@", path, ext]];

  return _workingStoreURL;
}

- (NSString *)workingStoreType
{
  if (_workingStoreType) {
    return _workingStoreType;
  }

  _workingStoreType = self.storeType;

  return _workingStoreType;
}

- (NSOperationQueue *)queue
{
  if (_queue) {
    return _queue;
  }

  _queue = [[NSOperationQueue alloc] init];
  [_queue setMaxConcurrentOperationCount:1];

  return _queue;
}

#pragma mark

- (instancetype)initWithManagedObjectModel:(NSManagedObjectModel *)model
                        persistentStoreURL:(NSURL *)storeURL
                       persistentStoreType:(NSString *)storeType
{
  self = [super init];
  if (self) {
    self.managedObjectModel = model;
    self.storeURL = storeURL;
    self.storeType = storeType;
    self.queue = nil;
  }

  return self;
}

- (instancetype)initWithBasename:(NSString *)basename
{
  self = [self initWithManagedObjectModel:nil
                       persistentStoreURL:nil
                      persistentStoreType:nil];
  if (self) {
    self.basename = basename;
  }

  return self;
}

#pragma mark - migration

- (TPMigrationManagerMigrationStatus)migrationStatus
{
  TPMigrationManagerMigrationStatus st =
    TPMigrationManagerMigrationStatusNoMappingModel;

  NSDictionary *sourceMetadata = nil;
  NSManagedObjectModel *destinationModel = nil;
  InternalMigrationStatus ist =
    [self migrationStatusWithResultingSourceMetadata:&sourceMetadata
                           resultingDestinationModel:&destinationModel
                                               error:nil];
  NSError *e = nil;
  NSManagedObjectModel *sourceModel;
  switch (ist) {
  case InternalMigrationStatusNoManagedObjectModel:
    st = TPMigrationManagerMigrationStatusNoManagedObjectModel;
    break;
  case InternalMigrationStatusSameModel:
    st = TPMigrationManagerMigrationStatusSameModel;
    break;
  case InternalMigrationStatusNoPersistentStore:
    st = TPMigrationManagerMigrationStatusNoPersistentStore;
    break;
  case InternalMigrationStatusCorruptStore:
    st = TPMigrationManagerMigrationStatusCorruptedStore;
    break;
  default:
    sourceModel = [self modelFromMetadata:sourceMetadata error:&e];
    BOOL infer = NO;
    BOOL specific = NO;

    if (e) {
      st = TPMigrationManagerMigrationStatusCorruptedStore;
      break;
    }
    e = nil;
    NSMappingModel *mappingModel;
    mappingModel =
      [self mappingModelWithSourceModel:sourceModel
                       destinationModel:destinationModel
                           inferMapping:YES
                                  error:&e];
    if (mappingModel) {
      infer = YES;
    }
    mappingModel =
      [self mappingModelWithSourceModel:sourceModel
                       destinationModel:destinationModel
                           inferMapping:NO
                                  error:&e];
    if (mappingModel) {
      specific = YES;
    }
    if (infer && specific) {
      st = TPMigrationManagerMigrationStatusAnyMappingModel;
    } else if (infer) {
      st = TPMigrationManagerMigrationStatusInferredMappingModel;
    } else if (specific) {
      st = TPMigrationManagerMigrationStatusSpecificMappingModel;
    }
    break;
  }

  return st;
}

- (void)migrateByInferredMappingModelWithOptions:(NSDictionary *)options
                                       completed:(TPMigrationManagerCompletedBlock)completedBlock
{
  NSMutableDictionary *opt =
    [NSMutableDictionary dictionaryWithDictionary:options];
  opt[TPMigrationManagerInferMappingModelOption] = @YES;
  opt[TPMigrationManagerSpecificMappingModelOption] = @NO;
  opt[TPMigrationManagerCompletedBlockOption] = completedBlock;
  self.operation =
    [[NSInvocationOperation alloc]
      initWithTarget:self
            selector:@selector(migrateSynchronouslyWithOptions:)
              object:opt];
  self.weakOperation = self.operation;
  [self.queue addOperation:self.operation];
}

- (void)migrateBySpecificMappingModelWithOptions:(NSDictionary *)options
                                        progress:(TPMigrationManagerProgressBlock)progressBlock
                                       completed:(TPMigrationManagerCompletedBlock)completedBlock
{
  NSMutableDictionary *opt =
    [NSMutableDictionary dictionaryWithDictionary:options];
  opt[TPMigrationManagerInferMappingModelOption] = @NO;
  opt[TPMigrationManagerSpecificMappingModelOption] = @YES;
  opt[TPMigrationManagerProgressBlockOption] = progressBlock;
  opt[TPMigrationManagerCompletedBlockOption] = completedBlock;
  self.operation =
    [[NSInvocationOperation alloc]
      initWithTarget:self
            selector:@selector(migrateSynchronouslyWithOptions:)
              object:opt];
  self.weakOperation = self.operation;
  [self.queue addOperation:self.operation];
}

#define NSERROR_CANCEL_BY_USER(e)                               \
{                                                               \
  NSString *s = NSLocalizedString(@"Cancelled by user.", nil);  \
  NSDictionary *u = @{NSLocalizedDescriptionKey:s};             \
  (e) =                                                         \
    [NSError errorWithDomain:TPMigrationManageErrorDomain       \
                        code:TPMigrationManageCancelByUserError \
                    userInfo:u];                                \
} while (0)

- (void)cancel
{
  NSError *error;
  NSERROR_CANCEL_BY_USER(error);
  [self.migrationManager cancelMigrationWithError:error];
  [self.operation cancel];
}

#pragma mark - private

- (BOOL)migrateSynchronouslyWithOptions:(NSDictionary *)options
{
  return [self migrateSynchronouslyWithOptions:options error:nil];
}

#define RETURN_IF_ERROR                         \
{                                               \
  if (e) {                                      \
    if (completedBlock) {                       \
      completedBlock(e);                        \
    }                                           \
    if (error) {                                \
      *error = e;                               \
    }                                           \
    return NO;                                  \
  }                                             \
} while (0)

#define CANCEL_CHECK                            \
{                                               \
  if ([self.weakOperation isCancelled]) {       \
    NSERROR_CANCEL_BY_USER(e);                  \
    RETURN_IF_ERROR;                            \
  }                                             \
} while (0)

- (BOOL)migrateSynchronouslyWithOptions:(NSDictionary *)options
                                  error:(NSError **)error
{
  NSError *e;
  BOOL inferMapping = NO;
  TPMigrationManagerProgressBlock progressBlock = nil;
  TPMigrationManagerCompletedBlock completedBlock = nil;
  NSString *backupPersitentStoreExtension = nil;
  if ([options[TPMigrationManagerInferMappingModelOption]
          isEqual:@YES]) {
    inferMapping = YES;
  }
  if (options[TPMigrationManagerBackupPersistentStoreExtensionOption]) {
    backupPersitentStoreExtension =
      options[TPMigrationManagerBackupPersistentStoreExtensionOption];
    if (![backupPersitentStoreExtension length]) {
      backupPersitentStoreExtension = nil;
    }
  }
  if (options[TPMigrationManagerProgressBlockOption]) {
    progressBlock = options[TPMigrationManagerProgressBlockOption];
  }
  if (options[TPMigrationManagerCompletedBlockOption]) {
    completedBlock = options[TPMigrationManagerCompletedBlockOption];
  }

  // Check whether DB needs migration or not.
  CANCEL_CHECK;
  NSDictionary *sourceMetadata = nil;
  NSManagedObjectModel *destinationModel = nil;
  e = nil;
  InternalMigrationStatus ist =
    [self migrationStatusWithResultingSourceMetadata:&sourceMetadata
                           resultingDestinationModel:&destinationModel
                                               error:&e];
  if (ist == InternalMigrationStatusSameModel) {
    // no need to migrate
    if (completedBlock) {
      completedBlock(0);
    }
    return YES;
  }
  RETURN_IF_ERROR;

  // Acquire sourceModel
  CANCEL_CHECK;
  e = nil;
  NSManagedObjectModel *sourceModel =
    [self modelFromMetadata:sourceMetadata error:&e];
  RETURN_IF_ERROR;

  // Acquire mappingModel
  CANCEL_CHECK;
  e = nil;
  NSMappingModel *mappingModel =
    [self mappingModelWithSourceModel:sourceModel
                     destinationModel:destinationModel
                         inferMapping:inferMapping
                                error:&e];
  RETURN_IF_ERROR;

  // Eliminate WorkingStore
  CANCEL_CHECK;
  e = nil;
  [self eliminateWorkingStoreWithError:&e];
  RETURN_IF_ERROR;

  // Migration
  CANCEL_CHECK;
  self.migrationManager =
    [[NSMigrationManager alloc]
            initWithSourceModel:sourceModel
               destinationModel:destinationModel];
  NSURL *sourceStoreURL = self.storeURL;
  NSString *sourceStoreType = self.storeType;
  NSDictionary *sourceStoreOptions = nil;
  NSURL *destinationStoreURL = self.workingStoreURL;
  NSString *destinationStoreType = self.workingStoreType;
  NSDictionary *destinationStoreOptions = nil;
  e = nil;
  [self.migrationManager
      addObserver:self
      forKeyPath:migrationProgressKeyPath
      options:NSKeyValueObservingOptionNew
      context:(__bridge void *)(progressBlock)];
  [self.migrationManager
      addObserver:self
      forKeyPath:currentEntityMappingKeyPath
      options:NSKeyValueObservingOptionNew
      context:(__bridge void *)(progressBlock)];

  __attribute__((__unused__)) BOOL ok = // for debug
    [self.migrationManager migrateStoreFromURL:sourceStoreURL
                                          type:sourceStoreType
                                       options:sourceStoreOptions
                              withMappingModel:mappingModel
                              toDestinationURL:destinationStoreURL
                               destinationType:destinationStoreType
                            destinationOptions:destinationStoreOptions
                                         error:&e];
  [self.migrationManager
      removeObserver:self forKeyPath:migrationProgressKeyPath];
  [self.migrationManager
      removeObserver:self forKeyPath:currentEntityMappingKeyPath];
  RETURN_IF_ERROR;
  self.migrationManager = nil;

  // replace migrated DB to original one.
  CANCEL_CHECK;
  [self replaceItemAtPath:[sourceStoreURL path]
                   toPath:[destinationStoreURL path]
          backupExtension:backupPersitentStoreExtension
                    error:&e];
  RETURN_IF_ERROR;

  if (completedBlock) {
    completedBlock(0);
  }

  return YES;
}

- (InternalMigrationStatus)migrationStatusWithResultingSourceMetadata:(NSDictionary **)resultingSourceMetadata
                                            resultingDestinationModel:(NSManagedObjectModel **)resultingDestinationModel
                                                                error:(NSError **)error
{
  self.migrationManager = nil;

  NSError *e;
  NSDictionary *sm = nil;
  if (!self.managedObjectModel) {
    e =
      [NSError errorWithDomain:TPMigrationManageErrorDomain
                          code:TPMigrationManageInvalidManagedObjectModel
                      userInfo:nil];
    if (error) {
      *error = e;
    }
    return InternalMigrationStatusNoManagedObjectModel;
  }

  if ([self.storeURL checkResourceIsReachableAndReturnError:&e] == NO) {
    if (error) {
      *error = e;
    }
    return InternalMigrationStatusNoPersistentStore;
  }

  @try {
    e = nil;
    sm =
      [NSPersistentStoreCoordinator
        metadataForPersistentStoreOfType:self.storeType
                                     URL:self.storeURL
                                   error:&e];
  }
  @catch (NSException *ex) {
    sm = nil;                   // for safety
  }
  if (!sm || e) {
    if (!e) {     // DataBase might be corrupt or not exist.
      e =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSFileReadCorruptFileError
                        userInfo:nil];
    }
    if (error) {
      *error = e;
    }
    return InternalMigrationStatusCorruptStore;
  }

  NSPersistentStoreCoordinator *psc =
    [[NSPersistentStoreCoordinator alloc]
      initWithManagedObjectModel:self.managedObjectModel];
  NSManagedObjectModel *dm = [psc managedObjectModel];
  BOOL pscCompatibile =
    [dm isConfiguration:nil
        compatibleWithStoreMetadata:sm];

  InternalMigrationStatus st = InternalMigrationStatusNeedMigration;
  if (pscCompatibile) {         // no need to migrate
    st = InternalMigrationStatusSameModel;
  }

  if (resultingSourceMetadata) {
    *resultingSourceMetadata = sm;
  }
  if (resultingDestinationModel) {
    *resultingDestinationModel = dm;
  }
  if (error) {
    *error = e;
  }

  return st;
}

- (NSManagedObjectModel *)modelFromMetadata:(NSDictionary *)metadata
                                      error:(NSError **)error
{
  NSArray *bundlesForModel = nil;
  NSManagedObjectModel *model =
    [NSManagedObjectModel
      mergedModelFromBundles:bundlesForModel
            forStoreMetadata:metadata];

  if (model == nil) {
    *error =
      [NSError errorWithDomain:NSCocoaErrorDomain
                          code:NSMigrationMissingSourceModelError
                      userInfo:nil];
  }
  return model;
}

- (NSMappingModel *)mappingModelWithSourceModel:(NSManagedObjectModel *)sourceModel
                               destinationModel:(NSManagedObjectModel *)destinationModel
                                   inferMapping:(BOOL)inferMapping
                                          error:(NSError **)error
{
  NSMappingModel *mappingModel = nil;
  if (inferMapping) {
    *error = nil;
    mappingModel =
      [NSMappingModel
        inferredMappingModelForSourceModel:sourceModel
                          destinationModel:destinationModel
                                     error:error];
  } else {
    NSArray *bundlesForMappingModel = nil;
    mappingModel =
      [NSMappingModel
        mappingModelFromBundles:bundlesForMappingModel
                 forSourceModel:sourceModel
               destinationModel:destinationModel];
    if (mappingModel == nil) {
      *error =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSMigrationMissingMappingModelError
                        userInfo:nil];
    }
  }
  return mappingModel;
}

- (void)eliminateWorkingStoreWithError:(NSError **)error
{
  NSURL *destinationStoreURL = self.workingStoreURL;
  BOOL exist =
    [destinationStoreURL checkResourceIsReachableAndReturnError:nil];
  if (exist) {
    // eliminate old WORKING file.
    [[NSFileManager defaultManager]
      removeItemAtURL:destinationStoreURL
                error:error];
  }
}

- (void)replaceItemAtPath:(NSString *)srcPath
                   toPath:(NSString *)dstPath
          backupExtension:(NSString *)extension
                    error:(NSError **)error
{
  NSFileManager *man = [NSFileManager defaultManager];
  NSString *srcBackupPath =
    [NSString stringWithFormat:@"%@%@", srcPath, extension];
  NSString *eliminatePath = srcPath;
  if (extension) {
    eliminatePath = srcBackupPath;
  }
  if ([man fileExistsAtPath:eliminatePath]) {
    *error = nil;
    [man removeItemAtPath:eliminatePath error:error];
    if (*error) {
      return;
    }
  }
  if (extension) {
    *error = nil;
    [man moveItemAtPath:srcPath toPath:srcBackupPath error:error];
    if (*error) {
      return;
    }
  }
  *error = nil;
  [man moveItemAtPath:dstPath toPath:srcPath error:error];
}

- (BOOL)eliminateExistFileURL:(NSURL *)fileURL error:(NSError **)error
{
  *error = nil;
  BOOL exist = [fileURL checkResourceIsReachableAndReturnError:error];
  if (!exist) {
    return YES;                 // no need to do.
  }
  *error = nil;
  [[NSFileManager defaultManager] removeItemAtURL:fileURL error:error];
  if (error) {
    return NO;
  }
  return YES;
}

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
  return [[[NSFileManager defaultManager]
            URLsForDirectory:NSDocumentDirectory
                   inDomains:NSUserDomainMask] lastObject];
}

// KVO
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  TPMigrationManagerProgressBlock block =
    (__bridge TPMigrationManagerProgressBlock)(context);
  if ([keyPath isEqualToString:migrationProgressKeyPath]) {
    self.migrationProgress = [[change objectForKey:@"new"] floatValue];
  } else if ([keyPath isEqualToString:currentEntityMappingKeyPath]) {
    self.currentEntityMapping = [change objectForKey:@"new"];
  }
  if (block) {
    block(self.migrationProgress, self.currentEntityMapping);
  }
}

@end

// EOF
