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

#import "ViewController.h"

#import "TPMigrationManager.h"
#import "CoreDataManager.h"

#if TARGET_IPHONE_SIMULATOR
#define MAX_ITEM_NUM 100000
#else
#define MAX_ITEM_NUM 10000
#endif

@interface ViewController ()

@property (strong, nonatomic) TPMigrationManager *migrationManager;

@end

@implementation ViewController

- (TPMigrationManager *)migrationManager
{
  if (_migrationManager) {
    return _migrationManager;
  }
  _migrationManager =
    [[TPMigrationManager alloc]
      initWithBasename:@"TPMigrationManagerExample"];

  return _migrationManager;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];

  self.itemNumber.text = [NSString stringWithFormat:@"%d", MAX_ITEM_NUM];
  self.itemNumber.delegate = self;
  self.progressView.hidden = YES;
  self.indicatorView.hidden = YES;

  [self setupButtonStatus];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
}

- (IBAction)setup:(id)sender
{
  ((UIButton *)sender).enabled = NO;
  self.indicatorView.hidden = NO;
  self.progressView.hidden = YES;
  [self.indicatorView startAnimating];
  self.progressView.progress = 0;
  dispatch_queue_t queue =
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_async(queue, ^{
      CoreDataManager *cdm =[[CoreDataManager alloc] init];
      [cdm
        setupPersistntStoreWithItemNumber:[self.itemNumber.text integerValue]];
      dispatch_async(dispatch_get_main_queue(), ^{
          [self.indicatorView stopAnimating];
          self.indicatorView.hidden = YES;
          ((UIButton *)sender).enabled = YES;
          [self setupButtonStatus];
        });
    });
}

- (IBAction)migrateAutomatically:(id)sender
{
  ((UIButton *)sender).enabled = NO;
  self.message.text = @"migrating...";
  self.progressView.hidden = YES;
  self.indicatorView.hidden = NO;
  [self.indicatorView startAnimating];

  [self.migrationManager migrateByInferredMappingModelWithOptions:nil
    completed:^(NSError *error) {
      NSString *label = @"done";
      if (error) {
        label = @"error";
      }
      dispatch_async(dispatch_get_main_queue(), ^{
          self.message.text = label;
          [self.indicatorView stopAnimating];
          self.progressView.hidden = YES;
          self.indicatorView.hidden = YES;
          [self setupButtonStatus];
        });
    }
  ];
}

- (IBAction)migrateManually:(id)sender
{
  ((UIButton *)sender).enabled = NO;
  self.message.text = @"migrating...";
  self.progressView.hidden = NO;
  self.indicatorView.hidden = YES;
  self.progressView.progress = 0;

  [self.migrationManager migrateBySpecificMappingModelWithOptions:nil
    progress:^(float migrationProgress,
               NSEntityMapping *currentEntityMapping) {
      dispatch_async(dispatch_get_main_queue(), ^{
          self.progressView.progress = migrationProgress;
        });
    }
    completed:^(NSError *error) {
      NSString *label = @"done";
      if (error) {
        label = @"error";
        if (([[error domain] isEqualToString:TPMigrationManageErrorDomain])
            && [error code] == TPMigrationManageCancelByUserError) {
          label = @"cancelled";
        }
      }
      dispatch_async(dispatch_get_main_queue(), ^{
          self.message.text = label;
          self.progressView.hidden = YES;
          self.indicatorView.hidden = YES;
          [self setupButtonStatus];
        });
    }
  ];
}

- (IBAction)cancel:(id)sender
{
  TPLog(@"cancel");
  [self.migrationManager cancel];
}

#pragma mark -

- (void)setupButtonStatus
{
  self.migrateAutomaticallyButton.enabled = NO;
  self.migrateManuallyButton.enabled = NO;

  TPMigrationManagerMigrationStatus st =
    [self.migrationManager migrationStatus];
  if (st == TPMigrationManagerMigrationStatusAnyMappingModel) {
    self.migrateAutomaticallyButton.enabled = YES;
    self.migrateManuallyButton.enabled = YES;
  } else if (st == TPMigrationManagerMigrationStatusInferredMappingModel) {
    self.migrateAutomaticallyButton.enabled = YES;
  } else if (st == TPMigrationManagerMigrationStatusSpecificMappingModel) {
    self.migrateManuallyButton.enabled = YES;
  }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  if([textField.text length]) {
    [textField resignFirstResponder];
    return YES;
  }

  return NO;
}

@end

// EOF
