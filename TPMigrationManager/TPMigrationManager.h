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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

///----------------
/// @name Migration Status
///----------------
/**
 The following constants are provided by migrationStatus.

    typedef NS_ENUM(NSInteger, TPMigrationManagerMigrationStatus)
    {
      TPMigrationManagerMigrationStatusSameModel,
      TPMigrationManagerMigrationStatusAnyMappingModel,
      TPMigrationManagerMigrationStatusInferredMappingModel,
      TPMigrationManagerMigrationStatusSpecificMappingModel,
      TPMigrationManagerMigrationStatusNoMappingModel,
      TPMigrationManagerMigrationStatusNoManagedObjectModel,
      TPMigrationManagerMigrationStatusNoPersistentStore,
      TPMigrationManagerMigrationStatusCorruptedStore,
    };

 @name Constants
 `TPMigrationManagerMigrationStatusSameModel`
  Old and new model is same and no need to migrate.

 `TPMigrationManagerMigrationStatusAnyMappingModel`
 Need migration, and you can use both
 migrateByInferredMappingModelWithOptions:completed: and
 migrateBySpecificMappingModelWithOptions:progress:completed:
 methods.

 `TPMigrationManagerMigrationStatusInferredMappingModel`
 Need migration.  You can use
 migrateByInferredMappingModelWithOptions:completed: method.

 `TPMigrationManagerMigrationStatusSpecificMappingModel`
 Need migration.  You can use
 migrateBySpecificMappingModelWithOptions:progress:completed:
 method.

 `TPMigrationManagerMigrationStatusNoMappingModel`
 There are no suitable mapping model and no way for migration.

 `TPMigrationManagerMigrationStatusNoManagedObjectModel`
 Specified or inferred managed object model is invalid and
 no way for migration.

 `TPMigrationManagerMigrationStatusNoPersistentStore`
 There are no persistent store and no way for migration.

 `TPMigrationManagerMigrationStatusCorruptedStore`
 The target persistent store is corrupt and no way for
 migration.
 */
typedef NS_ENUM(NSInteger, TPMigrationManagerMigrationStatus)
{
  TPMigrationManagerMigrationStatusSameModel,
  TPMigrationManagerMigrationStatusAnyMappingModel,
  TPMigrationManagerMigrationStatusInferredMappingModel,
  TPMigrationManagerMigrationStatusSpecificMappingModel,
  TPMigrationManagerMigrationStatusNoMappingModel,
  TPMigrationManagerMigrationStatusNoManagedObjectModel,
  TPMigrationManagerMigrationStatusNoPersistentStore,
  TPMigrationManagerMigrationStatusCorruptedStore,
};

/**
 The `TPMigrationManager` class provides easy way for
 `CoreData` migration.

 There are two migration ways.

 - Inferred mapping model migration.
 - Specific mapping model migration.

 'Inferred mapping model migration' is an easy and fast
 migration way.  You can use this way with
 migrateByInferredMappingModelWithOptions:completed: method.

 Fot this way, you don't need to prepare any migration
 model.  CoreData framework checks the differences between
 old and new model and tries to migrate automatically.  It
 is Apple's recommendation.  If model is not changed so
 much, you should use this way.  For this migration way, you
 _cannot_ terminate the migration process by cancel method
 and migrationProgress property is not changed at all.

 'Specific mapping model migration' is a flexible migration
 way.  You can use this way with
 migrateBySpecificMappingModelWithOptions:progress:completed:
 method.

 With this way, you can convert any old model to new one by
 offering specific migration model by yourself.  You can
 terminate the migration process anytime by cancel method,
 and migrationProgress property will be updated
 periodically.

 Before starting migration, you should use migrationStatus
 for checking which migration way you can use in your
 environment.

 During migration, temporary persistent store file is
 created and the file is used for migration.  After
 migration completed, the temporary persistent overwites old
 one.  If migration is terminated by cancel method or failed
 by error, old persistent remains as it is.  If you'd like
 to remain old persistent file, you can specify
 `TPMigrationManagerBackupPersistentStoreExtensionOption`
 option in migration method.

 After completing the migration, the existing persistent
 store is replaced to new one regardless of whether you use
 `TPMigrationManagerBackupPersistentStoreExtensionOption`
 option or not.  If you already have a
 NSManagedObjectContext object which is dedicated to old
 persistent store, you have to recreate it for new store.
 */
@interface TPMigrationManager : NSObject

/**
 The new(or destination) managed object model.
 */
@property (strong, nonatomic, readonly)
  NSManagedObjectModel *managedObjectModel;

/**
 The location of an migration target persistent store.
 */
@property (strong, nonatomic, readonly) NSURL *storeURL;

/**
 The persistentStoreType for storeURL.
 */
@property (strong, nonatomic, readonly) NSString *storeType;

/**
 The progress for migration.  Returns a number from 0 to 1
 that indicates the proportion of completeness of the
 migration.  You can observe this value using key-value
 observing.  This property holds valid value only if you use
 migrateByInferredMappingModelWithOptions:completed: method.
 */
@property (assign, nonatomic, readonly) float migrationProgress;

/**
 The entity mapping currently being processed.  You can
 observe this value using key-value observing.  This
 property holds valid value only if use
 migrateByInferredMappingModelWithOptions:completed: method.
 */
@property (strong, nonatomic, readonly) NSEntityMapping *currentEntityMapping;

typedef void(^TPMigrationManagerProgressBlock)(float migrationProgress, NSEntityMapping *currentEntityMapping);
typedef void(^TPMigrationManagerCompletedBlock)(NSError *error);

/**
 Initializes and returns a manager object with specified
 parameters.  It's designated initializer.

 @param model The new(or destination) model.
 @param storeURL The location of an migration target persistent store.
 @param storeType The type of store at storeURL.
 @return An initialized manager object.

 @see initWithBasename:
 */
- (instancetype)initWithManagedObjectModel:(NSManagedObjectModel *)model
                        persistentStoreURL:(NSURL *)storeURL
                       persistentStoreType:(NSString *)storeType;

/**
 Initializes and returns a manager object using the
 specified basename.  The managed object model name and
 persistent store is inferred on Xcode generate basic
 layout.  The persistent store type is assumed as
 `NSSQLiteStoreType`.

 @param basename The basename for managed object model and persistent store.
 @return An initialized manager object.

 @see initWithManagedObjectModel:persistentStoreURL:persistentStoreType:
 */
- (instancetype)initWithBasename:(NSString *)basename;

/**
 Returns the migration status.

 You can use this value for determining whether migration is
 necessary or not, or the way for migration.

 @return An TPMigrationManagerMigrationStatus value.
 */
- (TPMigrationManagerMigrationStatus)migrationStatus;

/**
 Migrates persistent store with inferred mapping model.

 @param options A dictionary of options(See Migration
 Options for possible values).
 @param completedBlock A block object to be executed when
 the migration finishes.  If migration is failed, the
 reason is stored in 'error' parameter.
 */
- (void)migrateByInferredMappingModelWithOptions:(NSDictionary *)options
                                       completed:(TPMigrationManagerCompletedBlock)completedBlock;


/**
 Migrates persistent store with specific mapping model.

 @param options A dictionary of options(See Migration
 Options for possible values).
 @param progressBlock A block object to be executed
 periodically according to migration progress.
 `migrationProgress` parameter and `currentEntityMapping`
 parameter for the blocks are the same as object's properties.
 @param completedBlock A block object to be executed when
 the migration finishes.  If migration is failed, the
 reason is stored in 'error' parameter.
 */
- (void)migrateBySpecificMappingModelWithOptions:(NSDictionary *)options
                                        progress:(TPMigrationManagerProgressBlock)progressBlock
                                       completed:(TPMigrationManagerCompletedBlock)completedBlock;

/**
 Cancel migration process.

 Terminates migration process.  It is effective only if you
 use
 migrateBySpecificMappingModelWithOptions:progress:completed:
 method.  You *cannot* terminate
 migrateByInferredMappingModelWithOptions:completed: method.
 */
- (void)cancel;

///----------------
/// @name Constants
///----------------

/**
 ## Migration Options

 Migration options, specified in the dictionary of options
 when adding a persistent store using
 migrateByInferredMappingModelWithOptions:completed:, or
 migrateBySpecificMappingModelWithOptions:progress:completed:
 method.

 @name Constants

 `TPMigrationManagerBackupPersistentStoreExtensionOption`
 Key to remain old persistent store.

 The corresponding value is an NSString object.  If you'd
 like to keep old persistent store after migration is
 completed, you should specify the extension for the old
 persisten store file name.  The specified value is
 concatenated to the original name.  If you don't specify
 this option, or the specified empty string, the old file is
 overwritten by the new one.
 */
extern NSString * const TPMigrationManagerBackupPersistentStoreExtensionOption;

///----------------
/// @name Error Domain
///----------------

/**
 Constant to TPMigration error domain.
 */
extern NSString * const TPMigrationManageErrorDomain;

///----------------
/// @name Migration Error Codes
///----------------
/**
    enum {
      TPMigrationManageCancelByUserError = 1,
      TPMigrationManageInvalidManagedObjectModel,
    };

 @name Constants
 `TPMigrationManageCancelByUserError`
 Error code for specified user cancel for migration.

 `TPMigrationManageInvalidManagedObjectModel`
 Error code to denote that specified or inferred managed
 object model is invalid.
 */
enum {
  TPMigrationManageCancelByUserError = 1,
  TPMigrationManageInvalidManagedObjectModel,
};

@end

// EOF
