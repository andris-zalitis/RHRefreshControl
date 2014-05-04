//
//  RHRefreshControl.m
//  Example
//
//  Created by Ratha Hin on 2/1/14.
//  Copyright (c) 2014 Ratha Hin. All rights reserved.
//

#import "RHRefreshControl.h"
#import "RHRefreshControlConfiguration.h"

static void * KVOContext = &KVOContext;

@interface RHRefreshControl ()

@property (nonatomic, strong) UIView<RHRefreshControlView> *refreshView;
@property (nonatomic, assign) CGFloat minimumForStart;
@property (nonatomic, assign) CGFloat maximumForPull;

@property (nonatomic, assign) RHRefreshState state;

@property (nonatomic, strong) UIScrollView *scrollView;

@end

@implementation RHRefreshControl
{
    UIEdgeInsets _originalInsets;
    BOOL _ignoreInsetChanges;
}

- (id)initWithConfiguration:(RHRefreshControlConfiguration *)configuration {
    self = [super init];
    if (self) {
        _refreshView = configuration.refreshView;
        _minimumForStart = [configuration.minimumForStart floatValue];
        _maximumForPull = [configuration.maximumForPull floatValue];
    }
    
    return self;
}

- (void)attachToScrollView:(UIScrollView *)scrollView {
    _scrollView = scrollView;
    [scrollView insertSubview:self.refreshView atIndex:0];
    
    _originalInsets = scrollView.contentInset;
    [self positionRefreshView];
    
    [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:KVOContext];
    [scrollView addObserver:self forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:KVOContext];
}

- (void)dealloc
{
    [_scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [_scrollView removeObserver:self forKeyPath:@"contentInset"];
}

- (void)positionRefreshView
{
    if (_scrollView) {
        // if we haven't pulled enough to start pulling progress, then position it just above the content
        CGPoint startPosition = CGPointMake(CGRectGetMidX(_scrollView.bounds), -1*(self.minimumForStart) / 2);
        if (_scrollView.contentOffset.y + _originalInsets.top + self.minimumForStart > 0) {
            self.refreshView.center = startPosition;
        } else {
            // now we're pulling, keep the refreshview sticking at the top
            startPosition.y += _scrollView.contentOffset.y + _originalInsets.top + self.minimumForStart;
            self.refreshView.center = startPosition;
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // if it's this class instance that's doing the observation
    if (context == KVOContext) {
        if ([keyPath isEqualToString:@"contentInset"]) {
            // reposition the refresh view when view controller automatically sets insets for our scroll view
            if (! _ignoreInsetChanges) {
                _originalInsets = [[change objectForKey:@"new"] UIEdgeInsetsValue];
                [self positionRefreshView];
            }
        } else if ([keyPath isEqualToString:@"contentOffset"]) {
            
            // if we are just starting the movement
            if (self.state == RHRefreshStateHidden && _scrollView.dragging) {
                [self setState:RHRefreshStateNormal];
            }

            [self positionRefreshView];

             // if we're scrolling while loading then adjust the inset as needed
            if (self.state == RHRefreshStateLoading) {
                // only do it if user released the scrollview and we haven't yet set the contentInset for it
                if (!_scrollView.dragging && _scrollView.contentInset.top == _originalInsets.top) {
                    // take the dragged offset
                    CGFloat offset = MAX((_scrollView.contentOffset.y + _originalInsets.top) * -1, 0);
                    // compare the dragged offset to height of our refresh view, and use the smallest
                    // this allows correctly adjusting scroll indicator - user can hide the refresh view
                    offset = MIN(offset, self.minimumForStart);
                    
                    _ignoreInsetChanges = YES;
                    [UIView animateWithDuration:0.1 animations:^{
                        _scrollView.contentInset = UIEdgeInsetsMake(offset + _originalInsets.top, 0.0f, 0.0f, 0.0f);
                    } completion:^(BOOL finished) {
                        _ignoreInsetChanges = NO;
                    }];
                }
            } else {
                // if we have pulled enough then start loading phase
                if (_scrollView.contentOffset.y + _originalInsets.top + self.minimumForStart <= -self.maximumForPull) {
                    // the state at this point can only be Normal or Pulling
                    if (self.state != RHRefreshStateLoading) {
                        [self setState:RHRefreshStateLoading];
                    }
                } else if (_scrollView.contentOffset.y + _originalInsets.top + self.minimumForStart < 0) { // if we have pulled more than a minimum
                    if (self.state != RHRefreshStatePulling) {
                        [self setState:RHRefreshStatePulling];
                    }
                    
                    CGFloat deltaOffsetY = MIN(fabsf(_scrollView.contentOffset.y + _originalInsets.top + self.minimumForStart), self.maximumForPull);
                    CGFloat percentage = deltaOffsetY / self.maximumForPull;
                    
                    NSLog(@"non zero percentage set!");
                    [self.refreshView updateViewWithPercentage:percentage state:self.state];
                } else {
                    NSLog(@"zero percentage set!");
                    [self.refreshView updateViewWithPercentage:0 state:self.state];
                }
            }
        }
    }
}

- (void)beginRefreshing
{
    if (self.state != RHRefreshStateLoading) {
        [self setState:RHRefreshStateLoading];
        [UIView animateWithDuration:0.3 animations:^{
            _scrollView.contentOffset = CGPointMake(_scrollView.contentOffset.x, - (_originalInsets.top + self.minimumForStart));
        }];
    }
}

- (void)endRefreshing {
    [UIView animateWithDuration:.3 animations:^{
        [_scrollView setContentInset:_originalInsets];
    }];
	
    if ([self.refreshView respondsToSelector:@selector(updateViewOnComplete)]) {
        [self.refreshView updateViewOnComplete];
    }
    
	[self setState:RHRefreshStateHidden];
}

- (void)setState:(RHRefreshState)newState {
    
    switch (newState) {
        case RHRefreshStateNormal:
            [self.refreshView updateViewOnNormalStatePreviousState:_state];
            break;
            
        case RHRefreshStateLoading:
            [self.refreshView updateViewOnLoadingStatePreviousState:_state];
            
            if ([_delegate respondsToSelector:@selector(refreshDidTriggerRefresh:)]) {
                [_delegate refreshDidTriggerRefresh:self];
            }
            break;
            
        case RHRefreshStatePulling:
            [self.refreshView updateViewOnPullingStatePreviousState:_state];
            break;
            
        case RHRefreshStateHidden:
            [self.refreshView updateViewOnHiddenStatePreviousState:_state];
            break;
            
        default:
            break;
    }
    
    _state = newState;
    
}

@end
