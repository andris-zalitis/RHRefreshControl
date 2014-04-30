//
//  ViewController.m
//  Example
//
//  Created by Ratha Hin on 1/31/14.
//  Copyright (c) 2014 Ratha Hin. All rights reserved.
//

#import "ViewController.h"
#import "RHRefreshControl.h"
#import "CutomRefreshView.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, RHRefreshControlDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) RHRefreshControl *refreshControl;
@property (nonatomic, assign, getter = isLoading) BOOL loading;

@end

@implementation ViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
//  CutomRefreshView *customRefreshView = [[CutomRefreshView alloc] initWithFrame:CGRectMake(0, 0, 320, 60)];
  
  RHRefreshControlConfiguration *refreshConfiguration = [[RHRefreshControlConfiguration alloc] init];
    refreshConfiguration.minimumForStart = @30;
  refreshConfiguration.refreshView = RHRefreshViewStylePinterest;
  //  refreshConfiguration.minimumForStart = @0;
  //  refreshConfiguration.maximumForPull = @120;
  self.refreshControl = [[RHRefreshControl alloc] initWithConfiguration:refreshConfiguration];
  self.refreshControl.delegate = self;
  self.tableView.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1.0];
  
  if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]) {
    self.automaticallyAdjustsScrollViewInsets = NO;
  }
  
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    
//    self.tableView.contentInset = UIEdgeInsetsMake(64, 0, 0, 0);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.refreshControl attachToScrollView:self.tableView];
    
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - TableView Datasource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return 15;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell"];
  cell.textLabel.text = [NSString stringWithFormat:@"Row %ld", indexPath.row];
  return cell;
}

#pragma mark - TableView ScrollView

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
	
	[self.refreshControl refreshScrollViewDidScroll:scrollView];
//    NSLog(@"scrolled, offset %f", scrollView.contentOffset.y);
  
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
	
	[self.refreshControl refreshScrollViewDidEndDragging:scrollView];
	
}

#pragma mark - RHRefreshControl Delegate
- (void)refreshDidTriggerRefresh:(RHRefreshControl *)refreshControl {
    self.loading = YES;
	
	[self performSelector:@selector(_fakeLoadComplete) withObject:nil afterDelay:10.0];
}

- (BOOL)refreshDataSourceIsLoading:(RHRefreshControl *)refreshControl {
	return self.isLoading; // should return if data source model is reloading
	
}

- (void) _fakeLoadComplete {
  self.loading = NO;
  [self.refreshControl refreshScrollViewDataSourceDidFinishedLoading:self.tableView];
}

@end
