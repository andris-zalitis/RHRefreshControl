//
//  RHRefreshControl.h
//  Example
//
//  Created by Ratha Hin on 2/1/14.
//  Copyright (c) 2014 Ratha Hin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RHRefreshControlView.h"
#import "RHRefreshControlConfiguration.h"

typedef NS_ENUM(NSInteger, RHRefreshState) {
    RHRefreshStateHidden,
    RHRefreshStateNormal,
    RHRefreshStatePulling,
    RHRefreshStateLoading,
};

@class RHRefreshControlConfiguration;
@protocol RHRefreshControlDelegate;

@interface RHRefreshControl : NSObject

@property (nonatomic, weak) id<RHRefreshControlDelegate> delegate;
@property (nonatomic, assign) UIEdgeInsets existingInsets;

- (id)initWithConfiguration:(RHRefreshControlConfiguration *)configuration;
- (void)attachToScrollView:(UIScrollView *)scrollView;

- (void)endRefreshing;

- (void)beginRefreshing;

@end


@protocol RHRefreshControlDelegate <NSObject>

- (void)refreshDidTriggerRefresh:(RHRefreshControl *)refreshControl;

@end
